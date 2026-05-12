//
//  ProjectFormView.swift
//  Lingua
//
//  Created by Egzon Arifi on 21/08/2023.
//

import AppKit
import SwiftUI
import LinguaLib

struct ProjectFormView: View {
  @ObservedObject var viewModel: ProjectFormViewModel
  @Binding var isLocalizing: Bool

  @State private var apiKeyValid = false
  @State private var sheetIdValid = false
  @State private var titleValid = true
  @State private var outputPathValid = false
  @State private var stringsDirectoryValid = false
  @State private var outputSwiftCodeFileDirectoryValid = false
  @State private var copied = false

  var onSave: ((Project) -> Void)? = nil
  var onDelete: ((Project) -> Void)? = nil
  var onLocalize: ((Project) -> Void)? = nil
  
  var body: some View {
    VStack(alignment: .leading) {
      Form {
        basicConfigurationFormSection()
        swiftCodeFormSection()
        filterSectionsFormSection()
        iOSInfoFormSection()
      }
      .toolbar {
        if #available(macOS 26.0, *) {
          ToolbarItem(placement: .navigation) {
            projectHeaderToolbarContent
          }
          .sharedBackgroundVisibility(.hidden)
        } else {
          ToolbarItem(placement: .navigation) {
            projectHeaderToolbarContent
          }
        }
        ToolbarItem(placement: .primaryAction) {
          localizeButton()
        }
      }
      .onChange(of: viewModel.project) { newValue in
        onSave?(newValue)
      }
      .formStyle(.grouped)

      bottomActionBar(for: viewModel.project).padding()
    }
    .padding()
    .overlay {
      Text(Lingua.ProjectForm.copiedToClipboard)
        .padding(8)
        .background(
          Color.black
            .opacity(0.4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 6)
        .shouldAddView(copied)
    }
  }
}

// MARK: - Private View Builders
private extension ProjectFormView {
  @ViewBuilder
  var projectHeaderToolbarContent: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(viewModel.project.title)
        .font(.headline)
        .lineLimit(1)
        .truncationMode(.tail)
      Text(viewModel.project.lastLocalizedAt.map { Lingua.ProjectForm.lastLocalizedSubtitle($0.formatted) } ?? "")
        .font(.subheadline)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .frame(maxWidth: 320, alignment: .leading)
  }

  @ViewBuilder
  func basicConfigurationFormSection() -> some View {
    Section(header: Text(Lingua.ProjectForm.configurationSection).font(.headline)) {
      Picker(Lingua.ProjectForm.platformPickerTitle, selection: $viewModel.project.type) {
        ForEach(LocalizationPlatform.allCases) { type in
          Text(type.title)
            .tag(type)
        }
      }
      
      ValidatingTextField(
        title: Lingua.ProjectForm.inputProjectName,
        validation: RequiredRule(),
        text: $viewModel.project.title,
        isValid: $titleValid
      )
      
      InformationHolderView(content: {
        ValidatingTextField(
          title: Lingua.ProjectForm.inputApiKey,
          validation: RequiredRule(),
          text: $viewModel.project.apiKey,
          isValid: $apiKeyValid
        )
      }) {
        Text(.init(Lingua.ProjectForm.apiKeyHelp))
          .padding()
      }
      
      InformationHolderView(content: {
        ValidatingTextField(
          title: Lingua.ProjectForm.inputSheetId,
          validation: RequiredRule(),
          text: $viewModel.project.sheetId,
          isValid: $sheetIdValid
        )
      }) {
        Text(.init(Lingua.ProjectForm.sheetIdHelp))
          .padding()
      }
      
      InformationHolderView(content: {
        DirectoryInputField(
          title: Lingua.ProjectForm.inputDirectoryOutput,
          bookmarkDataKey: viewModel.project.bookmarkDataForDirectoryPath,
          directoryPath: $viewModel.project.directoryPath,
          isValid: $outputPathValid,
          onDirectorySelected: updateDirectoryPaths,
          onDirectoryCopied: showCopiedMessage
        )
      }) {
        Text(.init(Lingua.ProjectForm.outputDirectoryHelp))
          .padding()
      }
    }
  }
  
  @ViewBuilder
  func swiftCodeFormSection() -> some View {
    if viewModel.project.type == .ios {
      Section {
        Toggle(isOn: $viewModel.project.swiftCodeEnabled) {
          Text(Lingua.ProjectForm.swiftCodeToggleTitle)
            .bold()
        }
        
        if viewModel.project.swiftCodeEnabled {
          VStack(alignment: .leading, spacing: 8) {
            Text(Lingua.ProjectForm.swiftCodeSection).font(.headline)
            Text(Lingua.ProjectForm.swiftCodeDescription)
              .font(.subheadline)
          }
          .padding(8)
          
          InformationHolderView(content: {
            DirectoryInputField(
              title: Lingua.ProjectForm.stringsDirectory,
              bookmarkDataKey: viewModel.project.bookmarkDataForStringsDirectory,
              directoryPath: $viewModel.project.swiftCode.stringsDirectory,
              isValid: $stringsDirectoryValid,
              onDirectoryCopied: showCopiedMessage
            )
          }) {
            Text(.init(Lingua.ProjectForm.lprojDirectoryHelp))
              .padding()
          }
          
          InformationHolderView(content: {
            DirectoryInputField(
              title: Lingua.ProjectForm.linguaSwiftOutputDirectory,
              bookmarkDataKey: viewModel.project.bookmarkDataForOutputSwiftCodeFileDirectory ,
              directoryPath: $viewModel.project.swiftCode.outputSwiftCodeFileDirectory,
              isValid: $outputSwiftCodeFileDirectoryValid,
              onDirectoryCopied: showCopiedMessage
            )
          }) {
            Text(.init(Lingua.ProjectForm.linguaSwiftOutputDirectoryHelp))
              .padding()
          }
        }
      }
    }
  }
  
  @ViewBuilder
  func filterSectionsFormSection() -> some View {
    Section {
      Toggle(isOn: $viewModel.project.filterSectionsEnabled) {
        Text(Lingua.ProjectForm.filteringSectionTitle)
          .bold()
      }
      if viewModel.project.filterSectionsEnabled {
        VStack(alignment: .leading, spacing: 8) {
          Text(Lingua.ProjectForm.filteringSectionDescription)
            .font(.subheadline)
          Divider()
          SectionsInputView(sections: $viewModel.project.allowedSections)
        }
        .padding(8)
      }
    }
  }

  @ViewBuilder
  func iOSInfoFormSection() -> some View {
    if viewModel.project.type == .ios {
      Section(Lingua.ProjectForm.infoHeader) {
        Text(Lingua.ProjectForm.iosLocalizationInfoMessage(viewModel.project.title))
          .font(.subheadline)
      }
    }
  }
  
  @ViewBuilder
  func deleteButton(for project: Project) -> some View {
    Button(action: {
      onDelete?(project)
    }, label: {
      Image(systemName: "trash")
        .foregroundColor(.red)
      Text(Lingua.General.delete)
        .foregroundColor(.red)
    })
  }

  @ViewBuilder
  func bottomActionBar(for project: Project) -> some View {
    HStack(alignment: .center) {
      deleteButton(for: project)
      Spacer(minLength: 16)
      Button {
        openOutputDirectoryInFinder(for: project)
      } label: {
        HStack {
          Image(systemName: "folder")
          Text(Lingua.ProjectForm.openInFinder)
        }
      }
      .disabled(!canOpenOutputDirectoryInFinder(project))
    }
  }

  @ViewBuilder
  func localizeButton() -> some View {
    Button(action: {
      onLocalize?(viewModel.project)
    }) {
      HStack {
        Image(systemName: "globe")
        Text(Lingua.ProjectForm.localizeButton)
      }
    }
    .disabled(!viewModel.project.isValid() || isLocalizing)
  }
}

