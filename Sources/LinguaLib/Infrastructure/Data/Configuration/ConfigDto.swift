import Foundation

public struct ConfigDto: Equatable, Codable {
  public let localization: Localization?
}

public extension ConfigDto {
  struct Localization: Equatable, Codable {
    let apiKey: String
    let sheetId: String
    let outputDirectory: String
    let swiftCode: LocalizedSwiftCode?
    let serviceAccountKeyPath: String?
    let defaultWriteSheet: String?

    enum CodingKeys: String, CodingKey {
      case apiKey
      case sheetId
      case outputDirectory
      case swiftCode
      case serviceAccountKeyPath
      case defaultWriteSheet
    }

    public init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      apiKey = try c.decode(String.self, forKey: .apiKey)
      sheetId = try c.decode(String.self, forKey: .sheetId)
      outputDirectory = try c.decode(String.self, forKey: .outputDirectory)
      swiftCode = try c.decodeIfPresent(LocalizedSwiftCode.self, forKey: .swiftCode)
      serviceAccountKeyPath = try c.decodeIfPresent(String.self, forKey: .serviceAccountKeyPath)
      defaultWriteSheet = try c.decodeIfPresent(String.self, forKey: .defaultWriteSheet)
    }

    init(apiKey: String,
         sheetId: String,
         outputDirectory: String,
         swiftCode: LocalizedSwiftCode?,
         serviceAccountKeyPath: String? = nil,
         defaultWriteSheet: String? = nil) {
      self.apiKey = apiKey
      self.sheetId = sheetId
      self.outputDirectory = outputDirectory
      self.swiftCode = swiftCode
      self.serviceAccountKeyPath = serviceAccountKeyPath
      self.defaultWriteSheet = defaultWriteSheet
    }
  }

  struct LocalizedSwiftCode: Equatable, Codable {
    let stringsDirectory: String
    let outputSwiftCodeFileDirectory: String
  }
}
