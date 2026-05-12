//
//  ProjectListView.swift
//  Lingua
//
//  Created by Yll Fejziu on 24/11/2023.
//

import SwiftUI

struct ProjectListView: View {
  @EnvironmentObject private var viewModel: ProjectsViewModel
  var shouldAddLocalizeButton: Bool = false

  // Mirrors `viewModel.selectedProjectId` locally so that `List(selection:)` does not
  // write directly to a `@Published` property during its own view-update phase,
  // which causes the "Publishing changes from within view updates is not allowed" warning.
  @State private var listSelection: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      CustomSearchBar(searchTerm: $viewModel.searchTerm)

      List(selection: $listSelection) {
        Section {
          ForEach(viewModel.filteredProjects) { project in
            HStack {
              ProjectItemView(project: project)
                .swipeActions(edge: .trailing) {
                  duplicateButton(for: project)
                    .shouldAddView(!shouldAddLocalizeButton)
                  deletionButton(for: project)
                    .shouldAddView(!shouldAddLocalizeButton)
                }
                .contextMenu {
                  duplicateButton(for: project)
                    .shouldAddView(!shouldAddLocalizeButton)
                  deletionButton(for: project)
                    .shouldAddView(!shouldAddLocalizeButton)
                }

              Button(action: {
                Task { await viewModel.localizeProject(project) }
              }) {
                HStack {
                  Image(systemName: "globe")
                  Text(Lingua.ProjectForm.localizeButton)
                }
              }
              .shouldAddView(shouldAddLocalizeButton)
            }
          }
        }
      }
      .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
      .listStyle(.sidebar)
    }
    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    .onAppear {
      listSelection = viewModel.selectedProjectId
    }
    .onChange(of: viewModel.selectedProjectId) { newValue in
      if listSelection != newValue {
        listSelection = newValue
      }
    }
    .onChange(of: listSelection) { newValue in
      if viewModel.selectedProjectId != newValue {
        viewModel.selectedProjectId = newValue
      }
    }
    .navigationSplitViewColumnWidth(min: 340, ideal: 340, max: 500)
    .toolbar {
      Button(action: {
        withAnimation {
          viewModel.createNewProject()
        }
      }) {
        Image(systemName: "plus")
      }
      .shouldAddView(!shouldAddLocalizeButton)
    }
    .overlay {
      ProgressView()
        .shouldAddView(shouldAddLocalizeButton && viewModel.isLocalizing)
    }
    .disabled(viewModel.isLocalizing)
    .opacity(viewModel.isLocalizing ? 0.5 : 1)
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
}

extension ProjectListView {
  @ViewBuilder
  func deletionButton(for project: Project) -> some View {
    Button(action: {
      viewModel.confirmDelete(for: project)
    }) {
      Text(Lingua.General.delete)
      Image(systemName: "trash")
    }
    .tint(.red)
  }

  @ViewBuilder
  func duplicateButton(for project: Project) -> some View {
    Button(action: {
      viewModel.duplicate(project)
    }) {
      Text(Lingua.General.duplicate)
      Image(systemName: "doc.on.doc")
    }
    .tint(.blue)
  }
}
