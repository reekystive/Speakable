import KeyboardShortcuts
import SwiftUI
import UserNotifications

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
  case general
  case voice
  case shortcuts
  case permissions

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: String(localized: "General")
    case .voice: String(localized: "Voice")
    case .shortcuts: String(localized: "Shortcuts")
    case .permissions: String(localized: "Permissions")
    }
  }

  var icon: String {
    switch self {
    case .general: "gear"
    case .voice: "waveform"
    case .shortcuts: "keyboard"
    case .permissions: "lock.shield"
    }
  }
}

// MARK: - Settings View

struct SettingsView: View {
  @State private var selectedTab: SettingsTab? = .general
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      List(SettingsTab.allCases, selection: $selectedTab) { tab in
        Label(tab.title, systemImage: tab.icon)
          .tag(tab)
      }
      .toolbar(removing: .sidebarToggle)
      .toolbar {
        ToolbarItem(placement: .navigation) {
          Button(action: toggleSidebar) {
            Image(systemName: "sidebar.leading")
          }
        }
      }
      .navigationSplitViewColumnWidth(180)
    } detail: {
      Group {
        switch selectedTab {
        case .general:
          GeneralSettingsView()
        case .voice:
          VoiceSettingsView()
        case .shortcuts:
          ShortcutsSettingsView()
        case .permissions:
          PermissionsSettingsView()
        case nil:
          GeneralSettingsView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

  }

  private func toggleSidebar() {
    NSApp.keyWindow?.firstResponder?
      .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
  }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
  @StateObject private var settings = SettingsManager.shared
  @StateObject private var updater = UpdaterController.shared
  @State private var showingAPIKeyField = false

  var body: some View {
    Form {
      Section {
        if settings.apiKey.isEmpty || showingAPIKeyField {
          LabeledContent {
            HStack {
              SecureField("sk-...", text: $settings.apiKey)
                .textFieldStyle(.roundedBorder)
              if showingAPIKeyField, !settings.apiKey.isEmpty {
                Button("Done") {
                  showingAPIKeyField = false
                }
              }
            }
          } label: {
            Text("API Key")
          }
        } else {
          LabeledContent {
            HStack {
              Text("••••••••" + String(settings.apiKey.suffix(4)))
                .font(.system(.body, design: .monospaced))
              Button("Change") {
                showingAPIKeyField = true
              }
            }
          } label: {
            Text("API Key")
          }
        }
      } header: {
        Text("OpenAI")
      } footer: {
        Text("Your API key is stored securely in the macOS Keychain.")
      }

      Section {
        Toggle(
          "Automatically check for updates",
          isOn: Binding(
            get: { updater.automaticallyChecksForUpdates },
            set: { updater.automaticallyChecksForUpdates = $0 }
          )
        )

        Button("Check for Updates...") {
          updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
      } header: {
        Text("Software Update")
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Voice Settings

private struct VoiceSettingsView: View {
  @StateObject private var settings = SettingsManager.shared
  @StateObject private var player = StreamingAudioPlayer.shared
  @State private var testText = "Hello! This is a test of OpenAI text to speech."

  var body: some View {
    Form {
      Section {
        Picker("Voice", selection: $settings.selectedVoice) {
          ForEach(TTSVoice.allCases) { voice in
            Text(voice.displayName).tag(voice)
          }
        }

        Picker("Model", selection: $settings.selectedModel) {
          ForEach(TTSModel.allCases) { model in
            Text(model.displayName).tag(model)
          }
        }
      } header: {
        Text("Voice")
      }

      Section {
        LabeledContent("Speed") {
          Text("\(settings.speechSpeed, specifier: "%.2f")x")
            .monospacedDigit()
        }
        Slider(value: $settings.speechSpeed, in: 0.25...4.0)
        Button("Reset to 1.0x") {
          settings.speechSpeed = 1.0
        }
        .disabled(settings.speechSpeed == 1.0)
      } header: {
        Text("Speed")
      }

      Section {
        TextField(
          "e.g. Speak cheerfully, Read slowly...",
          text: $settings.voiceInstructions,
          axis: .vertical
        )
        .lineLimit(2...4)
        .disabled(!settings.selectedModel.supportsInstructions)
      } header: {
        Text("Voice Instructions")
      } footer: {
        Text(
          settings.selectedModel.supportsInstructions
            ? "Custom instructions for GPT-4o Mini TTS."
            : "Requires GPT-4o Mini TTS model."
        )
        .foregroundColor(settings.selectedModel.supportsInstructions ? .secondary : .orange)
      }

      Section {
        TextField("Enter test text...", text: $testText, axis: .vertical)
          .lineLimit(2...4)

        Button(buttonTitle, action: testOrStop)
          .disabled(buttonDisabled)
      } header: {
        Text("Test")
      } footer: {
        if !settings.isConfigured {
          Text("Enter your API key in General settings to test.")
            .foregroundColor(.orange)
        }
      }
    }
    .formStyle(.grouped)
  }

  private var buttonTitle: String {
    if player.isPlaying { return String(localized: "Stop") }
    if case .loading = player.state { return String(localized: "Generating...") }
    return String(localized: "Test Voice")
  }

  private var buttonDisabled: Bool {
    if player.isPlaying { return false }
    if case .loading = player.state { return false }
    return !settings.isConfigured || testText.isEmpty
  }

  private func testOrStop() {
    if player.isPlaying {
      player.stop()
      return
    }
    if case .loading = player.state {
      player.stop()
      return
    }

    player.state = .loading

    Task {
      do {
        let stream = try await OpenAIClient.shared.generateSpeechStream(
          text: testText,
          voice: settings.selectedVoice,
          model: settings.selectedModel,
          speed: settings.speechSpeed,
          instructions: settings.selectedModel.supportsInstructions
            ? settings.voiceInstructions : nil
        )

        await MainActor.run {
          player.startStreaming(stream)
        }
      } catch {
        await MainActor.run {
          player.state = .idle
          let alert = NSAlert()
          alert.messageText = String(localized: "Test Failed")
          alert.informativeText = error.localizedDescription
          alert.alertStyle = .warning
          alert.runModal()
        }
      }
    }
  }
}

// MARK: - Shortcuts Settings

private struct ShortcutsSettingsView: View {
  var body: some View {
    Form {
      Section {
        KeyboardShortcuts.Recorder("Open Speak Bar:", name: .openSpeakBar)
        KeyboardShortcuts.Recorder("Speak Selected Text:", name: .speakSelectedText)
        KeyboardShortcuts.Recorder("Speak Clipboard:", name: .speakClipboard)
      } header: {
        Text("Global Hotkeys")
      } footer: {
        Text("Set global keyboard shortcuts to trigger Speakable from anywhere.")
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Permissions Settings

private struct PermissionsSettingsView: View {
  @StateObject private var permissions = PermissionsManager.shared

  var body: some View {
    Form {
      Section {
        LabeledContent {
          if permissions.accessibilityGranted {
            Text("Granted")
              .foregroundStyle(.secondary)
          } else {
            Button("Grant Access") {
              permissions.requestAccessibility()
            }
          }
        } label: {
          Label(
            "Accessibility",
            systemImage: permissions.accessibilityGranted ? "checkmark.circle.fill" : "circle"
          )
          .foregroundStyle(permissions.accessibilityGranted ? .green : .primary)
        }
      } header: {
        Text("Accessibility")
      } footer: {
        Text("Required to read selected text from other applications.")
      }

      Section {
        LabeledContent {
          if permissions.notificationStatus == .authorized {
            Text("Granted")
              .foregroundStyle(.secondary)
          } else if permissions.notificationStatus == .denied {
            Button("Open Settings") {
              permissions.openNotificationSettings()
            }
          } else {
            Button("Grant Access") {
              permissions.requestNotification()
            }
          }
        } label: {
          Label(
            "Notifications",
            systemImage: permissions.notificationStatus == .authorized
              ? "checkmark.circle.fill" : "circle"
          )
          .foregroundStyle(permissions.notificationStatus == .authorized ? .green : .primary)
        }
      } header: {
        Text("Notifications")
      } footer: {
        Text("Optional. Shows notifications when speech completes or errors occur.")
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Preview

#Preview {
  SettingsView()
    .frame(width: 600, height: 500)
}
