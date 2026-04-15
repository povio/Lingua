import Foundation
import LinguaLib

/// Dispatches agent-facing subcommands (sections, list, find, add, update, sync, doctor, ai).
/// All output goes through `AgentJSONOutput` for a stable JSON contract.
struct AgentCommandDispatcher {
  let entityFileLoader: EntityFileLoader<JSONDataParser<ConfigDto>, ConfigDtoTransformer>
  let localizationModuleFactory: (Config.Localization) -> ModuleLocalizing
  let agentFactory: AgentModuleFactory
  let output: AgentJSONOutput

  func dispatch(_ args: CommandLineArguments) async throws {
    do {
      switch args.command {
      case .sections:
        let config = try await loadConfig(args)
        let result = try await agentFactory.makeListSections(config: config).listSections()
        try output.emitSuccess(result)

      case .list:
        let config = try await loadConfig(args)
        let result = try await agentFactory.makeListTranslations(config: config).listTranslations(filterSection: args.flags["section"])
        try output.emitSuccess(result)

      case .find:
        let config = try await loadConfig(args)
        guard let query = args.positional.first else {
          throw AgentError(code: "missing_argument", message: "find requires a query argument: lingua find <config> <query>")
        }
        let limit = Int(args.flags["limit"] ?? "10") ?? 10
        let result = try await agentFactory.makeFindTranslation(config: config).find(query: query, limit: limit)
        try output.emitSuccess(result)

      case .add:
        let config = try await loadConfig(args)
        let translation = try buildNewTranslation(args)
        let result = try await agentFactory.makeAddTranslation(config: config).add(translation)
        try output.emitSuccess(result)

      case .update:
        let config = try await loadConfig(args)
        let update = try buildTranslationUpdate(args)
        let result = try await agentFactory.makeUpdateTranslation(config: config).update(update)
        try output.emitSuccess(result)

      case .delete:
        let config = try await loadConfig(args)
        guard let section = args.flags["section"] else {
          throw AgentError(code: "missing_argument", message: "--section is required")
        }
        guard let key = args.flags["key"] else {
          throw AgentError(code: "missing_argument", message: "--key is required")
        }
        let result = try await agentFactory.makeDeleteTranslation(config: config).delete(section: section, key: key)
        try output.emitSuccess(result)

      case .sync:
        let config = try await loadConfig(args)
        guard let platform = args.platform else {
          throw AgentError(code: "missing_platform", message: "sync requires --platform ios|android")
        }
        let module = localizationModuleFactory(config)
        try await module.localize(for: platform)
        try output.emitSuccess(SyncResult(platform: platform.rawValue, ok: true))

      case .doctor:
        let config = try await loadConfig(args)
        let report = try await agentFactory.makeDoctor(config: config).run()
        try output.emitSuccess(report)
        if !report.ok {
          exit(1)
        }

      case .ai:
        try handleAICommand(args)

      default:
        throw AgentError(code: "invalid_command", message: "Unknown command")
      }
    } catch let agentError as AgentError {
      output.emitFailure(code: agentError.code, message: agentError.message, details: agentError.details)
      exit(1)
    } catch {
      output.emitFailure(code: "unexpected_error", message: error.localizedDescription)
      exit(1)
    }
  }

  // MARK: - Helpers

  private func loadConfig(_ args: CommandLineArguments) async throws -> Config.Localization {
    guard let path = args.configFilePath else {
      throw AgentError(code: "missing_config", message: "Missing config file path")
    }
    let config: Config = try await entityFileLoader.loadEntity(from: path)
    guard let localization = config.localization else {
      throw AgentError(code: "missing_localization", message: "Config file is missing the 'localization' object.")
    }
    return localization
  }

  private func buildNewTranslation(_ args: CommandLineArguments) throws -> NewTranslation {
    guard let section = args.flags["section"] else {
      throw AgentError(code: "missing_argument", message: "--section is required")
    }
    guard let key = args.flags["key"] else {
      throw AgentError(code: "missing_argument", message: "--key is required")
    }
    let assignments = try parseValueFlags(args.multiValueFlags["value"] ?? [])
    if assignments.isEmpty {
      throw AgentError(code: "missing_argument", message: "At least one --value <lang>[:form]=<text> is required")
    }
    return NewTranslation(
      section: section,
      key: key,
      assignments: assignments,
      allowNewSection: args.booleanFlags.contains("new-section"),
      dryRun: args.booleanFlags.contains("dry-run")
    )
  }

