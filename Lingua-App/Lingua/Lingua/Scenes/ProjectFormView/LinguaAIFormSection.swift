import SwiftUI
import LinguaLib

struct LinguaAIFormSection: View {
  @ObservedObject var viewModel: LinguaAIFormSectionViewModel
  @Binding var aiInstallOption: LinguaAIInstallOption
  let onInstall: () -> Void
  let onUninstall: () -> Void

  var body: some View {
    Section(header: Text(Lingua.ProjectForm.linguaAiSection).font(.headline)) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(Lingua.ProjectForm.linguaAiStatusTitle)
            .bold()
          Spacer()
          Text(viewModel.aiStatusLabel)
            .foregroundStyle(viewModel.aiStatusColor)
        }

        if let statusError = viewModel.aiStatusError {
          Text(statusError.localizedDescription)
            .font(.subheadline)
            .foregroundStyle(.red)
        } else {
          Text(viewModel.aiStatusDetails)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 4)

      Picker(Lingua.ProjectForm.linguaAiTargetPicker, selection: $aiInstallOption) {
        ForEach(LinguaAIInstallOption.allCases) { option in
          Text(option.label.capitalized)
            .tag(option)
        }
      }
      .disabled(!viewModel.canManageLinguaAI)

      HStack(spacing: 12) {
        Button(action: onInstall) {
          HStack {
            Image(systemName: "sparkles")
            Text(Lingua.ProjectForm.linguaAiInstallButton)
          }
        }
        .disabled(!viewModel.canManageLinguaAI || viewModel.isManagingAI)

        if viewModel.shouldShowUninstallButton {
          Button(action: onUninstall) {
            HStack {
              Image(systemName: "trash")
              Text(Lingua.ProjectForm.linguaAiUninstallButton)
            }
          }
          .disabled(viewModel.isManagingAI)
        }
      }

      if !viewModel.canManageLinguaAI {
        Text(Lingua.ProjectForm.linguaAiNeedsDirectory)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }
}
