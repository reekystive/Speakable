import SwiftUI

struct MenuBarView: View {
  @StateObject private var settings = SettingsManager.shared
  @StateObject private var player = StreamingAudioPlayer.shared
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Group {
      statusItem
      Divider()
      playbackSection
      Divider()
      settingsButton
      quitButton
    }
    .onReceive(NotificationCenter.default.publisher(for: .openSettingsWindow)) { _ in
      openSettings()
    }
  }

  // MARK: - Status Item

  private var statusItem: some View {
    Label(statusText, systemImage: statusIcon)
      .disabled(true)
  }

  private var statusText: String {
    switch player.state {
    case .loading:
      "Generating..."
    case .playing:
      "Playing"
    case .paused:
      "Paused"
    case .error:
      "Error"
    case .idle:
      settings.isConfigured ? "Ready" : "API Key not set"
    }
  }

  private var statusIcon: String {
    switch player.state {
    case .loading:
      "ellipsis.circle.fill"
    case .playing:
      "speaker.wave.3.fill"
    case .paused:
      "speaker.slash.fill"
    case .error:
      "exclamationmark.circle.fill"
    case .idle:
      settings.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }
  }

  // MARK: - Playback Section

  @ViewBuilder
  private var playbackSection: some View {
    switch player.state {
    case .playing:
      Button("Pause") { player.pause() }
        .keyboardShortcut("p", modifiers: [])
      Button("Stop") { player.stop() }
        .keyboardShortcut("s", modifiers: [])
    case .paused:
      Button("Resume") { player.resume() }
        .keyboardShortcut("p", modifiers: [])
      Button("Stop") { player.stop() }
        .keyboardShortcut("s", modifiers: [])
    case .loading:
      Button("Stop") { player.stop() }
        .keyboardShortcut("s", modifiers: [])
    case .idle, .error:
      EmptyView()
    }
  }

  // MARK: - Menu Buttons

  private var settingsButton: some View {
    Button("Settings...") {
      openSettings()
    }
    .keyboardShortcut(",", modifiers: .command)
  }

  private var quitButton: some View {
    Button("Quit OpenAI TTS") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q", modifiers: .command)
  }
}

#Preview {
  MenuBarView()
    .frame(width: 250)
}
