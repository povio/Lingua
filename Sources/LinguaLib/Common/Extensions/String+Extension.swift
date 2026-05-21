import Foundation

public extension String {
  static let packageName = "Lingua"
  static let version = "1.1.1"
  static let swiftLocalizedName = "\(String.packageName).swift"
  static let fileHeader = """
  This file was generated with Lingua command line tool. Please do not change it!
  Source: https://github.com/poviolabs/Lingua\n\n
  """
  
  func formatSheetSection() -> String {
    self
      .components(separatedBy: CharacterSet(charactersIn: " _"))
      .enumerated()
      .reduce(into: "") { result, indexAndWord in
        let (index, word) = indexAndWord
        result += index == 0 ? word : word.capitalized
      }
  }
  
  func formatKey() -> String {
    camelCased().swiftIdentifier()
  }
  
  func camelCased() -> String {
    let items = split(separator: "_")
    var camelCase = ""
    
    for (index, item) in items.enumerated() {
      camelCase += index > 0 ? item.capitalized : item.lowercased()
    }
    
    return camelCase
  }
  
  func swiftIdentifier() -> String {
    let reservedWords = [
      "class", "deinit", "enum", "extension", "func", "import", "init", "inout", "let", "continue",
      "operator", "private", "protocol", "public", "static", "struct", "subscript", "typealias", "var"
    ]
    
    return reservedWords.contains(self) ? "`\(self)`" : self
  }
  
  func commentOut(for platform: LocalizationPlatform) -> String {
    let lines = split(separator: "\n").map { String($0) }
    var commentedLines: [String] = []
    
    for line in lines {
      switch platform {
      case .ios:
        commentedLines.append("// " + line)
      case .android:
        commentedLines.append("<!-- " + line + " -->")
      }
    }
    
    return commentedLines.joined(separator: "\n")
  }
}
