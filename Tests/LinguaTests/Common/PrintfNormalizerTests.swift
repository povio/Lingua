import XCTest
@testable import LinguaLib

final class PrintfNormalizerTests: XCTestCase {
  func test_stringSpecifier_isNormalized() {
    XCTAssertEqual(PrintfNormalizer.normalize("下午，\u{FF05}@！"), "下午，%@！")
  }

  func test_positionalStringSpecifier_isNormalized() {
    XCTAssertEqual(PrintfNormalizer.normalize("\u{FF05}1$@ likes \u{FF05}2$@"), "%1$@ likes %2$@")
  }

  func test_integerSpecifier_isNormalized() {
    XCTAssertEqual(PrintfNormalizer.normalize("Count: \u{FF05}d"), "Count: %d")
  }

  func test_longLongSpecifier_isNormalized() {
    XCTAssertEqual(PrintfNormalizer.normalize("ID: \u{FF05}lld"), "ID: %lld")
  }

  func test_precisionFloatSpecifier_isNormalized() {
    XCTAssertEqual(PrintfNormalizer.normalize("\u{FF05}.2f kg"), "%.2f kg")
  }

  func test_zeroPaddedWidthSpecifier_isNormalized() {
    XCTAssertEqual(PrintfNormalizer.normalize("\u{FF05}05d"), "%05d")
  }

  func test_androidStringSpecifier_isNormalized() {
    XCTAssertEqual(PrintfNormalizer.normalize("Hello \u{FF05}s"), "Hello %s")
  }

  func test_androidPositionalStringSpecifier_isNormalized() {
    XCTAssertEqual(PrintfNormalizer.normalize("\u{FF05}1$s likes \u{FF05}2$s"), "%1$s likes %2$s")
  }

  func test_plainFullWidthPercent_isLeftUntouched() {
    XCTAssertEqual(PrintfNormalizer.normalize("進捗は85\u{FF05}です。"), "進捗は85\u{FF05}です。")
  }

  func test_asciiPercent_isLeftUntouched() {
    XCTAssertEqual(PrintfNormalizer.normalize("%@ is fine"), "%@ is fine")
  }

  func test_emptyString_isUnchanged() {
    XCTAssertEqual(PrintfNormalizer.normalize(""), "")
  }

  func test_multipleOccurrences_areAllNormalized() {
    XCTAssertEqual(
      PrintfNormalizer.normalize("\u{FF05}@ scored \u{FF05}d points in \u{FF05}.1f seconds"),
      "%@ scored %d points in %.1f seconds"
    )
  }
}
