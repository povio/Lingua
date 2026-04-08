import Foundation

public struct FindMatch: Encodable {
  public let section: String
  public let key: String
  public let row: Int
  public let englishValue: String?
  public let score: Int
  public let matchedOn: String  // "key" | "section" | "value"
}

public struct FindTranslationResult: Encodable {
  public let canonicalSheet: String
  public let query: String
  public let matches: [FindMatch]
}

public protocol FindingTranslations {
  func find(query: String, limit: Int) async throws -> FindTranslationResult
}

public struct FindTranslationUseCase: FindingTranslations {
  private let sheetDataLoader: SheetDataLoader
  private let preferredSheet: String?

  public init(sheetDataLoader: SheetDataLoader, preferredSheet: String?) {
    self.sheetDataLoader = sheetDataLoader
    self.preferredSheet = preferredSheet
  }

  public func find(query: String, limit: Int = 10) async throws -> FindTranslationResult {
    let sheets = try await sheetDataLoader.loadSheets()
    guard let canonical = CanonicalSheetSelector.pick(from: sheets, preferred: preferredSheet) else {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }

    let normalizedQuery = query.lowercased()
    var matches: [FindMatch] = []

    for entry in canonical.entries {
      let englishValue = entry.translations["other"] ?? entry.translations["one"] ?? entry.translations.values.first
      let row = entry.sheetRow

      var bestScore = 0
      var matchedOn = ""

      // exact key match wins
      if entry.key.lowercased() == normalizedQuery {
        bestScore = 100; matchedOn = "key"
      } else if entry.key.lowercased().contains(normalizedQuery) {
        bestScore = 80; matchedOn = "key"
      }

      if entry.section.lowercased().contains(normalizedQuery), bestScore < 60 {
        bestScore = 60; matchedOn = "section"
      }

      if let v = englishValue?.lowercased() {
        if v == normalizedQuery, bestScore < 90 {
          bestScore = 90; matchedOn = "value"
        } else if v.contains(normalizedQuery), bestScore < 70 {
          bestScore = 70; matchedOn = "value"
        }
      }

      if bestScore > 0 {
        matches.append(FindMatch(
          section: entry.section,
          key: entry.key,
          row: row,
          englishValue: englishValue,
          score: bestScore,
          matchedOn: matchedOn
        ))
      }
    }

    matches.sort { $0.score > $1.score }
    return FindTranslationResult(
      canonicalSheet: canonical.language,
      query: query,
      matches: Array(matches.prefix(limit))
    )
  }
}
