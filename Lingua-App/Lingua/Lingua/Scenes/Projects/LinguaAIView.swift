import AppKit
import SwiftUI
import LinguaLib

struct LinguaAIView: View {
  @StateObject private var viewModel = LinguaAIViewModel()
  @State private var isExpanded = false
  @State private var isShowingInfo = false

  private static let docsURL = URL(string: "https://github.com/povio/Lingua/tree/feature/agentic-localization#using-lingua-with-an-ai-coding-agent")!

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      header

      if isExpanded {
        if !viewModel.isCLIDetected {
          step1InstallCLI
          Divider()
        }
        step2InstallSkills
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .windowBackgroundColor))
    .task { await viewModel.refresh() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      // Re-check CLI presence + skill status when the app regains focus
      // (e.g. after installing the CLI in Terminal). scenePhase doesn't toggle
      // on plain macOS app switching when our window is still visible.
      Task { await viewModel.refresh() }
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 6) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
      } label: {
        HStack(alignment: .center, spacing: 6) {
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
          Text(Lingua.ProjectForm.linguaAiTitle)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Lingua.ProjectForm.linguaAiTitle)

      infoButton

      Text(viewModel.headerStatusLabel)
        .font(.caption)
        .foregroundStyle(viewModel.headerStatusColor)
    }
  }

  private var infoButton: some View {
    Button {
      isShowingInfo.toggle()
    } label: {
      Image(systemName: "info.circle")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $isShowingInfo, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: 8) {
        Text(Lingua.ProjectForm.linguaAiInfoDescription)
          .font(.caption)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
        Link(Lingua.ProjectForm.linguaAiInfoLearnMore, destination: Self.docsURL)
          .font(.caption)
      }
      .padding(12)
      .frame(width: 260, alignment: .leading)
    }
  }

  private var step1InstallCLI: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(Lingua.ProjectForm.linguaAiStep1Title)
        .font(.caption.bold())
      Text(viewModel.brewInstallCommand)
        .font(.caption.monospaced())
        .textSelection(.enabled)
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
      Button {
        LinguaCLIInstall.copyCommandsAndOpenTerminal()
      } label: {
        Label(Lingua.ProjectForm.linguaAiCliOpenTerminalButton, systemImage: "terminal")
      }
      .buttonStyle(.bordered)
    }
  }

  private var step2InstallSkills: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(viewModel.isCLIDetected
           ? Lingua.ProjectForm.linguaAiSkillsTitle
           : Lingua.ProjectForm.linguaAiStep2Title)
        .font(.caption.bold())

      Text(viewModel.skillsStatusDetails)
        .font(.caption2)
        .foregroundStyle(.secondary)

      Picker(Lingua.ProjectForm.linguaAiTargetPicker, selection: $viewModel.installOption) {
        ForEach(LinguaAIInstallOption.allCases) { option in
          Text(option.label.capitalized).tag(option)
        }
      }
      .pickerStyle(.menu)

      HStack(spacing: 8) {
        Button {
          Task { await viewModel.install() }
        } label: {
          Label(Lingua.ProjectForm.linguaAiInstallButton, systemImage: "sparkles")
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isManaging)

        if viewModel.hasInstallations {
          Button {
            Task { await viewModel.uninstall() }
          } label: {
            Label(Lingua.ProjectForm.linguaAiUninstallButton, systemImage: "trash")
          }
          .buttonStyle(.bordered)
          .disabled(viewModel.isManaging)
        }
      }

      if case .failure(let error) = viewModel.result {
        Text(error.localizedDescription)
          .font(.caption)
          .foregroundStyle(.red)
      } else if case .success(let message) = viewModel.result {
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
