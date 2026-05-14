import XCTest
@testable import LinguaLib

final class LocalizationSheetTests: XCTestCase {
  func test_languageCode_whenSheetNameUsesLegacyLanguageRegionFormat_returnsLanguageCode() {
    let sheet = LocalizationSheet(language: "en_US_English", entries: [])
    
    XCTAssertEqual(sheet.languageCode, "en")
  }
  
  func test_languageCode_whenSheetNameUsesHyphenatedScriptFormat_returnsLocalePrefix() {
    let sheet = LocalizationSheet(language: "zh-Hans_CN_Simplified", entries: [])
    
    XCTAssertEqual(sheet.languageCode, "zh-Hans")
  }
  
  func test_languageCode_whenSheetNameUsesHyphenatedRegionFormat_returnsLocalePrefix() {
    let sheet = LocalizationSheet(language: "fr-CA_French_Canadian", entries: [])
    
    XCTAssertEqual(sheet.languageCode, "fr-CA")
  }
}
