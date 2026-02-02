import SwiftUI

@main
struct SpeakableApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var player = StreamingAudioPlayer.shared

  var body: some Scene {
    MenuBarExtra("Speakable", systemImage: menuBarIcon) {
      MenuBarView()
    }

    Settings {
      SettingsView()
    }
  }

  private var menuBarIcon: String {
    switch player.state {
    case .idle:
      "speaker.wave.2.fill"
    case .loading:
      "ellipsis.circle.fill"
    case .playing:
      "speaker.wave.3.fill"
    case .paused:
      "speaker.slash.fill"
    case .error:
      "exclamationmark.triangle.fill"
    }
  }
}
