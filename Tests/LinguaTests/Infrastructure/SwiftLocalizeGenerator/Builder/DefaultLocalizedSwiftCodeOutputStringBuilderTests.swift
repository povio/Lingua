import XCTest
@testable import LinguaLib

final class DefaultLocalizedSwiftCodeOutputStringBuilderTests: XCTestCase {
  func test_buildOutput_callsGenerateCodeForEachKeyWithCorrectParameters() throws {
    let (sut, mockCodeGenerator) = makeSUT()
    let sections: [String: Set<String>] = ["section1": Set(["key1", "key2"]), "section2": Set(["key3"])]
    let translations: [String: [String: String]] = ["section1": ["key1": "value1", "key2": "value2"], "section2": ["key3": "value3"]]
    
    _ = sut.buildOutput(sections: sections, translations: translations)
    
    XCTAssertTrue(mockCodeGenerator.generateCodeCalled)
    XCTAssertEqual(mockCodeGenerator.generateCodeSection, "section2")
    XCTAssertEqual(mockCodeGenerator.generateCodeKey, "key3")
    XCTAssertEqual(mockCodeGenerator.generateCodeTranslation, "value3")
  }
  
  func test_buildOutput_createsCorrectOutput() {
    let (sut, _) = makeSUT()
    let sections: [String: Set<String>] = ["section1": Set(["key1", "key2"]), "section2": Set(["key3"])]
    let translations: [String: [String: String]] = ["section1": ["key1": "value1", "key2": "value2"], "section2": ["key3": "value3"]]
    
    let output = sut.buildOutput(sections: sections, translations: translations)
    
    let expectedOutput = """
    // swiftlint:disable all
    // This file was generated with Lingua command line tool. Please do not change it!
    // Source: https://github.com/poviolabs/Lingua
    
    import Foundation
    
    public enum Lingua {
    \tpublic enum section1 {
    \t\tgeneratedCode(section1, key1, value1)
    \t\tgeneratedCode(section1, key2, value2)
    \t}\n
    \tpublic enum section2 {
    \t\tgeneratedCode(section2, key3, value3)
    \t}
        
    \tprivate static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    \t\tlet format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
    \t\treturn String(format: format, locale: Locale.current, arguments: args)
    \t}
    }
    
    private final class BundleToken {
      static let bundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: BundleToken.self)
        #endif
      }()
    }
    
    // swiftlint:enable all
    
    """
    
    XCTAssertEqual(output, expectedOutput)
  }
}

private extension DefaultLocalizedSwiftCodeOutputStringBuilderTests {
  func makeSUT(codeGenerator: MockCodeGenerator = MockCodeGenerator()) -> (DefaultLocalizedSwiftCodeOutputStringBuilder, MockCodeGenerator) {
    let sut = DefaultLocalizedSwiftCodeOutputStringBuilder(codeGenerator: codeGenerator)
    
    return (sut, codeGenerator)
  }
}