// MARK: - Private Methods
private extension ProjectFormView {
  func updateDirectoryPaths(for directory: String) {
    if viewModel.project.swiftCode.outputSwiftCodeFileDirectory.isEmpty {
      viewModel.project.swiftCode.outputSwiftCodeFileDirectory = directory
    }
    
    guard let directoryURL = URL(string: directory) else { return }
    try? directoryURL.saveBookmarkData(forKey: viewModel.project.bookmarkDataForOutputSwiftCodeFileDirectory)
    
    guard viewModel.project.swiftCode.stringsDirectory.isEmpty else { return }
    let directoryPath = directoryURL.path
    let fileManager = FileManager.default
    
    guard let subpaths = fileManager.subpaths(atPath: directoryPath) else { return }
    
    let enLprojPath = directoryPath.appending("/en.lproj")
    if subpaths.contains(where: { $0 == "en.lproj" }) ||
        !subpaths.contains(where: { $0.hasSuffix(".lproj") }) {
      let enLprojURL = URL(fileURLWithPath: enLprojPath)
      viewModel.project.swiftCode.stringsDirectory = enLprojURL.absoluteString
      try? enLprojURL.saveBookmarkData(forKey: viewModel.project.bookmarkDataForStringsDirectory)
    } else if let firstLprojRelativePath = subpaths.first(where: { $0.hasSuffix(".lproj") }) {
      let firstLprojFullPath = directoryPath.appending("/\(firstLprojRelativePath)")
      let firstLprojFullURL = URL(fileURLWithPath: firstLprojFullPath)
      viewModel.project.swiftCode.stringsDirectory = firstLprojFullURL.absoluteString
      try? firstLprojFullURL.saveBookmarkData(forKey: viewModel.project.bookmarkDataForStringsDirectory)
    }
  }

  func showCopiedMessage() {
    withAnimation {
      copied = true
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      withAnimation {
        self.copied = false
      }
    }
  }

  func canOpenOutputDirectoryInFinder(_ project: Project) -> Bool {
    let path = project.directoryPath
    guard !path.isEmpty, let url = resolvedOutputDirectoryURL(from: path) else { return false }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
    return isDirectory.boolValue
  }

  func openOutputDirectoryInFinder(for project: Project) {
    guard canOpenOutputDirectoryInFinder(project) else { return }
    do {
      try DirectoryAccessor().withAccessToDirectory(
        fromBookmarkKey: project.bookmarkDataForDirectoryPath,
        path: project.directoryPath
      ) { url in
        NSWorkspace.shared.activateFileViewerSelecting([url])
      }
    } catch {
      debugPrint("ProjectFormView.openOutputDirectoryInFinder: \(error.localizedDescription)")
    }
  }

  func resolvedOutputDirectoryURL(from path: String) -> URL? {
    if let url = URL(string: path), url.isFileURL {
      return url
    }
    return URL(fileURLWithPath: path)
  }
}
