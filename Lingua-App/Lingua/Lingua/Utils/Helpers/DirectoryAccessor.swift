//
//  DirectoryAccessor.swift
//  Lingua
//
//  Created by Egzon Arifi on 21/08/2023.
//

import Foundation

struct DirectoryAccessor {
  enum Error: Swift.Error {
    case bookmarkError
    case securityScopeError
  }
  
  func accessDirectory(fromBookmarkKey key: String, path: String) async throws {
    guard let directoryURL = resolvedDirectoryURL(from: path),
          directoryExists(at: directoryURL) else { return }

    _ = try startAccessingDirectory(fromBookmarkKey: key)
  }

  func withAccessToDirectory<T>(
    fromBookmarkKey key: String,
    path: String,
    perform: (URL) throws -> T
  ) throws -> T {
    guard let directoryURL = resolvedDirectoryURL(from: path),
          directoryExists(at: directoryURL) else {
      throw Error.bookmarkError
    }

    let bookmarkURL = try startAccessingDirectory(fromBookmarkKey: key)
    defer { bookmarkURL.stopAccessingSecurityScopedResource() }
    return try perform(bookmarkURL)
  }
  
  private func directoryExists(at url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
      return isDirectory.boolValue
    } else {
      return false
    }
  }

  private func startAccessingDirectory(fromBookmarkKey key: String) throws -> URL {
    guard let bookmarkData = UserDefaults.standard.data(forKey: key) else {
      throw Error.bookmarkError
    }

    var isStale = false
    let bookmarkURL = try URL(
      resolvingBookmarkData: bookmarkData,
      options: .withSecurityScope,
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )

    if isStale {
      throw Error.bookmarkError
    }

    if !bookmarkURL.startAccessingSecurityScopedResource() {
      throw Error.securityScopeError
    }

    return bookmarkURL
  }

  private func resolvedDirectoryURL(from path: String) -> URL? {
    if let url = URL(string: path), url.isFileURL {
      return url
    }
    return URL(fileURLWithPath: path)
  }
}
