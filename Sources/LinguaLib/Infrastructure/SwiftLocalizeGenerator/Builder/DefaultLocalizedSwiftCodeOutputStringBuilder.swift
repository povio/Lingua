import Foundation

struct DefaultLocalizedSwiftCodeOutputStringBuilder: LocalizedSwiftCodeOutputStringBuilder {
  private let codeGenerator: LocalizedSwiftCodeGenerating
  
  init(codeGenerator: LocalizedSwiftCodeGenerating = LocalizedSwiftCodeGenerator()) {
    self.codeGenerator = codeGenerator
  }
  
  func buildOutput(sections: [String: Set<String>], translations: [String: [String: String]]) -> String {
    let sectionsOutput = buildSectionsOutput(sections: sections, translations: translations)
    
    let output = """
           // swiftlint:disable all
           \(String.fileHeader.commentOut(for: .ios))
           
           import Foundation
           
           public enum \(String.packageName) {
           \(sectionsOutput)
               
           \tprivate static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
           \t\tlet format = normalizedPrintfFormat(BundleToken.bundle.localizedString(forKey: key, value: nil, table: table))
           \t\treturn String(format: format, locale: Locale.current, arguments: args)
           \t}

           \t/// Maps full-width `％@` (U+FF05 + `@`) to ASCII `%@` so `String(format:)` substitutes arguments in zh-Hant copy.
           \tprivate static func normalizedPrintfFormat(_ format: String) -> String {
           \t\tformat.replacingOccurrences(of: "\\u{FF05}@", with: "%@")
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
    return output
  }
}

private extension DefaultLocalizedSwiftCodeOutputStringBuilder {
  func buildSectionsOutput(sections: [String: Set<String>], translations: [String: [String: String]]) -> String {
    sections
      .keys
      .sorted()
      .map { section in
        guard let keys = sections[section] else { return "" }
        let keysOutput = buildKeysOutput(section: section, keys: keys, translations: translations)
        return "\tpublic enum \(section.formatSheetSection()) {\n\(keysOutput)\n\t}"
      }
      .joined(separator: "\n\n")
  }
  
  func buildKeysOutput(section: String, keys: Set<String>, translations: [String: [String: String]]) -> String {
    keys
      .sorted()
      .map { key in
        let translation = translations[section]?[key] ?? ""
        return "\t\t" + codeGenerator.generateCode(section: section, key: key, translation: translation)
      }
      .joined(separator: "\n")
  }
}
