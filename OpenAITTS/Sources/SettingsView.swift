import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
  @StateObject private var settings = SettingsManager.shared
  @StateObject private var player = StreamingAudioPlayer.shared
  @State private var isTestingVoice = false
  @State private var showingAPIKeyField = false
  @State private var testText = "Hello! This is a test of OpenAI text to speech."

  var body: some View {
    Form {
      Section {
        if settings.apiKey.isEmpty || showingAPIKeyField {
          LabeledContent {
            HStack {
              SecureField("sk-...", text: $settings.apiKey)
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
        Text("OpenAI API Key")
      } footer: {
        Text("Stored securely in macOS Keychain.")
      }

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
            ? "Available for GPT-4o Mini TTS."
            : "Requires GPT-4o Mini TTS."
        )
        .foregroundColor(settings.selectedModel.supportsInstructions ? .secondary : .orange)
      }

      Section {
        KeyboardShortcuts.Recorder("Speak Clipboard:", name: .speakClipboard)
      } header: {
        Text("Global Hotkey")
      } footer: {
        Text("Set a global keyboard shortcut to speak clipboard content from anywhere.")
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
          Text("Enter your API key to test.")
            .foregroundColor(.orange)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 620)
  }

  private var buttonTitle: String {
    if player.isPlaying { return "Stop" }
    if case .loading = player.state { return "Generating..." }
    return "Test Voice"
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

    Task {
      do {
        let stream = try await OpenAIClient.shared.generateSpeechStream(
          text: testText,
          voice: settings.selectedVoice,
          model: settings.selectedModel,
          speed: settings.speechSpeed,
          instructions: settings.selectedModel.supportsInstructions ? settings.voiceInstructions : nil
        )

        await MainActor.run {
          player.startStreaming(stream)
        }
      } catch {
        await MainActor.run {
          let alert = NSAlert()
          alert.messageText = "Test Failed"
          alert.informativeText = error.localizedDescription
          alert.alertStyle = .warning
          alert.runModal()
        }
      }
    }
  }
}

#Preview {
  SettingsView()
}
