import Foundation

/// Single entry point used by the CLI dispatcher to build agent-facing use cases.
public struct AgentModuleFactory {
  public init() {}

  public func makeListSections(config: Config.Localization) -> ListingSections {
    ListSectionsUseCase(
      sheetDataLoader: GoogleSheetDataLoaderFactory.make(with: config),
      preferredSheet: config.defaultWriteSheet
    )
  }

  public func makeListTranslations(config: Config.Localization) -> ListingTranslations {
    ListTranslationsUseCase(
      sheetDataLoader: GoogleSheetDataLoaderFactory.make(with: config),
      preferredSheet: config.defaultWriteSheet
    )
  }

  public func makeFindTranslation(config: Config.Localization) -> FindingTranslations {
    FindTranslationUseCase(
      sheetDataLoader: GoogleSheetDataLoaderFactory.make(with: config),
      preferredSheet: config.defaultWriteSheet
    )
  }

  public func makeAddTranslation(config: Config.Localization) throws -> AddingTranslation {
    let writer = try Self.makeWriter(config: config)
    return AddTranslationUseCase(
      sheetDataLoader: GoogleSheetDataLoaderFactory.make(with: config),
      writer: writer,
      preferredSheet: config.defaultWriteSheet
    )
  }

  public func makeUpdateTranslation(config: Config.Localization) throws -> UpdatingTranslation {
    let writer = try Self.makeWriter(config: config)
    return UpdateTranslationUseCase(
      sheetDataLoader: GoogleSheetDataLoaderFactory.make(with: config),
      writer: writer,
      preferredSheet: config.defaultWriteSheet
    )
  }

  public func makeDeleteTranslation(config: Config.Localization) throws -> DeletingTranslation {
    let writer = try Self.makeWriter(config: config)
    return DeleteTranslationUseCase(
      sheetDataLoader: GoogleSheetDataLoaderFactory.make(with: config),
      writer: writer
    )
  }

  public func makeDoctor(config: Config.Localization) -> RunningDoctor {
    DoctorUseCase(
      config: config,
      sheetDataLoader: GoogleSheetDataLoaderFactory.make(with: config)
    )
  }

  private static func makeWriter(config: Config.Localization) throws -> GoogleSheetsWriting {
    guard let saPath = config.serviceAccountKeyPath else {
      throw AgentError(
        code: "missing_service_account",
        message: "serviceAccountKeyPath is required in lingua_config.json for write operations."
      )
    }
    let key = try ServiceAccountKey.load(fromPath: saPath)
    let tokenProvider = ServiceAccountTokenProvider(key: key)
    return GoogleSheetsWriter(sheetId: config.sheetId, tokenProvider: tokenProvider)
  }
}
