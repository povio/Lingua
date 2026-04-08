import XCTest
import LinguaLib
@testable import Lingua

final class CommandLineParserTests: XCTestCase {
  private lazy var sut: CommandLineParser = {
    return makeSUT()
  }()
  
  func test_parse_returnsHelpCommand_forBareInvocation() throws {
    // Bare `lingua` shows help instead of erroring out — it's friendlier and what every other CLI does.
    let parsed = try sut.parse(arguments: ["Lingua"])
    XCTAssertEqual(parsed.command, .help)
  }
  
  func test_parse_throwsInvalidPlatformError_forInvalidPlatform() {
    let arguments = ["Lingua", "localization_invalid", "config.json"]
    
    XCTAssertThrowsError(try sut.parse(arguments: arguments)) { error in
      XCTAssertEqual((error as? CommandLineParsingError)?.localizedDescription,
                     CommandLineParsingError.invalidCommand.localizedDescription)
    }
  }
  
  func test_parse_throwsInvalidConfigFilePathError_forInvalidConfigFilePath() {
    let arguments = ["Lingua", "ios", "config.txt"]
    
    XCTAssertThrowsError(try sut.parse(arguments: arguments)) { error in
      XCTAssertEqual((error as? CommandLineParsingError)?.localizedDescription,
                     CommandLineParsingError.invalidConfigFilePath.localizedDescription)
    }
  }
  
  func test_parse_parsesArgumentsCorrectly_forValidArguments() throws {
    let arguments = ["Lingua", "ios", "config.json"]

    let commandLineArguments = try sut.parse(arguments: arguments)

    XCTAssertEqual(commandLineArguments.platform, .ios)
    XCTAssertEqual(commandLineArguments.configFilePath, "config.json")
  }

  // MARK: - Agent commands

  func test_parse_helpFlag_returnsHelpCommand() throws {
    XCTAssertEqual(try sut.parse(arguments: ["Lingua", "--help"]).command, .help)
    XCTAssertEqual(try sut.parse(arguments: ["Lingua", "-h"]).command, .help)
    XCTAssertEqual(try sut.parse(arguments: ["Lingua", "help"]).command, .help)
  }

  func test_parse_versionFlag_returnsVersionCommand() throws {
    XCTAssertEqual(try sut.parse(arguments: ["Lingua", "--version"]).command, .version)
    XCTAssertEqual(try sut.parse(arguments: ["Lingua", "-v"]).command, .abbreviatedVersion)
  }

  func test_parse_configInit_returnsConfigCommand() throws {
    let parsed = try sut.parse(arguments: ["Lingua", "config", "init"])
    XCTAssertEqual(parsed.command, .config)
  }

  func test_parse_configWithoutInit_throwsInvalidCommand() {
    XCTAssertThrowsError(try sut.parse(arguments: ["Lingua", "config", "wat"])) { error in
      XCTAssertEqual((error as? CommandLineParsingError)?.localizedDescription,
                     CommandLineParsingError.invalidCommand.localizedDescription)
    }
  }

  func test_parse_listCommand_parsesFlagsAndPositionals() throws {
    let parsed = try sut.parse(arguments: ["Lingua", "list", "config.json", "--section", "welcome"])
    XCTAssertEqual(parsed.command, .list)
    XCTAssertEqual(parsed.configFilePath, "config.json")
    XCTAssertEqual(parsed.flags["section"], "welcome")
  }

  func test_parse_findCommand_parsesPositionalAndLimitFlag() throws {
    let parsed = try sut.parse(arguments: ["Lingua", "find", "config.json", "hello", "--limit", "5"])
    XCTAssertEqual(parsed.command, .find)
    XCTAssertEqual(parsed.positional, ["hello"])
    XCTAssertEqual(parsed.flags["limit"], "5")
  }

  func test_parse_addCommand_collectsMultiValueFlags() throws {
    let parsed = try sut.parse(arguments: [
      "Lingua", "add", "config.json",
      "--section", "welcome",
      "--key", "title",
      "--value", "en=Hello",
      "--value", "de=Hallo",
      "--new-section",
      "--dry-run"
    ])
    XCTAssertEqual(parsed.command, .add)
    XCTAssertEqual(parsed.flags["section"], "welcome")
    XCTAssertEqual(parsed.flags["key"], "title")
    XCTAssertEqual(parsed.multiValueFlags["value"], ["en=Hello", "de=Hallo"])
    XCTAssertTrue(parsed.booleanFlags.contains("new-section"))
    XCTAssertTrue(parsed.booleanFlags.contains("dry-run"))
  }

