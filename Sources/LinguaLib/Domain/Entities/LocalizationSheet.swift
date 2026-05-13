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
  /// Returns the locale prefix (e.g. `zh-Hant`, `pt-BR`, `en`) by trimming legacy `_<region>_<descriptor>` suffixes used in sheet headers.
  var languageCode: String {
    guard let separatorIndex = language.firstIndex(of: "_") else { return language }
    return String(language[..<separatorIndex])
  }
}
