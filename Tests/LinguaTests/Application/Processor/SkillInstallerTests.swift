import XCTest
@testable import Lingua

final class SkillInstallerTests: XCTestCase {

  func test_install_writesAllBundledSkillsToProjectScope() throws {
    let tempDir = makeTempDir()
    let originalCwd = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(tempDir.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalCwd) }

    let installer = SkillInstaller()
    let installed = try installer.install(scope: .project, force: false)

    XCTAssertEqual(Set(installed), Set(BundledSkills.all.map(\.name)))
    for skill in BundledSkills.all {
      let path = tempDir
        .appendingPathComponent(".claude")
        .appendingPathComponent("skills")
        .appendingPathComponent(skill.name)
        .appendingPathComponent("SKILL.md")
      XCTAssertTrue(FileManager.default.fileExists(atPath: path.path), "Missing skill: \(skill.name)")
    }
  }

  func test_install_isIdempotent_withoutForce() throws {
    let tempDir = makeTempDir()
    let originalCwd = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(tempDir.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalCwd) }

    let installer = SkillInstaller()
    _ = try installer.install(scope: .project, force: false)
    let second = try installer.install(scope: .project, force: false)

    XCTAssertTrue(second.isEmpty, "Second install should not overwrite existing skills without --force")
  }

  func test_uninstall_removesInstalledSkills() throws {
    let tempDir = makeTempDir()
    let originalCwd = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(tempDir.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalCwd) }

    let installer = SkillInstaller()
    _ = try installer.install(scope: .project, force: false)
    let removed = try installer.uninstall(scope: .project)

    XCTAssertEqual(Set(removed), Set(BundledSkills.all.map(\.name)))
    let skillsDir = tempDir.appendingPathComponent(".claude").appendingPathComponent("skills")
    if FileManager.default.fileExists(atPath: skillsDir.path) {
      let contents = try FileManager.default.contentsOfDirectory(at: skillsDir, includingPropertiesForKeys: nil)
      XCTAssertTrue(contents.isEmpty)
    }
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
}
