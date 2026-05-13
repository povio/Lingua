import SwiftUI
import LinguaLib

@MainActor
final class LinguaAIViewModel: ObservableObject {
  @Published var status: LinguaAIStatusReport?
  @Published var statusError: Error?
  @Published var installOption: LinguaAIInstallOption = .claude
  @Published var isRefreshing: Bool = false
  @Published var isManaging: Bool = false
  @Published var result: Result<String, Error>?

  private let aiManager: LinguaAIManager

  init(aiManager: LinguaAIManager = LinguaAIManager()) {
    self.aiManager = aiManager
  }

  var isCLIDetected: Bool { LinguaCLIInstall.isCLIDetected }
  var brewInstallCommand: String { LinguaCLIInstall.brewInstallCommand }
  var hasInstallations: Bool { status?.hasGlobalInstallations == true }

  /// Collapsed-header pill: combines CLI presence + skills state into one signal.
  var headerStatusLabel: String {
    if !isCLIDetected {
      return Lingua.ProjectForm.linguaAiSetupRequired
    }
    return skillsStatusLabel
  }

  var headerStatusColor: Color {
    if !isCLIDetected { return .orange }
    return skillsStatusColor
  }

  var skillsStatusLabel: String {
    if isRefreshing { return Lingua.ProjectForm.linguaAiCheckingStatus }
    if statusError != nil { return Lingua.ProjectForm.linguaAiStatusUnavailable }
    // No refresh has run yet: show "Checking..." rather than "Unavailable" to avoid a flash.
    guard let status else { return Lingua.ProjectForm.linguaAiCheckingStatus }

    switch status.globalInstallationState {
    case .notInstalled:       return Lingua.ProjectForm.linguaAiNotInstalled
    case .partiallyInstalled: return Lingua.ProjectForm.linguaAiPartiallyInstalled
    case .installed:          return Lingua.ProjectForm.linguaAiInstalledStatus
    }
  }

  var skillsStatusDetails: String {
    guard let status, status.hasGlobalInstallations else {
      return Lingua.ProjectForm.linguaAiNoTargetsInstalled
    }
    let labels = status.globalInstalledTargets
      .map { $0.label.capitalized }
      .joined(separator: ", ")
    return Lingua.ProjectForm.linguaAiInstalledTargets(labels)
  }

  var skillsStatusColor: Color {
    switch status?.globalInstallationState {
    case .installed:          return .green
    case .partiallyInstalled: return .orange
    default:                  return .secondary
    }
  }

  func refresh() async {
    isRefreshing = true
    statusError = nil

    do {
      let updated = try await aiManager.globalStatus()
      status = updated
      installOption = try await aiManager.suggestedGlobalInstallOption(status: updated)
    } catch {
      status = nil
      statusError = error
    }

    isRefreshing = false
  }

  func install() async {
    isManaging = true
    result = nil
    statusError = nil

    do {
      _ = try await aiManager.installGlobally(option: installOption)
      let updated = try await aiManager.globalStatus()
      status = updated
      installOption = try await aiManager.suggestedGlobalInstallOption(status: updated)
      result = .success(Lingua.ProjectForm.linguaAiInstalled(installOption.label.capitalized))
    } catch {
      result = .failure(error)
    }

    isManaging = false
  }

  func uninstall() async {
    guard let status else { return }
    isManaging = true
    result = nil
    statusError = nil

    do {
      _ = try await aiManager.uninstallGloballyInstalledTargets(status: status)
      let updated = try await aiManager.globalStatus()
      self.status = updated
      installOption = try await aiManager.suggestedGlobalInstallOption(status: updated)
      result = .success(Lingua.ProjectForm.linguaAiUninstalled)
    } catch {
      result = .failure(error)
    }

    isManaging = false
  }
}
