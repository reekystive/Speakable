import AppKit

/// Custom borderless window styled as a floating input panel
final class SpeakWindow: NSPanel {

  // MARK: - Layout Constants

  static let fixedWidth: CGFloat = 460
  static let contentMinHeight: CGFloat = 100
  static let contentMaxHeight: CGFloat = 360
  static let titleBarHeight: CGFloat = 36
  static let titleBarGap: CGFloat = 8

  static var windowMinHeight: CGFloat {
    contentMinHeight + titleBarHeight + titleBarGap
  }

  static var windowMaxHeight: CGFloat {
    contentMaxHeight + titleBarHeight + titleBarGap
  }

  /// Toolbar height used by SpeakView (kept here as single source of truth)
  static let toolbarHeight: CGFloat = 54

  /// Compute the total window height for a given text content height.
  /// Used by the text editor coordinator to update the window frame synchronously.
  static func windowHeight(forTextHeight textHeight: CGFloat) -> CGFloat {
    let contentHeight = textHeight + toolbarHeight + 32
    let clamped = min(max(contentHeight, contentMinHeight), contentMaxHeight)
    return clamped + titleBarHeight + titleBarGap
  }

  /// Resize the window to fit the given text height, keeping the top edge fixed.
  static func updateFrame(forTextHeight textHeight: CGFloat) {
    guard let window = NSApp.windows.first(where: { $0 is SpeakWindow }) else { return }

    let newHeight = windowHeight(forTextHeight: textHeight)
    var frame = window.frame
    let oldHeight = frame.height
    guard abs(newHeight - oldHeight) > 1 else { return }

    frame.origin.y += oldHeight - newHeight
    frame.size.height = newHeight
    window.setFrame(frame, display: true)
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

    // Fixed width, variable height
    minSize = NSSize(width: Self.fixedWidth, height: Self.windowMinHeight)
    maxSize = NSSize(width: Self.fixedWidth, height: Self.windowMaxHeight)

    // Center on screen
    center()
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  // Close on Escape
  override func cancelOperation(_ sender: Any?) {
    close()
  }
}
