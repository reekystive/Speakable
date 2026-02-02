import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let serviceProvider = TTSServiceProvider()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.servicesProvider = serviceProvider
    NSUpdateDynamicServices()

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

  func applicationWillTerminate(_ notification: Notification) {
    StreamingAudioPlayer.shared.stop()
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }

  @objc private func windowDidBecomeVisible(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }

    // Only show dock icon for Settings window (has title and is a normal level window)
    let isSettingsWindow = window.styleMask.contains(.titled)
      && window.level == .normal
      && window.title.contains("Settings")

    if isSettingsWindow, NSApp.activationPolicy() != .regular {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
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
