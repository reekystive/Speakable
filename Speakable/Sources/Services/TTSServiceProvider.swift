import AppKit
import Foundation
import UserNotifications

/// Service Provider that handles the macOS Services menu integration
final class TTSServiceProvider: NSObject {
  static let shared = TTSServiceProvider()

  private var currentTask: Task<Void, Never>?

  /// Called by macOS Services when user selects "Speak with Speakable"
  /// This method name must match NSMessage in Info.plist
  @objc func speakText(
    _ pboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    guard let text = pboard.string(forType: .string), !text.isEmpty else {
      error.pointee = "No text selected" as NSString
      return
    }

    let settings = SettingsManager.shared

    guard settings.isConfigured else {
      error.pointee = String(localized: "API Key not configured. Please open Speakable settings.") as NSString
      Self.postNotification(
        title: "Speakable",
        body: String(localized: "API Key not configured. Please open the app to set up your API key.")
      )
      openSettingsWindow()
      return
    }

    // Cancel any ongoing task and stop playback immediately
    currentTask?.cancel()
    StreamingAudioPlayer.shared.stop()

    // Set loading state immediately before API call
    StreamingAudioPlayer.shared.state = .loading

    // Start new TTS task
    currentTask = Task.detached { [weak self] in
      await self?.performTTS(text: text)
    }
  }

  /// Speak text from clipboard
  func speakClipboard() {
    guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
      Self.postNotification(title: "Speakable", body: String(localized: "Clipboard is empty or contains no text."))
      return
    }

    speakTextDirectly(text)
  }

  /// Speak currently selected text using Accessibility API
  func speakSelectedText() {
    // Check Accessibility permission first
    guard AccessibilityPermission.isGranted else {
      AccessibilityPermission.request()
      Self.postNotification(
        title: "Speakable",
        body: String(localized: "Accessibility permission required. Please grant access in System Settings.")
      )
      return
    }

    // Get selected text via Accessibility API
    guard let text = AccessibilityPermission.getSelectedText() else {
      Self.postNotification(title: "Speakable", body: String(localized: "No text selected."))
      return
    }

    speakTextDirectly(text)
  }

  /// Speak given text directly
  private func speakTextDirectly(_ text: String) {
    let settings = SettingsManager.shared

    guard settings.isConfigured else {
      Self.postNotification(
        title: "Speakable",
        body: String(localized: "API Key not configured. Please open the app to set up your API key.")
      )
      openSettingsWindow()
      return
    }

    // Cancel any ongoing task and stop playback immediately
    currentTask?.cancel()
    StreamingAudioPlayer.shared.stop()

    // Set loading state immediately before API call
    StreamingAudioPlayer.shared.state = .loading

    // Start new TTS task
    currentTask = Task.detached { [weak self] in
      await self?.performTTS(text: text)
    }
  }

  private func performTTS(text: String) async {
    let settings = SettingsManager.shared
    let client = OpenAIClient.shared

    let instructions = settings.selectedModel.supportsInstructions ? settings.voiceInstructions : nil

    do {
      // Check if cancelled before making API call
      try Task.checkCancellation()

      let stream = try await client.generateSpeechStream(
        text: text,
        voice: settings.selectedVoice,
        model: settings.selectedModel,
        speed: settings.speechSpeed,
        instructions: instructions
      )

      // Check if cancelled after API call
      try Task.checkCancellation()

      DispatchQueue.main.async {
        StreamingAudioPlayer.shared.startStreaming(stream)
      }
    } catch is CancellationError {
      // Task was cancelled, reset state
      DispatchQueue.main.async {
        StreamingAudioPlayer.shared.state = .idle
      }
    } catch let error as OpenAIError {
      let errorMessage = error.localizedDescription
      DispatchQueue.main.async {
        StreamingAudioPlayer.shared.stop()
        Self.postNotification(title: "Speakable", body: errorMessage)
      }
    } catch {
      let errorMessage = error.localizedDescription
      DispatchQueue.main.async {
        StreamingAudioPlayer.shared.stop()
        Self.postNotification(title: "Speakable", body: errorMessage)
      }
    }
  }

  private static func postNotification(title: String, body: String) {
    let center = UNUserNotificationCenter.current()

    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else { return }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body

      let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
      )

      center.add(request)
    }
  }

  private func openSettingsWindow() {
    DispatchQueue.main.async {
      SettingsWindowManager.shared.requestOpenSettings()
    }
  }
}
