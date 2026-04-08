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
}
