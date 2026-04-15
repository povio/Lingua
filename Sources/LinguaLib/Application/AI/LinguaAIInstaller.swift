import Foundation

public enum LinguaAITarget: String, CaseIterable, Codable, Identifiable {
  case claudeCode = "claude"
  case cursor
  case agents

  public var id: String { rawValue }
  public var label: String { rawValue }
}

public enum LinguaAIInstallOption: String, CaseIterable, Codable, Identifiable {
  case claude
  case cursor
  case agents
  case both

  public var id: String { rawValue }
  public var label: String { rawValue }

  public var targets: [LinguaAITarget] {
    switch self {
    case .claude:
      return [.claudeCode]
    case .cursor:
      return [.cursor]
    case .agents:
      return [.agents]
    case .both:
      return [.claudeCode, .cursor]
    }
  }

  public static var supportedLabels: [String] {
    allCases.map(\.rawValue)
  }

  public static func bestMatch(for targets: [LinguaAITarget]) -> LinguaAIInstallOption {
    let targetSet = Set(targets)
    if targetSet == Set(LinguaAIInstallOption.both.targets) {
      return .both
    }
    if targetSet == Set([.claudeCode]) {
      return .claude
    }
    if targetSet == Set([.cursor]) {
      return .cursor
    }
    if targetSet == Set([.agents]) {
      return .agents
    }
    return .claude
  }
}

public enum LinguaAIInstallScope: String, Codable {
  case project
  case global

  public var label: String { rawValue }
}

public enum LinguaAIInstallationState: Equatable {
  case notInstalled
  case partiallyInstalled
  case installed
}

public struct LinguaAIScopeStatus: Codable {
  public let target: String
  public let scope: String
  public let directory: String
  public let installed: [String]

  public init(target: String, scope: String, directory: String, installed: [String]) {
    self.target = target
    self.scope = scope
    self.directory = directory
    self.installed = installed
  }

  public var targetValue: LinguaAITarget? {
    LinguaAITarget(rawValue: target)
  }

  public var installationState: LinguaAIInstallationState {
    if installed.isEmpty {
      return .notInstalled
    }
    if installed.count < LinguaAIBundledSkills.all.count {
      return .partiallyInstalled
    }
    return .installed
  }

  public var isInstalled: Bool {
    !installed.isEmpty
  }
}

public struct LinguaAIStatusReport: Codable {
  public let claudeCodeProject: LinguaAIScopeStatus
  public let claudeCodeGlobal: LinguaAIScopeStatus
  public let cursorProject: LinguaAIScopeStatus
  public let cursorGlobal: LinguaAIScopeStatus
  public let agentsProject: LinguaAIScopeStatus
  public let agentsGlobal: LinguaAIScopeStatus

  public init(
    claudeCodeProject: LinguaAIScopeStatus,
    claudeCodeGlobal: LinguaAIScopeStatus,
    cursorProject: LinguaAIScopeStatus,
    cursorGlobal: LinguaAIScopeStatus,
    agentsProject: LinguaAIScopeStatus,
    agentsGlobal: LinguaAIScopeStatus
  ) {
    self.claudeCodeProject = claudeCodeProject
    self.claudeCodeGlobal = claudeCodeGlobal
    self.cursorProject = cursorProject
    self.cursorGlobal = cursorGlobal
    self.agentsProject = agentsProject
    self.agentsGlobal = agentsGlobal
  }

  enum CodingKeys: String, CodingKey {
    case claudeCodeProject = "claude_project"
    case claudeCodeGlobal = "claude_global"
    case cursorProject = "cursor_project"
    case cursorGlobal = "cursor_global"
    case agentsProject = "agents_project"
    case agentsGlobal = "agents_global"
  }

  public var projectStatuses: [LinguaAIScopeStatus] {
    [claudeCodeProject, cursorProject, agentsProject]
  }

  public var globalStatuses: [LinguaAIScopeStatus] {
    [claudeCodeGlobal, cursorGlobal, agentsGlobal]
  }

  public var projectInstalledTargets: [LinguaAITarget] {
    projectStatuses.compactMap { status in
      guard status.isInstalled else { return nil }
      return status.targetValue
    }
  }

  public var hasProjectInstallations: Bool {
    projectStatuses.contains(where: \.isInstalled)
  }

  public var projectInstallationState: LinguaAIInstallationState {
    let statuses = projectStatuses
    if statuses.allSatisfy({ !$0.isInstalled }) {
      return .notInstalled
    }
    if statuses.contains(where: { $0.installationState == .partiallyInstalled }) {
      return .partiallyInstalled
    }
    return .installed
  }
}

public struct LinguaAIInstaller {
  private let fileManager: FileManager
  private let homeDirectory: URL
  private let skills: [LinguaAIBundledSkills.Skill]

  public init(
    fileManager: FileManager = .default,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    skills: [LinguaAIBundledSkills.Skill] = LinguaAIBundledSkills.all
  ) {
    self.fileManager = fileManager
    self.homeDirectory = homeDirectory
    self.skills = skills
  }

