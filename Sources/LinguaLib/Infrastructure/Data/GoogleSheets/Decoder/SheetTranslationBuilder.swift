import Foundation

protocol TranslationBuilder {
  func buildTranslations(from row: [String]) -> [String: String]
}

struct SheetTranslationBuilder: TranslationBuilder {
  private let numberOfMetadataColumns = 2
  private let numberOfTranslationColumns = 6

  func buildTranslations(from row: [String]) -> [String: String] {
    let pluralCategories: [String] = PluralCategory.allCases.map { $0.rawValue }
    let values: [String] = Array(row.dropFirst(numberOfMetadataColumns).prefix(numberOfTranslationColumns))
    
    let nonEmptyPairs = zip(pluralCategories, values)
      .filter { _, value in !value.isEmpty }
      .map { (category, value) in (category, PrintfNormalizer.normalize(value)) }
    return Dictionary(uniqueKeysWithValues: nonEmptyPairs)
  }
}
