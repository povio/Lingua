import Foundation

public protocol ListingSections {
  func listSections() async throws -> ListSectionsResult
}

public struct ListSectionsUseCase: ListingSections {
  private let sheetDataLoader: SheetDataLoader
  private let preferredSheet: String?

  public init(sheetDataLoader: SheetDataLoader, preferredSheet: String?) {
    self.sheetDataLoader = sheetDataLoader
    self.preferredSheet = preferredSheet
  }

  public func listSections() async throws -> ListSectionsResult {
    let sheets = try await sheetDataLoader.loadSheets()
    guard let canonical = CanonicalSheetSelector.pick(from: sheets, preferred: preferredSheet) else {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }
    return ListSectionsResult(
      canonicalSheet: canonical.language,
      languages: sheets.map { LanguageInfo(code: $0.languageCode, tabName: $0.language) },
      sections: Self.summarize(entries: canonical.entries)
    )
  }

  /// Builds an ordered list of section summaries based on the row order in the canonical sheet.
  /// Row indices come from each entry's recorded `sheetRow` (1-based, header is row 1) so
  /// they correctly account for blank separator rows between sections.
  static func summarize(entries: [LocalizationEntry]) -> [SectionSummary] {
    var order: [String] = []
    var rowsBySection: [String: [Int]] = [:]
    var keysBySection: [String: [String]] = [:]

    for entry in entries {
      if rowsBySection[entry.section] == nil {
        order.append(entry.section)
        rowsBySection[entry.section] = []
        keysBySection[entry.section] = []
      }
      rowsBySection[entry.section]?.append(entry.sheetRow)
      keysBySection[entry.section]?.append(entry.key)
    }

    return order.map { name in
      let rows = rowsBySection[name] ?? []
      let keys = keysBySection[name] ?? []
      return SectionSummary(
        name: name,
        keyCount: keys.count,
        firstRow: rows.first ?? 0,
        lastRow: rows.last ?? 0,
        sampleKeys: Array(keys.prefix(5))
      )
    }
  }
}
