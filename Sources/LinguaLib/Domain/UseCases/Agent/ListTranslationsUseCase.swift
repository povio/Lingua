import Foundation

public struct TranslationRow: Encodable {
  public let section: String
  public let key: String
  public let row: Int
  public let values: [String: [String: String]]
  // values["en"]["other"] = "Hello"
}

public struct ListTranslationsResult: Encodable {
  public let canonicalSheet: String
  public let languages: [String]
  public let rows: [TranslationRow]
}

public protocol ListingTranslations {
  func listTranslations(filterSection: String?) async throws -> ListTranslationsResult
}

public struct ListTranslationsUseCase: ListingTranslations {
  private let sheetDataLoader: SheetDataLoader
  private let preferredSheet: String?

  public init(sheetDataLoader: SheetDataLoader, preferredSheet: String?) {
    self.sheetDataLoader = sheetDataLoader
    self.preferredSheet = preferredSheet
  }

  public func listTranslations(filterSection: String?) async throws -> ListTranslationsResult {
    let sheets = try await sheetDataLoader.loadSheets()
    guard let canonical = CanonicalSheetSelector.pick(from: sheets, preferred: preferredSheet) else {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }

    let rows: [TranslationRow] = canonical.entries.compactMap { entry in
      if let filterSection, entry.section != filterSection { return nil }
      var values: [String: [String: String]] = [:]
      for sheet in sheets {
        if let match = sheet.entries.first(where: { $0.section == entry.section && $0.key == entry.key }) {
          values[sheet.languageCode] = match.translations
        }
      }
      return TranslationRow(section: entry.section, key: entry.key, row: entry.sheetRow, values: values)
    }

    return ListTranslationsResult(
      canonicalSheet: canonical.language,
      languages: sheets.map(\.language),
      rows: rows
    )
  }
}
