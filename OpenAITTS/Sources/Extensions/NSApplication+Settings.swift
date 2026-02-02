import AppKit

extension Notification.Name {
  static let openSettingsWindow = Notification.Name("openSettingsWindow")
}

extension NSApplication {
  /// Requests to open the settings window via notification
  func openSettingsWindow() {
    activate(ignoringOtherApps: true)
    NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
  }
}
