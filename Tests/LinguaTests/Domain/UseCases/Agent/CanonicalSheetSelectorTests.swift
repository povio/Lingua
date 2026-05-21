import XCTest
@testable import LinguaLib

final class CanonicalSheetSelectorTests: XCTestCase {

  // MARK: - pickTabName

  func test_pickTabName_returnsPreferred_whenPresent() {
    let tabs = ["en_US_English", "de_DE_German", "fr_FR_French"]
    XCTAssertEqual(CanonicalSheetSelector.pickTabName(from: tabs, preferred: "de_DE_German"), "de_DE_German")
  }

  func test_pickTabName_fallsBackToEnglish_whenPreferredMissing() {
    let tabs = ["de_DE_German", "en_US_English", "fr_FR_French"]
    XCTAssertEqual(CanonicalSheetSelector.pickTabName(from: tabs, preferred: nil), "en_US_English")
  }

  func test_pickTabName_fallsBackToEnglish_whenPreferredNotInTabs() {
    let tabs = ["de_DE_German", "en_US_English"]
    XCTAssertEqual(CanonicalSheetSelector.pickTabName(from: tabs, preferred: "es_ES_Spanish"), "en_US_English")
  }

  func test_pickTabName_returnsFirstTab_whenNoEnglish() {
    let tabs = ["de_DE_German", "fr_FR_French"]
    XCTAssertEqual(CanonicalSheetSelector.pickTabName(from: tabs, preferred: nil), "de_DE_German")
  }

  func test_pickTabName_returnsNil_whenEmpty() {
    XCTAssertNil(CanonicalSheetSelector.pickTabName(from: [], preferred: nil))
    XCTAssertNil(CanonicalSheetSelector.pickTabName(from: [], preferred: "en_US_English"))
  }

  // MARK: - languageCode(forTabName:)

  func test_languageCode_stripsSuffix_afterUnderscore() {
    XCTAssertEqual(CanonicalSheetSelector.languageCode(forTabName: "en_US_English"), "en")
    XCTAssertEqual(CanonicalSheetSelector.languageCode(forTabName: "zh-Hant_TW_Chinese"), "zh-Hant")
  }

  func test_languageCode_returnsWhole_whenNoUnderscore() {
    XCTAssertEqual(CanonicalSheetSelector.languageCode(forTabName: "en"), "en")
  }
}
