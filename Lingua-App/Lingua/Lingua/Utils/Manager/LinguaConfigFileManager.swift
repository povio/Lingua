//
//  LinguaConfigFileManager.swift
//  Lingua
//

import Foundation

struct LinguaConfigFileManager {
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let configFileName = "lingua_config.json"

  init(fileManager: FileManager = .default, encoder: JSONEncoder = JSONEncoder()) {
    self.fileManager = fileManager
    self.encoder = encoder
    self.encoder.outputFormatting = [.prettyPrinted]
  }

  func writeConfig(for project: Project) throws {
    let outputDirectoryPath = normalizedPath(from: project.directoryPath)
    guard !outputDirectoryPath.isEmpty else {
      throw Error.invalidOutputDirectory
    }

    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: outputDirectoryPath, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw Error.invalidOutputDirectory
    }

    let configURL = URL(fileURLWithPath: outputDirectoryPath, isDirectory: true)
      .appendingPathComponent(configFileName)

    let config = makeConfig(from: project, normalizedOutputDirectory: outputDirectoryPath)
    let data = try encoder.encode(config)
    guard var content = String(data: data, encoding: .utf8) else {
      throw Error.malformedContent
    }

    content = content.replacingOccurrences(of: "\\/", with: "/")
    try content.write(to: configURL, atomically: true, encoding: .utf8)
  }
}

private extension LinguaConfigFileManager {
  func makeConfig(from project: Project, normalizedOutputDirectory: String) -> LinguaConfig {
    let normalizedStringsDirectory = normalizedPath(from: project.swiftCode.stringsDirectory)
    let normalizedSwiftOutputDirectory = normalizedPath(from: project.swiftCode.outputSwiftCodeFileDirectory)
    let shouldIncludeSwiftCode = project.type == .ios &&
    project.swiftCodeEnabled &&
    !normalizedStringsDirectory.isEmpty &&
    !normalizedSwiftOutputDirectory.isEmpty

    let swiftCode: LinguaConfigSwiftCode? = shouldIncludeSwiftCode
    ? .init(stringsDirectory: normalizedStringsDirectory,
            outputSwiftCodeFileDirectory: normalizedSwiftOutputDirectory)
    : nil

    return .init(localization: .init(apiKey: project.apiKey,
                                     sheetId: project.sheetId,
                                     outputDirectory: normalizedOutputDirectory,
                                     swiftCode: swiftCode))
  }

  func normalizedPath(from rawPath: String) -> String {
    let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPath.isEmpty else { return "" }

    if let fileURL = URL(string: trimmedPath), fileURL.isFileURL {
      return fileURL.path
    }

    return trimmedPath
  }
}

extension LinguaConfigFileManager {
  enum Error: LocalizedError {
    case invalidOutputDirectory
    case malformedContent

    var errorDescription: String? {
      switch self {
      case .invalidOutputDirectory:
        return "Unable to create lingua_config.json because the output directory is invalid."
      case .malformedContent:
        return "Unable to create lingua_config.json because the generated content is malformed."
      }
    }
  }
}

private struct LinguaConfig: Encodable {
  let localization: LinguaConfigLocalization
}

private struct LinguaConfigLocalization: Encodable {
  let apiKey: String
  let sheetId: String
  let outputDirectory: String
  let swiftCode: LinguaConfigSwiftCode?
}

private struct LinguaConfigSwiftCode: Encodable {
  let stringsDirectory: String
  let outputSwiftCodeFileDirectory: String
}
