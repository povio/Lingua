import Foundation
import LinguaLib

/// Backward-compatible CLI wrapper around the shared Lingua AI installer.
struct SkillInstaller {
  typealias Scope = LinguaAIInstallScope
  typealias Target = LinguaAITarget
  typealias StatusReport = LinguaAIStatusReport
  typealias ScopeStatus = LinguaAIScopeStatus

  private let installer = LinguaAIInstaller()

  func install(scope: Scope, target: Target, force: Bool) throws -> ScopeStatus {
    try installer.install(
      scope: scope,
      target: target,
      force: force,
      projectDirectory: currentProjectDirectory
    )
  }

  func uninstall(scope: Scope, target: Target) throws -> ScopeStatus {
    try installer.uninstall(
      scope: scope,
      target: target,
      projectDirectory: currentProjectDirectory
    )
  }

  func status() -> StatusReport {
    installer.status(projectDirectory: currentProjectDirectory)
  }

  static func autoDetectTargets(in directory: URL) -> [Target] {
    LinguaAIInstaller.autoDetectTargets(in: directory)
  }

  private var currentProjectDirectory: URL {
    LinguaAIProjectRootResolver.resolve(
      from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    )
  }
}
