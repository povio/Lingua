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
  let directoryAccessor: DirectoryAccessor

  init(
    installer: LinguaAIInstaller = .init(),
    directoryAccessor: DirectoryAccessor = .init()
  ) {
    self.installer = installer
    self.directoryAccessor = directoryAccessor
  }

  func status(for project: Project) throws -> LinguaAIStatusReport {
    try withProjectDirectory(for: project) { projectDirectory in
      installer.status(projectDirectory: projectDirectory)
    }
  }

  func suggestedInstallOption(
    for project: Project,
    status: LinguaAIStatusReport? = nil
  ) throws -> LinguaAIInstallOption {
    if let status, status.hasProjectInstallations {
      return LinguaAIInstallOption.bestMatch(for: status.projectInstalledTargets)
    }

    return try withProjectDirectory(for: project) { projectDirectory in
      LinguaAIInstallOption.bestMatch(
        for: LinguaAIInstaller.autoDetectTargets(in: projectDirectory)
      )
    }
  }

  func install(
    option: LinguaAIInstallOption,
    for project: Project,
    force: Bool = false
  ) throws -> [LinguaAIScopeStatus] {
    try withProjectDirectory(for: project) { projectDirectory in
      try installer.install(
        scope: .project,
        option: option,
        force: force,
        projectDirectory: projectDirectory
      )
    }
  }

  func uninstallInstalledTargets(
    for project: Project,
    status: LinguaAIStatusReport
  ) throws -> [LinguaAIScopeStatus] {
    let installedTargets = status.projectInstalledTargets
    guard !installedTargets.isEmpty else {
      throw Error.noInstalledTargets
    }

    return try withProjectDirectory(for: project) { projectDirectory in
      try installedTargets.map { target in
        try installer.uninstall(
          scope: .project,
          target: target,
          projectDirectory: projectDirectory
        )
      }
    }
  }

  private func withProjectDirectory<T>(
    for project: Project,
    perform: (URL) throws -> T
  ) throws -> T {
    guard project.aiProjectRootURL != nil else {
      throw Error.missingProjectDirectory
    }

    do {
      return try directoryAccessor.withAccessToDirectory(
        fromBookmarkKey: project.bookmarkDataForDirectoryPath,
        path: project.directoryPath,
        perform: { accessedDirectory in
          try perform(accessedDirectory)
        }
      )
    } catch is DirectoryAccessor.Error {
      throw Error.directoryAccessUnavailable
    } catch let error as Error {
      throw error
    }
  }
}

private extension Project {
  var aiProjectRootURL: URL? {
    guard !directoryPath.isEmpty else { return nil }
    if let url = URL(string: directoryPath), url.isFileURL {
      return url
    }
    return URL(fileURLWithPath: directoryPath)
  }
}
