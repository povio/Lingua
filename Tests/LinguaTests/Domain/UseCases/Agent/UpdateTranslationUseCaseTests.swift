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
}
