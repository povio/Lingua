import Foundation
import LinguaLib

/// Installs the bundled Claude Code skill files into the project's `.claude/skills/` directory
/// (or the user's `~/.claude/skills/` directory) so an AI agent can call Lingua autonomously.
struct SkillInstaller {
  enum Scope {
    case project   // ./.claude/skills/
    case global    // ~/.claude/skills/

    var label: String {
      switch self {
      case .project: return "project"
      case .global: return "global"
      }
    }

    func directory() -> URL {
      switch self {
      case .project:
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
          .appendingPathComponent(".claude")
          .appendingPathComponent("skills")
      case .global:
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude").appendingPathComponent("skills")
      }
    }
  }

  func install(scope: Scope, force: Bool) throws -> [String] {
    let destination = scope.directory()
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    var installed: [String] = []
    for skill in BundledSkills.all {
      let skillDir = destination.appendingPathComponent(skill.name)
      let skillFile = skillDir.appendingPathComponent("SKILL.md")
      if FileManager.default.fileExists(atPath: skillFile.path) && !force {
        continue
      }
      try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
      try skill.contents.data(using: .utf8)!.write(to: skillFile)
      installed.append(skill.name)
    }
    return installed
  }

  func uninstall(scope: Scope) throws -> [String] {
    let destination = scope.directory()
    var removed: [String] = []
    for skill in BundledSkills.all {
      let skillDir = destination.appendingPathComponent(skill.name)
      if FileManager.default.fileExists(atPath: skillDir.path) {
        try FileManager.default.removeItem(at: skillDir)
        removed.append(skill.name)
      }
    }
    return removed
  }

  func status() -> StatusReport {
    let project = scopeStatus(.project)
    let global = scopeStatus(.global)
    return StatusReport(project: project, global: global)
  }

  private func scopeStatus(_ scope: Scope) -> ScopeStatus {
    let dir = scope.directory()
    var present: [String] = []
    for skill in BundledSkills.all {
      let skillFile = dir.appendingPathComponent(skill.name).appendingPathComponent("SKILL.md")
      if FileManager.default.fileExists(atPath: skillFile.path) {
        present.append(skill.name)
      }
    }
    return ScopeStatus(scope: scope.label, directory: dir.path, installed: present)
  }

  struct StatusReport: Encodable {
    let project: ScopeStatus
    let global: ScopeStatus
  }

  struct ScopeStatus: Encodable {
    let scope: String
    let directory: String
    let installed: [String]
  }
}
