import XCTest
@testable import LinguaLib

final class GoogleSheetDataLoaderFactoryTests: XCTestCase {
  func test_make_returnsGoogleSheetDataLoader() {
    let config = Config.Localization(
      apiKey: "any-api-key",
      sheetId: "any-sheet-id",
      outputDirectory: "/tmp",
      localizedSwiftCode: nil
    )
    let loader = GoogleSheetDataLoaderFactory.make(with: config)
    XCTAssertTrue(loader is GoogleSheetDataLoader)
  }

  func test_googleSheetsAPIConfig_usesProductionBaseURL() {
    let config = GoogleSheetsAPIConfig(apiKey: "k", sheetId: "s")
    XCTAssertEqual(config.apiKey, "k")
    XCTAssertEqual(config.sheetId, "s")
    XCTAssertEqual(config.baseUrl, "https://sheets.googleapis.com/v4/spreadsheets")
  }
}