  func test_parse_syncCommand_parsesPlatformFlag() throws {
    let parsed = try sut.parse(arguments: ["Lingua", "sync", "config.json", "--platform", "ios"])
    XCTAssertEqual(parsed.command, .sync)
    XCTAssertEqual(parsed.platform, .ios)
  }

  func test_parse_doctorCommand_parsesConfigPath() throws {
    let parsed = try sut.parse(arguments: ["Lingua", "doctor", "config.json"])
    XCTAssertEqual(parsed.command, .doctor)
    XCTAssertEqual(parsed.configFilePath, "config.json")
  }

  func test_parse_agentCommand_throwsInvalidConfigPath_whenNotJSON() {
    XCTAssertThrowsError(try sut.parse(arguments: ["Lingua", "list", "config.txt"])) { error in
      XCTAssertEqual((error as? CommandLineParsingError)?.localizedDescription,
                     CommandLineParsingError.invalidConfigFilePath.localizedDescription)
    }
  }

  func test_parse_agentCommand_throwsNotEnoughArguments_whenConfigMissing() {
    XCTAssertThrowsError(try sut.parse(arguments: ["Lingua", "list"])) { error in
      XCTAssertEqual((error as? CommandLineParsingError)?.localizedDescription,
                     CommandLineParsingError.notEnoughArguments.localizedDescription)
    }
  }

  // MARK: - AI command

  func test_parse_aiInstall_defaultFlags() throws {
    let parsed = try sut.parse(arguments: ["Lingua", "ai", "install"])
    XCTAssertEqual(parsed.command, .ai)
    XCTAssertEqual(parsed.subcommand, .install)
  }

  func test_parse_aiInstall_withTargetAndForce() throws {
    let parsed = try sut.parse(arguments: ["Lingua", "ai", "install", "--target", "claude", "--force", "--global"])
    XCTAssertEqual(parsed.subcommand, .install)
    XCTAssertEqual(parsed.flags["target"], "claude")
    XCTAssertTrue(parsed.booleanFlags.contains("force"))
    XCTAssertTrue(parsed.booleanFlags.contains("global"))
  }

  func test_parse_aiUninstall_andStatus() throws {
    XCTAssertEqual(try sut.parse(arguments: ["Lingua", "ai", "uninstall"]).subcommand, .uninstall)
    XCTAssertEqual(try sut.parse(arguments: ["Lingua", "ai", "status"]).subcommand, .status)
  }

  func test_parse_ai_throwsForUnknownSubcommand() {
    XCTAssertThrowsError(try sut.parse(arguments: ["Lingua", "ai", "wat"]))
  }

  func test_parse_ai_throwsForBareTargetWord() {
    XCTAssertThrowsError(try sut.parse(arguments: ["Lingua", "ai", "install", "cursor"])) { error in
      XCTAssertTrue((error as? CommandLineParsingError)?.localizedDescription.contains("--target") ?? false)
    }
  }

  func test_parse_ai_throwsForUnexpectedPositional() {
    XCTAssertThrowsError(try sut.parse(arguments: ["Lingua", "ai", "install", "wat"]))
  }

  func test_parse_ai_throwsWhenTargetMissingValue() {
    XCTAssertThrowsError(try sut.parse(arguments: ["Lingua", "ai", "install", "--target"]))
  }

  func test_parse_ai_throwsForInvalidTargetValue() {
    XCTAssertThrowsError(try sut.parse(arguments: ["Lingua", "ai", "install", "--target", "wat"]))
  }

  func test_parse_ai_acceptsBothTarget() throws {
    let parsed = try sut.parse(arguments: ["Lingua", "ai", "install", "--target", "both"])
    XCTAssertEqual(parsed.flags["target"], "both")
  }
}

private extension CommandLineParserTests {
  func makeSUT() -> CommandLineParser {
    CommandLineParser()
  }
}
