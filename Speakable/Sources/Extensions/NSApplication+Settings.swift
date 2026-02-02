import AppKit

extension NSApplication {
  /// Opens the Settings window programmatically
  func openSettingsWindow() {
    activate(ignoringOtherApps: true)
    // Use the standard macOS selector to open Settings/Preferences window
    if #available(macOS 14.0, *) {
      NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else {
      NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
  }
}
