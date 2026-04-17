import AppKit
import Foundation
import LinguaLib

struct LinguaAIProjectRootAccessor {
  enum Error: LocalizedError {
    case missingProjectDirectory
    case userDeniedProjectRootAccess
    case projectRootBookmarkInvalid
    case projectRootAccessDenied

    var errorDescription: String? {
      switch self {
      case .missingProjectDirectory:
        return Lingua.ProjectForm.linguaAiMissingDirectoryError
      case .projectRootBookmarkInvalid,
           .projectRootAccessDenied:
        return Lingua.ProjectForm.linguaAiDirectoryAccessError
      case .userDeniedProjectRootAccess:
        return Lingua.ProjectForm.linguaAiProjectRootAccessDenied
      }
    }
  }

  let fileManager: FileManager
  let userDefaults: UserDefaults

  init(
    fileManager: FileManager = .default,
    userDefaults: UserDefaults = .standard
  ) {
    self.fileManager = fileManager
    self.userDefaults = userDefaults
  }

  @MainActor
  func withAccessToProjectRoot<T>(
    for project: Project,
    promptIfNeeded: Bool,
    perform: (URL) throws -> T
  ) async throws -> T {
    guard !project.directoryPath.isEmpty,
          let selectedDirectory = resolvedDirectoryURL(from: project.directoryPath) else {
      throw Error.missingProjectDirectory
    }

    if let bookmarkURL = try? startAccessingExistingBookmark(
      forKey: project.bookmarkDataForLinguaAISkillsInstallDirectory
    ) {
      defer { bookmarkURL.stopAccessingSecurityScopedResource() }
      return try perform(bookmarkURL)
    }

    guard promptIfNeeded else {
      throw Error.projectRootBookmarkInvalid
    }

    let suggestedRoot = LinguaAIProjectRootResolver.resolve(
      from: selectedDirectory,
      fileManager: fileManager
    )

    let grantedURL = try await promptForProjectRootAccess(startingAt: suggestedRoot)
    try grantedURL.saveBookmarkData(forKey: project.bookmarkDataForLinguaAISkillsInstallDirectory)

    guard grantedURL.startAccessingSecurityScopedResource() else {
      throw Error.projectRootAccessDenied
    }
    defer { grantedURL.stopAccessingSecurityScopedResource() }

    return try perform(grantedURL)
  }
}

// MARK: - Private helpers
private extension LinguaAIProjectRootAccessor {
  func resolvedDirectoryURL(from path: String) -> URL? {
    if let url = URL(string: path), url.isFileURL {
      return url
    }
    return URL(fileURLWithPath: path)
  }

  func startAccessingExistingBookmark(forKey key: String) throws -> URL {
    guard let bookmarkData = userDefaults.data(forKey: key) else {
      throw Error.projectRootBookmarkInvalid
    }

    var isStale = false
    let bookmarkURL = try URL(
      resolvingBookmarkData: bookmarkData,
      options: .withSecurityScope,
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )

    if isStale {
      throw Error.projectRootBookmarkInvalid
    }

    if !bookmarkURL.startAccessingSecurityScopedResource() {
      throw Error.projectRootAccessDenied
    }

    return bookmarkURL
  }

  @MainActor
  func promptForProjectRootAccess(startingAt suggestedRoot: URL) async throws -> URL {
    let pickedURL = await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = false
      panel.directoryURL = suggestedRoot
      panel.prompt = Lingua.General.choose
      panel.message = Lingua.ProjectForm.linguaAiProjectRootAccessPrompt
      panel.begin { _ in
        continuation.resume(returning: panel.urls.first)
      }
    }

    guard let pickedURL else {
      throw Error.userDeniedProjectRootAccess
    }

    return pickedURL
  }
}
