import Foundation
import LinguaLib

struct LinguaAIManager {
  enum Error: LocalizedError {
    case noInstalledTargets
    case directoryAccessUnavailable

    var errorDescription: String? {
      switch self {
      case .noInstalledTargets:
        return Lingua.ProjectForm.linguaAiNoInstalledTargetsError
      case .directoryAccessUnavailable:
        return Lingua.ProjectForm.linguaAiDirectoryAccessError
      }
    }
  }

  let globalHomeAccessor: LinguaAIGlobalHomeAccessor

  init(globalHomeAccessor: LinguaAIGlobalHomeAccessor = .init()) {
    self.globalHomeAccessor = globalHomeAccessor
  }

  @MainActor
  func globalStatus() async throws -> LinguaAIStatusReport {
    // First-open: no bookmark yet means "not installed", not an error.
    do {
      return try await globalHomeAccessor.withAccessToGlobalHome(promptIfNeeded: false) { homeURL in
        LinguaAIInstaller(homeDirectory: homeURL).status(projectDirectory: homeURL)
      }
    } catch LinguaAIGlobalHomeAccessor.Error.globalHomeBookmarkInvalid {
      return Self.emptyStatusReport
    }
  }

  @MainActor
  func suggestedGlobalInstallOption(
    status: LinguaAIStatusReport? = nil
  ) async throws -> LinguaAIInstallOption {
    if let status, status.hasGlobalInstallations {
      return LinguaAIInstallOption.bestMatch(for: status.globalInstalledTargets)
    }

    do {
      return try await globalHomeAccessor.withAccessToGlobalHome(promptIfNeeded: false) { homeURL in
        LinguaAIInstallOption.bestMatch(
          for: LinguaAIInstaller.autoDetectTargets(in: homeURL)
        )
      }
    } catch LinguaAIGlobalHomeAccessor.Error.globalHomeBookmarkInvalid {
      return .claude
    }
  }

  @MainActor
  func installGlobally(
    option: LinguaAIInstallOption,
    force: Bool = false
  ) async throws -> [LinguaAIScopeStatus] {
    try await globalHomeAccessor.withAccessToGlobalHome(promptIfNeeded: true) { homeURL in
      try LinguaAIInstaller(homeDirectory: homeURL).install(
        scope: .global,
        option: option,
        force: force,
        projectDirectory: homeURL
      )
    }
  }

  @MainActor
  func uninstallGloballyInstalledTargets(
    status: LinguaAIStatusReport
  ) async throws -> [LinguaAIScopeStatus] {
    let installedTargets = status.globalInstalledTargets
    guard !installedTargets.isEmpty else {
      throw Error.noInstalledTargets
    }

    return try await globalHomeAccessor.withAccessToGlobalHome(promptIfNeeded: true) { homeURL in
      let globalInstaller = LinguaAIInstaller(homeDirectory: homeURL)
      return try installedTargets.map { target in
        try globalInstaller.uninstall(
          scope: .global,
          target: target,
          projectDirectory: homeURL
        )
      }
    }
  }

  private static var emptyStatusReport: LinguaAIStatusReport {
    func empty(_ target: LinguaAITarget, _ scope: LinguaAIInstallScope) -> LinguaAIScopeStatus {
      LinguaAIScopeStatus(target: target.label, scope: scope.label, directory: "", installed: [])
    }
    return LinguaAIStatusReport(
      claudeCodeProject: empty(.claudeCode, .project),
      claudeCodeGlobal: empty(.claudeCode, .global),
      cursorProject: empty(.cursor, .project),
      cursorGlobal: empty(.cursor, .global),
      agentsProject: empty(.agents, .project),
      agentsGlobal: empty(.agents, .global)
    )
  }
}

// MARK: - Global-scope status accessors
extension LinguaAIStatusReport {
  var globalInstalledTargets: [LinguaAITarget] {
    globalStatuses.compactMap { status in
      guard status.isInstalled else { return nil }
      return status.targetValue
    }
  }

  var hasGlobalInstallations: Bool {
    globalStatuses.contains(where: \.isInstalled)
  }

  var globalInstallationState: LinguaAIInstallationState {
    if globalStatuses.allSatisfy({ !$0.isInstalled }) {
      return .notInstalled
    }
    if globalStatuses.contains(where: { $0.installationState == .partiallyInstalled }) {
      return .partiallyInstalled
    }
    return .installed
  }
}
