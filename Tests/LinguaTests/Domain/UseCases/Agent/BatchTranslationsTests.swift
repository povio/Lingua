import XCTest
@testable import LinguaLib

final class BatchTranslationsTests: XCTestCase {

  // MARK: - addBatch

  func test_addBatch_singleSection_insertsAllItemsAsOneBlock() async throws {
    let sheets = makeSheets(entries: [
      ("welcome", "title", 2),
      ("welcome", "subtitle", 3),
      ("onboarding", "step_1", 4)
    ])
    let writer = SpyBatchWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.addBatch(AddTranslationBatch(
      items: [
        item(section: "onboarding", key: "step_2", en: "Two", de: "Zwei"),
        item(section: "onboarding", key: "step_3", en: "Three", de: "Drei")
      ],
      allowNewSections: false,
      dryRun: false
    ))

    XCTAssertEqual(result.totalAdded, 2)
    XCTAssertEqual(result.items.map(\.rowIndex), [5, 6])
    XCTAssertTrue(result.createdSections.isEmpty)

    // 2 tabs × 1 block each = 2 edits. Each is an insertRows with 2 rows.
    XCTAssertEqual(writer.received.count, 2)
    for edit in writer.received {
      XCTAssertEqual(edit.mode, .insertRows)
      XCTAssertEqual(edit.startRow, 5)
      XCTAssertEqual(edit.rows.count, 2)
    }
  }

  func test_addBatch_newSection_writesOnly_withSeparator() async throws {
    let sheets = makeSheets(entries: [
      ("welcome", "title", 2),
      ("welcome", "subtitle", 3)
    ])
    let writer = SpyBatchWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.addBatch(AddTranslationBatch(
      items: [
        item(section: "settings", key: "title", en: "Settings", de: "Einstellungen"),
        item(section: "settings", key: "account", en: "Account", de: "Konto")
      ],
      allowNewSections: true,
      dryRun: false
    ))

    XCTAssertEqual(result.createdSections, ["settings"])
    // Last existing row = 3. New section starts at 3 + 2 = 5 (leaves row 4 blank as separator).
    XCTAssertEqual(result.items.map(\.rowIndex), [5, 6])
    for edit in writer.received {
      XCTAssertEqual(edit.mode, .writeOnly)
      XCTAssertEqual(edit.startRow, 5)
    }
  }

  func test_addBatch_mixedExistingAndNew_plansEachIndependently() async throws {
    let sheets = makeSheets(entries: [
      ("welcome", "title", 2),
      ("welcome", "subtitle", 3),
      ("errors", "generic", 4)
    ])
    let writer = SpyBatchWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.addBatch(AddTranslationBatch(
      items: [
        item(section: "welcome", key: "tagline", en: "Hi", de: "Hi"),
        item(section: "settings", key: "title", en: "Settings", de: "Einstellungen")
      ],
      allowNewSections: true,
      dryRun: false
    ))

    // welcome was at rows 2-3, so the new item slots in at row 4 (existing-section insert).
    // settings is new, lands at lastOverall(4) + 2 = 6.
    XCTAssertEqual(result.items.first(where: { $0.key == "tagline" })?.rowIndex, 4)
    XCTAssertEqual(result.items.first(where: { $0.key == "title" })?.rowIndex, 6)
    XCTAssertEqual(result.createdSections, ["settings"])

    let writeOnly = writer.received.filter { $0.mode == .writeOnly }
    let insertRows = writer.received.filter { $0.mode == .insertRows }
    XCTAssertEqual(writeOnly.count, 2, "one writeOnly per tab for the new section")
    XCTAssertEqual(insertRows.count, 2, "one insertRows per tab for the existing section")
  }

  func test_addBatch_rejectsInBatchDuplicate() async throws {
    let sheets = makeSheets(entries: [("welcome", "title", 2)])
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyBatchWriter(),
      preferredSheet: "en_US_English"
    )

