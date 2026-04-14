import SwiftUI
import LinguaLib

final class LinguaAIFormSectionViewModel: ObservableObject {
  let isManagingAI: Bool
  let isRefreshingAIStatus: Bool

  let projectViewModel: ProjectFormViewModel
  let aiStatus: LinguaAIStatusReport?
  let aiStatusError: Error?

  init(projectViewModel: ProjectFormViewModel,
       aiStatus: LinguaAIStatusReport?,
       aiStatusError: Error?,
       isRefreshingAIStatus: Bool,
       isManagingAI: Bool) {
    self.projectViewModel = projectViewModel
    self.aiStatus = aiStatus
    self.aiStatusError = aiStatusError
    self.isRefreshingAIStatus = isRefreshingAIStatus
    self.isManagingAI = isManagingAI
  }

  var canManageLinguaAI: Bool { !projectViewModel.project.directoryPath.isEmpty }
  var shouldShowUninstallButton: Bool { aiStatus?.hasProjectInstallations == true }

  var aiStatusLabel: String {
    if isRefreshingAIStatus {
      return Lingua.ProjectForm.linguaAiCheckingStatus
    }

    if aiStatusError != nil {
      return Lingua.ProjectForm.linguaAiStatusUnavailable
    }

    guard let aiStatus else {
      return Lingua.ProjectForm.linguaAiStatusUnavailable
    }

    switch aiStatus.projectInstallationState {
    case .notInstalled:
      return Lingua.ProjectForm.linguaAiNotInstalled
    case .partiallyInstalled:
      return Lingua.ProjectForm.linguaAiPartiallyInstalled
    case .installed:
      return Lingua.ProjectForm.linguaAiInstalledStatus
    }
  }

  var aiStatusDetails: String {
    guard let aiStatus, aiStatus.hasProjectInstallations else {
      return Lingua.ProjectForm.linguaAiNoTargetsInstalled
    }

    let installedTargets = aiStatus.projectInstalledTargets
      .map { $0.label.capitalized }
      .joined(separator: ", ")
    return Lingua.ProjectForm.linguaAiInstalledTargets(installedTargets)
  }

  var aiStatusColor: Color {
    switch aiStatus?.projectInstallationState {
    case .installed:
      return .green
    case .partiallyInstalled:
      return .orange
    default:
      return .secondary
    }
  }
}
