import Foundation

public struct Config: Equatable {
  public let localization: Localization?
}

public extension Config {
  struct Localization: Equatable {
    public let apiKey: String
    public let sheetId: String
    public let outputDirectory: String
    public let localizedSwiftCode: LocalizedSwiftCode?
    public let allowedSections: [String]?
    public let serviceAccountKeyPath: String?
    public let defaultWriteSheet: String?

    public init(
      apiKey: String,
      sheetId: String,
      outputDirectory: String,
      localizedSwiftCode: LocalizedSwiftCode?,
      allowedSections: [String]? = nil,
      serviceAccountKeyPath: String? = nil,
      defaultWriteSheet: String? = nil
    ) {
      self.apiKey = apiKey
      self.sheetId = sheetId
      self.outputDirectory = outputDirectory
      self.localizedSwiftCode = localizedSwiftCode
      self.allowedSections = allowedSections
      self.serviceAccountKeyPath = serviceAccountKeyPath
      self.defaultWriteSheet = defaultWriteSheet
    }
  }

  struct LocalizedSwiftCode: Equatable {
    public let stringsDirectory: String
    public let outputSwiftCodeFileDirectory: String

    public init(stringsDirectory: String, outputSwiftCodeFileDirectory: String) {
      self.stringsDirectory = stringsDirectory
      self.outputSwiftCodeFileDirectory = outputSwiftCodeFileDirectory
    }
  }
}