  private func buildTranslationUpdate(_ args: CommandLineArguments) throws -> TranslationUpdate {
    guard let section = args.flags["section"] else {
      throw AgentError(code: "missing_argument", message: "--section is required")
    }
    guard let key = args.flags["key"] else {
      throw AgentError(code: "missing_argument", message: "--key is required")
    }
    let assignments = try parseValueFlags(args.multiValueFlags["value"] ?? [])
    if assignments.isEmpty {
      throw AgentError(code: "missing_argument", message: "At least one --value <lang>[:form]=<text> is required")
    }
    return TranslationUpdate(section: section, key: key, assignments: assignments)
  }

  /// Parses `--value` tokens into a list of `ValueAssignment`s. Two forms are supported:
  ///
  ///   en=Hello              → ValueAssignment(language: "en", form: nil, text: "Hello")
  ///   en:other=%d items     → ValueAssignment(language: "en", form: "other", text: "%d items")
  ///
  /// `form == nil` means "use the sheet's detected default plural form" — for most templates
  /// that's `one`, but the use case decides at execution time by inspecting the canonical sheet.
  private func parseValueFlags(_ raw: [String]) throws -> [ValueAssignment] {
    var out: [ValueAssignment] = []
    for entry in raw {
      guard let eq = entry.firstIndex(of: "=") else {
        throw AgentError(
          code: "invalid_value",
          message: "--value must be lang[:form]=text, got '\(entry)'"
        )
      }
      let langPart = String(entry[..<eq])
      let text = String(entry[entry.index(after: eq)...])

      let language: String
      let form: String?
      if let colon = langPart.firstIndex(of: ":") {
        language = String(langPart[..<colon])
        form = String(langPart[langPart.index(after: colon)...])
      } else {
        language = langPart
        form = nil
      }

      if language.isEmpty {
        throw AgentError(code: "invalid_value", message: "--value missing language: '\(entry)'")
      }
      out.append(ValueAssignment(language: language, form: form, text: text))
    }
    return out
  }

  private func handleAICommand(_ args: CommandLineArguments) throws {
    let supportedTargetList = LinguaAIInstallOption.supportedLabels.joined(separator: "|")

    guard let sub = args.subcommand else {
      throw AgentError(
        code: "invalid_command",
        message: "Usage: lingua ai install|uninstall|status [--target \(supportedTargetList)] [--global] [--force]"
      )
    }
    let installer = LinguaAIInstaller()
    let scope: LinguaAIInstallScope = args.booleanFlags.contains("global") ? .global : .project
    let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let projectDirectory = LinguaAIProjectRootResolver.resolve(from: currentDirectory)

    // Resolve targets: explicit --target wins, else auto-detect.
    // For project scope, auto-detection looks at the resolved project root (where the project's
    // `.cursor/`, `.claude/`, and `.agents/` directories live). For global scope, it looks at the
    // user's home directory (where `~/.cursor/`, `~/.claude/`, and `~/.agents/` live).
    let detectionRoot: URL = scope == .global
      ? FileManager.default.homeDirectoryForCurrentUser
      : projectDirectory

    let option: LinguaAIInstallOption
    let autoDetected: Bool
    if let raw = args.flags["target"] {
      guard let explicitOption = LinguaAIInstallOption(rawValue: raw) else {
        throw AgentError(
          code: "invalid_target",
          message: "--target must be one of: \(LinguaAIInstallOption.supportedLabels.joined(separator: ", "))"
        )
      }
      option = explicitOption
      autoDetected = false
    } else {
      let detectedTargets = LinguaAIInstaller.autoDetectTargets(in: detectionRoot)
      option = LinguaAIInstallOption.bestMatch(for: detectedTargets)
      autoDetected = true
    }

    switch sub {
    case .install:
      let force = args.booleanFlags.contains("force")
      let results = try installer.install(
        scope: scope,
        option: option,
        force: force,
        projectDirectory: projectDirectory
      )
      try output.emitSuccess(InstallResult(targets: results, autoDetected: autoDetected))
    case .uninstall:
      let results = try installer.uninstall(
        scope: scope,
        option: option,
        projectDirectory: projectDirectory
      )
      try output.emitSuccess(InstallResult(targets: results, autoDetected: autoDetected))
    case .status:
      let report = installer.status(projectDirectory: projectDirectory)
      try output.emitSuccess(report)
    default:
      throw AgentError(code: "invalid_command", message: "Unknown ai subcommand")
    }
  }

}

private struct SyncResult: Encodable {
  let platform: String
  let ok: Bool
}

private struct InstallResult: Encodable {
  let targets: [LinguaAIScopeStatus]
  let autoDetected: Bool

  enum CodingKeys: String, CodingKey {
    case targets
    case autoDetected = "auto_detected"
  }
}
