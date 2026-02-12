import AppKit

/// Custom borderless window styled as a floating input panel.
///
/// The window always occupies its maximum frame size; the visible content
/// area is animated by SwiftUI within this fixed frame, avoiding frame-resize
/// jitter while keeping smooth height transitions.
final class SpeakWindow: NSPanel {

  // MARK: - Layout Constants

  static let fixedWidth: CGFloat = 460
  static let contentMinHeight: CGFloat = 120  // ~2 lines of text + padding + toolbar
  static let contentMaxHeight: CGFloat = 360
  static let titleBarHeight: CGFloat = 36
  static let titleBarGap: CGFloat = 8

  /// Total fixed window height (always at maximum so SwiftUI can animate
  /// content height within a stable frame).
  static var fixedHeight: CGFloat {
    contentMaxHeight + titleBarHeight + titleBarGap
  }

  /// Toolbar height used by SpeakView (kept here as single source of truth)
  static let toolbarHeight: CGFloat = 44

  /// Compute the visible content-area height for a given text height.
  static func contentHeight(forTextHeight textHeight: CGFloat) -> CGFloat {
    // textContainerInset: 16pt top + bottom padding
    let padding: CGFloat = 32
    let raw = textHeight + toolbarHeight + padding
    return min(max(raw, contentMinHeight), contentMaxHeight)
  }

  // MARK: - Init

  override init(
    contentRect: NSRect,
    styleMask style: NSWindow.StyleMask,
    backing backingStoreType: NSWindow.BackingStoreType,
    defer flag: Bool
  ) {
    super.init(
      contentRect: contentRect,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: backingStoreType,
      defer: flag
    )

    // Window appearance
    isMovableByWindowBackground = true
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    level = .floating

    // Panel behavior
    hidesOnDeactivate = false
    becomesKeyOnlyIfNeeded = false
    isFloatingPanel = true

    isRestorable = false

    // Fixed size – content animates within the frame
    let fixedSize = NSSize(width: Self.fixedWidth, height: Self.fixedHeight)
    minSize = fixedSize
    maxSize = fixedSize

    // Center on screen
    center()
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  // Close on Escape
  override func cancelOperation(_ sender: Any?) {
    close()
  }

  // Handle keyboard shortcuts for borderless window
  // Use performKeyEquivalent instead of keyDown because NSTextView intercepts keyDown
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard event.modifierFlags.contains(.command),
          event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.command, .numericPad, .function]) .isEmpty
    else {
      return super.performKeyEquivalent(with: event)
    }

    switch event.charactersIgnoringModifiers {
    case "w":
      close()
      return true
    case "h":
      NSApp.hide(nil)
      return true
    default:
      return super.performKeyEquivalent(with: event)
    }
  }
}
