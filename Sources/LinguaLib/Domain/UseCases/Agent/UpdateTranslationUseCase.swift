import Foundation

public struct TranslationUpdate {
  public let section: String
  public let key: String
  public let assignments: [ValueAssignment]

  public init(section: String, key: String, assignments: [ValueAssignment]) {
    self.section = section
    self.key = key
    self.assignments = assignments
  }
}

public struct UpdatedTranslation: Encodable {
  public let section: String
  public let key: String
  public let rowIndex: Int
  public let resolvedDefaultForm: String
  public let cellsUpdated: [UpdatedCell]
  public let languagesSkipped: [String]
}

public struct UpdatedCell: Encodable {
  public let tab: String
  public let column: String   // letter, e.g. "D"
  public let form: String     // resolved plural form
}

public protocol UpdatingTranslation {
  func update(_ update: TranslationUpdate) async throws -> UpdatedTranslation
  func updateBatch(_ updates: [TranslationUpdate]) async throws -> UpdatedBatch
}

public struct UpdatedBatchEntry: Encodable {
  public let section: String
  public let key: String
  public let rowIndex: Int
  public let cellsUpdated: [UpdatedCell]
}

public struct UpdatedBatch: Encodable {
  public let totalUpdated: Int
  public let items: [UpdatedBatchEntry]
  public let notFound: [NotFoundEntry]
}

public struct NotFoundEntry: Encodable {
  public let section: String
  public let key: String
}

public struct UpdateTranslationUseCase: UpdatingTranslation {
  private let sheetDataLoader: SheetDataLoader
  private let writer: GoogleSheetsWriting
  private let preferredSheet: String?

  init(sheetDataLoader: SheetDataLoader, writer: GoogleSheetsWriting, preferredSheet: String?) {
    self.sheetDataLoader = sheetDataLoader
    self.writer = writer
    self.preferredSheet = preferredSheet
  }

  public func update(_ update: TranslationUpdate) async throws -> UpdatedTranslation {
    let sheets = try await sheetDataLoader.loadSheets()
    guard let canonical = CanonicalSheetSelector.pick(from: sheets, preferred: preferredSheet) else {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }

    guard let offset = canonical.entries.firstIndex(where: { $0.section == update.section && $0.key == update.key }) else {
      throw AgentError(
        code: "not_found",
        message: "No row found for section '\(update.section)' / key '\(update.key)'.",
        details: ["section": update.section, "key": update.key]
      )
    }
    // Use the entry's recorded sheet row (preserves blank separator rows) rather than the
    // entries-array index.
    let rowIndex = canonical.entries[offset].sheetRow

    // Validate plural forms.
    for a in update.assignments {
      if let form = a.form, PluralColumnLayout.column(forForm: form) == nil {
        throw AgentError(
          code: "invalid_plural_form",
          message: "Unknown plural form '\(form)'. Valid: \(PluralColumnLayout.formsInColumnOrder.joined(separator: ", "))",
          details: ["form": form]
        )
      }
    }

    // For updates, the default form is detected by inspecting the existing row itself: if the
    // row already has `one` filled, that's the column we update; if `other` is the only filled
    // form, we use that. Falling back to sheet-wide detection if neither is filled.
    let existingForms: [String] = canonical.entries[offset].translations
      .filter { !$0.value.isEmpty }
      .map { $0.key }
    let defaultForm: String = {
      if existingForms.count == 1, let only = existingForms.first { return only }
      if existingForms.contains("one") { return "one" }
      if existingForms.contains("other") { return "other" }
      return PluralColumnLayout.detectDefaultForm(in: canonical.entries)
    }()

    // Group assignments by language.
    let assignmentsByLang = Dictionary(grouping: update.assignments, by: \.language)

    var cellsUpdated: [UpdatedCell] = []
    var languagesSkipped: [String] = []

    for sheet in sheets {
      guard let assignments = assignmentsByLang[sheet.languageCode] else {
        languagesSkipped.append(sheet.language)
        continue
      }

      // Confirm the row exists in this tab at the same position. Misalignment → abort.
      let theseKeys = sheet.entries.map { "\($0.section)::\($0.key)" }
      let canonicalKeys = canonical.entries.map { "\($0.section)::\($0.key)" }
      guard theseKeys == canonicalKeys else {
        throw AgentError(
          code: "tabs_out_of_sync",
          message: "Language tab '\(sheet.language)' is not aligned with canonical tab '\(canonical.language)'.",
          details: ["misalignedTab": sheet.language]
        )
      }

      for a in assignments {
        let form = a.form ?? defaultForm
        guard let column = PluralColumnLayout.column(forForm: form) else { continue }
        try await writer.updateCell(
          sheetTab: sheet.language,
          oneBasedRow: rowIndex,
          oneBasedColumn: column,
          value: a.text
        )
        cellsUpdated.append(UpdatedCell(
          tab: sheet.language,
          column: GoogleSheetsWriter.columnLetters(forIndex: column),
          form: form
        ))
      }
    }

    return UpdatedTranslation(
      section: update.section,
      key: update.key,
      rowIndex: rowIndex,
      resolvedDefaultForm: defaultForm,
      cellsUpdated: cellsUpdated,
      languagesSkipped: languagesSkipped
    )
  }

