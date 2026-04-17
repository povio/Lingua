//
//  ProjectsViewModel.swift
//  Lingua
//
//  Created by Egzon Arifi on 18/08/2023.
//

import SwiftUI
import LinguaLib

class ProjectsViewModel: ObservableObject {
  @Published var projects: [Project] = UserDefaults.getProjects() {
    didSet { UserDefaults.setProjects(projects) }
  }
  private var sortedProjects: [Project] {
    projects.sorted(by: {
      $0.lastLocalizedAt ?? Date.distantPast > $1.lastLocalizedAt ?? Date.distantPast
    })
  }
  var filteredProjects: [Project] {
    guard !searchTerm.isEmpty else { return sortedProjects }
    return sortedProjects.filter { $0.title.localizedCaseInsensitiveContains(searchTerm) }
  }
  @Published var searchTerm: String = ""
  var selectedProject: Project? {
    projects.first(where: { $0.id == selectedProjectId })
  }
  @Published var isLocalizing: Bool = false
  @Published var isRefreshingAIStatus: Bool = false
  @Published var isManagingAI: Bool = false
  @Published var showDeleteAlert: Bool = false
  @Published var projectToDelete: Project?
  @Published var localizationResult: Result<String, Error>?
  @Published var aiResult: Result<String, Error>?
  @Published var aiStatus: LinguaAIStatusReport?
  @Published var aiStatusError: Error?
  @Published var aiInstallOption: LinguaAIInstallOption = .claude
  @Published var aiProgressText: String = ""
  @Published var selectedProjectId: UUID?

  var isShowingProgressOverlay: Bool {
    isLocalizing || isManagingAI
  }

  var progressOverlayText: String {
    isManagingAI ? aiProgressText : Lingua.Projects.localizing
  }
  
  private let localizationManager = LocalizationManager(directoryAccessor: DirectoryAccessor())
  private let aiManager = LinguaAIManager()
}

// MARK: - Public Methods
extension ProjectsViewModel {
  func deleteProject(_ project: Project) {
    guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
    if projects[index] == selectedProject {
      selectedProjectId = nil
      aiStatus = nil
      aiStatusError = nil
    }
    projects.remove(at: index)
  }
  
  func addProject(_ project: Project) {
    projects.append(project)
  }
  
  func updateProject(_ project: Project) {
    guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
    let previousProject = projects[index]
    projects[index] = project

    if previousProject.directoryPath != project.directoryPath {
      UserDefaults.standard.removeObject(forKey: project.bookmarkDataForLinguaAISkillsInstallDirectory)
    }

    if selectedProject?.id == project.id {
      updateSelectedProject(project)
      if previousProject.directoryPath != project.directoryPath {
        Task { await refreshAIStatus(for: project) }
      }
    }
  }
  
  func createNewProject() {
    let newProject = Project(id: UUID(), type: .ios, title: Lingua.Projects.newProject)
    projects.append(newProject)
    updateSelectedProject(newProject)
  }
  
  func duplicate(_ project: Project) {
    let newProject = Project(id: UUID(),
                             type: project.type,
                             apiKey: project.apiKey,
                             sheetId: project.sheetId,
                             title: Lingua.Projects.copyProject(project.title))
    projects.append(newProject)
    updateSelectedProject(newProject)
  }
  
  func selectFirstProject() {
    guard let firstProject = filteredProjects.first else { return }
    updateSelectedProject(firstProject)
  }

  @MainActor
  func refreshSelectedProjectAIStatus() async {
    guard let project = selectedProject else {
      aiStatus = nil
      aiStatusError = nil
      return
    }

    await refreshAIStatus(for: project)
  }
  
  @MainActor
  func updateSyncDate(for project: Project) {
    if let index = projects.firstIndex(where: { $0.id == project.id }) {
      withAnimation {
        projects[index].lastLocalizedAt = Date()
        projects.insert(projects.remove(at: index), at: 0)
      }
    }
  }
  
  @MainActor
  func localizeProject(_ project: Project) async {
    withAnimation {
      isLocalizing = true
      localizationResult = nil
    }
    
    do {
      let message = try await localizationManager.localize(project: project)
      updateSyncDate(for: project)
      localizationResult = .success(message)
    } catch {
      localizationResult = .failure(error)
    }
    
    withAnimation {
      isLocalizing = false
    }
  }

  @MainActor
  func installLinguaAI(for project: Project) async {
    withAnimation {
      isManagingAI = true
      aiProgressText = Lingua.ProjectForm.linguaAiInstalling
      aiResult = nil
      aiStatusError = nil
    }

    do {
      _ = try await aiManager.install(option: aiInstallOption, for: project)
      let updatedStatus = try await aiManager.status(for: project)

      aiStatus = updatedStatus
      aiInstallOption = try await aiManager.suggestedInstallOption(for: project, status: updatedStatus)
      aiResult = .success(Lingua.ProjectForm.linguaAiInstalled(aiInstallOption.label.capitalized))
    } catch {
      aiResult = .failure(error)
    }

    withAnimation {
      isManagingAI = false
      aiProgressText = ""
    }
  }

  @MainActor
  func uninstallLinguaAI(for project: Project) async {
    guard let status = aiStatus else { return }

    withAnimation {
      isManagingAI = true
      aiProgressText = Lingua.ProjectForm.linguaAiUninstalling
      aiResult = nil
      aiStatusError = nil
    }

    do {
      _ = try await aiManager.uninstallInstalledTargets(for: project, status: status)
      let updatedStatus = try await aiManager.status(for: project)

      aiStatus = updatedStatus
      aiInstallOption = try await aiManager.suggestedInstallOption(for: project, status: updatedStatus)
      aiResult = .success(Lingua.ProjectForm.linguaAiUninstalled)
    } catch {
      aiResult = .failure(error)
    }

    withAnimation {
      isManagingAI = false
      aiProgressText = ""
    }
  }

  func confirmDelete(for project: Project) {
    projectToDelete = project
    showDeleteAlert = true
  }
}

// MARK: - Private methods
private extension ProjectsViewModel {
  @MainActor
  func refreshAIStatus(for project: Project) async {
    guard !project.directoryPath.isEmpty else {
      aiStatus = nil
      aiStatusError = nil
      aiInstallOption = .claude
      return
    }

    isRefreshingAIStatus = true
    aiStatusError = nil

    do {
      let status = try await aiManager.status(for: project)
      aiStatus = status
      aiInstallOption = try await aiManager.suggestedInstallOption(for: project, status: status)
    } catch {
      aiStatus = nil
      aiStatusError = error
    }

    isRefreshingAIStatus = false
  }

  func updateSelectedProject(_ project: Project) {
    withAnimation(.easeIn(duration: 0.5)) {
      self.selectedProjectId = project.id
    }
  }
}
