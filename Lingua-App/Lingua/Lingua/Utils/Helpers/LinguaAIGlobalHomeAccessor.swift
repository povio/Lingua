import AppKit
import Foundation

struct LinguaAIGlobalHomeAccessor {
  enum Error: LocalizedError {
    case userDeniedGlobalHomeAccess
    case globalHomeBookmarkInvalid
    case globalHomeAccessDenied

    var errorDescription: String? {
      switch self {
      case .globalHomeBookmarkInvalid,
           .globalHomeAccessDenied:
        return Lingua.ProjectForm.linguaAiDirectoryAccessError
      case .userDeniedGlobalHomeAccess:
        return Lingua.ProjectForm.linguaAiGlobalHomeAccessDenied
      }
    }
  }

  static let bookmarkUserDefaultsKey = "bookmarkDataForLinguaAIGlobalHome"

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
  func withAccessToGlobalHome<T>(
    promptIfNeeded: Bool,
    perform: (URL) throws -> T
  ) async throws -> T {
    if let bookmarkURL = try? startAccessingExistingBookmark() {
      defer { bookmarkURL.stopAccessingSecurityScopedResource() }
      return try perform(bookmarkURL)
    }

    guard promptIfNeeded else {
      throw Error.globalHomeBookmarkInvalid
    }

    let grantedURL = try await promptForGlobalHomeAccess()
    try grantedURL.saveBookmarkData(forKey: Self.bookmarkUserDefaultsKey)

    guard grantedURL.startAccessingSecurityScopedResource() else {
      throw Error.globalHomeAccessDenied
    }
    defer { grantedURL.stopAccessingSecurityScopedResource() }

    return try perform(grantedURL)
  }
}

// MARK: - Private helpers
private extension LinguaAIGlobalHomeAccessor {
  func startAccessingExistingBookmark() throws -> URL {
    guard let bookmarkData = userDefaults.data(forKey: Self.bookmarkUserDefaultsKey) else {
      throw Error.globalHomeBookmarkInvalid
    }

    var isStale = false
    let bookmarkURL = try URL(
      resolvingBookmarkData: bookmarkData,
      options: .withSecurityScope,
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )

    if isStale {
      throw Error.globalHomeBookmarkInvalid
    }

    if !bookmarkURL.startAccessingSecurityScopedResource() {
      throw Error.globalHomeAccessDenied
    }

    return bookmarkURL
  }

  @MainActor
  func promptForGlobalHomeAccess() async throws -> URL {
    let pickedURL = await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = false
      // NSOpenPanel runs outside the sandbox and shows the real home, which is what
      // we need — FileManager.homeDirectoryForCurrentUser would resolve to the container.
      panel.directoryURL = URL(fileURLWithPath: NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory())
      panel.prompt = Lingua.General.choose
      panel.message = Lingua.ProjectForm.linguaAiGlobalHomeAccessPrompt
      panel.begin { _ in
        continuation.resume(returning: panel.urls.first)
      }
    }

    guard let pickedURL else {
      throw Error.userDeniedGlobalHomeAccess
    }

    return pickedURL
  }
}
