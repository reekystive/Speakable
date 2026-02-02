import AppKit
import Foundation
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.servicesProvider = TTSServiceProvider.shared
    NSUpdateDynamicServices()

    // Register global hotkey
    setupGlobalHotkey()

    // Start as accessory (no dock icon)
    NSApp.setActivationPolicy(.accessory)

    // Close any windows that were restored (we want to start with just menu bar)
    DispatchQueue.main.async {
      for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled) {
        window.close()
      }
    }

    // Monitor window visibility
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeVisible),
      name: NSWindow.didBecomeKeyNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowWillClose),
      name: NSWindow.willCloseNotification,
      object: nil
    )
  }

  private func setupGlobalHotkey() {
    KeyboardShortcuts.onKeyUp(for: .speakClipboard) {
      TTSServiceProvider.shared.speakClipboard()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    StreamingAudioPlayer.shared.stop()
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }

  @objc private func windowDidBecomeVisible(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }

    // Only show dock icon for Settings window (not for floating Speak panel)
    let isSettingsWindow = window.styleMask.contains(.titled)
      && window.level == .normal
      && window.title.contains("Settings")

    if isSettingsWindow, NSApp.activationPolicy() != .regular {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate()
    }
  }

  @objc private func windowWillClose(_ notification: Notification) {
    // Check if this is the last window
    DispatchQueue.main.async {
      let visibleWindows = NSApp.windows.filter { $0.isVisible && !$0.className.contains("StatusBar") }
      if visibleWindows.isEmpty {
        NSApp.setActivationPolicy(.accessory)
      }
    }
  }
}
