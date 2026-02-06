import SwiftUI

struct MenuBarView: View {
  @Environment(\.openWindow) private var openWindow
  @StateObject private var settings = SettingsManager.shared
  @StateObject private var player = StreamingAudioPlayer.shared
  @StateObject private var updater = UpdaterController.shared

  var body: some View {
    Group {
      statusItem
      Divider()
      speakWindowButton
      speakActionsSection
      playbackSection
      Divider()
      checkForUpdatesButton
      settingsButton
      quitButton
    }
    .onReceive(SettingsWindowManager.shared.openSettingsPublisher) {
      showSettings()
    }
  }

  // MARK: - Speak Window

  private var speakWindowButton: some View {
    Button("Speak...") {
      SpeakWindowController.shared.showWindow()
    }
    .keyboardShortcut("n", modifiers: .command)
  }

  // MARK: - Speak Actions

  @ViewBuilder
  private var speakActionsSection: some View {
    Button("Speak Selected Text") {
      TTSServiceProvider.shared.speakSelectedText()
    }
    .disabled(!settings.isConfigured || player.state == .loading)

    Button("Speak Clipboard") {
      TTSServiceProvider.shared.speakClipboard()
    }
    .disabled(!settings.isConfigured || player.state == .loading)

    Divider()
  }

  // MARK: - Status Item

  private var statusItem: some View {
    Label(statusText, systemImage: statusIcon)
      .disabled(true)
  }

  private var statusText: String {
    switch player.state {
    case .loading:
      String(localized: "Generating...")
    case .playing:
      String(localized: "Playing")
    case .paused:
      String(localized: "Paused")
    case .error:
      String(localized: "Error")
    case .idle:
      if settings.isConfigured {
        String(localized: "Ready")
      } else {
        String(localized: "API Key not set")
      }
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

  // MARK: - Update

  private var checkForUpdatesButton: some View {
    Button("Check for Updates...") {
      updater.checkForUpdates()
    }
    .disabled(!updater.canCheckForUpdates)
  }

  // MARK: - Menu Buttons

  private var settingsButton: some View {
    Button("Settings...") {
      showSettings()
    }
    .keyboardShortcut(",", modifiers: .command)
  }

  private func showSettings() {
    openWindow(id: "settings")
    NSApp.activate(ignoringOtherApps: true)
  }

  private var quitButton: some View {
    Button("Quit Speakable") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q", modifiers: .command)
  }
}

#Preview {
  MenuBarView()
    .frame(width: 250)
}
