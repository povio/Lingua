import XCTest
import LinguaLib
@testable import Lingua

final class SkillInstallerTests: XCTestCase {

  // MARK: - Claude Code target

  func test_install_claudeCode_writesNestedSkillFiles() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      let result = try installer.install(scope: .project, target: .claudeCode, force: false)
      XCTAssertEqual(Set(result.installed), Set(BundledSkills.all.map(\.name)))
    }

    for skill in BundledSkills.all {
      let path = tempDir
        .appendingPathComponent(".claude")
        .appendingPathComponent("skills")
        .appendingPathComponent(skill.name)
        .appendingPathComponent("SKILL.md")
      XCTAssertTrue(FileManager.default.fileExists(atPath: path.path), "Missing skill: \(skill.name)")
    }
  }

  func test_install_claudeCode_isIdempotentWithoutForce() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      _ = try installer.install(scope: .project, target: .claudeCode, force: false)
      let second = try installer.install(scope: .project, target: .claudeCode, force: false)
      XCTAssertTrue(second.installed.isEmpty)
    }
  }

  func test_uninstall_claudeCode_removesAllSubdirectories() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      _ = try installer.install(scope: .project, target: .claudeCode, force: false)
      let removed = try installer.uninstall(scope: .project, target: .claudeCode)
      XCTAssertEqual(Set(removed.installed), Set(BundledSkills.all.map(\.name)))
    }

    let skillsDir = tempDir.appendingPathComponent(".claude").appendingPathComponent("skills")
    if FileManager.default.fileExists(atPath: skillsDir.path) {
      let contents = try FileManager.default.contentsOfDirectory(at: skillsDir, includingPropertiesForKeys: nil)
      XCTAssertTrue(contents.isEmpty)
    }
  }

  // MARK: - Cursor target

  func test_install_cursor_writesNestedSkillFiles() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      let result = try installer.install(scope: .project, target: .cursor, force: false)
      XCTAssertEqual(Set(result.installed), Set(BundledSkills.all.map(\.name)))
    }

    // Cursor 2.4+ uses the same Agent Skills layout as Claude: <dir>/<name>/SKILL.md
    for skill in BundledSkills.all {
      let path = tempDir
        .appendingPathComponent(".cursor")
        .appendingPathComponent("skills")
        .appendingPathComponent(skill.name)
        .appendingPathComponent("SKILL.md")
      XCTAssertTrue(FileManager.default.fileExists(atPath: path.path), "Missing skill: \(skill.name)")
    }
  }

  func test_install_cursor_isIdempotentWithoutForce() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      _ = try installer.install(scope: .project, target: .cursor, force: false)
      let second = try installer.install(scope: .project, target: .cursor, force: false)
      XCTAssertTrue(second.installed.isEmpty)
    }
  }

  func test_uninstall_cursor_removesAllSubdirectories() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      _ = try installer.install(scope: .project, target: .cursor, force: false)
      let removed = try installer.uninstall(scope: .project, target: .cursor)
      XCTAssertEqual(Set(removed.installed), Set(BundledSkills.all.map(\.name)))
    }

    let skillsDir = tempDir.appendingPathComponent(".cursor").appendingPathComponent("skills")
    if FileManager.default.fileExists(atPath: skillsDir.path) {
      let contents = try FileManager.default.contentsOfDirectory(at: skillsDir, includingPropertiesForKeys: nil)
      XCTAssertTrue(contents.isEmpty)
    }
  }

  // MARK: - Agents target

  func test_install_agents_writesNestedSkillFiles() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      let result = try installer.install(scope: .project, target: .agents, force: false)
      XCTAssertEqual(Set(result.installed), Set(BundledSkills.all.map(\.name)))
    }

    for skill in BundledSkills.all {
      let path = tempDir
        .appendingPathComponent(".agents")
        .appendingPathComponent("skills")
        .appendingPathComponent(skill.name)
        .appendingPathComponent("SKILL.md")
      XCTAssertTrue(FileManager.default.fileExists(atPath: path.path), "Missing skill: \(skill.name)")
    }
  }

  func test_install_agents_isIdempotentWithoutForce() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      _ = try installer.install(scope: .project, target: .agents, force: false)
      let second = try installer.install(scope: .project, target: .agents, force: false)
      XCTAssertTrue(second.installed.isEmpty)
    }
  }

  func test_uninstall_agents_removesAllSubdirectories() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      _ = try installer.install(scope: .project, target: .agents, force: false)
      let removed = try installer.uninstall(scope: .project, target: .agents)
      XCTAssertEqual(Set(removed.installed), Set(BundledSkills.all.map(\.name)))
    }

    let skillsDir = tempDir.appendingPathComponent(".agents").appendingPathComponent("skills")
    if FileManager.default.fileExists(atPath: skillsDir.path) {
      let contents = try FileManager.default.contentsOfDirectory(at: skillsDir, includingPropertiesForKeys: nil)
      XCTAssertTrue(contents.isEmpty)
    }
  }

  // MARK: - Auto-detection

  func test_autoDetect_emptyDir_fallsBackToClaude() {
    let tempDir = makeTempDir()
    XCTAssertEqual(SkillInstaller.autoDetectTargets(in: tempDir), [.claudeCode])
  }

  func test_autoDetect_cursorOnly() throws {
    let tempDir = makeTempDir()
    try FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent(".cursor"),
      withIntermediateDirectories: true
    )
    XCTAssertEqual(SkillInstaller.autoDetectTargets(in: tempDir), [.cursor])
  }

  func test_autoDetect_claudeOnly() throws {
    let tempDir = makeTempDir()
    try FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent(".claude"),
      withIntermediateDirectories: true
    )
    XCTAssertEqual(SkillInstaller.autoDetectTargets(in: tempDir), [.claudeCode])
  }

  func test_autoDetect_bothPresent() throws {
    let tempDir = makeTempDir()
    try FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent(".cursor"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent(".claude"),
      withIntermediateDirectories: true
    )
    XCTAssertEqual(
      Set(SkillInstaller.autoDetectTargets(in: tempDir)),
      Set([.cursor, .claudeCode])
    )
  }

  func test_autoDetect_agentsOnly() throws {
    let tempDir = makeTempDir()
    try FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent(".agents"),
      withIntermediateDirectories: true
    )
    XCTAssertEqual(SkillInstaller.autoDetectTargets(in: tempDir), [.agents])
  }

  func test_autoDetect_cursorClaudeAndAgentsPresent() throws {
    let tempDir = makeTempDir()
    try FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent(".cursor"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent(".claude"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: tempDir.appendingPathComponent(".agents"),
      withIntermediateDirectories: true
    )
    XCTAssertEqual(
      Set(SkillInstaller.autoDetectTargets(in: tempDir)),
      Set([.cursor, .claudeCode, .agents])
    )
  }

  func test_installOption_bestMatch_returnsBothForClaudeAndCursorTargets() {
    XCTAssertEqual(
      LinguaAIInstallOption.bestMatch(for: [.claudeCode, .cursor]),
      .both
    )
  }

  func test_statusReport_projectInstallationState_returnsInstalled_whenAnyTargetIsFullyInstalled() {
    let fullyInstalled = LinguaAIScopeStatus(
      target: LinguaAITarget.claudeCode.label,
      scope: LinguaAIInstallScope.project.label,
      directory: "/tmp/.claude/skills",
      installed: BundledSkills.all.map(\.name)
    )
    let emptyProjectStatus = LinguaAIScopeStatus(
      target: LinguaAITarget.cursor.label,
      scope: LinguaAIInstallScope.project.label,
      directory: "/tmp/.cursor/skills",
      installed: []
    )
    let emptyGlobalStatus = LinguaAIScopeStatus(
      target: LinguaAITarget.agents.label,
      scope: LinguaAIInstallScope.global.label,
      directory: "/tmp/.agents/skills",
      installed: []
    )

    let report = LinguaAIStatusReport(
      claudeCodeProject: fullyInstalled,
      claudeCodeGlobal: emptyGlobalStatus,
      cursorProject: emptyProjectStatus,
      cursorGlobal: emptyGlobalStatus,
      agentsProject: emptyProjectStatus,
      agentsGlobal: emptyGlobalStatus
    )

    XCTAssertEqual(report.projectInstallationState, .installed)
    XCTAssertEqual(report.projectInstalledTargets, [.claudeCode])
  }

  func test_statusReport_projectInstallationState_returnsPartiallyInstalled_whenAnyTargetIsPartial() {
    let partialProjectStatus = LinguaAIScopeStatus(
      target: LinguaAITarget.agents.label,
      scope: LinguaAIInstallScope.project.label,
      directory: "/tmp/.agents/skills",
      installed: [BundledSkills.all[0].name]
    )
    let emptyStatus = LinguaAIScopeStatus(
      target: LinguaAITarget.claudeCode.label,
      scope: LinguaAIInstallScope.project.label,
      directory: "/tmp/.claude/skills",
      installed: []
    )
    let emptyGlobalStatus = LinguaAIScopeStatus(
      target: LinguaAITarget.cursor.label,
      scope: LinguaAIInstallScope.global.label,
      directory: "/tmp/.cursor/skills",
      installed: []
    )

    let report = LinguaAIStatusReport(
      claudeCodeProject: emptyStatus,
      claudeCodeGlobal: emptyGlobalStatus,
      cursorProject: emptyStatus,
      cursorGlobal: emptyGlobalStatus,
      agentsProject: partialProjectStatus,
      agentsGlobal: emptyGlobalStatus
    )

    XCTAssertEqual(report.projectInstallationState, .partiallyInstalled)
    XCTAssertEqual(report.projectInstalledTargets, [.agents])
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

  /// Run `block` with the process cwd temporarily switched to `dir`. Restores the original cwd
  /// even if the block throws.
  private func withCwd(_ dir: URL, _ block: () throws -> Void) rethrows {
    let original = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(dir.path)
    defer { FileManager.default.changeCurrentDirectoryPath(original) }
    try block()
  }
}
