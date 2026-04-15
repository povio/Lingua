import XCTest
import LinguaLib
@testable import Lingua

final class SkillInstallerProjectRootTests: XCTestCase {

  func test_install_claudeCode_fromNestedDirectory_writesToResolvedGitRoot() throws {
    let repoRoot = makeTempDir()
    let nestedDir = repoRoot.appendingPathComponent("App/Resources/Localization")
    try FileManager.default.createDirectory(
      at: repoRoot.appendingPathComponent(".git"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)

    let installer = SkillInstaller()
    try withCwd(nestedDir) {
      _ = try installer.install(scope: .project, target: .claudeCode, force: false)
    }

    let rootSkill = repoRoot
      .appendingPathComponent(".claude")
      .appendingPathComponent("skills")
      .appendingPathComponent(BundledSkills.all[0].name)
      .appendingPathComponent("SKILL.md")
    XCTAssertTrue(FileManager.default.fileExists(atPath: rootSkill.path))

    let nestedSkillsDir = nestedDir.appendingPathComponent(".claude").appendingPathComponent("skills")
    XCTAssertFalse(FileManager.default.fileExists(atPath: nestedSkillsDir.path))
  }

  func test_autoDetect_nestedDirectory_usesAncestorTargets() throws {
    let repoRoot = makeTempDir()
    let nestedDir = repoRoot.appendingPathComponent("Features/Profile")
    try FileManager.default.createDirectory(
      at: repoRoot.appendingPathComponent(".cursor"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: repoRoot.appendingPathComponent(".agents"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)

    XCTAssertEqual(
      Set(SkillInstaller.autoDetectTargets(in: nestedDir)),
      Set([.cursor, .agents])
    )
  }

  func test_autoDetect_nestedDirectory_withoutMarkersFallsBackToCurrentDirectory() throws {
    let tempDir = makeTempDir()
    let nestedDir = tempDir.appendingPathComponent("Features/Profile")
    try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)

    XCTAssertEqual(SkillInstaller.autoDetectTargets(in: nestedDir), [.claudeCode])
  }

  func test_status_fromNestedDirectory_reportsResolvedProjectRoot() throws {
    let repoRoot = makeTempDir()
    let nestedDir = repoRoot.appendingPathComponent("App/Resources/Localization")
    try FileManager.default.createDirectory(
      at: repoRoot.appendingPathComponent(".cursor"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)

    let installer = SkillInstaller()
    let report = withCwd(nestedDir) {
      installer.status()
    }

    XCTAssertEqual(
      report.cursorProject.directory,
      repoRoot.appendingPathComponent(".cursor").appendingPathComponent("skills").path
    )
  }

  private func makeTempDir() -> URL {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: dir)
    }
    return dir
  }

  private func withCwd<T>(_ dir: URL, _ block: () throws -> T) rethrows -> T {
    let original = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(dir.path)
    defer { FileManager.default.changeCurrentDirectoryPath(original) }
    return try block()
  }
}
