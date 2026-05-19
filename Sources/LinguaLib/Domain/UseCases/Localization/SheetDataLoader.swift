import Foundation

/// A protocol that defines the contract for loading sheet data
public protocol SheetDataLoader {
  func loadSheets() async throws -> [LocalizationSheet]

  /// Loads only the canonical language tab plus the names of every other tab. Used by
  /// read-only commands (`find`, `sections`) that don't need every language's row data.
  /// Concrete implementations can avoid fetching N tabs when this is called; the default
  /// implementation in the protocol extension falls back to `loadSheets()` so test mocks
  /// keep working unchanged.
  func loadCanonicalSheet(preferred: String?) async throws -> CanonicalSheetLoad
}

public struct CanonicalSheetLoad: Equatable {
  public let canonical: LocalizationSheet
  public let allLanguageTabNames: [String]

  public init(canonical: LocalizationSheet, allLanguageTabNames: [String]) {
    self.canonical = canonical
    self.allLanguageTabNames = allLanguageTabNames
  }
}

public extension SheetDataLoader {
  func loadCanonicalSheet(preferred: String?) async throws -> CanonicalSheetLoad {
    let sheets = try await loadSheets()
    guard let canonical = CanonicalSheetSelector.pick(from: sheets, preferred: preferred) else {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }
    return CanonicalSheetLoad(
      canonical: canonical,
      allLanguageTabNames: sheets.map(\.language)
    )
  }
}