  public func updateBatch(_ updates: [TranslationUpdate]) async throws -> UpdatedBatch {
    let sheets = try await sheetDataLoader.loadSheets()
    guard let canonical = CanonicalSheetSelector.pick(from: sheets, preferred: preferredSheet) else {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }

    // One alignment check up front (vs once per item) — every cell write below assumes the
    // canonical row position matches every other tab's row position.
    let canonicalKeys = canonical.entries.map { "\($0.section)::\($0.key)" }
    for sheet in sheets where sheet.language != canonical.language {
      let theseKeys = sheet.entries.map { "\($0.section)::\($0.key)" }
      if theseKeys != canonicalKeys {
        throw AgentError(
          code: "tabs_out_of_sync",
          message: "Language tab '\(sheet.language)' is not aligned with canonical tab '\(canonical.language)'.",
          details: ["misalignedTab": sheet.language]
        )
      }
    }

    // Plural-form validation up front.
    for update in updates {
      for a in update.assignments {
        if let form = a.form, PluralColumnLayout.column(forForm: form) == nil {
          throw AgentError(
            code: "invalid_plural_form",
            message: "Unknown plural form '\(form)'. Valid: \(PluralColumnLayout.formsInColumnOrder.joined(separator: ", "))",
            details: ["form": form]
          )
        }
      }
    }

    var edits: [SheetBatchEdit] = []
    var entries: [UpdatedBatchEntry] = []
    var notFound: [NotFoundEntry] = []

    for update in updates {
      guard let offset = canonical.entries.firstIndex(where: { $0.section == update.section && $0.key == update.key }) else {
        notFound.append(NotFoundEntry(section: update.section, key: update.key))
        continue
      }
      let rowIndex = canonical.entries[offset].sheetRow
      let existingForms = canonical.entries[offset].translations.filter { !$0.value.isEmpty }.map { $0.key }
      let defaultForm: String = {
        if existingForms.count == 1, let only = existingForms.first { return only }
        if existingForms.contains("one") { return "one" }
        if existingForms.contains("other") { return "other" }
        return PluralColumnLayout.detectDefaultForm(in: canonical.entries)
      }()

      let assignmentsByLang = Dictionary(grouping: update.assignments, by: \.language)
      var cells: [UpdatedCell] = []
      for sheet in sheets {
        guard let assignments = assignmentsByLang[sheet.languageCode] else { continue }
        for a in assignments {
          let form = a.form ?? defaultForm
          guard let column = PluralColumnLayout.column(forForm: form) else { continue }
          edits.append(SheetBatchEdit(
            sheetTab: sheet.language,
            startRow: rowIndex,
            startColumn: column,
            rows: [[a.text]],
            mode: .writeOnly
          ))
          cells.append(UpdatedCell(
            tab: sheet.language,
            column: GoogleSheetsWriter.columnLetters(forIndex: column),
            form: form
          ))
        }
      }
      entries.append(UpdatedBatchEntry(
        section: update.section,
        key: update.key,
        rowIndex: rowIndex,
        cellsUpdated: cells
      ))
    }

    if !edits.isEmpty {
      try await writer.applyBatchEdits(edits)
    }

    return UpdatedBatch(
      totalUpdated: entries.count,
      items: entries,
      notFound: notFound
    )
  }
}
