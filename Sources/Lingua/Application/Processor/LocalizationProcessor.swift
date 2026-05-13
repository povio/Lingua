import Foundation
import LinguaLib

final class LocalizationProcessor: CommandLineProcessable {
  private let argumentParser: CommandLineParsable
  private let logger: Logger
  private let entityFileLoader: EntityFileLoader<JSONDataParser<ConfigDto>, ConfigDtoTransformer>
  private let localizationModuleFactory: (Config.Localization) -> ModuleLocalizing
  private let configFileGenerator: ConfigInitialFileGenerating
  private let agentDispatcher: AgentCommandDispatcher

  init(argumentParser: CommandLineParsable,
       logger: Logger,
       entityFileLoader: EntityFileLoader<JSONDataParser<ConfigDto>, ConfigDtoTransformer>,
       localizationModuleFactory: @escaping (Config.Localization) -> ModuleLocalizing,
       configFileGenerator: ConfigInitialFileGenerating) {
    self.argumentParser = argumentParser
    self.logger = logger
    self.entityFileLoader = entityFileLoader
    self.localizationModuleFactory = localizationModuleFactory
    self.configFileGenerator = configFileGenerator
    self.agentDispatcher = AgentCommandDispatcher(
      entityFileLoader: entityFileLoader,
      localizationModuleFactory: localizationModuleFactory,
      agentFactory: AgentModuleFactory(),
      output: AgentJSONOutput.shared
    )
  }

  func process(arguments: [String]) async throws {
    do {
      let parsed = try argumentParser.parse(arguments: arguments)

      switch parsed.command {
      case .ios, .android:
        guard let configFilePath = parsed.configFilePath, let platform = parsed.platform else {
          throw ProcessorError.missingArguments
        }

        logger.log("Loading configuration file...", level: .info)

        let config: Config = try await entityFileLoader.loadEntity(from: configFilePath)

        guard let localization = config.localization else {
          throw ProcessorError.missingLocalization
        }

        logger.log("Initializing localization module...", level: .info)

        let localizationModule = localizationModuleFactory(localization)

        logger.log("Starting localization...", level: .info)

        try await localizationModule.localize(for: platform)

        logger.log("Localization completed!", level: .success)

      case .config:
        try configFileGenerator.generate()
        logger.log("Lingua config file is created.", level: .success)
      case .version, .abbreviatedVersion:
        logger.log("Lingua version: \(String.version)", level: .info)

      case .help, .helpFlag, .helpShort:
        print(HelpText.usage)

      case .sections, .list, .find, .add, .update, .delete, .sync, .doctor, .ai:
        try await agentDispatcher.dispatch(parsed)

      default:
        throw CommandLineParsingError.invalidCommand
      }
    } catch let error as ConfigInitialFileGenerator.Error {
      logger.log(error.localizedDescription, level: .error)
      throw error
    } catch let error as ProcessorError {
      logger.log(error.localizedDescription, level: .error)
      logger.printUsage()
      throw error
    } catch {
      logger.log(error.localizedDescription, level: .error)
      throw error
    }
  }
}
