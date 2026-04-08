import Foundation

public struct SectionSummary: Equatable, Encodable {
  public let name: String
  public let keyCount: Int
  public let firstRow: Int
  public let lastRow: Int
  public let sampleKeys: [String]
}

public struct ListSectionsResult: Encodable {
  public let canonicalSheet: String
  public let languages: [LanguageInfo]
  public let sections: [SectionSummary]
}

public struct LanguageInfo: Encodable, Equatable {
  public let code: String        // 2-letter prefix, e.g. "en"
  public let tabName: String     // full sheet tab name, e.g. "en_EN_English"
}
