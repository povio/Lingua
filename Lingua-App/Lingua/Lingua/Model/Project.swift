//
//  Project.swift
//  Lingua
//
//  Created by Egzon Arifi on 17/08/2023.
//

import SwiftUI
import LinguaLib

struct Project: Identifiable, Hashable, Equatable, Codable {
  var id: UUID
  var type: LocalizationPlatform
  var apiKey: String
  var sheetId: String
  var directoryPath: String
  var title: String
  var swiftCode: SwiftCode
  var swiftCodeEnabled: Bool
  var createdAt: Date
  var lastLocalizedAt: Date?
  var filterSectionsEnabled: Bool
  var allowedSections: [String]
  
  init(id: UUID,
       type: LocalizationPlatform,
       apiKey: String = "",
       sheetId: String = "",
       directoryPath: String = "",
       title: String = "",
       swiftCode: SwiftCode = .init(stringsDirectory: "", outputSwiftCodeFileDirectory: ""),
       swiftCodeEnabled: Bool = true,
       createdAt: Date = .init(),
       lastLocalizedAt: Date? = nil,
       filterSectionsEnabled: Bool = false,
       allowedSections: [String] = []) {
    self.id = id
    self.type = type
    self.apiKey = apiKey
    self.sheetId = sheetId
    self.directoryPath = directoryPath
    self.title = title
    self.swiftCode = swiftCode
    self.swiftCodeEnabled = swiftCodeEnabled
    self.createdAt = createdAt
    self.lastLocalizedAt = lastLocalizedAt
    self.filterSectionsEnabled = filterSectionsEnabled
    self.allowedSections = allowedSections
  }
  
  /// Custom initializer for decoding [Project] from persisted storage.
  /// This initializer ensures that if new properties are added to [Project] in the future and the persisted
  /// object doesn't contain those properties (due to being saved with an older app version), the new properties
  /// will have default values rather than causing a decoding failure.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    id = try container.decode(UUID.self, forKey: .id)
    type = try container.decode(LocalizationPlatform.self, forKey: .type)
    apiKey = try container.decode(String.self, forKey: .apiKey)
    sheetId = try container.decode(String.self, forKey: .sheetId)
    directoryPath = try container.decode(String.self, forKey: .directoryPath)
    title = try container.decode(String.self, forKey: .title)
    swiftCode = try container.decode(SwiftCode.self, forKey: .swiftCode)
    swiftCodeEnabled = try container.decode(Bool.self, forKey: .swiftCodeEnabled)
    createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    lastLocalizedAt = try container.decodeIfPresent(Date.self, forKey: .lastLocalizedAt)
    filterSectionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .filterSectionsEnabled) ?? false
    allowedSections = try container.decodeIfPresent([String].self, forKey: .allowedSections) ?? []
  }
}

extension Project {
  struct SwiftCode: Hashable, Equatable, Codable {
    var stringsDirectory: String
    var outputSwiftCodeFileDirectory: String
  }
  
  var bookmarkDataForDirectoryPath: String {
    "\(id.uuidString)directoryPath"
  }
  
  var bookmarkDataForOutputSwiftCodeFileDirectory: String {
    "\(id.uuidString)outputSwiftCodeFileDirectory"
  }
  
  var bookmarkDataForStringsDirectory: String {
    "\(id.uuidString)stringsDirectory"
  }

  var bookmarkDataForLinguaAISkillsInstallDirectory: String {
    "\(id.uuidString)linguaAISkillsInstallDirectory"
  }
  
  var icon: Image {
    switch type {
    case .ios:
      return Image(systemName: "apple.logo")
    case .android:
      return Image(systemName: "a.square.fill")
    }
  }
  
  func isValid(_ rule: RequiredRule = .init()) -> Bool {
    let basicValidation = rule.validate(apiKey) && rule.validate(sheetId) &&
    rule.validate(title) && rule.validate(directoryPath)
    if type == .ios && swiftCodeEnabled {
      return basicValidation && rule.validate(swiftCode.stringsDirectory) &&
      rule.validate(swiftCode.outputSwiftCodeFileDirectory)
    }
    return basicValidation
  }
}
