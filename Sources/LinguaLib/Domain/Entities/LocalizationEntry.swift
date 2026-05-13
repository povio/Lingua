import Foundation

public struct LocalizationEntry: Equatable {
  public let section: String
  public let key: String
  public let translations: [String: String]
  /// 1-based row number this entry occupies in the source Google Sheet. The header is row 1,
  /// the first data row is row 2, etc. Crucially this counts physical rows in the sheet, not
  /// positions in the decoded `entries` array — so blank rows used as section separators do not
  /// shift `sheetRow` values for entries that come after them. Defaults to 0 for entries
  /// constructed in tests that don't care about row math.
  public let sheetRow: Int

  public init(section: String, key: String, translations: [String: String], sheetRow: Int = 0) {
    self.section = section
    self.key = key
    self.translations = translations
    self.sheetRow = sheetRow
  }

  var plural: Bool {
    translations.count > 1
  }

  // Equatable intentionally ignores `sheetRow` so existing tests that compare entries by
  // identity (section/key/translations) keep working without having to thread row indices
  // through every fixture.
  public static func == (lhs: LocalizationEntry, rhs: LocalizationEntry) -> Bool {
    lhs.section == rhs.section && lhs.key == rhs.key && lhs.translations == rhs.translations
  }
}
