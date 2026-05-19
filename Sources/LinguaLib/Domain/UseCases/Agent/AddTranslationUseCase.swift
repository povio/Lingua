import Foundation

public struct NewTranslation {
  public let section: String
  public let key: String
  /// One value per (language, plural-form). Forms with `nil` are resolved to the sheet's
  /// detected default convention (`one` for most templates) at execution time.
  public let assignments: [ValueAssignment]
  public let allowNewSection: Bool
  public let dryRun: Bool

  public init(section: String, key: String, assignments: [ValueAssignment], allowNewSection: Bool, dryRun: Bool) {
    self.section = section
    self.key = key
    self.assignments = assignments
    self.allowNewSection = allowNewSection
    self.dryRun = dryRun
  }
}

public struct AddedTranslation: Encodable {
  public let section: String
  public let key: String
  public let rowIndex: Int
  public let createdNewSection: Bool
  public let resolvedDefaultForm: String
  public let languagesWritten: [String]
  public let languagesSkipped: [String]
  public let dryRun: Bool
}

public protocol AddingTranslation {
  func add(_ translation: NewTranslation) async throws -> AddedTranslation
  func addBatch(_ batch: AddTranslationBatch) async throws -> AddedBatch
}

public struct NewTranslationBatchItem: Equatable {
  public let section: String
  public let key: String
  public let assignments: [ValueAssignment]

  public init(section: String, key: String, assignments: [ValueAssignment]) {
    self.section = section
    self.key = key
    self.assignments = assignments
  }
}

public struct AddTranslationBatch: Equatable {
  public let items: [NewTranslationBatchItem]
  public let allowNewSections: Bool
  public let dryRun: Bool

  public init(items: [NewTranslationBatchItem], allowNewSections: Bool, dryRun: Bool) {
    self.items = items
    self.allowNewSections = allowNewSections
    self.dryRun = dryRun
  }
}

public struct AddedBatchEntry: Encodable {
  public let section: String
  public let key: String
  public let rowIndex: Int
  public let createdNewSection: Bool
}

public struct AddedBatch: Encodable {
  public let totalAdded: Int
  public let createdSections: [String]
  public let resolvedDefaultForm: String
  public let languagesWritten: [String]
  public let languagesSkipped: [String]
  public let items: [AddedBatchEntry]
  public let dryRun: Bool
}

public struct AddTranslationUseCase: AddingTranslation {
  private let sheetDataLoader: SheetDataLoader
  private let writer: GoogleSheetsWriting
  private let preferredSheet: String?

  init(sheetDataLoader: SheetDataLoader, writer: GoogleSheetsWriting, preferredSheet: String?) {
    self.sheetDataLoader = sheetDataLoader
    self.writer = writer
    self.preferredSheet = preferredSheet
  }

  public func add(_ translation: NewTranslation) async throws -> AddedTranslation {
    let sheets = try await sheetDataLoader.loadSheets()
    guard let canonical = CanonicalSheetSelector.pick(from: sheets, preferred: preferredSheet) else {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }

    try assertTabsAligned(sheets: sheets, canonical: canonical)

    // Reject duplicates anywhere in the canonical tab.
    if canonical.entries.contains(where: { $0.section == translation.section && $0.key == translation.key }) {
      throw AgentError(
        code: "duplicate_key",
        message: "Key '\(translation.key)' already exists in section '\(translation.section)'.",
        details: ["section": translation.section, "key": translation.key]
      )
    }

    // Resolve insertion point. We use the entries' actual sheet rows (which preserve blank
    // separator rows) instead of computing from the entries-array index, so the math stays
    // correct even when sections are visually separated by blank rows.
    let sectionExists = canonical.entries.contains(where: { $0.section == translation.section })
    var createdNewSection = false
    let insertionRow: Int

    if sectionExists {
      let lastEntryInSection = canonical.entries.last { $0.section == translation.section }!
      insertionRow = lastEntryInSection.sheetRow + 1
    } else {
      guard translation.allowNewSection else {
        let suggestions = Self.closestSections(to: translation.section, in: canonical.entries, limit: 3)
        throw AgentError(
          code: "unknown_section",
          message: "Section '\(translation.section)' does not exist. Pass --new-section to create it. Closest matches: \(suggestions.joined(separator: ", "))",
          details: ["suggestions": suggestions.joined(separator: ",")]
        )
      }
      // Append at the bottom of the sheet, leaving exactly one blank separator row above the
      // new section if the sheet already has any data. The blank row makes the sheet far more
      // readable for humans browsing it, and because every other use case looks up rows by
      // `entry.sheetRow` rather than by entries-array index, future adds/updates/deletes to
      // this new section continue to target the correct row.
      if let lastOverall = canonical.entries.last {
        insertionRow = lastOverall.sheetRow + 2
      } else {
        insertionRow = 2 // empty sheet — first data row right after the header
      }
      createdNewSection = true
    }

    // Validate plural forms before doing any I/O.
    let defaultForm = PluralColumnLayout.detectDefaultForm(in: canonical.entries)
    for a in translation.assignments {
      if let form = a.form, PluralColumnLayout.column(forForm: form) == nil {
        throw AgentError(
          code: "invalid_plural_form",
          message: "Unknown plural form '\(form)'. Valid: \(PluralColumnLayout.formsInColumnOrder.joined(separator: ", "))",
          details: ["form": form]
        )
      }
    }

    // Group assignments per language so we can build one row per language tab.
    let assignmentsByLang = Dictionary(grouping: translation.assignments, by: \.language)

    var languagesWritten: [String] = []
    var languagesSkipped: [String] = []
    for sheet in sheets {
      if assignmentsByLang[sheet.languageCode] != nil {
        languagesWritten.append(sheet.language)
      } else {
        languagesSkipped.append(sheet.language)
      }
    }

    if translation.dryRun {
      return AddedTranslation(
        section: translation.section,
        key: translation.key,
        rowIndex: insertionRow,
        createdNewSection: createdNewSection,
        resolvedDefaultForm: defaultForm,
        languagesWritten: languagesWritten,
        languagesSkipped: languagesSkipped,
        dryRun: true
      )
    }

    // Write the same row position to every language tab so the sheets stay aligned, even when
    // a particular language wasn't supplied (those cells stay blank).
    //
    // For brand-new sections we use `updateRow` (deterministic `values.update` at a known row
    // index) instead of Google's flaky `:append` endpoint, which previously caused some tabs
    // to silently drop the row.
    for sheet in sheets {
      let cells = Self.buildRowCells(
        section: translation.section,
        key: translation.key,
        assignments: assignmentsByLang[sheet.languageCode] ?? [],
        defaultForm: defaultForm
      )
      if createdNewSection {
        try await writer.updateRow(sheetTab: sheet.language, oneBasedRowIndex: insertionRow, cells: cells)
      } else {
        try await writer.insertRow(sheetTab: sheet.language, oneBasedRowIndex: insertionRow, cells: cells)
      }
    }

    return AddedTranslation(
      section: translation.section,
      key: translation.key,
      rowIndex: insertionRow,
      createdNewSection: createdNewSection,
      resolvedDefaultForm: defaultForm,
      languagesWritten: languagesWritten,
      languagesSkipped: languagesSkipped,
      dryRun: false
    )
  }

