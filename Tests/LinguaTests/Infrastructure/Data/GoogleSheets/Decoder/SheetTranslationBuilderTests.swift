import XCTest
@testable import LinguaLib

final class SheetTranslationBuilderTests: XCTestCase {
  func test_buildTranslations_createsCorrectTranslations_forNonPlurals() {
    let sut = makeSUT()
    let row = ["section", "key", "", "translation"]
    let expectedTranslations = ["one": "translation"]
    
    let translations = sut.buildTranslations(from: row)
    
    XCTAssertEqual(translations, expectedTranslations)
  }
  
  func test_buildTranslations_createsCorrectTranslations_forPlurals() {
    let sut = makeSUT()
    let row = ["section", "key", "zero", "one", "two", "few", "many", "other"]
    let expectedTranslations: [String: String] = [
      "zero": "zero",
      "one": "one",
      "two": "two",
      "few": "few",
      "many": "many",
      "other": "other"
    ]
    
    let translations = sut.buildTranslations(from: row)
    
    XCTAssertEqual(translations, expectedTranslations)
  }
  
  func test_buildTranslations_withInsufficientData_returnsEmptyTranslations() {
    let sut = makeSUT()
    let row = ["section", "key"]
    let expectedTranslations: [String: String] = [:]
    
    let translations = sut.buildTranslations(from: row)
    
    XCTAssertEqual(translations, expectedTranslations)
  }
  
  func test_buildTranslations_withPartialData_returnsPartialTranslations() {
    let sut = makeSUT()
    let row = ["section", "key", "zero", "one", "two"]
    let expectedTranslations: [String: String] = [
      "zero": "zero",
      "one": "one",
      "two": "two"
    ]
    
    let translations = sut.buildTranslations(from: row)
    
    XCTAssertEqual(translations, expectedTranslations)
  }

  func test_buildTranslations_normalizesFullWidthPrintfPlaceholders() {
    let sut = makeSUT()
    let row = ["section", "key", "", "下午，\u{FF05}@！"]
    let expectedTranslations = ["one": "下午，%@！"]

    let translations = sut.buildTranslations(from: row)

    XCTAssertEqual(translations, expectedTranslations)
  }

  func test_buildTranslations_normalizesAllPluralForms() {
    let sut = makeSUT()
    let row = [
      "section", "key",
      "\u{FF05}d 张",
      "\u{FF05}d 张",
      "\u{FF05}d 张",
      "\u{FF05}d 张",
      "\u{FF05}d 张",
      "\u{FF05}d 张"
    ]
    let expectedTranslations: [String: String] = [
      "zero": "%d 张",
      "one": "%d 张",
      "two": "%d 张",
      "few": "%d 张",
      "many": "%d 张",
      "other": "%d 张"
    ]

    let translations = sut.buildTranslations(from: row)

    XCTAssertEqual(translations, expectedTranslations)
  }
}

extension SheetTranslationBuilderTests {
  private func makeSUT() -> TranslationBuilder {
    SheetTranslationBuilder()
  }
}
