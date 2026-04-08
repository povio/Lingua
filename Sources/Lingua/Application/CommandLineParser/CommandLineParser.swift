import Foundation
import LinguaLib

protocol CommandLineParsable {
  func parse(arguments: [String]) throws -> CommandLineArguments
}

final class CommandLineParser: CommandLineParsable {
  func parse(arguments: [String]) throws -> CommandLineArguments {
    if arguments.count <= 1 {
      // Bare invocation: show help instead of "not enough arguments".
      return CommandLineArguments(command: .help)
    }

    let firstArgument = arguments[1].lowercased()
    let firstCommand = Command(rawValue: firstArgument)

    switch firstCommand {
    case .help, .helpFlag, .helpShort:
      return CommandLineArguments(command: .help)

    case .ios, .android:
      try validateArgumentCount(arguments, count: 2)
      let configFilePathArgument = arguments[2]
      let platform = try getPlatform(from: firstArgument)
      try validateConfigFilePath(configFilePathArgument)
      return CommandLineArguments(command: firstCommand, platform: platform, configFilePath: configFilePathArgument)

    case .config:
      try validateArgumentCount(arguments, count: 2)
      guard Command(rawValue: arguments[2].lowercased()) == .initializer else {
        throw CommandLineParsingError.invalidCommand
      }
      return CommandLineArguments(command: firstCommand)

    case .version, .abbreviatedVersion:
      return CommandLineArguments(command: firstCommand)

    case .sections, .list, .find, .add, .update, .delete, .doctor, .sync:
      return try parseAgentCommand(firstCommand!, arguments: arguments)

    case .ai:
      return try parseAICommand(arguments: arguments)

    default:
      throw CommandLineParsingError.invalidCommand
    }
  }
}

private extension CommandLineParser {
  func parseAgentCommand(_ command: Command, arguments: [String]) throws -> CommandLineArguments {
    // Layout: lingua <command> <config.json> [positional...] [--flag value] [--bool]
    try validateArgumentCount(arguments, count: 2)
    let configPath = arguments[2]
    try validateConfigFilePath(configPath)

    var positional: [String] = []
    var flags: [String: String] = [:]
    var multi: [String: [String]] = [:]
    var booleanFlags: Set<String> = []
    var platform: LocalizationPlatform?

    var i = 3
    while i < arguments.count {
      let token = arguments[i]
      if token.hasPrefix("--") {
        let name = String(token.dropFirst(2))
        if i + 1 < arguments.count, !arguments[i + 1].hasPrefix("--") {
          let value = arguments[i + 1]
          if name == "value" {
            multi[name, default: []].append(value)
          } else if name == "platform" {
            platform = LocalizationPlatform(rawValue: value.lowercased())
            flags[name] = value
          } else {
            flags[name] = value
          }
          i += 2
        } else {
          booleanFlags.insert(name)
          i += 1
        }
      } else {
        positional.append(token)
        i += 1
      }
    }

    return CommandLineArguments(
      command: command,
      platform: platform,
      configFilePath: configPath,
      positional: positional,
      flags: flags,
      multiValueFlags: multi,
      booleanFlags: booleanFlags
    )
  }

  func parseAICommand(arguments: [String]) throws -> CommandLineArguments {
    // Layout: lingua ai <install|uninstall|status> [--global] [--force]
    try validateArgumentCount(arguments, count: 2)
    guard let sub = Command(rawValue: arguments[2].lowercased()),
          [.install, .uninstall, .status].contains(sub) else {
      throw CommandLineParsingError.invalidCommand
    }
    var booleanFlags: Set<String> = []
    for token in arguments.dropFirst(3) {
      if token.hasPrefix("--") {
        booleanFlags.insert(String(token.dropFirst(2)))
      }
    }
    return CommandLineArguments(
      command: .ai,
      subcommand: sub,
      booleanFlags: booleanFlags
    )
  }

  func validateArgumentCount(_ arguments: [String], count: Int) throws {
    guard arguments.count > count else {
      throw CommandLineParsingError.notEnoughArguments
    }
  }

  func getPlatform(from argument: String) throws -> LocalizationPlatform {
    guard let platform = LocalizationPlatform(rawValue: argument) else {
      throw CommandLineParsingError.invalidPlatform
    }
    return platform
  }

  func validateConfigFilePath(_ path: String) throws {
    guard path.hasSuffix(".json") else {
      throw CommandLineParsingError.invalidConfigFilePath
    }
  }
}
