import XCTest
@testable import LinguaLib

final class UpdateTranslationUseCaseTests: XCTestCase {

  func test_update_writesToCorrectColumn_basedOnExistingRowConvention() async throws {
    // Existing row uses `one` column → update should target `one`, not `other`.
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title", ["one": "Welcome"]),
        ("welcome", "subtitle", ["one": "Sub"])
      ]),
      sheet(language: "de_DE_German", entries: [
        ("welcome", "title", ["one": "Willkommen"]),
        ("welcome", "subtitle", ["one": "Untertitel"])
      ])
    ]
    let writer = SpyWriter()
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.update(TranslationUpdate(
      section: "welcome",
      key: "subtitle",
      assignments: [ValueAssignment(language: "en", form: nil, text: "Updated")]
    ))

    XCTAssertEqual(result.rowIndex, 3)
    XCTAssertEqual(result.resolvedDefaultForm, "one")
    XCTAssertEqual(writer.cellUpdates.count, 1)
    XCTAssertEqual(writer.cellUpdates[0].tab, "en_US_English")
    XCTAssertEqual(writer.cellUpdates[0].row, 3)
    XCTAssertEqual(writer.cellUpdates[0].col, 4) // column D = `one`
    XCTAssertEqual(writer.cellUpdates[0].value, "Updated")
  }

  func test_update_explicitForm_targetsThatColumn() async throws {
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("cart", "item_count", ["one": "1 item", "other": "%d items"])
      ])
    ]
    let writer = SpyWriter()
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    _ = try await sut.update(TranslationUpdate(
      section: "cart",
      key: "item_count",
      assignments: [ValueAssignment(language: "en", form: "other", text: "%d things")]
    ))

    XCTAssertEqual(writer.cellUpdates.count, 1)
    XCTAssertEqual(writer.cellUpdates[0].col, 8) // column H = `other`
    XCTAssertEqual(writer.cellUpdates[0].value, "%d things")
  }

  func test_update_throwsNotFound_whenKeyMissing() async {
    let sheets = [sheet(language: "en_US_English", entries: [("welcome", "title", ["one": "Hi"])])]
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyWriter(),
      preferredSheet: nil
    )
    do {
      _ = try await sut.update(TranslationUpdate(
        section: "welcome",
        key: "missing",
        assignments: [ValueAssignment(language: "en", form: nil, text: "x")]
      ))
      XCTFail("Expected not_found")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "not_found")
    } catch {
      XCTFail("Wrong error: \(error)")
    }
  }

  // MARK: - Error paths

  func test_update_throwsNoSheets_whenSheetsEmpty() async {
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success([])),
      writer: SpyWriter(),
      preferredSheet: nil
    )
    await assertAgentError(code: "no_sheets") {
      _ = try await sut.update(TranslationUpdate(
        section: "welcome",
        key: "title",
        assignments: [ValueAssignment(language: "en", form: nil, text: "x")]
      ))
    }
  }

  func test_update_throwsInvalidPluralForm_whenFormUnknown() async {
    let sheets = [sheet(language: "en_US_English", entries: [("welcome", "title", ["one": "Hi"])])]
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyWriter(),
      preferredSheet: nil
    )
    await assertAgentError(code: "invalid_plural_form") {
      _ = try await sut.update(TranslationUpdate(
        section: "welcome",
        key: "title",
        assignments: [ValueAssignment(language: "en", form: "bogus", text: "x")]
      ))
    }
  }

  func test_update_throwsTabsOutOfSync_whenLanguageTabRowsMisaligned() async {
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title", ["one": "Hi"]),
        ("welcome", "subtitle", ["one": "Sub"])
      ]),
      sheet(language: "de_DE_German", entries: [
        ("welcome", "title", ["one": "Hallo"])
        // missing 'subtitle' → misaligned
      ])
    ]
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyWriter(),
      preferredSheet: "en_US_English"
    )
    await assertAgentError(code: "tabs_out_of_sync") {
      _ = try await sut.update(TranslationUpdate(
        section: "welcome",
        key: "title",
        assignments: [ValueAssignment(language: "de", form: nil, text: "x")]
      ))
    }
  }

  func test_update_defaultFormFallsBackToSheetDetection_whenRowHasNoFilledTranslations() async throws {
    // Target row has only empty translations → fallback path: detectDefaultForm picks the
    // dominant form across the sheet. With three other rows using `other`, the fallback is `other`.
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title", ["other": "Hi"]),
        ("welcome", "subtitle", ["other": "Sub"]),
        ("welcome", "footer", ["other": "Foot"]),
        ("welcome", "blank", ["one": "", "other": ""])
      ])
    ]
    let writer = SpyWriter()
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    let result = try await sut.update(TranslationUpdate(
      section: "welcome",
      key: "blank",
      assignments: [ValueAssignment(language: "en", form: nil, text: "Filled")]
    ))

    XCTAssertEqual(result.resolvedDefaultForm, "other")
    XCTAssertEqual(writer.cellUpdates.first?.col, 8) // column H = `other`
  }

  // MARK: - updateBatch

  func test_updateBatch_writesEditsViaApplyBatchEdits() async throws {
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title", ["one": "Hi"]),
        ("welcome", "subtitle", ["one": "Sub"])
      ]),
      sheet(language: "de_DE_German", entries: [
        ("welcome", "title", ["one": "Hallo"]),
        ("welcome", "subtitle", ["one": "Untertitel"])
      ])
    ]
    let writer = SpyWriter()
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: "en_US_English"
    )

    let result = try await sut.updateBatch([
      TranslationUpdate(
        section: "welcome",
        key: "title",
        assignments: [ValueAssignment(language: "de", form: nil, text: "Hi-DE")]
      )
    ])

    XCTAssertEqual(result.totalUpdated, 1)
    XCTAssertEqual(result.items.count, 1)
    XCTAssertTrue(result.notFound.isEmpty)
    XCTAssertEqual(writer.batchEdits.count, 1)
    XCTAssertEqual(writer.batchEdits[0].sheetTab, "de_DE_German")
    XCTAssertEqual(writer.batchEdits[0].startRow, 2)
    XCTAssertEqual(writer.batchEdits[0].startColumn, 4) // `one` column
  }

  func test_updateBatch_recordsNotFound_whenKeyMissing() async throws {
    let sheets = [sheet(language: "en_US_English", entries: [("welcome", "title", ["one": "Hi"])])]
    let writer = SpyWriter()
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer,
      preferredSheet: nil
    )

    let result = try await sut.updateBatch([
      TranslationUpdate(
        section: "welcome",
        key: "missing",
        assignments: [ValueAssignment(language: "en", form: nil, text: "x")]
      )
    ])

    XCTAssertEqual(result.totalUpdated, 0)
    XCTAssertEqual(result.notFound.count, 1)
    XCTAssertEqual(result.notFound[0].key, "missing")
    XCTAssertTrue(writer.batchEdits.isEmpty)
  }

  func test_updateBatch_throwsNoSheets_whenSheetsEmpty() async {
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success([])),
      writer: SpyWriter(),
      preferredSheet: nil
    )
    await assertAgentError(code: "no_sheets") {
      _ = try await sut.updateBatch([
        TranslationUpdate(
          section: "welcome",
          key: "title",
          assignments: [ValueAssignment(language: "en", form: nil, text: "x")]
        )
      ])
    }
  }

  func test_updateBatch_throwsInvalidPluralForm_whenFormUnknown() async {
    let sheets = [sheet(language: "en_US_English", entries: [("welcome", "title", ["one": "Hi"])])]
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyWriter(),
      preferredSheet: nil
    )
    await assertAgentError(code: "invalid_plural_form") {
      _ = try await sut.updateBatch([
        TranslationUpdate(
          section: "welcome",
          key: "title",
          assignments: [ValueAssignment(language: "en", form: "bogus", text: "x")]
        )
      ])
    }
  }

  func test_updateBatch_throwsTabsOutOfSync_whenLanguageTabRowsMisaligned() async {
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title", ["one": "Hi"]),
        ("welcome", "subtitle", ["one": "Sub"])
      ]),
      sheet(language: "de_DE_German", entries: [
        ("welcome", "title", ["one": "Hallo"])
        // missing 'subtitle' → misaligned
      ])
    ]
    let sut = UpdateTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyWriter(),
      preferredSheet: "en_US_English"
    )
    await assertAgentError(code: "tabs_out_of_sync") {
      _ = try await sut.updateBatch([
        TranslationUpdate(
          section: "welcome",
          key: "title",
          assignments: [ValueAssignment(language: "de", form: nil, text: "x")]
        )
      ])
    }
  }

  // MARK: - Helpers

  private func assertAgentError(
    code expectedCode: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ block: () async throws -> Void
  ) async {
    do {
      try await block()
      XCTFail("Expected AgentError(\(expectedCode))", file: file, line: line)
    } catch let error as AgentError {
      XCTAssertEqual(error.code, expectedCode, file: file, line: line)
    } catch {
      XCTFail("Wrong error type: \(error)", file: file, line: line)
    }
  }

  private func sheet(language: String, entries: [(String, String, [String: String])]) -> LocalizationSheet {
    LocalizationSheet(
      language: language,
      entries: entries.enumerated().map { offset, e in
        LocalizationEntry(section: e.0, key: e.1, translations: e.2, sheetRow: offset + 2)
      }
    )
  }
}

private final class SpyWriter: GoogleSheetsWriting {
  var inserts: [(String, Int, [String])] = []
  var appends: [(String, [String])] = []
  var cellUpdates: [(tab: String, row: Int, col: Int, value: String)] = []
  var batchEdits: [SheetBatchEdit] = []

  func insertRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {
    inserts.append((sheetTab, oneBasedRowIndex, cells))
  }
  func updateRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {}
  func appendRow(sheetTab: String, cells: [String]) async throws {
    appends.append((sheetTab, cells))
  }
  func updateCell(sheetTab: String, oneBasedRow: Int, oneBasedColumn: Int, value: String) async throws {
    cellUpdates.append((sheetTab, oneBasedRow, oneBasedColumn, value))
  }
  func deleteRow(sheetTab: String, oneBasedRowIndex: Int) async throws {}
  func applyBatchEdits(_ edits: [SheetBatchEdit]) async throws {
    batchEdits.append(contentsOf: edits)
  }
}
