import AppKit
import Foundation

enum LinguaCLIInstall {
  /// Homebrew install; one line for Terminal (`&&` skips install if tap fails).
  static let brewInstallCommand = "brew tap poviolabs/lingua && brew install lingua"

  /// Probes the well-known Homebrew install paths for the `lingua` executable.
  /// Sandboxed apps cannot run `which`, but `FileManager.fileExists` on these
  /// system paths is allowed without TCC.
  static var isCLIDetected: Bool {
    let candidates = ["/opt/homebrew/bin/lingua", "/usr/local/bin/lingua"]
    return candidates.contains(where: { FileManager.default.fileExists(atPath: $0) })
  }

  static func copyInstallCommandsToPasteboard() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(brewInstallCommand, forType: .string)
  }

  /// Copies the brew command and brings Terminal.app to the front so the user can paste + run.
  /// Sandbox blocks injecting keystrokes into Terminal, so the user still hits Cmd+V Enter.
  static func copyCommandsAndOpenTerminal() {
    copyInstallCommandsToPasteboard()
    let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
    NSWorkspace.shared.open(terminalURL)
  }
}
