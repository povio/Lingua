import XCTest
@testable import LinguaLib

final class GoogleSheetDataLoaderTests: XCTestCase {
  func test_loadSheets_withValidData_returnsLocalizationSheets() async throws {
    let sheetMetadata = SheetMetadata(sheets: [
      SheetMetadata.Sheet(properties: SheetMetadata.Sheet.SheetProperties(title: "Sheet1")),
      SheetMetadata.Sheet(properties: SheetMetadata.Sheet.SheetProperties(title: "Sheet2"))
    ])
    let sheetDataResponse = SheetDataResponse(values: [
      ["Section", "Key", "Unused", "Translation"],
      ["test_section", "test_key", "", "test_translation"]
    ])
    let fetcher = MockGoogleSheetsFetcher(sheetMetadata: sheetMetadata, sheetData: sheetDataResponse)
    let sut = makeSUT(fetcher: fetcher)
    
    let result = try await sut.loadSheets()
    
    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0].language, "Sheet1")
    XCTAssertEqual(result[0].entries.count, 1)
    XCTAssertEqual(result[0].entries[0].section, "test_section")
    XCTAssertEqual(result[0].entries[0].key, "test_key")
    XCTAssertEqual(result[0].entries[0].translations, ["one": "test_translation"])
  }
  
  func test_loadSheets_withEmptyData_returnsEmptyArray() async throws {
    let sheetMetadata = SheetMetadata(sheets: [])
    let sheetDataResponse = SheetDataResponse(values: [])
    let fetcher = MockGoogleSheetsFetcher(sheetMetadata: sheetMetadata, sheetData: sheetDataResponse)
    let sut = makeSUT(fetcher: fetcher)

    let result = try await sut.loadSheets()

    XCTAssertEqual(result.count, 0)
  }

  // MARK: - loadCanonicalSheet

  func test_loadCanonicalSheet_preferred_isUsedWhenPresent_andOnlyFetchesThatTab() async throws {
    let fetcher = TrackingGoogleSheetsFetcher(
      tabNames: ["en_US_English", "de_DE_German", "fr_FR_French"]
    )
    let sut = makeSUT(fetcher: fetcher)

    let load = try await sut.loadCanonicalSheet(preferred: "de_DE_German")

    XCTAssertEqual(load.canonical.language, "de_DE_German")
    XCTAssertEqual(load.allLanguageTabNames, ["en_US_English", "de_DE_German", "fr_FR_French"])
    XCTAssertEqual(fetcher.dataRequests, ["de_DE_German"])
  }

  func test_loadCanonicalSheet_fallsBackToEnglish_whenPreferredNil() async throws {
    let fetcher = TrackingGoogleSheetsFetcher(
      tabNames: ["de_DE_German", "en_US_English", "fr_FR_French"]
    )
    let sut = makeSUT(fetcher: fetcher)

    let load = try await sut.loadCanonicalSheet(preferred: nil)

    XCTAssertEqual(load.canonical.language, "en_US_English")
    XCTAssertEqual(fetcher.dataRequests, ["en_US_English"])
  }

  func test_loadCanonicalSheet_fallsBackToFirstTab_whenNoEnglish() async throws {
    let fetcher = TrackingGoogleSheetsFetcher(
      tabNames: ["de_DE_German", "fr_FR_French"]
    )
    let sut = makeSUT(fetcher: fetcher)

    let load = try await sut.loadCanonicalSheet(preferred: nil)

    XCTAssertEqual(load.canonical.language, "de_DE_German")
    XCTAssertEqual(fetcher.dataRequests, ["de_DE_German"])
  }

  func test_loadCanonicalSheet_throwsNoSheets_whenNoTabs() async {
    let fetcher = TrackingGoogleSheetsFetcher(tabNames: [])
    let sut = makeSUT(fetcher: fetcher)

    do {
      _ = try await sut.loadCanonicalSheet(preferred: nil)
      XCTFail("Expected no_sheets")
    } catch let error as AgentError {
      XCTAssertEqual(error.code, "no_sheets")
    } catch {
      XCTFail("Wrong error: \(error)")
    }
    XCTAssertTrue(fetcher.dataRequests.isEmpty)
  }
}

private extension GoogleSheetDataLoaderTests {
  func makeSUT(fetcher: GoogleSheetsFetchable, sheetDataDecoder: SheetDataDecoder = LocalizationSheetDataDecoder()) -> SheetDataLoader {
    GoogleSheetDataLoader(fetcher: fetcher, sheetDataDecoder: sheetDataDecoder)
  }
}

/// Mock that exposes per-tab data and records which tabs were fetched, so we can verify
/// `loadCanonicalSheet` only hits the canonical tab.
private final class TrackingGoogleSheetsFetcher: GoogleSheetsFetchable {
  let tabNames: [String]
  private(set) var dataRequests: [String] = []

  init(tabNames: [String]) {
    self.tabNames = tabNames
  }

  func fetchSheetNames() async throws -> SheetMetadata {
    SheetMetadata(sheets: tabNames.map {
      SheetMetadata.Sheet(properties: SheetMetadata.Sheet.SheetProperties(title: $0))
    })
  }

  func fetchSheetData(sheetName: String) async throws -> SheetDataResponse {
    dataRequests.append(sheetName)
    return SheetDataResponse(values: [
      ["Section", "Key", "Unused", "Translation"],
      ["welcome", "title", "", "Hello"]
    ])
  }
}
