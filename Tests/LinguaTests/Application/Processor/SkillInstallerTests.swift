import XCTest
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

  func test_install_cursor_writesFlatMdcFiles() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      let result = try installer.install(scope: .project, target: .cursor, force: false)
      XCTAssertEqual(Set(result.installed), Set(BundledSkills.all.map(\.name)))
    }

    let rulesDir = tempDir.appendingPathComponent(".cursor").appendingPathComponent("rules")
    for skill in BundledSkills.all {
      let path = rulesDir.appendingPathComponent("\(skill.name).mdc")
      XCTAssertTrue(FileManager.default.fileExists(atPath: path.path), "Missing rule: \(skill.name).mdc")
      // No nested SKILL.md directory should exist for Cursor.
      let nested = rulesDir.appendingPathComponent(skill.name).appendingPathComponent("SKILL.md")
      XCTAssertFalse(FileManager.default.fileExists(atPath: nested.path))
    }
  }

  func test_install_cursor_globalThrowsCursorNoGlobal() throws {
    let installer = SkillInstaller()
    XCTAssertThrowsError(try installer.install(scope: .global, target: .cursor, force: false)) { error in
      // Wrapped in AgentError with code "cursor_no_global".
      let mirror = String(describing: error)
      XCTAssertTrue(mirror.contains("cursor_no_global"), "Expected cursor_no_global error, got \(mirror)")
    }
  }

  func test_uninstall_cursor_removesOnlyMdcFiles() throws {
    let tempDir = makeTempDir()
    let installer = SkillInstaller()
    try withCwd(tempDir) {
      _ = try installer.install(scope: .project, target: .cursor, force: false)
      let removed = try installer.uninstall(scope: .project, target: .cursor)
      XCTAssertEqual(Set(removed.installed), Set(BundledSkills.all.map(\.name)))
    }
    let rulesDir = tempDir.appendingPathComponent(".cursor").appendingPathComponent("rules")
    let contents = (try? FileManager.default.contentsOfDirectory(at: rulesDir, includingPropertiesForKeys: nil)) ?? []
    XCTAssertTrue(contents.isEmpty)
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
