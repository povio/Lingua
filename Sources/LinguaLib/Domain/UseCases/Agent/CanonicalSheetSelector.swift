import Foundation

enum CanonicalSheetSelector {
  /// Picks the canonical sheet for read/write operations.
  /// Preference order: explicit defaultWriteSheet > sheet whose languageCode is "en" > first sheet.
  static func pick(from sheets: [LocalizationSheet], preferred: String?) -> LocalizationSheet? {
    if let preferred, let match = sheets.first(where: { $0.language == preferred }) {
      return match
    }
    if let english = sheets.first(where: { $0.languageCode == "en" }) {
      return english
    }
    return sheets.first
  }

  /// Picks the canonical tab name when only metadata is available — same preference order as
  /// `pick(from:preferred:)`, but operates on raw tab titles to avoid fetching every tab's data.
  static func pickTabName(from tabNames: [String], preferred: String?) -> String? {
    if let preferred, tabNames.contains(preferred) { return preferred }
    if let english = tabNames.first(where: { languageCode(forTabName: $0) == "en" }) { return english }
    return tabNames.first
  }

  /// Derives the locale prefix from a tab title using the same rule as `LocalizationSheet.languageCode`.
  static func languageCode(forTabName tabName: String) -> String {
    guard let separator = tabName.firstIndex(of: "_") else { return tabName }
    return String(tabName[..<separator])
  }
}
