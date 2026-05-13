import Foundation

protocol SheetDataDecoder {
  func decode(sheetData: SheetDataResponse, sheetName: String) -> LocalizationSheet
}

struct LocalizationSheetDataDecoder: SheetDataDecoder {
  typealias Sheet = (name: String, entries: [LocalizationEntry])
  private let translationBuilder: TranslationBuilder
  private let sectionIndex = 0
  private let keyIndex = 1
  private let metadataNumberOfColumns = 2
  
  init(translationBuilder: TranslationBuilder = SheetTranslationBuilder()) {
    self.translationBuilder = translationBuilder
  }
  
  func decode(sheetData: SheetDataResponse, sheetName: String) -> LocalizationSheet {
    // Walk every raw row including blanks so we can record each entry's actual sheet row
    // (1-based, header is row 1). compactMap drops blank rows from the result, but the
    // enumeration index keeps `sheetRow` accurate even when blank separator rows exist
    // between sections.
    let entries: [LocalizationEntry] = sheetData.values.enumerated().compactMap { offset, row in
      guard offset > 0 else { return nil } // skip header row
      return createEntry(from: row, sheetRow: offset + 1)
    }
    return LocalizationSheet(language: sheetName, entries: entries)
  }
}

private extension LocalizationSheetDataDecoder {
  func createEntry(from row: [String], sheetRow: Int) -> LocalizationEntry? {
    guard row.count > metadataNumberOfColumns else { return nil }

    let section = row[sectionIndex]
    let key = row[keyIndex]
    let translations = translationBuilder.buildTranslations(from: row)

    return LocalizationEntry(section: section, key: key, translations: translations, sheetRow: sheetRow)
  }
}
