import Foundation
import LinguaLib

/// Installs the bundled Lingua agent skills into the project's `.claude/skills/` (Claude Code),
/// `.cursor/skills/` (Cursor), or `.agents/skills/` (generic Agent Skills layout) — or the global
/// equivalents under `~` — so an AI agent can drive Lingua autonomously.
///
/// Cursor 2.4+ and compatible runtimes use the same Agent Skills standard as Claude Code (same
/// `SKILL.md` nested layout and frontmatter), so every target shares the exact same on-disk
/// format; only the parent directory differs.
struct SkillInstaller {
  enum Scope {
    case project   // ./
    case global    // ~/

    var label: String {
      switch self {
      case .project: return "project"
      case .global: return "global"
      }
    }

    /// Returns the directory where files for the given target should be written.
    func directory(for target: Target) -> URL {
      let root: URL
      switch self {
      case .project:
        root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      case .global:
        root = FileManager.default.homeDirectoryForCurrentUser
      }
      switch target {
      case .claudeCode:
        return root.appendingPathComponent(".claude").appendingPathComponent("skills")
      case .cursor:
        return root.appendingPathComponent(".cursor").appendingPathComponent("skills")
      case .agents:
        return root.appendingPathComponent(".agents").appendingPathComponent("skills")
      }
    }
  }

  enum Target: String, CaseIterable {
    case claudeCode = "claude"
    case cursor
    case agents

    var label: String { rawValue }
  }

  // MARK: - Install

  func install(scope: Scope, target: Target, force: Bool) throws -> ScopeStatus {
    let destination = scope.directory(for: target)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    var installed: [String] = []
    for skill in BundledSkills.all {
      let path = filePath(for: skill, in: destination)
      if FileManager.default.fileExists(atPath: path.path) && !force {
        continue
      }
      try FileManager.default.createDirectory(
        at: path.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try skill.contents.data(using: .utf8)!.write(to: path)
      installed.append(skill.name)
    }
    return ScopeStatus(
      target: target.label,
      scope: scope.label,
      directory: destination.path,
      installed: installed
    )
  }

  // MARK: - Uninstall

  func uninstall(scope: Scope, target: Target) throws -> ScopeStatus {
    let destination = scope.directory(for: target)
    var removed: [String] = []
    for skill in BundledSkills.all {
      // Each skill lives in its own subdirectory; remove the whole subdirectory.
      let skillDir = destination.appendingPathComponent(skill.name)
      if FileManager.default.fileExists(atPath: skillDir.path) {
        try FileManager.default.removeItem(at: skillDir)
        removed.append(skill.name)
      }
    }
    return ScopeStatus(
      target: target.label,
      scope: scope.label,
      directory: destination.path,
      installed: removed
    )
  }

  // MARK: - Status

  func status() -> StatusReport {
    StatusReport(
      claudeCodeProject: scopeStatus(.project, target: .claudeCode),
      claudeCodeGlobal: scopeStatus(.global, target: .claudeCode),
      cursorProject: scopeStatus(.project, target: .cursor),
      cursorGlobal: scopeStatus(.global, target: .cursor),
      agentsProject: scopeStatus(.project, target: .agents),
      agentsGlobal: scopeStatus(.global, target: .agents)
    )
  }

  private func scopeStatus(_ scope: Scope, target: Target) -> ScopeStatus {
    let dir = scope.directory(for: target)
    var present: [String] = []
    for skill in BundledSkills.all {
      let path = filePath(for: skill, in: dir)
      if FileManager.default.fileExists(atPath: path.path) {
        present.append(skill.name)
      }
    }
    return ScopeStatus(target: target.label, scope: scope.label, directory: dir.path, installed: present)
  }

  // MARK: - Auto-detection

  /// Picks targets based on what's already in the given directory. Used when the user runs
  /// `lingua ai install` without an explicit `--target`.
  ///
  /// - If `.cursor/` exists → include `.cursor`.
  /// - If `.claude/` exists → include `.claudeCode`.
  /// - If `.agents/` exists → include `.agents`.
  /// - If none of the above exist → fall back to `[.claudeCode]` so brand-new projects get the
  ///   original behavior, which is what existing users expect.
  ///
  /// Any combination of the above can be returned, in which case each detected target is
  /// installed.
  ///
  /// For project scope this is called with the cwd; for global scope it's called with the
  /// user's home directory (since `~/.cursor/`, `~/.claude/`, and `~/.agents/` are the global
  /// skill roots).
  static func autoDetectTargets(in directory: URL) -> [Target] {
    var targets: [Target] = []
    let cursorDir = directory.appendingPathComponent(".cursor")
    let claudeDir = directory.appendingPathComponent(".claude")
    let agentsDir = directory.appendingPathComponent(".agents")
    if FileManager.default.fileExists(atPath: cursorDir.path) {
      targets.append(.cursor)
    }
    if FileManager.default.fileExists(atPath: claudeDir.path) {
      targets.append(.claudeCode)
    }
    if FileManager.default.fileExists(atPath: agentsDir.path) {
      targets.append(.agents)
    }
    return targets.isEmpty ? [.claudeCode] : targets
  }

  // MARK: - Helpers

  /// Computes where a skill's file lives on disk. Every target uses the same nested layout:
  /// `<dir>/<skill.name>/SKILL.md`.
  private func filePath(for skill: BundledSkills.Skill, in directory: URL) -> URL {
    directory.appendingPathComponent(skill.name).appendingPathComponent("SKILL.md")
  }

  // MARK: - Output types

  struct StatusReport: Encodable {
    let claudeCodeProject: ScopeStatus
    let claudeCodeGlobal: ScopeStatus
    let cursorProject: ScopeStatus
    let cursorGlobal: ScopeStatus
    let agentsProject: ScopeStatus
    let agentsGlobal: ScopeStatus

    enum CodingKeys: String, CodingKey {
      case claudeCodeProject = "claude_project"
      case claudeCodeGlobal = "claude_global"
      case cursorProject = "cursor_project"
      case cursorGlobal = "cursor_global"
      case agentsProject = "agents_project"
      case agentsGlobal = "agents_global"
    }
  }

  struct ScopeStatus: Encodable {
    let target: String
    let scope: String
    let directory: String
    let installed: [String]
  }
}
