import SwiftUI

struct SpeakView: View {
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var settings = SettingsManager.shared
  @StateObject private var player = StreamingAudioPlayer.shared

  @State private var text = ""
  @State private var temporarySpeed: Double?
  @State private var temporaryVoice: TTSVoice?
  @State private var textHeight: CGFloat = 20

  /// The visible height of the content area, derived from the text height.
  private var visibleContentHeight: CGFloat {
    SpeakWindow.contentHeight(forTextHeight: textHeight)
  }

  private var effectiveSpeed: Double {
    temporarySpeed ?? settings.speechSpeed
  }

  private var effectiveVoice: TTSVoice {
    temporaryVoice ?? settings.selectedVoice
  }

  var body: some View {
    VStack(spacing: SpeakWindow.titleBarGap) {
      // Floating title bar
      titleBar

      // Main content – height is driven by text, animated by SwiftUI
      ZStack {
        // Native material background
        VisualEffectBackground()

        // Content
        ZStack(alignment: .bottom) {
          textArea
          toolbar
        }
      }
      .frame(height: visibleContentHeight)
      .clipShape(RoundedRectangle(cornerRadius: 20))

      // Push content to the top; transparent area below is click-through
      Spacer(minLength: 0)
    }
    .animation(.smooth(duration: 0.2), value: visibleContentHeight)
  }

  // MARK: - Title Bar

  private var titleBar: some View {
    HStack(spacing: 12) {
      // Native close button
      StandardCloseButton {
        NSApp.windows.first(where: { $0 is SpeakWindow })?.close()
      }
      .frame(width: 12, height: 12)

      // Title (left-aligned)
      Text("Speakable")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)

      Spacer()

      // Stop button (when playing)
      if player.isPlaying || player.state == .loading {
        Button(action: { player.stop() }) {
          Image(systemName: "stop.fill")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      // Voice menu (plain text, no background/arrow)
      Menu {
        ForEach(TTSVoice.allCases) { voice in
          Button(voice.rawValue.capitalized) {
            temporaryVoice = voice
          }
        }
      } label: {
        Text(effectiveVoice.rawValue.capitalized)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)

      // Speed menu (plain text, no background/arrow)
      Menu {
        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
          Button("\(speed, specifier: "%.2g")x") {
            temporarySpeed = speed
          }
        }
      } label: {
        Text("\(effectiveSpeed, specifier: "%.2g")x")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
    }
    .padding(.horizontal, 14)
    .frame(height: SpeakWindow.titleBarHeight)
    .background(VisualEffectBackground(material: .titlebar))
    .clipShape(Capsule())
  }

  // MARK: - Text Area

  private var textArea: some View {
    ZStack(alignment: .topLeading) {
      if text.isEmpty {
        Text("Type to speak...")
          .foregroundStyle(.tertiary)
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .allowsHitTesting(false)
      }

      SpeakTextEditor(
        text: $text,
        textHeight: $textHeight,
        onSubmit: speakOrStop
      )
    }
  }

  // MARK: - Toolbar

  private var toolbar: some View {
    HStack {
      Spacer()
      speakButton
    }
    .padding(.trailing, 10)
    .padding(.bottom, 10)
  }

  // MARK: - Speak Button

  private var speakButton: some View {
    let isLoading = player.state == .loading
    let isActive = canSpeak && !isLoading
    let isDark = colorScheme == .dark

    // Active: high contrast (white bg + black fg in dark, black bg + white fg in light)
    // Inactive: muted solid gray
    let activeBg = isDark ? Color.white : Color.black
    let activeFg = isDark ? Color.black : Color.white
    let inactiveBg = isDark ? Color(white: 0.35) : Color(white: 0.75)
    let inactiveFg = isDark ? Color(white: 0.6) : Color(white: 0.45)

    return Button(action: speakOrStop) {
      Group {
        if isLoading {
          ProgressView()
            .scaleEffect(0.5)
            .frame(width: 16, height: 16)
        } else {
          Image(systemName: "arrow.up")
            .font(.system(size: 14, weight: .semibold))
        }
      }
      .foregroundColor(isActive ? activeFg : inactiveFg)
      .frame(width: 32, height: 32)
      .background(
        Circle()
          .fill(isActive ? activeBg : inactiveBg)
      )
    }
    .buttonStyle(.plain)
    .disabled(!canSpeak && !player.isPlaying && !isLoading)
  }

  private var canSpeak: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && settings.isConfigured
  }

  // MARK: - Actions

  private func speakOrStop() {
    // Stop any current playback first
    if player.isPlaying || player.state == .loading {
      player.stop()
    }

    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty, settings.isConfigured else { return }

    // Immediately show loading state
    player.state = .loading

    Task {
      do {
        let instructions = settings.selectedModel.supportsInstructions ? settings.voiceInstructions : nil

        let stream = try await OpenAIClient.shared.generateSpeechStream(
          text: trimmedText,
          voice: effectiveVoice,
          model: settings.selectedModel,
          speed: effectiveSpeed,
          instructions: instructions
        )

        await MainActor.run {
          player.startStreaming(stream)
        }
      } catch {
        await MainActor.run {
          player.state = .idle
          let alert = NSAlert()
          alert.messageText = String(localized: "Speech Generation Failed")
          alert.informativeText = error.localizedDescription
          alert.alertStyle = .warning
          alert.runModal()
        }
      }
    }
  }

}

// MARK: - Preview

#Preview {
  SpeakView()
    .frame(width: 500)
}
