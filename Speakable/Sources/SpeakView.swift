import SwiftUI

struct SpeakView: View {
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
          // Text editor with gradient mask at bottom
          textArea
            .mask(
              VStack(spacing: 0) {
                Color.black

                LinearGradient(
                  colors: [.black, .clear],
                  startPoint: .top,
                  endPoint: .bottom
                )
                .frame(height: 40)
              }
              .padding(.bottom, 44)
            )

          // Floating toolbar
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
    HStack {
      // Native close button
      StandardCloseButton {
        NSApp.windows.first(where: { $0 is SpeakWindow })?.close()
      }
      .frame(width: 14, height: 14)

      Spacer()

      // Title
      Text("Speakable")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)

      Spacer()

      // Spacer for symmetry
      Color.clear
        .frame(width: 14, height: 14)
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
    HStack(spacing: 12) {
      // Left side controls
      HStack(spacing: 8) {
        // Voice picker
        ToolbarPopoverButton(icon: "waveform", label: effectiveVoice.rawValue.capitalized) {
          voicePopover
        }

        // Speed picker
        ToolbarPopoverButton(icon: "gauge.with.needle", label: String(format: "%.1f", effectiveSpeed)) {
          speedPopover
        }
      }

      Spacer()

      // Right side controls
      HStack(spacing: 8) {
        // Stop button (when playing)
        if player.isPlaying || player.state == .loading {
          Button(
            action: { player.stop() },
            label: {
              Image(systemName: "stop.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            }
          )
          .buttonStyle(.plain)
        }

        // Speak button
        speakButton
      }
    }
    .padding(.leading, 14)
    .padding(.trailing, 10)
    .padding(.bottom, 10)
  }

  // MARK: - Speed Popover

  private var speedPopover: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Speed")
          .font(.system(size: 12, weight: .medium))
        Spacer()
        Text("\(effectiveSpeed, specifier: "%.2f")x")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.secondary)
      }

      Slider(
        value: Binding(
          get: { effectiveSpeed },
          set: { temporarySpeed = $0 }
        ),
        in: 0.25...4.0,
        step: 0.05
      )

      if temporarySpeed != nil {
        Button("Reset to default") {
          temporarySpeed = nil
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .frame(width: 200)
  }

  // MARK: - Voice Popover

  private var voicePopover: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Voice")
          .font(.system(size: 12, weight: .medium))
        Spacer()
        if temporaryVoice != nil {
          Button("Reset") {
            temporaryVoice = nil
          }
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        }
      }

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
        ForEach(TTSVoice.allCases) { voice in
          Button {
            temporaryVoice = voice
          } label: {
            Text(voice.rawValue.capitalized)
              .font(.system(size: 11))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
              .background(
                RoundedRectangle(cornerRadius: 6)
                  .fill(effectiveVoice == voice ? Color.accentColor.opacity(0.15) : Color.clear)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .strokeBorder(
                    effectiveVoice == voice ? Color.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 1
                  )
              )
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(14)
    .frame(width: 240)
  }

  // MARK: - Speak Button

  private var speakButton: some View {
    let isLoading = player.state == .loading
    let isActive = canSpeak && !isLoading

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
      .foregroundColor(isActive ? .black : .gray)
      .frame(width: 32, height: 32)
      .background(
        Circle()
          .fill(isActive ? Color.white : Color.primary.opacity(0.1))
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
    if player.isPlaying || player.state == .loading {
      player.stop()
      return
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
