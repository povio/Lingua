import Foundation

public struct LocalizationSheet: Equatable {
  public let language: String
  public let entries: [LocalizationEntry]

  public init(language: String, entries: [LocalizationEntry]) {
    self.language = language
    self.entries = entries
  }
}

public extension LocalizationSheet {
  var languageCode: String {
    String(language.prefix(2))
  }
}
