import AppKit

extension NSApplication {
  /// Opens the app's settings/preferences window
  /// Handles the API difference between macOS 13+ and earlier versions
  func openSettingsWindow() {
    activate(ignoringOtherApps: true)
    if #available(macOS 13.0, *) {
      sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else {
      sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
  }
}