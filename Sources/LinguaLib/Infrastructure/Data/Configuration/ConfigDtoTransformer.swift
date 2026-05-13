import Foundation

public struct ConfigDtoTransformer: Transformable {
  public typealias Input = ConfigDto
  public typealias Output = Config
  
  public func transform(_ object: ConfigDto) throws -> Config {
    var localizationDto: Config.Localization?
    
    if let localization = object.localization {
      var localizedSwiftCode: Config.LocalizedSwiftCode?
      if let localizedSwiftCodeDto = localization.swiftCode {
        localizedSwiftCode = .init(stringsDirectory: localizedSwiftCodeDto.stringsDirectory,
                                   outputSwiftCodeFileDirectory: localizedSwiftCodeDto.outputSwiftCodeFileDirectory)
      }
      
      localizationDto = Config.Localization(apiKey: localization.apiKey,
                                                    sheetId: localization.sheetId,
                                                    outputDirectory: localization.outputDirectory,
                                                    localizedSwiftCode: localizedSwiftCode,
                                                    serviceAccountKeyPath: localization.serviceAccountKeyPath,
                                                    defaultWriteSheet: localization.defaultWriteSheet)
    }
    
    return Config(localization: localizationDto)
  }
}
