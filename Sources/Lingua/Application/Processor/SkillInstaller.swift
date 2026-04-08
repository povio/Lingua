import Foundation
import LinguaLib

/// Installs the bundled Lingua agent skills into the project's `.claude/skills/` (Claude Code)
/// or `.cursor/rules/` (Cursor) directory so an AI agent in either editor can drive Lingua
/// autonomously. Both targets are optional and orthogonal — install one, the other, or both.
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

    /// Returns the directory where files for the given target should be written. Throws
    /// `cursor_no_global` for the unsupported `.global + .cursor` combination — Cursor doesn't
    /// have a user-scoped rules directory; its global rules are configured through the
    /// Settings UI instead.
    func directory(for target: Target) throws -> URL {
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
        if case .global = self {
          throw AgentError(
            code: "cursor_no_global",
            message: "Cursor does not support a global rules directory; install per-project instead."
          )
        }
        return root.appendingPathComponent(".cursor").appendingPathComponent("rules")
      }
    }
  }

  enum Target: String, CaseIterable {
    case claudeCode = "claude"
    case cursor

    var label: String { rawValue }
  }

  // MARK: - Install

  func install(scope: Scope, target: Target, force: Bool) throws -> ScopeStatus {
    let destination = try scope.directory(for: target)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    var installed: [String] = []
    for skill in BundledSkills.all {
      let path = filePath(for: skill, in: destination, target: target)
      if FileManager.default.fileExists(atPath: path.path) && !force {
        continue
      }
      try FileManager.default.createDirectory(
        at: path.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let body = render(skill: skill, target: target)
      try body.data(using: .utf8)!.write(to: path)
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
    let destination = try scope.directory(for: target)
    var removed: [String] = []
    for skill in BundledSkills.all {
      let path = filePath(for: skill, in: destination, target: target)
      let containerToRemove: URL
      switch target {
      case .claudeCode:
        // Each Claude Code skill lives in its own subdirectory; remove the whole subdirectory.
        containerToRemove = path.deletingLastPathComponent()
      case .cursor:
        // Cursor rules are flat single .mdc files; remove the file itself.
        containerToRemove = path
      }
      if FileManager.default.fileExists(atPath: containerToRemove.path) {
        try FileManager.default.removeItem(at: containerToRemove)
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
      cursorProject: scopeStatus(.project, target: .cursor)
    )
  }

  private func scopeStatus(_ scope: Scope, target: Target) -> ScopeStatus {
    do {
      let dir = try scope.directory(for: target)
      var present: [String] = []
      for skill in BundledSkills.all {
        let path = filePath(for: skill, in: dir, target: target)
        if FileManager.default.fileExists(atPath: path.path) {
          present.append(skill.name)
        }
      }
      return ScopeStatus(target: target.label, scope: scope.label, directory: dir.path, installed: present)
    } catch {
      // The only throwing case is `.global + .cursor`, which is reported as an empty/N-A entry.
      return ScopeStatus(target: target.label, scope: scope.label, directory: "(unsupported)", installed: [])
    }
  }

  // MARK: - Auto-detection

  /// Picks targets based on what's already in the given directory. Used when the user runs
  /// `lingua ai install` without an explicit `--target`.
  ///
  /// - If `.cursor/` exists → include `.cursor`.
  /// - If `.claude/` exists → include `.claudeCode`.
  /// - If neither exists → fall back to `[.claudeCode]` so brand-new projects get the
  ///   original behavior, which is what existing users expect.
  ///
  /// Both can be returned, in which case both are installed.
  static func autoDetectTargets(in directory: URL) -> [Target] {
    var targets: [Target] = []
    let cursorDir = directory.appendingPathComponent(".cursor")
    let claudeDir = directory.appendingPathComponent(".claude")
    if FileManager.default.fileExists(atPath: cursorDir.path) {
      targets.append(.cursor)
    }
    if FileManager.default.fileExists(atPath: claudeDir.path) {
      targets.append(.claudeCode)
    }
    return targets.isEmpty ? [.claudeCode] : targets
  }

  // MARK: - Helpers

  /// Computes where a skill's file lives on disk for a given target.
  ///
  /// - Claude Code: `<dir>/<skill.name>/SKILL.md`
  /// - Cursor:      `<dir>/<skill.name>.mdc`
  private func filePath(for skill: BundledSkills.Skill, in directory: URL, target: Target) -> URL {
    switch target {
    case .claudeCode:
      return directory.appendingPathComponent(skill.name).appendingPathComponent("SKILL.md")
    case .cursor:
      return directory.appendingPathComponent("\(skill.name).mdc")
    }
  }

  /// Returns the on-disk content for a skill in the given target's format.
  private func render(skill: BundledSkills.Skill, target: Target) -> String {
    switch target {
    case .claudeCode:
      return skill.contents
    case .cursor:
      return CursorRuleFormatter.mdc(for: skill)
    }
  }

  // MARK: - Output types

  struct StatusReport: Encodable {
    let claudeCodeProject: ScopeStatus
    let claudeCodeGlobal: ScopeStatus
    let cursorProject: ScopeStatus

    enum CodingKeys: String, CodingKey {
      case claudeCodeProject = "claude_project"
      case claudeCodeGlobal = "claude_global"
      case cursorProject = "cursor_project"
    }
  }

  struct ScopeStatus: Encodable {
    let target: String
    let scope: String
    let directory: String
    let installed: [String]
  }
}
