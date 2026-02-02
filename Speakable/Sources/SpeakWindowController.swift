import AppKit
import SwiftUI

/// Manages the Speak window lifecycle
final class SpeakWindowController {
  static let shared = SpeakWindowController()

  private var window: SpeakWindow?

  private init() {}

  /// Show the Speak window, creating it if necessary
  func showWindow() {
    if let existingWindow = window, existingWindow.isVisible {
      existingWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let contentRect = NSRect(x: 0, y: 0, width: 500, height: 100)
    let newWindow = SpeakWindow(
      contentRect: contentRect,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    let hostingView = NSHostingView(rootView: SpeakView())
    newWindow.contentView = hostingView

    // Add window observer for cleanup
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowWillClose),
      name: NSWindow.willCloseNotification,
      object: newWindow
    )

    window = newWindow
    newWindow.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Close the Speak window if open
  func closeWindow() {
    window?.close()
    window = nil
  }

  @objc private func windowWillClose(_ notification: Notification) {
    guard let closingWindow = notification.object as? NSWindow,
          closingWindow === window
    else {
      return
    }

    NotificationCenter.default.removeObserver(
      self,
      name: NSWindow.willCloseNotification,
      object: closingWindow
    )
    window = nil
  }

  /// Check if the window is currently visible
  var isWindowVisible: Bool {
    window?.isVisible ?? false
  }
}
