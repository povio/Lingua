import XCTest
import LinguaLib
@testable import Lingua

final class AgentCommandDispatcherTests: XCTestCase {

  // MARK: - parseValueFlags

  func test_parseValueFlags_parsesLanguageOnlyForm() throws {
    let sut = makeSUT()
    let result = try sut.parseValueFlags(["en=Hello"])
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].language, "en")
    XCTAssertNil(result[0].form)
    XCTAssertEqual(result[0].text, "Hello")
  }

  func test_parseValueFlags_parsesLanguageAndForm() throws {
    let sut = makeSUT()
    let result = try sut.parseValueFlags(["en:other=%d items"])
    XCTAssertEqual(result[0].language, "en")
    XCTAssertEqual(result[0].form, "other")
    XCTAssertEqual(result[0].text, "%d items")
  }

  func test_parseValueFlags_preservesEqualsInsideText() throws {
    let sut = makeSUT()
    let result = try sut.parseValueFlags(["en=a=b"])
    XCTAssertEqual(result[0].text, "a=b")
  }

  func test_parseValueFlags_throwsInvalidValue_whenNoEquals() {
    let sut = makeSUT()
    assertAgentError(code: "invalid_value") {
      _ = try sut.parseValueFlags(["enHello"])
    }
  }

  func test_parseValueFlags_throwsInvalidValue_whenLanguageEmpty() {
    let sut = makeSUT()
    assertAgentError(code: "invalid_value") {
      _ = try sut.parseValueFlags(["=Hello"])
    }
  }

  // MARK: - buildNewTranslation / buildTranslationUpdate

  func test_buildNewTranslation_returnsTranslation_whenAllFlagsPresent() throws {
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .add,
      flags: ["section": "welcome", "key": "title"],
      multiValueFlags: ["value": ["en=Hello"]],
      booleanFlags: ["new-section", "dry-run"]
    )
    let translation = try sut.buildNewTranslation(args)
    XCTAssertEqual(translation.section, "welcome")
    XCTAssertEqual(translation.key, "title")
    XCTAssertEqual(translation.assignments.count, 1)
    XCTAssertTrue(translation.allowNewSection)
    XCTAssertTrue(translation.dryRun)
  }

  func test_buildNewTranslation_throwsMissingArgument_whenSectionMissing() {
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .add,
      flags: ["key": "title"],
      multiValueFlags: ["value": ["en=Hello"]]
    )
    assertAgentError(code: "missing_argument") { _ = try sut.buildNewTranslation(args) }
  }

  func test_buildNewTranslation_throwsMissingArgument_whenKeyMissing() {
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .add,
      flags: ["section": "welcome"],
      multiValueFlags: ["value": ["en=Hello"]]
    )
    assertAgentError(code: "missing_argument") { _ = try sut.buildNewTranslation(args) }
  }

  func test_buildNewTranslation_throwsMissingArgument_whenNoValues() {
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .add,
      flags: ["section": "welcome", "key": "title"]
    )
    assertAgentError(code: "missing_argument") { _ = try sut.buildNewTranslation(args) }
  }

  func test_buildTranslationUpdate_returnsUpdate_whenAllFlagsPresent() throws {
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .update,
      flags: ["section": "welcome", "key": "title"],
      multiValueFlags: ["value": ["en=Hello", "de:other=Hallo"]]
    )
    let update = try sut.buildTranslationUpdate(args)
    XCTAssertEqual(update.section, "welcome")
    XCTAssertEqual(update.key, "title")
    XCTAssertEqual(update.assignments.count, 2)
  }

  func test_buildTranslationUpdate_throwsMissingArgument_whenSectionMissing() {
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .update,
      flags: ["key": "title"],
      multiValueFlags: ["value": ["en=Hello"]]
    )
    assertAgentError(code: "missing_argument") { _ = try sut.buildTranslationUpdate(args) }
  }

  func test_buildTranslationUpdate_throwsMissingArgument_whenKeyMissing() {
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .update,
      flags: ["section": "welcome"],
      multiValueFlags: ["value": ["en=Hello"]]
    )
    assertAgentError(code: "missing_argument") { _ = try sut.buildTranslationUpdate(args) }
  }

  func test_buildTranslationUpdate_throwsMissingArgument_whenNoValues() {
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .update,
      flags: ["section": "welcome", "key": "title"]
    )
    assertAgentError(code: "missing_argument") { _ = try sut.buildTranslationUpdate(args) }
  }

  // MARK: - maybeRunSync

  func test_maybeRunSync_isNoOp_whenFlagAbsent() async throws {
    let module = MockLocalizationModule(errorMessage: nil)
    let sut = makeSUT(moduleFactory: { _ in module })

    try await sut.maybeRunSync(args: CommandLineArguments(command: .add), config: makeConfig())

    XCTAssertTrue(module.messages.isEmpty)
  }

  func test_maybeRunSync_runsSinglePlatform() async throws {
    let module = MockLocalizationModule(errorMessage: nil)
    let sut = makeSUT(moduleFactory: { _ in module })

    let args = CommandLineArguments(command: .add, flags: ["sync": "ios"])
    try await sut.maybeRunSync(args: args, config: makeConfig())

    XCTAssertEqual(module.messages, [.localize(.ios)])
  }

  func test_maybeRunSync_runsMultiplePlatforms_andDeduplicates() async throws {
    let module = MockLocalizationModule(errorMessage: nil)
    let sut = makeSUT(moduleFactory: { _ in module })

    let args = CommandLineArguments(command: .add, flags: ["sync": "ios, android , ios"])
    try await sut.maybeRunSync(args: args, config: makeConfig())

    XCTAssertEqual(module.messages, [.localize(.ios), .localize(.android)])
  }

  func test_maybeRunSync_throwsInvalidSync_onUnknownPlatform() async {
    let sut = makeSUT()
    let args = CommandLineArguments(command: .add, flags: ["sync": "windows"])
    await assertAgentErrorAsync(code: "invalid_sync_value") {
      try await sut.maybeRunSync(args: args, config: makeConfig())
    }
  }

  // MARK: - loadConfig

  func test_loadConfig_throwsMissingConfig_whenPathNil() async {
    let sut = makeSUT()
    let args = CommandLineArguments(command: .sections, configFilePath: nil)
    await assertAgentErrorAsync(code: "missing_config") {
      _ = try await sut.loadConfig(args)
    }
  }

  func test_loadConfig_returnsLocalization_whenFileHasLocalization() async throws {
    let url = writeTempConfig(json: """
    {
      "localization": {
        "apiKey": "key",
        "sheetId": "sheet",
        "outputDirectory": "out"
      }
    }
    """)
    let sut = makeSUT()
    let args = CommandLineArguments(command: .sections, configFilePath: url.path)

    let localization = try await sut.loadConfig(args)

    XCTAssertEqual(localization.apiKey, "key")
    XCTAssertEqual(localization.sheetId, "sheet")
    XCTAssertEqual(localization.outputDirectory, "out")
  }

  func test_loadConfig_throwsMissingLocalization_whenFileLacksLocalization() async throws {
    let url = writeTempConfig(json: "{}")
    let sut = makeSUT()
    let args = CommandLineArguments(command: .sections, configFilePath: url.path)
    await assertAgentErrorAsync(code: "missing_localization") {
      _ = try await sut.loadConfig(args)
    }
  }

  // MARK: - dispatch: --help short-circuit

  func test_dispatch_help_returnsWithoutLoadingConfig() async throws {
    // No configFilePath provided — if dispatch tried to load config it would call exit(1).
    // Reaching the end of this test without crashing proves the help branch short-circuited.
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .sections,
      configFilePath: nil,
      booleanFlags: ["help"]
    )
    try await sut.dispatch(args)
  }

  func test_dispatch_helpShort_returnsWithoutLoadingConfig() async throws {
    let sut = makeSUT()
    let args = CommandLineArguments(
      command: .sections,
      configFilePath: nil,
      booleanFlags: ["h"]
    )
    try await sut.dispatch(args)
  }

  // MARK: - Helpers

  private func makeSUT(
    moduleFactory: @escaping (Config.Localization) -> ModuleLocalizing = { _ in
      MockLocalizationModule(errorMessage: nil)
    }
  ) -> AgentCommandDispatcher {
    AgentCommandDispatcher(
      entityFileLoader: EntityLoaderFactory.makeConfigLoader(),
      localizationModuleFactory: moduleFactory,
      agentFactory: AgentModuleFactory(),
      output: AgentJSONOutput()
    )
  }

  private func makeConfig() -> Config.Localization {
    Config.Localization(
      apiKey: "key",
      sheetId: "sheet",
      outputDirectory: "out",
      localizedSwiftCode: nil
    )
  }

  private func writeTempConfig(json: String) -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("\(UUID().uuidString).json")
    try? json.data(using: .utf8)?.write(to: url)
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return url
  }

  private func assertAgentError(
    code expectedCode: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ block: () throws -> Void
  ) {
    do {
      try block()
      XCTFail("Expected AgentError(\(expectedCode))", file: file, line: line)
    } catch let error as AgentError {
      XCTAssertEqual(error.code, expectedCode, file: file, line: line)
    } catch {
      XCTFail("Wrong error type: \(error)", file: file, line: line)
    }
  }

  private func assertAgentErrorAsync(
    code expectedCode: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ block: () async throws -> Void
  ) async {
    do {
      try await block()
      XCTFail("Expected AgentError(\(expectedCode))", file: file, line: line)
    } catch let error as AgentError {
      XCTAssertEqual(error.code, expectedCode, file: file, line: line)
    } catch {
      XCTFail("Wrong error type: \(error)", file: file, line: line)
    }
  }
}
