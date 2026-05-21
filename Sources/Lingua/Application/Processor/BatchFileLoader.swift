import Foundation
import LinguaLib

/// Parses the JSON file passed to `lingua add --batch <file>` / `lingua update --batch <file>`.
///
/// File shape (a bare array — the agent can produce this without thinking about wrappers):
///
/// ```json
/// [
///   {
///     "section": "Settings",
///     "key": "title",
///     "values": {"en": "Settings", "de": "Einstellungen"}
///   },
///   {
///     "section": "Cart",
///     "key": "item_count",
///     "values": {
///       "en": {"one": "1 item", "other": "%d items"},
///       "de": {"one": "1 Artikel", "other": "%d Artikel"}
///     }
///   }
/// ]
/// ```
///
/// Each `values` entry is either a plain string (non-plural — the use case picks the right
/// column based on the sheet's detected default form) or a `{form: text}` object for plurals.
enum BatchFileLoader {
  static func loadAddBatch(path: String, allowNewSections: Bool, dryRun: Bool) throws -> AddTranslationBatch {
    let entries = try loadEntries(path: path)
    let items = entries.map { entry in
      NewTranslationBatchItem(
        section: entry.section,
        key: entry.key,
        assignments: entry.toAssignments()
      )
    }
    return AddTranslationBatch(items: items, allowNewSections: allowNewSections, dryRun: dryRun)
  }

  static func loadUpdateBatch(path: String) throws -> [TranslationUpdate] {
    let entries = try loadEntries(path: path)
    return entries.map { entry in
      TranslationUpdate(section: entry.section, key: entry.key, assignments: entry.toAssignments())
    }
  }

  private static func loadEntries(path: String) throws -> [Entry] {
    let url = URL(fileURLWithPath: path)
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      throw AgentError(
        code: "batch_file_unreadable",
        message: "Could not read batch file at '\(path)': \(error.localizedDescription)"
      )
    }
    do {
      return try JSONDecoder().decode([Entry].self, from: data)
    } catch {
      throw AgentError(
        code: "batch_file_invalid",
        message: "Could not parse batch file: \(error.localizedDescription)"
      )
    }
  }
}

private struct Entry: Decodable {
  let section: String
  let key: String
  let values: [String: ValuePayload]

  func toAssignments() -> [ValueAssignment] {
    values.flatMap { language, payload -> [ValueAssignment] in
      switch payload {
      case .plain(let text):
        return [ValueAssignment(language: language, form: nil, text: text)]
      case .plural(let forms):
        return forms.map { form, text in
          ValueAssignment(language: language, form: form, text: text)
        }
      }
    }
  }
}

private enum ValuePayload: Decodable {
  case plain(String)
  case plural([String: String])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let text = try? container.decode(String.self) {
      self = .plain(text)
      return
    }
    if let dict = try? container.decode([String: String].self) {
      self = .plural(dict)
      return
    }
    throw DecodingError.typeMismatch(
      ValuePayload.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "Expected either a string or a {form: text} object."
      )
    )
  }
}
