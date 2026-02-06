import AppKit
import ApplicationServices

/// Manages Accessibility permission and selected text retrieval
enum AccessibilityPermission {
  /// Check if Accessibility permission is granted
  static var isGranted: Bool {
    AXIsProcessTrusted()
  }

  /// Request Accessibility permission
  /// Shows system prompt if not already granted
  /// - Returns: true if already granted, false if user needs to grant permission
  @discardableResult
  static func request() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  /// Open System Settings to Accessibility pane
  static func openSystemSettings() {
    let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!
    NSWorkspace.shared.open(url)
  }

  /// Get selected text using Accessibility API
  /// - Returns: The selected text, or nil if not available
  static func getSelectedText() -> String? {
    // Create system-wide accessibility element
    let systemWide = AXUIElementCreateSystemWide()

    // Get the focused element
    var focusedElement: CFTypeRef?
    let focusError = AXUIElementCopyAttributeValue(
      systemWide,
      kAXFocusedUIElementAttribute as CFString,
      &focusedElement
    )

    guard focusError == .success, let focused = focusedElement else {
      return nil
    }

    // Get selected text from focused element
    var selectedText: CFTypeRef?
    // swiftlint:disable:next force_cast
    let textError = AXUIElementCopyAttributeValue(
      focused as! AXUIElement,
      kAXSelectedTextAttribute as CFString,
      &selectedText
    )

    guard textError == .success, let text = selectedText as? String, !text.isEmpty else {
      return nil
    }

    return text
  }
}
