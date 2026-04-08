import XCTest
@testable import LinguaLib

final class ListTranslationsUseCaseTests: XCTestCase {

  func test_listTranslations_returnsRowsFromCanonicalSheet_withValuesFromAllLanguages() async throws {
    let sheets = [
      LocalizationSheet(language: "en_US_English", entries: [
        LocalizationEntry(section: "welcome", key: "title", translations: ["other": "Hello"], sheetRow: 2),
        LocalizationEntry(section: "errors", key: "generic", translations: ["other": "Oops"], sheetRow: 3)
      ]),
      LocalizationSheet(language: "de_DE_German", entries: [
        LocalizationEntry(section: "welcome", key: "title", translations: ["other": "Hallo"], sheetRow: 2),
        LocalizationEntry(section: "errors", key: "generic", translations: ["other": "Fehler"], sheetRow: 3)
      ])
    ]
    let sut = ListTranslationsUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      preferredSheet: nil
    )

    let result = try await sut.listTranslations(filterSection: nil)

    XCTAssertEqual(result.canonicalSheet, "en_US_English")
    XCTAssertEqual(result.languages, ["en_US_English", "de_DE_German"])
    XCTAssertEqual(result.rows.count, 2)
    XCTAssertEqual(result.rows[0].section, "welcome")
    XCTAssertEqual(result.rows[0].key, "title")
    XCTAssertEqual(result.rows[0].row, 2)
    XCTAssertEqual(result.rows[0].values["en"]?["other"], "Hello")
    XCTAssertEqual(result.rows[0].values["de"]?["other"], "Hallo")
  }

  func test_listTranslations_filtersBySection() async throws {
    let sheets = [
      LocalizationSheet(language: "en_US_English", entries: [
        LocalizationEntry(section: "welcome", key: "title", translations: ["other": "Hello"], sheetRow: 2),
        LocalizationEntry(section: "errors", key: "generic", translations: ["other": "Oops"], sheetRow: 3)
      ])
    ]
    let sut = ListTranslationsUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      preferredSheet: nil
    )

    let result = try await sut.listTranslations(filterSection: "errors")

    XCTAssertEqual(result.rows.count, 1)
    XCTAssertEqual(result.rows[0].section, "errors")
  }

  func test_listTranslations_throwsNoSheets_whenLoaderReturnsEmpty() async {
    let sut = ListTranslationsUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success([])),
      preferredSheet: nil
    )

    do {
      _ = try await sut.listTranslations(filterSection: nil)
      XCTFail("Expected no_sheets error")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "no_sheets")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}
