import Foundation

struct GoogleSheetDataLoader: SheetDataLoader {
  private let fetcher: GoogleSheetsFetchable
  private let sheetDataDecoder: SheetDataDecoder
  
  init(fetcher: GoogleSheetsFetchable,
       sheetDataDecoder: SheetDataDecoder = LocalizationSheetDataDecoder()) {
    self.fetcher = fetcher
    self.sheetDataDecoder = sheetDataDecoder
  }
  
  func loadSheets() async throws -> [LocalizationSheet] {
    let sheetMetadata = try await fetcher.fetchSheetNames()
    var sections = [LocalizationSheet]()

    for sheet in sheetMetadata.sheets {
      let sheetName = sheet.properties.title
      let sheetDataResponse = try await fetcher.fetchSheetData(sheetName: sheetName)
      let section = sheetDataDecoder.decode(sheetData: sheetDataResponse, sheetName: sheetName)
      sections.append(section)
    }

    return sections
  }

  /// Optimized canonical-only path: one metadata call + one data fetch for the canonical tab,
  /// instead of one data fetch per language tab. Used by read-only commands (`find`, `sections`)
  /// where the other tabs' row data is never read.
  func loadCanonicalSheet(preferred: String?) async throws -> CanonicalSheetLoad {
    let metadata = try await fetcher.fetchSheetNames()
    let tabNames = metadata.sheets.map { $0.properties.title }
    guard let canonicalTab = CanonicalSheetSelector.pickTabName(from: tabNames, preferred: preferred) else {
      throw AgentError(code: "no_sheets", message: "No language sheets found in the spreadsheet.")
    }
    let response = try await fetcher.fetchSheetData(sheetName: canonicalTab)
    let canonical = sheetDataDecoder.decode(sheetData: response, sheetName: canonicalTab)
    return CanonicalSheetLoad(canonical: canonical, allLanguageTabNames: tabNames)
  }
}
