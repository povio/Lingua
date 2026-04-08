import XCTest
@testable import LinguaLib

final class AddTranslationUseCaseTests: XCTestCase {

  // MARK: - Section-aware insertion

  func test_add_insertsAtEndOfTargetSection_whenSectionExists() async throws {
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title", "one"),
        ("welcome", "subtitle", "one"),
        ("onboarding", "step_1", "one"),
        ("onboarding", "step_2", "one"),
        ("errors", "generic", "one")
      ]),
      sheet(language: "de_DE_German", entries: [
        ("welcome", "title", "one"),
        ("welcome", "subtitle", "one"),
        ("onboarding", "step_1", "one"),
        ("onboarding", "step_2", "one"),
        ("errors", "generic", "one")
      ])
    ]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.add(NewTranslation(
      section: "onboarding",
      key: "step_3",
      assignments: [
        ValueAssignment(language: "en", form: nil, text: "Step 3"),
        ValueAssignment(language: "de", form: nil, text: "Schritt 3")
      ],
      allowNewSection: false,
      dryRun: false
    ))

    // step_2 is at offset 3 → row 5. Insertion goes at row 6 (last_row + 1).
    XCTAssertEqual(result.rowIndex, 6)
    XCTAssertFalse(result.createdNewSection)
    XCTAssertEqual(result.resolvedDefaultForm, "one") // existing rows use `one`
    XCTAssertEqual(writer.inserts.count, 2)
    XCTAssertEqual(writer.inserts[0].row, 6)
    XCTAssertEqual(writer.inserts[0].cells[0], "onboarding")
    XCTAssertEqual(writer.inserts[0].cells[1], "step_3")
    // Auto-detected default form is `one` → column D (1-based 4 → array index 3).
    XCTAssertEqual(writer.inserts[0].cells[3], "Step 3")
    // The "other" column (H, index 7) should NOT be populated.
    XCTAssertEqual(writer.inserts[0].cells[7], "")
  }

  func test_add_writesToBottomRow_whenSectionIsNew_andAllowed_acrossAllTabs() async throws {
    // Two tabs so we can verify the new-section path writes to BOTH (not just the language we
    // supplied a value for). This is the regression that bit us in real-world usage: previously
    // appendRow used Google's :append endpoint which silently dropped tabs whose only populated
    // cell was the section/key metadata, leaving them misaligned.
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title", "one"),     // sheetRow 2
        ("onboarding", "step_1", "one")  // sheetRow 3
      ]),
      sheet(language: "de_DE_German", entries: [
        ("welcome", "title", "one"),
        ("onboarding", "step_1", "one")
      ])
    ]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.add(NewTranslation(
      section: "favorites",
      key: "empty_state",
      assignments: [ValueAssignment(language: "en", form: nil, text: "No favorites yet")],
      allowNewSection: true,
      dryRun: false
    ))

    XCTAssertTrue(result.createdNewSection)
    // Last entry sheetRow = 3, so the new section row lands at 3 + 2 = 5 (row 4 stays blank
    // as a visual separator). This is the auto-separator behavior for new sections.
    XCTAssertEqual(result.rowIndex, 5)
    XCTAssertEqual(writer.appends.count, 0)
    XCTAssertEqual(writer.updateRows.count, 2)
    XCTAssertEqual(Set(writer.updateRows.map(\.tab)), Set(["en_US_English", "de_DE_German"]))
    XCTAssertTrue(writer.updateRows.allSatisfy { $0.row == 5 })
    let englishRow = writer.updateRows.first { $0.tab == "en_US_English" }!
    let germanRow = writer.updateRows.first { $0.tab == "de_DE_German" }!
    XCTAssertEqual(englishRow.cells[3], "No favorites yet")
    XCTAssertEqual(englishRow.cells[7], "")
    XCTAssertEqual(germanRow.cells[3], "")
    XCTAssertEqual(germanRow.cells[0], "favorites")
    XCTAssertEqual(germanRow.cells[1], "empty_state")
  }

  func test_add_emptySheet_newSection_landsAtRow2_noSeparator() async throws {
    // On a completely empty sheet, there's nothing to separate from — the new section's first
    // row goes right after the header at row 2.
    let sheets = [sheet(language: "en_US_English", entries: [])]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    let result = try await sut.add(NewTranslation(
      section: "general",
      key: "first",
      assignments: [ValueAssignment(language: "en", form: nil, text: "Hi")],
      allowNewSection: true,
      dryRun: false
    ))

    XCTAssertTrue(result.createdNewSection)
    XCTAssertEqual(result.rowIndex, 2)
    XCTAssertEqual(writer.updateRows[0].row, 2)
  }

  func test_add_existingSection_doesNotInsertSeparator() async throws {
    // Adding to an *existing* section just goes to lastRow + 1 — no separator gap.
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title", "one"),    // sheetRow 2
        ("welcome", "subtitle", "one"), // sheetRow 3
      ])
    ]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    let result = try await sut.add(NewTranslation(
      section: "welcome",
      key: "footer",
      assignments: [ValueAssignment(language: "en", form: nil, text: "Bye")],
      allowNewSection: false,
      dryRun: false
    ))

    XCTAssertEqual(result.rowIndex, 4) // 3 + 1, NOT 3 + 2
    XCTAssertEqual(writer.inserts[0].row, 4)
  }

  func test_add_respectsExistingBlankSeparatorRows_whenInsertingIntoSection() async throws {
    // Simulate a sheet that already has a blank separator row between sections. The decoder
    // would record sheetRows like:
    //   row 2: General/save
    //   row 3: General/success
    //   row 4: BLANK (decoder skips it)
    //   row 5: Login/title
    // Adding another key to Login should land at row 6 (Login.lastRow + 1), NOT at row 5 + 1
    // computed from the entries-array index (which would collide with Login/title).
    let sheets = [
      sheetWithRows(language: "en_US_English", entries: [
        ("General", "save", "one", 2),
        ("General", "success", "one", 3),
        ("Login", "title", "one", 5)
      ])
    ]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    let result = try await sut.add(NewTranslation(
      section: "Login",
      key: "subtitle",
      assignments: [ValueAssignment(language: "en", form: nil, text: "Sign in to continue")],
      allowNewSection: false,
      dryRun: false
    ))

    XCTAssertEqual(result.rowIndex, 6) // Login/title is at sheet row 5, so the new row is 6.
    XCTAssertEqual(writer.inserts[0].row, 6)
  }

  // MARK: - Plural form handling (new in this round)

  func test_add_explicitPluralForms_writesEachFormToCorrectColumn() async throws {
    let sheets = [
      sheet(language: "en_US_English", entries: [("general", "save", "one")])
    ]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    _ = try await sut.add(NewTranslation(
      section: "general",
      key: "item_count",
      assignments: [
        ValueAssignment(language: "en", form: "one",   text: "1 item"),
        ValueAssignment(language: "en", form: "other", text: "%d items")
      ],
      allowNewSection: false,
      dryRun: false
    ))

    XCTAssertEqual(writer.inserts.count, 1)
    let row = writer.inserts[0].cells
    XCTAssertEqual(row[3], "1 item")     // column D = "one"
    XCTAssertEqual(row[7], "%d items")   // column H = "other"
  }

  func test_add_autoDetectsDefaultForm_asOther_whenSheetUsesOtherConvention() async throws {
    // Sheet's existing rows live in the "other" column. Lingua should follow that convention
    // for new non-plural strings instead of always defaulting to "one".
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("general", "save", "other"),
        ("general", "cancel", "other")
      ])
    ]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    let result = try await sut.add(NewTranslation(
      section: "general",
      key: "delete",
      assignments: [ValueAssignment(language: "en", form: nil, text: "Delete")],
      allowNewSection: false,
      dryRun: false
    ))

    XCTAssertEqual(result.resolvedDefaultForm, "other")
    XCTAssertEqual(writer.inserts[0].cells[7], "Delete") // column H = "other"
    XCTAssertEqual(writer.inserts[0].cells[3], "")       // column D unused
  }

  func test_add_emptySheet_defaultsToOne() async throws {
    let sheets = [sheet(language: "en_US_English", entries: [])]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    let result = try await sut.add(NewTranslation(
      section: "general",
      key: "first",
      assignments: [ValueAssignment(language: "en", form: nil, text: "Hi")],
      allowNewSection: true,
      dryRun: false
    ))

    XCTAssertEqual(result.resolvedDefaultForm, "one")
    XCTAssertEqual(writer.updateRows[0].cells[3], "Hi")
  }

  func test_add_throwsInvalidPluralForm_forUnknownForm() async {
    let sheets = [sheet(language: "en_US_English", entries: [("general", "save", "one")])]
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyWriter(),
      preferredSheet: nil
    )

    do {
      _ = try await sut.add(NewTranslation(
        section: "general",
        key: "x",
        assignments: [ValueAssignment(language: "en", form: "plural", text: "x")],
        allowNewSection: false,
        dryRun: false
      ))
      XCTFail("Expected invalid_plural_form")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "invalid_plural_form")
    } catch {
      XCTFail("Wrong error: \(error)")
    }
  }

  // MARK: - Existing error paths (kept)

  func test_add_throwsUnknownSection_withSuggestions_whenSectionMissing_andNotAllowed() async {
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title", "one"),
        ("onboarding", "step_1", "one"),
        ("errors", "generic", "one")
      ])
    ]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    do {
      _ = try await sut.add(NewTranslation(
        section: "onboardin",
        key: "x",
        assignments: [ValueAssignment(language: "en", form: nil, text: "x")],
        allowNewSection: false,
        dryRun: false
      ))
      XCTFail("Expected unknown_section error")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "unknown_section")
      XCTAssertTrue(error.details?["suggestions"]?.contains("onboarding") ?? false)
    } catch {
      XCTFail("Wrong error type: \(error)")
    }
    XCTAssertEqual(writer.inserts.count, 0)
  }

  func test_add_throwsDuplicateKey_whenSectionAndKeyExist() async {
    let sheets = [sheet(language: "en_US_English", entries: [("welcome", "title", "one")])]
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyWriter(),
      preferredSheet: nil
    )

    do {
      _ = try await sut.add(NewTranslation(
        section: "welcome",
        key: "title",
        assignments: [ValueAssignment(language: "en", form: nil, text: "Hi")],
        allowNewSection: false,
        dryRun: false
      ))
      XCTFail("Expected duplicate_key error")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "duplicate_key")
    } catch {
      XCTFail("Wrong error type: \(error)")
    }
  }

  func test_add_throwsTabsOutOfSync_whenLanguageTabsDontMatch() async {
    let sheets = [
      sheet(language: "en_US_English", entries: [("welcome", "title", "one"), ("welcome", "subtitle", "one")]),
      sheet(language: "de_DE_German", entries: [("welcome", "title", "one")])
    ]
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyWriter(),
      preferredSheet: "en_US_English"
    )

    do {
      _ = try await sut.add(NewTranslation(
        section: "welcome",
        key: "footer",
        assignments: [ValueAssignment(language: "en", form: nil, text: "Bye")],
        allowNewSection: false,
        dryRun: false
      ))
      XCTFail("Expected tabs_out_of_sync error")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "tabs_out_of_sync")
    } catch {
      XCTFail("Wrong error type: \(error)")
    }
  }

  func test_add_dryRun_doesNotWrite() async throws {
    let sheets = [sheet(language: "en_US_English", entries: [("welcome", "title", "one")])]
    let writer = SpyWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    let result = try await sut.add(NewTranslation(
      section: "welcome",
      key: "subtitle",
      assignments: [ValueAssignment(language: "en", form: nil, text: "Hi")],
      allowNewSection: false,
      dryRun: true
    ))

    XCTAssertTrue(result.dryRun)
    XCTAssertEqual(writer.inserts.count, 0)
    XCTAssertEqual(writer.updateRows.count, 0)
  }

  // MARK: - Helpers

  /// Creates a sheet whose entries have a single value in the given plural-form column.
  /// Lets each test set up the convention it wants to test. By default, sheetRow is computed
  /// as if the sheet has no blank separator rows (entries are contiguous starting at row 2).
  private func sheet(language: String, entries: [(String, String, String)]) -> LocalizationSheet {
    LocalizationSheet(
      language: language,
      entries: entries.enumerated().map { offset, e in
        LocalizationEntry(section: e.0, key: e.1, translations: [e.2: "x"], sheetRow: offset + 2)
      }
    )
  }

  /// Variant for tests that need to simulate blank separator rows: pass explicit sheet rows.
  private func sheetWithRows(language: String, entries: [(String, String, String, Int)]) -> LocalizationSheet {
    LocalizationSheet(
      language: language,
      entries: entries.map { LocalizationEntry(section: $0.0, key: $0.1, translations: [$0.2: "x"], sheetRow: $0.3) }
    )
  }
}

private final class SpyWriter: GoogleSheetsWriting {
  struct RowOp { let tab: String; let row: Int; let cells: [String] }
  struct Append { let tab: String; let cells: [String] }

  var inserts: [RowOp] = []
  var updateRows: [RowOp] = []
  var appends: [Append] = []
  var cellUpdates: [(tab: String, row: Int, col: Int, value: String)] = []
  var deletes: [(tab: String, row: Int)] = []

  func insertRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {
    inserts.append(.init(tab: sheetTab, row: oneBasedRowIndex, cells: cells))
  }
  func updateRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {
    updateRows.append(.init(tab: sheetTab, row: oneBasedRowIndex, cells: cells))
  }
  func appendRow(sheetTab: String, cells: [String]) async throws {
    appends.append(.init(tab: sheetTab, cells: cells))
  }
  func updateCell(sheetTab: String, oneBasedRow: Int, oneBasedColumn: Int, value: String) async throws {
    cellUpdates.append((sheetTab, oneBasedRow, oneBasedColumn, value))
  }
  func deleteRow(sheetTab: String, oneBasedRowIndex: Int) async throws {
    deletes.append((sheetTab, oneBasedRowIndex))
  }
}
