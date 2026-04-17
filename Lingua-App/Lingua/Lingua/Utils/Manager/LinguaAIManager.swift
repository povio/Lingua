import Foundation
import LinguaLib

struct LinguaAIManager {
  enum Error: LocalizedError {
    case missingProjectDirectory
    case noInstalledTargets
    case directoryAccessUnavailable

    var errorDescription: String? {
      switch self {
      case .missingProjectDirectory:
        return Lingua.ProjectForm.linguaAiMissingDirectoryError
      case .noInstalledTargets:
        return Lingua.ProjectForm.linguaAiNoInstalledTargetsError
      case .directoryAccessUnavailable:
        return Lingua.ProjectForm.linguaAiDirectoryAccessError
      }
    }
  }

  let installer: LinguaAIInstaller
  let rootAccessor: LinguaAIProjectRootAccessor

  init(
    installer: LinguaAIInstaller = .init(),
    rootAccessor: LinguaAIProjectRootAccessor = .init()
  ) {
    self.installer = installer
    self.rootAccessor = rootAccessor
  }

  @MainActor
  func status(for project: Project) async throws -> LinguaAIStatusReport {
    try await withProjectRoot(for: project, promptIfNeeded: false) { projectRoot in
      installer.status(projectDirectory: projectRoot)
    }
  }

  @MainActor
  func suggestedInstallOption(
    for project: Project,
    status: LinguaAIStatusReport? = nil
  ) async throws -> LinguaAIInstallOption {
    if let status, status.hasProjectInstallations {
      return LinguaAIInstallOption.bestMatch(for: status.projectInstalledTargets)
    }

    return try await withProjectRoot(for: project, promptIfNeeded: false) { projectRoot in
      LinguaAIInstallOption.bestMatch(
        for: LinguaAIInstaller.autoDetectTargets(in: projectRoot)
      )
    }
  }

  @MainActor
  func install(
    option: LinguaAIInstallOption,
    for project: Project,
    force: Bool = false
  ) async throws -> [LinguaAIScopeStatus] {
    try await withProjectRoot(for: project, promptIfNeeded: true) { projectRoot in
      try installer.install(
        scope: .project,
        option: option,
        force: force,
        projectDirectory: projectRoot
      )
    }
  }

  @MainActor
  func uninstallInstalledTargets(
    for project: Project,
    status: LinguaAIStatusReport
  ) async throws -> [LinguaAIScopeStatus] {
    let installedTargets = status.projectInstalledTargets
    guard !installedTargets.isEmpty else {
      throw Error.noInstalledTargets
    }

    return try await withProjectRoot(for: project, promptIfNeeded: true) { projectRoot in
      try installedTargets.map { target in
        try installer.uninstall(
          scope: .project,
          target: target,
          projectDirectory: projectRoot
        )
      }
    }
  }

  @MainActor
  private func withProjectRoot<T>(
    for project: Project,
    promptIfNeeded: Bool,
    perform: (URL) throws -> T
  ) async throws -> T {
    try await rootAccessor.withAccessToProjectRoot(
      for: project,
      promptIfNeeded: promptIfNeeded,
      perform: { grantedURL in
        try perform(grantedURL)
      }
    )
  }
}
