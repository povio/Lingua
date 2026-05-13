import Foundation

public enum LinguaAIProjectRootResolver {
  private static let markerDirectoryNames = [".git", ".claude", ".cursor", ".agents"]

  public static func resolve(from startingDirectory: URL, fileManager: FileManager = .default) -> URL {
    let normalizedDirectory = startingDirectory.standardizedFileURL.resolvingSymlinksInPath()
    var candidate = normalizedDirectory

    while true {
      if containsProjectMarker(in: candidate, fileManager: fileManager) {
        return candidate
      }

      let parent = candidate.deletingLastPathComponent()
      if parent.path == candidate.path {
        return normalizedDirectory
      }
      candidate = parent
    }
  }

  private static func containsProjectMarker(in directory: URL, fileManager: FileManager) -> Bool {
    markerDirectoryNames.contains { marker in
      fileManager.fileExists(atPath: directory.appendingPathComponent(marker).path)
    }
  }
}
