import Foundation

enum CommandLineParsingError: LocalizedError {
  case notEnoughArguments
  case invalidPlatform
  case invalidConfigFilePath
  case invalidCommand
  /// Like `invalidCommand` but carries a specific reason for the user. Use this whenever the
  /// parser knows *why* the input is wrong (e.g. unknown flag value, misplaced positional).
  case invalidUsage(String)

  var errorDescription: String? {
    switch self {
    case .notEnoughArguments:
      return "Not enough arguments provided."
    case .invalidPlatform:
      return "Invalid platform."
    case .invalidConfigFilePath:
      return "Invalid config file path. Must end with '.json'."
    case .invalidCommand:
      return "Invalid command."
    case .invalidUsage(let message):
      return message
    }
  }
}
