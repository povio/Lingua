//
//  DirectoryInputField.swift
//  Lingua
//
//  Created by Egzon Arifi on 21/08/2023.
//

import AppKit
import SwiftUI

struct DirectoryInputField: View {
  var title: String
  var bookmarkDataKey: String

  @Binding var directoryPath: String
  @Binding var isValid: Bool
  @State private var isHovered = false

  var onDirectorySelected: ((String) -> Void)? = nil
  var onDirectoryCopied: (() -> Void)? = nil

  var body: some View {
    HStack {
      ValidatingTextField(title: title, validation: RequiredRule(), isDisabled: true, text: $directoryPath, isValid: $isValid)
        .overlay {
          // Transparent overlay to capture tap gesture
          Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
              copyPathToClipboard()
              onDirectoryCopied?()
            }
        }
        .onHover { hovering in
          isHovered = hovering
        }
      Button(Lingua.ProjectForm.inputDirectoryButton) {
        chooseDirectory()
      }
    }
    .padding(.vertical, 5)
    .background(
      GeometryReader { geometry in
        Text(directoryPath)
          .font(.caption)
          .padding(8)
          .background(Color.black.opacity(0.8))
          .foregroundColor(.white)
          .cornerRadius(8)
          .frame(width: geometry.size.width, alignment: .center)
          .offset(y: -geometry.size.height)
          .transition(.opacity)
          .shouldAddView(isHovered)
      }
    )
  }
}

// MARK: - Private Methods
private extension DirectoryInputField {
  func chooseDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = Lingua.General.choose
    
    panel.begin { (result) in
      if let url = panel.urls.first {
        directoryPath = url.absoluteString
        saveBookmarkData(from: url)
      }
      onDirectorySelected?(directoryPath)
    }
  }
  
  func saveBookmarkData(from url: URL) {
    do {
      try url.saveBookmarkData(forKey: bookmarkDataKey)
    } catch {
      debugPrint(error.localizedDescription)
      directoryPath = ""
    }
  }

  private func copyPathToClipboard() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(directoryPath, forType: .string)
  }
}
