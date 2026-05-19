import XCTest
@testable import LinguaLib

final class LinguaAIInstallerTests: XCTestCase {

  // MARK: - LinguaAIInstallOption.bestMatch

  func test_bestMatch_claudeAndCursor_returnsBoth() {
    XCTAssertEqual(LinguaAIInstallOption.bestMatch(for: [.claudeCode, .cursor]), .both)
    // Order shouldn't matter — bestMatch operates on a Set.
    XCTAssertEqual(LinguaAIInstallOption.bestMatch(for: [.cursor, .claudeCode]), .both)
  }

  func test_bestMatch_claudeOnly_returnsClaude() {
    XCTAssertEqual(LinguaAIInstallOption.bestMatch(for: [.claudeCode]), .claude)
  }

  func test_bestMatch_cursorOnly_returnsCursor() {
    XCTAssertEqual(LinguaAIInstallOption.bestMatch(for: [.cursor]), .cursor)
  }

  func test_bestMatch_agentsOnly_returnsAgents() {
    XCTAssertEqual(LinguaAIInstallOption.bestMatch(for: [.agents]), .agents)
  }

  func test_bestMatch_empty_returnsClaude() {
    XCTAssertEqual(LinguaAIInstallOption.bestMatch(for: []), .claude)
  }

  func test_bestMatch_unrecognizedCombination_fallsBackToClaude() {
    // Three targets together (claude + cursor + agents) doesn't match any explicit option →
    // fallback path. This guards the "return .claude" tail of bestMatch.
    XCTAssertEqual(
      LinguaAIInstallOption.bestMatch(for: [.claudeCode, .cursor, .agents]),
      .claude
    )
  }

  // MARK: - LinguaAIInstallOption.targets

  func test_option_targets_mapsExpectedTargets() {
    XCTAssertEqual(LinguaAIInstallOption.claude.targets, [.claudeCode])
    XCTAssertEqual(LinguaAIInstallOption.cursor.targets, [.cursor])
    XCTAssertEqual(LinguaAIInstallOption.agents.targets, [.agents])
    XCTAssertEqual(LinguaAIInstallOption.both.targets, [.claudeCode, .cursor])
  }

  // MARK: - Plural install / uninstall overloads (scope: option:)

  func test_install_option_both_installsBothTargets() throws {
    let projectDir = makeTempDir()
    let installer = LinguaAIInstaller(homeDirectory: makeTempDir())

    let results = try installer.install(
      scope: .project,
      option: .both,
      force: false,
      projectDirectory: projectDir
    )

    XCTAssertEqual(results.count, 2)
    XCTAssertEqual(Set(results.map(\.target)), Set([LinguaAITarget.claudeCode.label, LinguaAITarget.cursor.label]))
    for result in results {
      XCTAssertEqual(Set(result.installed), Set(LinguaAIBundledSkills.all.map(\.name)))
    }
  }

  func test_uninstall_option_both_removesBothTargets() throws {
    let projectDir = makeTempDir()
    let installer = LinguaAIInstaller(homeDirectory: makeTempDir())

    _ = try installer.install(scope: .project, option: .both, force: false, projectDirectory: projectDir)
    let removed = try installer.uninstall(scope: .project, option: .both, projectDirectory: projectDir)

    XCTAssertEqual(removed.count, 2)
    for status in removed {
      XCTAssertEqual(Set(status.installed), Set(LinguaAIBundledSkills.all.map(\.name)))
    }
  }

  // MARK: - LinguaAIStatusReport accessors

  func test_statusReport_globalStatuses_returnsAllGlobalScopes() {
    let report = makeReport(
      claudeCodeProject: makeStatus(target: .claudeCode, scope: .project, installed: []),
      claudeCodeGlobal: makeStatus(target: .claudeCode, scope: .global, installed: ["x"]),
      cursorProject: makeStatus(target: .cursor, scope: .project, installed: []),
      cursorGlobal: makeStatus(target: .cursor, scope: .global, installed: ["y"]),
      agentsProject: makeStatus(target: .agents, scope: .project, installed: []),
      agentsGlobal: makeStatus(target: .agents, scope: .global, installed: ["z"])
    )

    XCTAssertEqual(
      report.globalStatuses.map(\.target),
      [LinguaAITarget.claudeCode.label, LinguaAITarget.cursor.label, LinguaAITarget.agents.label]
    )
    XCTAssertEqual(report.globalStatuses.map(\.installed), [["x"], ["y"], ["z"]])
  }

  func test_statusReport_hasProjectInstallations_isFalse_whenAllProjectScopesEmpty() {
    let report = makeReport(
      claudeCodeProject: makeStatus(target: .claudeCode, scope: .project, installed: []),
      cursorProject: makeStatus(target: .cursor, scope: .project, installed: []),
      agentsProject: makeStatus(target: .agents, scope: .project, installed: [])
    )

    XCTAssertFalse(report.hasProjectInstallations)
    XCTAssertEqual(report.projectInstallationState, .notInstalled)
    XCTAssertEqual(report.projectInstalledTargets, [])
  }

  func test_statusReport_hasProjectInstallations_isTrue_whenAnyProjectScopeHasInstalls() {
    let report = makeReport(
      claudeCodeProject: makeStatus(target: .claudeCode, scope: .project, installed: ["one"]),
      cursorProject: makeStatus(target: .cursor, scope: .project, installed: []),
      agentsProject: makeStatus(target: .agents, scope: .project, installed: [])
    )

    XCTAssertTrue(report.hasProjectInstallations)
  }

  // MARK: - Helpers

  private func makeTempDir() -> URL {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: dir)
    }
    return dir
  }

  private func makeStatus(
    target: LinguaAITarget,
    scope: LinguaAIInstallScope,
    installed: [String]
  ) -> LinguaAIScopeStatus {
    LinguaAIScopeStatus(
      target: target.label,
      scope: scope.label,
      directory: "/tmp/\(target.label)/\(scope.label)",
      installed: installed
    )
  }

  /// Fills missing arguments with empty-scope defaults so each test only specifies what matters.
  private func makeReport(
    claudeCodeProject: LinguaAIScopeStatus? = nil,
    claudeCodeGlobal: LinguaAIScopeStatus? = nil,
    cursorProject: LinguaAIScopeStatus? = nil,
    cursorGlobal: LinguaAIScopeStatus? = nil,
    agentsProject: LinguaAIScopeStatus? = nil,
    agentsGlobal: LinguaAIScopeStatus? = nil
  ) -> LinguaAIStatusReport {
    LinguaAIStatusReport(
      claudeCodeProject: claudeCodeProject ?? makeStatus(target: .claudeCode, scope: .project, installed: []),
      claudeCodeGlobal: claudeCodeGlobal ?? makeStatus(target: .claudeCode, scope: .global, installed: []),
      cursorProject: cursorProject ?? makeStatus(target: .cursor, scope: .project, installed: []),
      cursorGlobal: cursorGlobal ?? makeStatus(target: .cursor, scope: .global, installed: []),
      agentsProject: agentsProject ?? makeStatus(target: .agents, scope: .project, installed: []),
      agentsGlobal: agentsGlobal ?? makeStatus(target: .agents, scope: .global, installed: [])
    )
  }
}