  // MARK: - Helpers

  /// Builds an 8-cell row by placing each assignment into the column indicated by its plural
  /// form. Assignments with `form == nil` use `defaultForm`. Multiple assignments for the same
  /// language are stacked into the same row (e.g. for plural `one` + `other`).
  static func buildRowCells(section: String, key: String, assignments: [ValueAssignment], defaultForm: String) -> [String] {
    var cells = Array(repeating: "", count: PluralColumnLayout.columnsPerRow)
    cells[0] = section
    cells[1] = key
    for a in assignments {
      let form = a.form ?? defaultForm
      guard let column = PluralColumnLayout.column(forForm: form) else { continue }
      cells[column - 1] = a.text
    }
    return cells
  }

  /// Verifies every language tab has the same `(section, key)` rows in the same order. Aborts
  /// if not — silently writing into a misaligned sheet would corrupt the localization.
  private func assertTabsAligned(sheets: [LocalizationSheet], canonical: LocalizationSheet) throws {
    let canonicalKeys = canonical.entries.map { "\($0.section)::\($0.key)" }
    for sheet in sheets where sheet.language != canonical.language {
      let theseKeys = sheet.entries.map { "\($0.section)::\($0.key)" }
      if theseKeys != canonicalKeys {
        throw AgentError(
          code: "tabs_out_of_sync",
          message: "Language tab '\(sheet.language)' is not aligned with canonical tab '\(canonical.language)'. Run `lingua doctor` for details.",
          details: ["misalignedTab": sheet.language]
        )
      }
    }
  }

  static func closestSections(to query: String, in entries: [LocalizationEntry], limit: Int) -> [String] {
    let unique = Array(Set(entries.map(\.section)))
    return unique
      .map { (name: $0, distance: levenshtein($0.lowercased(), query.lowercased())) }
      .sorted { $0.distance < $1.distance }
      .prefix(limit)
      .map(\.name)
  }
}

// MARK: - Batch

