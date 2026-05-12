//
//  LinguaCLIInstallFooterView.swift
//  Lingua
//

import AppKit
import SwiftUI

struct LinguaCLIInstallFooterView: View {
  @State private var copied = false
  @State private var isExpanded = false

  /// Homebrew install; one line for Terminal (`&&` skips install if tap fails).
  private static let terminalCommands = "brew tap poviolabs/lingua && brew install lingua"

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded.toggle()
        }
      } label: {
        HStack(alignment: .center, spacing: 6) {
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
          Text(Lingua.Projects.cliInstallTitle)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Lingua.Projects.cliInstallTitle)

      if isExpanded {
        Text(Lingua.Projects.cliInstallDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .lineLimit(nil)
          .multilineTextAlignment(.leading)
        Button(action: copyCommands) {
          Label(Lingua.Projects.cliInstallCopyButton, systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        if copied {
          Text(Lingua.ProjectForm.copiedToClipboard)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private func copyCommands() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(Self.terminalCommands, forType: .string)
    Task { @MainActor in
      copied = true
      try? await Task.sleep(nanoseconds: 2_000_000_000)
      copied = false
    }
  }
}
