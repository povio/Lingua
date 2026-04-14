//
//  LocalizationManager.swift
//  Lingua
//
//  Created by Egzon Arifi on 22/08/2023.
//

import Foundation
import LinguaLib

struct LocalizationManager {
  let directoryAccessor: DirectoryAccessor
  
  func localize(project: Project) async throws -> String {
    try await directoryAccessor.accessDirectory(fromBookmarkKey: project.bookmarkDataForDirectoryPath,
                                                path: project.directoryPath)
    try await directoryAccessor.accessDirectory(fromBookmarkKey: project.bookmarkDataForStringsDirectory,
                                                path: project.swiftCode.stringsDirectory)
    try await directoryAccessor.accessDirectory(fromBookmarkKey: project.bookmarkDataForOutputSwiftCodeFileDirectory,
                                                path: project.swiftCode.outputSwiftCodeFileDirectory)
    
    var localizedSwiftCode: Config.LocalizedSwiftCode?
    if project.swiftCodeEnabled,
       !project.swiftCode.stringsDirectory.isEmpty,
       !project.swiftCode.outputSwiftCodeFileDirectory.isEmpty,
       let stringsDirectoryURL = URL(string: project.swiftCode.stringsDirectory),
       let swiftCodeFileDirectoryURL = URL(string: project.swiftCode.outputSwiftCodeFileDirectory) {
      localizedSwiftCode = .init(stringsDirectory: stringsDirectoryURL.path,
                                 outputSwiftCodeFileDirectory: swiftCodeFileDirectoryURL.path)
    }
    
    let config = Config.Localization(apiKey: project.apiKey,
                                     sheetId: project.sheetId,
                                     outputDirectory: project.directoryPath,
                                     localizedSwiftCode: localizedSwiftCode,
                                     allowedSections: project.filterSectionsEnabled ? project.allowedSections : .none)
    let module = LocalizationModuleFactory.make(config: config)
    
    try await module.localize(for: project.type)
    return Lingua.Projects.localizedMessage(project.title)
  }
}
