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
        Divider()
        LinguaAIView()
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
      onSave: { updatedProject in
        viewModel.updateProject(updatedProject)
      },
      onDelete: { deletedProject in
        viewModel.confirmDelete(for: deletedProject)
      },
      onLocalize: { projectToLocalize in
        Task { await viewModel.localizeProject(projectToLocalize) }
      }
    )
    .navigationSplitViewColumnWidth(min: 400, ideal: 600)
  }

  @ViewBuilder
  func hudResultOverlay() -> some View {
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
