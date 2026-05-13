import Foundation
import LinguaLib

public struct CommandLineArguments: Equatable {
  public let command: Command?
  public let platform: LocalizationPlatform?
  public let configFilePath: String?
  public let subcommand: Command?
  public let positional: [String]
  public let flags: [String: String]
  public let multiValueFlags: [String: [String]]
  public let booleanFlags: Set<String>

  public init(command: Command?,
              platform: LocalizationPlatform? = nil,
              configFilePath: String? = nil,
              subcommand: Command? = nil,
              positional: [String] = [],
              flags: [String: String] = [:],
              multiValueFlags: [String: [String]] = [:],
              booleanFlags: Set<String> = []) {
    self.command = command
    self.platform = platform
    self.configFilePath = configFilePath
    self.subcommand = subcommand
    self.positional = positional
    self.flags = flags
    self.multiValueFlags = multiValueFlags
    self.booleanFlags = booleanFlags
  }
}
