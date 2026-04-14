//
//  LinguaTests.swift
//  LinguaTests
//
//  Created by Egzon Arifi on 17/08/2023.
//

import XCTest
@testable import Lingua

final class LinguaConfigFileManagerTests: XCTestCase {
  private var temporaryDirectory: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    if let temporaryDirectory, FileManager.default.fileExists(atPath: temporaryDirectory.path) {
      try FileManager.default.removeItem(at: temporaryDirectory)
    }
    temporaryDirectory = nil
    try super.tearDownWithError()
  }

  func testWriteConfigCreatesConfigWithNormalizedPaths() throws {
    let outputDirectory = temporaryDirectory.appendingPathComponent("Output Folder", isDirectory: true)
    let stringsDirectory = outputDirectory.appendingPathComponent("en.lproj", isDirectory: true)
    let swiftOutputDirectory = outputDirectory.appendingPathComponent("Generated", isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: stringsDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: swiftOutputDirectory, withIntermediateDirectories: true)

    let project = Project(id: UUID(),
                          type: .ios,
                          apiKey: "api-key",
                          sheetId: "sheet-id",
                          directoryPath: outputDirectory.absoluteString,
                          title: "Test project",
                          swiftCode: .init(stringsDirectory: stringsDirectory.absoluteString,
                                           outputSwiftCodeFileDirectory: swiftOutputDirectory.absoluteString),
                          swiftCodeEnabled: true)

    try LinguaConfigFileManager().writeConfig(for: project)

    let configURL = outputDirectory.appendingPathComponent("lingua_config.json")
    let data = try Data(contentsOf: configURL)
    let config = try JSONDecoder().decode(LinguaConfig.self, from: data)

    XCTAssertEqual(config.localization.apiKey, "api-key")
    XCTAssertEqual(config.localization.sheetId, "sheet-id")
    XCTAssertEqual(config.localization.outputDirectory, outputDirectory.path)
    XCTAssertEqual(config.localization.swiftCode?.stringsDirectory, stringsDirectory.path)
    XCTAssertEqual(config.localization.swiftCode?.outputSwiftCodeFileDirectory, swiftOutputDirectory.path)
  }

  func testWriteConfigOverwritesExistingConfig() throws {
    let outputDirectory = temporaryDirectory.appendingPathComponent("Output", isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let configURL = outputDirectory.appendingPathComponent("lingua_config.json")
    let originalContent = """
    {
      "keep": true
    }
    """
    try originalContent.write(to: configURL, atomically: true, encoding: .utf8)

    let project = Project(id: UUID(),
                          type: .ios,
                          apiKey: "new-api-key",
                          sheetId: "new-sheet-id",
                          directoryPath: outputDirectory.path,
                          title: "Test project")

    try LinguaConfigFileManager().writeConfig(for: project)

    let content = try String(contentsOf: configURL, encoding: .utf8)
    XCTAssertNotEqual(content, originalContent)
    let config = try JSONDecoder().decode(LinguaConfig.self, from: Data(content.utf8))
    XCTAssertEqual(config.localization.apiKey, "new-api-key")
    XCTAssertEqual(config.localization.sheetId, "new-sheet-id")
  }

  func testWriteConfigOmitsSwiftCodeWhenDisabled() throws {
    let outputDirectory = temporaryDirectory.appendingPathComponent("Output", isDirectory: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let project = Project(id: UUID(),
                          type: .ios,
                          apiKey: "api-key",
                          sheetId: "sheet-id",
                          directoryPath: outputDirectory.path,
                          title: "Test project",
                          swiftCode: .init(stringsDirectory: "/tmp/en.lproj",
                                           outputSwiftCodeFileDirectory: "/tmp/generated"),
                          swiftCodeEnabled: false)

    try LinguaConfigFileManager().writeConfig(for: project)

    let configURL = outputDirectory.appendingPathComponent("lingua_config.json")
    let data = try Data(contentsOf: configURL)
    let config = try JSONDecoder().decode(LinguaConfig.self, from: data)

    XCTAssertNil(config.localization.swiftCode)
  }
}

private struct LinguaConfig: Decodable {
  let localization: LinguaConfigLocalization
}

private struct LinguaConfigLocalization: Decodable {
  let apiKey: String
  let sheetId: String
  let outputDirectory: String
  let swiftCode: LinguaConfigSwiftCode?
}

private struct LinguaConfigSwiftCode: Decodable {
  let stringsDirectory: String
  let outputSwiftCodeFileDirectory: String
}