  public func install(
    scope: LinguaAIInstallScope,
    target: LinguaAITarget,
    force: Bool,
    projectDirectory: URL
  ) throws -> LinguaAIScopeStatus {
    let resolvedProjectDirectory = resolvedProjectDirectory(from: projectDirectory)
    let destination = directory(for: scope, target: target, projectDirectory: resolvedProjectDirectory)
    try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

    var installed: [String] = []
    for skill in skills {
      let path = filePath(for: skill, in: destination)
      if fileManager.fileExists(atPath: path.path) && !force {
        continue
      }
      try fileManager.createDirectory(
        at: path.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try skill.contents.data(using: .utf8)!.write(to: path)
      installed.append(skill.name)
    }

    return LinguaAIScopeStatus(
      target: target.label,
      scope: scope.label,
      directory: destination.path,
      installed: installed
    )
  }

  public func install(
    scope: LinguaAIInstallScope,
    option: LinguaAIInstallOption,
    force: Bool,
    projectDirectory: URL
  ) throws -> [LinguaAIScopeStatus] {
    try option.targets.map { target in
      try install(scope: scope, target: target, force: force, projectDirectory: projectDirectory)
    }
  }

  public func uninstall(
    scope: LinguaAIInstallScope,
    target: LinguaAITarget,
    projectDirectory: URL
  ) throws -> LinguaAIScopeStatus {
    let resolvedProjectDirectory = resolvedProjectDirectory(from: projectDirectory)
    let destination = directory(for: scope, target: target, projectDirectory: resolvedProjectDirectory)
    var removed: [String] = []

    for skill in skills {
      let skillDirectory = destination.appendingPathComponent(skill.name)
      if fileManager.fileExists(atPath: skillDirectory.path) {
        try fileManager.removeItem(at: skillDirectory)
        removed.append(skill.name)
      }
    }

    return LinguaAIScopeStatus(
      target: target.label,
      scope: scope.label,
      directory: destination.path,
      installed: removed
    )
  }

  public func uninstall(
    scope: LinguaAIInstallScope,
    option: LinguaAIInstallOption,
    projectDirectory: URL
  ) throws -> [LinguaAIScopeStatus] {
    try option.targets.map { target in
      try uninstall(scope: scope, target: target, projectDirectory: projectDirectory)
    }
  }

  public func status(projectDirectory: URL) -> LinguaAIStatusReport {
    let resolvedProjectDirectory = resolvedProjectDirectory(from: projectDirectory)
    return LinguaAIStatusReport(
      claudeCodeProject: scopeStatus(.project, target: .claudeCode, projectDirectory: resolvedProjectDirectory),
      claudeCodeGlobal: scopeStatus(.global, target: .claudeCode, projectDirectory: resolvedProjectDirectory),
      cursorProject: scopeStatus(.project, target: .cursor, projectDirectory: resolvedProjectDirectory),
      cursorGlobal: scopeStatus(.global, target: .cursor, projectDirectory: resolvedProjectDirectory),
      agentsProject: scopeStatus(.project, target: .agents, projectDirectory: resolvedProjectDirectory),
      agentsGlobal: scopeStatus(.global, target: .agents, projectDirectory: resolvedProjectDirectory)
    )
  }

  public func scopeStatus(
    _ scope: LinguaAIInstallScope,
    target: LinguaAITarget,
    projectDirectory: URL
  ) -> LinguaAIScopeStatus {
    let resolvedProjectDirectory = resolvedProjectDirectory(from: projectDirectory)
    let directory = directory(for: scope, target: target, projectDirectory: resolvedProjectDirectory)
    let present = skills.compactMap { skill in
      let path = filePath(for: skill, in: directory)
      return fileManager.fileExists(atPath: path.path) ? skill.name : nil
    }

    return LinguaAIScopeStatus(
      target: target.label,
      scope: scope.label,
      directory: directory.path,
      installed: present
    )
  }

  public static func autoDetectTargets(
    in directory: URL,
    fileManager: FileManager = .default
  ) -> [LinguaAITarget] {
    let resolvedDirectory = LinguaAIProjectRootResolver.resolve(from: directory, fileManager: fileManager)
    var targets: [LinguaAITarget] = []
    let cursorDirectory = resolvedDirectory.appendingPathComponent(".cursor")
    let claudeDirectory = resolvedDirectory.appendingPathComponent(".claude")
    let agentsDirectory = resolvedDirectory.appendingPathComponent(".agents")

    if fileManager.fileExists(atPath: cursorDirectory.path) {
      targets.append(.cursor)
    }
    if fileManager.fileExists(atPath: claudeDirectory.path) {
      targets.append(.claudeCode)
    }
    if fileManager.fileExists(atPath: agentsDirectory.path) {
      targets.append(.agents)
    }

    return targets.isEmpty ? [.claudeCode] : targets
  }

  private func directory(
    for scope: LinguaAIInstallScope,
    target: LinguaAITarget,
    projectDirectory: URL
  ) -> URL {
    let root: URL
    switch scope {
    case .project:
      root = projectDirectory
    case .global:
      root = homeDirectory
    }

    switch target {
    case .claudeCode:
      return root.appendingPathComponent(".claude").appendingPathComponent("skills")
    case .cursor:
      return root.appendingPathComponent(".cursor").appendingPathComponent("skills")
    case .agents:
      return root.appendingPathComponent(".agents").appendingPathComponent("skills")
    }
  }

  private func resolvedProjectDirectory(from projectDirectory: URL) -> URL {
    LinguaAIProjectRootResolver.resolve(from: projectDirectory, fileManager: fileManager)
  }

  private func filePath(
    for skill: LinguaAIBundledSkills.Skill,
    in directory: URL
  ) -> URL {
    directory.appendingPathComponent(skill.name).appendingPathComponent("SKILL.md")
  }
}