extension AddTranslationUseCase {
  public func addBatch(_ batch: AddTranslationBatch) async throws -> AddedBatch {
    let sheets = try await sheetDataLoader.loadSheets()
    guard let canonical = CanonicalSheetSelector.pick(from: sheets, preferred: preferredSheet) else {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }

    try assertTabsAligned(sheets: sheets, canonical: canonical)

    // Validate plural forms up-front so we can fail fast without doing any work.
    for item in batch.items {
      for a in item.assignments {
        if let form = a.form, PluralColumnLayout.column(forForm: form) == nil {
          throw AgentError(
            code: "invalid_plural_form",
            message: "Unknown plural form '\(form)'. Valid: \(PluralColumnLayout.formsInColumnOrder.joined(separator: ", "))",
            details: ["form": form]
          )
        }
      }
    }

    // Reject duplicates against the canonical sheet AND within the batch itself.
    var seenIdentities = Set(canonical.entries.map { "\($0.section)::\($0.key)" })
    for item in batch.items {
      let identity = "\(item.section)::\(item.key)"
      if seenIdentities.contains(identity) {
        throw AgentError(
          code: "duplicate_key",
          message: "Key '\(item.key)' already exists in section '\(item.section)'.",
          details: ["section": item.section, "key": item.key]
        )
      }
      seenIdentities.insert(identity)
    }

    let defaultForm = PluralColumnLayout.detectDefaultForm(in: canonical.entries)
    let existingSections = Set(canonical.entries.map(\.section))

    // Group items by section, preserving first-seen order so multiple items going to the same
    // section land as a contiguous block of consecutive rows.
    var sectionOrder: [String] = []
    var itemsBySection: [String: [NewTranslationBatchItem]] = [:]
    for item in batch.items {
      if itemsBySection[item.section] == nil {
        sectionOrder.append(item.section)
      }
      itemsBySection[item.section, default: []].append(item)
    }

    struct SectionPlan {
      let section: String
      let firstRow: Int
      let isNew: Bool
      let items: [NewTranslationBatchItem]
    }

    var plans: [SectionPlan] = []
    // Tracks the last row "used" by planning so far. New sections appended at the bottom
    // advance this cursor by (their item count) — each new section also reserves one blank
    // separator row above itself, baked into the `+2` offset below.
    var newSectionCursor = canonical.entries.last?.sheetRow ?? 1

    for section in sectionOrder {
      guard let sectionItems = itemsBySection[section] else { continue }
      if existingSections.contains(section) {
        let lastInSection = canonical.entries.last { $0.section == section }!
        plans.append(SectionPlan(
          section: section,
          firstRow: lastInSection.sheetRow + 1,
          isNew: false,
          items: sectionItems
        ))
      } else {
        guard batch.allowNewSections else {
          let suggestions = Self.closestSections(to: section, in: canonical.entries, limit: 3)
          throw AgentError(
            code: "unknown_section",
            message: "Section '\(section)' does not exist. Pass --new-section to create it. Closest matches: \(suggestions.joined(separator: ", "))",
            details: ["suggestions": suggestions.joined(separator: ",")]
          )
        }
        let firstRow = newSectionCursor + 2
        plans.append(SectionPlan(
          section: section,
          firstRow: firstRow,
          isNew: true,
          items: sectionItems
        ))
        newSectionCursor = firstRow + sectionItems.count - 1
      }
    }

    // Build the per-tab edits. Each plan produces one edit per language tab so the same row
    // range receives the right cells in every language sheet — keeping the tabs aligned.
    var edits: [SheetBatchEdit] = []
    var addedItems: [AddedBatchEntry] = []
    var createdSections: [String] = []

    for plan in plans {
      if plan.isNew {
        createdSections.append(plan.section)
      }
      var nextRow = plan.firstRow
      for item in plan.items {
        addedItems.append(AddedBatchEntry(
          section: item.section,
          key: item.key,
          rowIndex: nextRow,
          createdNewSection: plan.isNew
        ))
        nextRow += 1
      }
      for sheet in sheets {
        let rows: [[String]] = plan.items.map { item in
          let langAssignments = item.assignments.filter { $0.language == sheet.languageCode }
          return Self.buildRowCells(
            section: item.section,
            key: item.key,
            assignments: langAssignments,
            defaultForm: defaultForm
          )
        }
        edits.append(SheetBatchEdit(
          sheetTab: sheet.language,
          startRow: plan.firstRow,
          rows: rows,
          mode: plan.isNew ? .writeOnly : .insertRows
        ))
      }
    }

    let allLangsTouched = Set(batch.items.flatMap { $0.assignments.map(\.language) })
    var languagesWritten: [String] = []
    var languagesSkipped: [String] = []
    for sheet in sheets {
      if allLangsTouched.contains(sheet.languageCode) {
        languagesWritten.append(sheet.language)
      } else {
        languagesSkipped.append(sheet.language)
      }
    }

    if !batch.dryRun {
      try await writer.applyBatchEdits(edits)
    }

    return AddedBatch(
      totalAdded: batch.items.count,
      createdSections: createdSections,
      resolvedDefaultForm: defaultForm,
      languagesWritten: languagesWritten,
      languagesSkipped: languagesSkipped,
      items: addedItems,
      dryRun: batch.dryRun
    )
  }
}

/// Compact iterative Levenshtein. Used only for "did you mean…" hints.
func levenshtein(_ a: String, _ b: String) -> Int {
  let aChars = Array(a)
  let bChars = Array(b)
  if aChars.isEmpty { return bChars.count }
  if bChars.isEmpty { return aChars.count }
  var prev = Array(0...bChars.count)
  var curr = Array(repeating: 0, count: bChars.count + 1)
  for i in 1...aChars.count {
    curr[0] = i
    for j in 1...bChars.count {
      let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
      curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
    }
    swap(&prev, &curr)
  }
  return prev[bChars.count]
}
