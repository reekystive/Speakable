import SwiftUI

@main
struct SpeakableApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra {
      MenuBarView()
    } label: {
      #if DEBUG
      Image(nsImage: Self.makeDebugMenuBarIcon())
      #else
      Image(systemName: "waveform")
      #endif
    }

    Window("Settings", id: "settings") {
      SettingsView()
        .frame(minWidth: 600, maxWidth: 600, minHeight: 400, maxHeight: .infinity)
    }
    .defaultSize(width: 600, height: 500)
    .windowResizability(.contentSize)
  }

  #if DEBUG
  /// Creates a menu bar icon with a small yellow indicator dot for debug builds.
  /// Uses SF Symbol palette rendering with `NSColor.labelColor` so the waveform
  /// adapts to the menu bar appearance, while the dot stays yellow.
  private static func makeDebugMenuBarIcon() -> NSImage {
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
      .applying(.init(paletteColors: [.labelColor]))

    guard let waveform = NSImage(
      systemSymbolName: "waveform",
      accessibilityDescription: "Speakable"
    )?.withSymbolConfiguration(symbolConfig) else {
      return NSImage(systemSymbolName: "waveform", accessibilityDescription: "Speakable")!
    }

    let dotDiameter: CGFloat = 5
    let baseSize = waveform.size

    let image = NSImage(size: baseSize, flipped: false) { _ in
      waveform.draw(in: NSRect(origin: .zero, size: baseSize))

      NSColor.systemYellow.setFill()
      NSBezierPath(ovalIn: NSRect(
        x: baseSize.width - dotDiameter,
        y: baseSize.height - dotDiameter,
        width: dotDiameter,
        height: dotDiameter
      )).fill()

      return true
    }

    // Non-template to preserve the yellow dot color
    image.isTemplate = false
    return image
  }
  #endif
}
