import XCTest
@testable import LinguaLib

final class DeleteTranslationUseCaseTests: XCTestCase {

  func test_delete_removesRowFromEveryTabWhereItExists() async throws {
    let sheets = [
      sheet(language: "en_US_English", entries: [("welcome", "title"), ("welcome", "subtitle")]),
      sheet(language: "de_DE_German", entries: [("welcome", "title"), ("welcome", "subtitle")])
    ]
    let writer = SpyWriter()
    let sut = DeleteTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer
    )

    let result = try await sut.delete(section: "welcome", key: "subtitle")

    XCTAssertEqual(result.rowsDeleted.count, 2)
    XCTAssertEqual(Set(result.rowsDeleted.map(\.tab)), Set(["en_US_English", "de_DE_German"]))
    XCTAssertTrue(result.rowsDeleted.allSatisfy { $0.row == 3 }) // header + 2nd entry
    XCTAssertEqual(writer.deletes.count, 2)
  }

  func test_delete_succeedsEvenWhenTabsAreMisaligned() async throws {
    // The whole point of delete is recovery from misalignment, so it must work on misaligned
    // tabs. Here English has the orphan row but German doesn't.
    let sheets = [
      sheet(language: "en_US_English", entries: [
        ("welcome", "title"),
        ("login", "welcome_back") // orphan from a failed earlier add
      ]),
      sheet(language: "de_DE_German", entries: [
        ("welcome", "title")
      ])
    ]
    let writer = SpyWriter()
    let sut = DeleteTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: writer
    )

    let result = try await sut.delete(section: "login", key: "welcome_back")

    XCTAssertEqual(result.rowsDeleted.count, 1)
    XCTAssertEqual(result.rowsDeleted[0].tab, "en_US_English")
    XCTAssertEqual(result.rowsDeleted[0].row, 3)
  }

  func test_delete_throwsNotFound_whenKeyDoesNotExist() async {
    let sheets = [sheet(language: "en_US_English", entries: [("welcome", "title")])]
    let sut = DeleteTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      writer: SpyWriter()
    )
    do {
      _ = try await sut.delete(section: "missing", key: "key")
      XCTFail("Expected not_found")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "not_found")
    } catch {
      XCTFail("Wrong error: \(error)")
    }
  }

  private func sheet(language: String, entries: [(String, String)]) -> LocalizationSheet {
    LocalizationSheet(
      language: language,
      entries: entries.enumerated().map { offset, e in
        LocalizationEntry(section: e.0, key: e.1, translations: ["other": "x"], sheetRow: offset + 2)
      }
    )
  }
}

private final class SpyWriter: GoogleSheetsWriting {
  var deletes: [(tab: String, row: Int)] = []
  func insertRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {}
  func updateRow(sheetTab: String, oneBasedRowIndex: Int, cells: [String]) async throws {}
  func appendRow(sheetTab: String, cells: [String]) async throws {}
  func updateCell(sheetTab: String, oneBasedRow: Int, oneBasedColumn: Int, value: String) async throws {}
  func deleteRow(sheetTab: String, oneBasedRowIndex: Int) async throws {
    deletes.append((sheetTab, oneBasedRowIndex))
  }
}
