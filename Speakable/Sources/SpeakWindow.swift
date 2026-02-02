import AppKit

/// Custom borderless window styled as a floating input panel
final class SpeakWindow: NSPanel {
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
    let fixedWidth: CGFloat = 500
    minSize = NSSize(width: fixedWidth, height: 100)
    maxSize = NSSize(width: fixedWidth, height: 360)

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
