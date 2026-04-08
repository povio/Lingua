import Foundation

/// Knows the geometry of a Lingua sheet row: which 1-based column corresponds to each plural
/// form, what the canonical form names are, and which form should be used as the default when
/// the agent / CLI user doesn't specify one.
///
/// Sheet layout (matches `SheetTranslationBuilder`):
///
///     A          B    C        D       E       F       G       H
///     section    key  zero     one     two     few     many    other
///
public enum PluralColumnLayout {
  /// Number of metadata columns (section, key) before the plural value columns. Mirrors
  /// `SheetTranslationBuilder.numberOfMetadataColumns`.
  public static let metadataColumnCount = 2

  /// Total columns per row: 2 metadata + 6 plural value columns.
  public static let columnsPerRow = 8

  /// All plural form names in column order. PluralCategory.allCases must match this exactly.
  public static let formsInColumnOrder = ["zero", "one", "two", "few", "many", "other"]

  /// Returns the 1-based column index for a plural form, or nil if the form is unknown.
  public static func column(forForm form: String) -> Int? {
    guard let offset = formsInColumnOrder.firstIndex(of: form) else { return nil }
    return metadataColumnCount + offset + 1
  }

  /// Picks the most-used "default" plural form for non-plural strings by inspecting existing
  /// rows. Whichever of `one` / `other` has more entries wins. Empty sheets default to `one`,
  /// matching the README template convention.
  public static func detectDefaultForm(in entries: [LocalizationEntry]) -> String {
    var oneCount = 0
    var otherCount = 0
    for entry in entries {
      // Only count rows that look non-plural (a single populated value column).
      // For plural rows, both `one` and `other` are typically present, which we ignore.
      let nonEmpty = entry.translations.filter { !$0.value.isEmpty }
      if nonEmpty.count == 1 {
        if nonEmpty.keys.contains("one") { oneCount += 1 }
        if nonEmpty.keys.contains("other") { otherCount += 1 }
      }
    }
    if oneCount == 0 && otherCount == 0 { return "one" }
    return otherCount > oneCount ? "other" : "one"
  }
}

/// One value the user / agent wants to write. `form == nil` means "use the sheet's detected
/// default convention", which the use case resolves after loading.
public struct ValueAssignment: Equatable {
  public let language: String
  public let form: String?
  public let text: String

  public init(language: String, form: String?, text: String) {
    self.language = language
    self.form = form
    self.text = text
  }
}
