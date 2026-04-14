//
//  ProjectsView.swift
//  Lingua
//
//  Created by Egzon Arifi on 17/08/2023.
//

import SwiftUI

struct ProjectsView: View {
  @EnvironmentObject private var viewModel: ProjectsViewModel

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        ProjectListView()
          .environmentObject(viewModel)
          .layoutPriority(0)
          .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        LinguaCLIInstallFooterView()
          .layoutPriority(1)
      }
      .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    } detail: {
      if let project = viewModel.selectedProject {
        projectFormView(for: project)
          .toolbar {
            Spacer()
          }
      } else {
        Text(Lingua.Projects.placeholder)
          .toolbar {
            Spacer()
          }
      }
    }
    .scrollContentBackground(.hidden)
    .navigationTitle("")
    .onAppear {
      viewModel.selectFirstProject()
    }
    .task(id: viewModel.selectedProjectId) {
      await viewModel.refreshSelectedProjectAIStatus()
    }
    .alert(isPresented: $viewModel.showDeleteAlert) { deletionAlert() }
    .overlay(ProgressOverlay(
      isProgressing: viewModel.isShowingProgressOverlay,
      text: viewModel.progressOverlayText
    ))
    .overlay(hudResultOverlay())
  }
}

// MARK: - Private View Builders
private extension ProjectsView {
  func projectFormView(for project: Project) -> some View {
    ProjectFormView(
      viewModel: ProjectFormViewModel(project: project),
      isLocalizing: $viewModel.isLocalizing,
      aiInstallOption: $viewModel.aiInstallOption,
      aiStatus: viewModel.aiStatus,
      aiStatusError: viewModel.aiStatusError,
      isRefreshingAIStatus: viewModel.isRefreshingAIStatus,
      isManagingAI: viewModel.isManagingAI,
      onSave: { updatedProject in
        viewModel.updateProject(updatedProject)
      },
      onDelete: { deletedProject in
        viewModel.confirmDelete(for: deletedProject)
      },
      onLocalize: { projectToLocalize in
        Task { await viewModel.localizeProject(projectToLocalize) }
      },
      onInstallLinguaAI: { projectToInstall in
        Task { await viewModel.installLinguaAI(for: projectToInstall) }
      },
      onUninstallLinguaAI: { projectToUninstall in
        Task { await viewModel.uninstallLinguaAI(for: projectToUninstall) }
      }
    )
    .navigationSplitViewColumnWidth(min: 400, ideal: 600)
  }

  @ViewBuilder
  func hudResultOverlay() -> some View {
    if case .success(let message) = viewModel.aiResult {
      HUDOverlay(message: message, isError: false) {
        viewModel.aiResult = nil
      }
    } else if case .failure(let error) = viewModel.aiResult {
      HUDOverlay(message: error.localizedDescription, isError: true) {
        viewModel.aiResult = nil
      }
    } else {
      switch viewModel.localizationResult {
      case .success(let message):
        HUDOverlay(message: message, isError: false) {
          viewModel.localizationResult = nil
        }
      case .failure(let error):
        HUDOverlay(message: error.localizedDescription, isError: true) {
          viewModel.localizationResult = nil
        }
      case .none:
        EmptyView()
      }
    }
  }

  func deletionAlert() -> Alert {
    Alert(
      title: Text(Lingua.Projects.deleteAlertTitle),
      message: Text(Lingua.Projects.deleteAlertMessage(viewModel.projectToDelete?.title ?? Lingua.General.this)),
      primaryButton: .destructive(Text(Lingua.General.delete), action: {
        guard let project = viewModel.projectToDelete else { return }
        viewModel.deleteProject(project)
      }),
      secondaryButton: .cancel())
  }
}