    do {
      _ = try await sut.addBatch(AddTranslationBatch(
        items: [
          item(section: "welcome", key: "subtitle", en: "A", de: "A"),
          item(section: "welcome", key: "subtitle", en: "B", de: "B")
        ],
        allowNewSections: false,
        dryRun: false
      ))
      XCTFail("expected duplicate_key")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "duplicate_key")
    }
  }

  func test_addBatch_unknownSection_withoutAllowNew_returnsSuggestions() async throws {
    let sheets = makeSheets(entries: [
      ("settings", "title", 2),
      ("onboarding", "step_1", 3)
    ])
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyBatchWriter(),
      preferredSheet: "en_US_English"
    )

    do {
      _ = try await sut.addBatch(AddTranslationBatch(
        items: [item(section: "setings", key: "x", en: "A", de: "A")],
        allowNewSections: false,
        dryRun: false
      ))
      XCTFail("expected unknown_section")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "unknown_section")
      XCTAssertTrue(error.details?["suggestions"]?.contains("settings") ?? false)
    }
  }

  func test_addBatch_dryRun_doesNotWrite() async throws {
    let sheets = makeSheets(entries: [("welcome", "title", 2)])
    let writer = SpyBatchWriter()
    let sut = AddTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.addBatch(AddTranslationBatch(
      items: [item(section: "welcome", key: "subtitle", en: "Hi", de: "Hallo")],
      allowNewSections: false,
      dryRun: true
    ))

    XCTAssertTrue(result.dryRun)
    XCTAssertTrue(writer.received.isEmpty)
  }

  // MARK: - updateBatch

  func test_updateBatch_targetsCorrectColumnsPerLanguage() async throws {
    let sheets = makeSheets(entries: [
      ("settings", "title", 2),
      ("settings", "account", 3)
    ])
    let writer = SpyBatchWriter()
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.updateBatch([
      TranslationUpdate(
        section: "settings",
        key: "title",
        assignments: [
          ValueAssignment(language: "en", form: nil, text: "Preferences"),
          ValueAssignment(language: "de", form: nil, text: "Voreinstellungen")
        ]
      )
    ])

    XCTAssertEqual(result.totalUpdated, 1)
    XCTAssertTrue(result.notFound.isEmpty)
    XCTAssertEqual(writer.received.count, 2, "one edit per language tab")
    for edit in writer.received {
      XCTAssertEqual(edit.mode, .writeOnly)
      XCTAssertEqual(edit.startRow, 2)
      // Existing rows have `one` populated → default form column D (1-based 4).
      XCTAssertEqual(edit.startColumn, 4)
      XCTAssertEqual(edit.rows.count, 1)
      XCTAssertEqual(edit.rows[0].count, 1)
    }
  }

  func test_updateBatch_collectsNotFound_withoutAborting() async throws {
    let sheets = makeSheets(entries: [("settings", "title", 2)])
    let writer = SpyBatchWriter()
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.updateBatch([
      TranslationUpdate(
        section: "settings",
        key: "title",
        assignments: [ValueAssignment(language: "en", form: nil, text: "Preferences")]
      ),
      TranslationUpdate(
        section: "settings",
        key: "ghost",
        assignments: [ValueAssignment(language: "en", form: nil, text: "Nope")]
      )
    ])

    XCTAssertEqual(result.totalUpdated, 1)
    XCTAssertEqual(result.notFound.count, 1)
    XCTAssertEqual(result.notFound[0].key, "ghost")
  }

  func test_updateBatch_explicitPluralForm_targetsThatColumn() async throws {
    let sheets = [
      LocalizationSheet(language: "en_US_English", entries: [
        LocalizationEntry(section: "cart", key: "item_count", translations: ["one": "1 item", "other": "%d items"], sheetRow: 2)
      ]),
      LocalizationSheet(language: "de_DE_German", entries: [
        LocalizationEntry(section: "cart", key: "item_count", translations: ["one": "1 Artikel", "other": "%d Artikel"], sheetRow: 2)
      ])
    ]
    let writer = SpyBatchWriter()
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    _ = try await sut.updateBatch([
      TranslationUpdate(
        section: "cart",
        key: "item_count",
        assignments: [ValueAssignment(language: "en", form: "other", text: "%d things")]
      )
    ])

    XCTAssertEqual(writer.received.count, 1)
    // `other` is column H = 1-based 8.
    XCTAssertEqual(writer.received[0].startColumn, 8)
    XCTAssertEqual(writer.received[0].rows[0], ["%d things"])
  }

  // MARK: - Helpers

  private func makeSheets(entries: [(String, String, Int)]) -> [LocalizationSheet] {
    let build: (String) -> LocalizationSheet = { lang in
      LocalizationSheet(
        language: lang,
        entries: entries.map { LocalizationEntry(section: $0.0, key: $0.1, translations: ["one": "x"], sheetRow: $0.2) }
      )
    }
    return [build("en_US_English"), build("de_DE_German")]
  }

  private func item(section: String, key: String, en: String, de: String) -> NewTranslationBatchItem {
    NewTranslationBatchItem(
      section: section,
      key: key,
      assignments: [
        ValueAssignment(language: "en", form: nil, text: en),
        ValueAssignment(language: "de", form: nil, text: de)
      ]
    )
  }
}

// MARK: - Spy

private final class SpyBatchWriter: GoogleSheetsWriting {
  var received: [SheetBatchEdit] = []

  func insertRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {}
  func updateRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {}
  func appendRow(sheetTab: String, cells: [String]) async throws {}
  func updateCell(sheetTab: String, oneBasedRow: Int, oneBasedColumn: Int, value: String) async throws {}
  func deleteRow(sheetTab: String, oneBasedRowIndex: Int) async throws {}
  func applyBatchEdits(_ edits: [SheetBatchEdit]) async throws {
    received.append(contentsOf: edits)
  }
}
