import XCTest
@testable import LinguaLib

final class FindAndSectionsTests: XCTestCase {

  func test_listSections_returnsOrderedSummariesWithRowsAndSamples() async throws {
    let sheets = [
      LocalizationSheet(language: "en_US_English", entries: [
        LocalizationEntry(section: "welcome", key: "title", translations: ["other": "Hi"], sheetRow: 2),
        LocalizationEntry(section: "welcome", key: "subtitle", translations: ["other": "Sub"], sheetRow: 3),
        // Blank separator row at sheet row 4 — decoder skips it but the next entry's sheetRow
        // jumps to 5. ListSectionsUseCase must report the actual sheet row, not the
        // entries-array index.
        LocalizationEntry(section: "errors", key: "generic", translations: ["other": "Oops"], sheetRow: 5)
      ])
    ]
    let sut = ListSectionsUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      preferredSheet: nil
    )

    let result = try await sut.listSections()
    XCTAssertEqual(result.canonicalSheet, "en_US_English")
    XCTAssertEqual(result.sections.count, 2)
    XCTAssertEqual(result.sections[0].name, "welcome")
    XCTAssertEqual(result.sections[0].keyCount, 2)
    XCTAssertEqual(result.sections[0].firstRow, 2)
    XCTAssertEqual(result.sections[0].lastRow, 3)
    XCTAssertEqual(result.sections[1].name, "errors")
    XCTAssertEqual(result.sections[1].firstRow, 5) // not 4 — there's a blank separator row
  }

  func test_findTranslation_rankByKeyExact_thenValueExact() async throws {
    let sheets = [
      LocalizationSheet(language: "en_US_English", entries: [
        LocalizationEntry(section: "welcome", key: "title", translations: ["other": "Hello"]),
        LocalizationEntry(section: "welcome", key: "hello_button", translations: ["other": "Press me"]),
        LocalizationEntry(section: "errors", key: "generic", translations: ["other": "Hello world"])
      ])
    ]
    let sut = FindTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      preferredSheet: nil
    )

    let result = try await sut.find(query: "hello", limit: 10)
    XCTAssertGreaterThanOrEqual(result.matches.count, 2)
    // Either an exact value match (Hello → score 90) or key contains "hello" (80) wins.
    XCTAssertEqual(result.matches.first?.englishValue?.lowercased(), "hello")
  }
}
