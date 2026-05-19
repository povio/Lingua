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

  func test_findTranslation_multipleQueries_shareOneLoad_returningPerQueryResults() async throws {
    let loader = CountingMockLoader(sheets: [
      LocalizationSheet(language: "en_US_English", entries: [
        LocalizationEntry(section: "settings", key: "title", translations: ["other": "Settings"]),
        LocalizationEntry(section: "settings", key: "account", translations: ["other": "Account"]),
        LocalizationEntry(section: "settings", key: "display_name", translations: ["other": "Display name"])
      ])
    ])
    let sut = FindTranslationUseCase(sheetDataLoader: loader, preferredSheet: nil)

    let result = try await sut.find(queries: ["Settings", "Account", "Display name"], limit: 5)

    XCTAssertEqual(result.results.count, 3)
    XCTAssertEqual(result.results[0].query, "Settings")
    XCTAssertEqual(result.results[1].query, "Account")
    XCTAssertEqual(result.results[2].query, "Display name")
    // The sheet was loaded exactly once — the whole point of the multi-query path.
    XCTAssertEqual(loader.loadCount, 1)
  }

  func test_findTranslation_partialKeyMatch_scoresEighty() async throws {
    // No exact key/value match — only the substring-in-key branch ("hello_button" contains "hello_b").
    // The English value ("Press me") doesn't contain the query either, so the score-80 branch
    // is the only one that fires.
    let sheets = [
      LocalizationSheet(language: "en_US_English", entries: [
        LocalizationEntry(section: "welcome", key: "hello_button", translations: ["other": "Press me"])
      ])
    ]
    let sut = FindTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      preferredSheet: nil
    )

    let result = try await sut.find(query: "hello_b", limit: 10)

    XCTAssertEqual(result.matches.count, 1)
    XCTAssertEqual(result.matches[0].score, 80)
    XCTAssertEqual(result.matches[0].matchedOn, "key")
  }

  func test_findTranslation_defaultLimitOverloads_returnUpToTen() async throws {
    // Eleven matching entries — the no-limit overloads must cap at 10. Calling through the
    // protocol type (`FindingTranslations`) is what routes through the protocol-extension
    // default-limit overload; calling on the concrete type resolves directly to the
    // class's `find(query:limit:)` method with `limit = 10` default.
    let entries = (0..<11).map { i in
      LocalizationEntry(section: "welcome", key: "hello_\(i)", translations: ["other": "Hello \(i)"])
    }
    let sheets = [LocalizationSheet(language: "en_US_English", entries: entries)]
    let sut: FindingTranslations = FindTranslationUseCase(
      sheetDataLoader: MockSheetDataLoader(loadSheetsResult: .success(sheets)),
      preferredSheet: nil
    )

    let single = try await sut.find(query: "hello")
    XCTAssertEqual(single.matches.count, 10)

    let multi = try await sut.find(queries: ["hello", "world"])
    XCTAssertEqual(multi.results.count, 2)
    XCTAssertEqual(multi.results[0].matches.count, 10)
    XCTAssertEqual(multi.results[1].matches.count, 0)
  }
}

/// Loader that records how many times any loading method was called. Used to verify the
/// multi-query / canonical-only paths share a single round trip across queries.
private final class CountingMockLoader: SheetDataLoader {
  private let sheets: [LocalizationSheet]
  private(set) var loadCount = 0

  init(sheets: [LocalizationSheet]) { self.sheets = sheets }

  func loadSheets() async throws -> [LocalizationSheet] {
    loadCount += 1
    return sheets
  }
}
