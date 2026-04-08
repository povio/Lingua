import SwiftUI

  struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var marketingEmails = false
    @State private var displayName = ""
    @State private var connectedDeviceCount = 3
    @State private var photoCount = 1        // hits the singular case
    @State private var videoCount = 8        // hits the plural case
    @State private var minutesSinceBackup = 12

    var body: some View {
      NavigationStack {
        Form {
          Section("Account") {
            TextField("Display name", text: $displayName)

            LabeledContent("Email") {
              Text("you@example.com")
                .foregroundStyle(.secondary)
            }

            NavigationLink("Change password") {
              Text("Password screen")
            }
          }

          Section {
            Toggle("Push notifications", isOn: $notificationsEnabled)
            Toggle("Marketing emails", isOn: $marketingEmails)
          } header: {
            Text("Notifications")
          } footer: {
            Text("We will only send you important updates about your account.")
          }

          Section("Devices") {
            // Plural: "1 connected device" / "5 connected devices"
            Text("\(connectedDeviceCount) connected devices")

            Button("Sign out of all devices") {
              // TODO
            }
          }

          Section("Storage") {
            // Plural: "1 photo" / "42 photos"
            LabeledContent("Photos") {
              Text("\(photoCount) photos")
                .foregroundStyle(.secondary)
            }

            // Plural: "1 video" / "8 videos"
            LabeledContent("Videos") {
              Text("\(videoCount) videos")
                .foregroundStyle(.secondary)
            }

            // Mixed plural with a number interpolation
            Text("Last backup: \(minutesSinceBackup) minutes ago")
              .font(.footnote)
              .foregroundStyle(.secondary)

            Button("Free up space") {
              // TODO
            }
          }

          Section {
            Button("Delete account", role: .destructive) {
              // TODO
            }
          } footer: {
            Text("This action cannot be undone. All your data will be permanently removed.")
          }

          Section {
            // Footer-only section for the version line
          } footer: {
            Text("Version 1.0.6")
          }
        }
        .navigationTitle("Settings")
      }
    }
  }

  #Preview {
    SettingsView()
  }