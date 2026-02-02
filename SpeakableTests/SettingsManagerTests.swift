@testable import Speakable
import XCTest

final class SettingsManagerTests: XCTestCase {
  // MARK: - TTSVoice Tests

  func testTTSVoiceAllCases() {
    // Verify all expected voices are available (13 total)
    let expectedVoices = [
      "alloy",
      "ash",
      "ballad",
      "coral",
      "echo",
      "fable",
      "marin",
      "cedar",
      "nova",
      "onyx",
      "sage",
      "shimmer",
      "verse",
    ]
    let actualVoices = TTSVoice.allCases.map(\.rawValue)

    XCTAssertEqual(TTSVoice.allCases.count, 13)
    for voice in expectedVoices {
      XCTAssertTrue(actualVoices.contains(voice), "Missing voice: \(voice)")
    }
  }

  func testTTSVoiceDisplayName() {
    XCTAssertEqual(TTSVoice.alloy.displayName, "Alloy")
    XCTAssertEqual(TTSVoice.nova.displayName, "Nova")
    XCTAssertEqual(TTSVoice.shimmer.displayName, "Shimmer")
  }

  func testTTSVoiceIdentifiable() {
    let voice = TTSVoice.coral
    XCTAssertEqual(voice.id, voice.rawValue)
  }

  // MARK: - TTSModel Tests

  func testTTSModelRawValues() {
    XCTAssertEqual(TTSModel.tts1.rawValue, "tts-1")
    XCTAssertEqual(TTSModel.tts1HD.rawValue, "tts-1-hd")
    XCTAssertEqual(TTSModel.gpt4oMiniTTS.rawValue, "gpt-4o-mini-tts")
  }

  func testTTSModelSupportsInstructions() {
    XCTAssertFalse(TTSModel.tts1.supportsInstructions)
    XCTAssertFalse(TTSModel.tts1HD.supportsInstructions)
    XCTAssertTrue(TTSModel.gpt4oMiniTTS.supportsInstructions)
  }

  func testTTSModelDisplayName() {
    XCTAssertEqual(TTSModel.tts1.displayName, "TTS-1 (Fast)")
    XCTAssertEqual(TTSModel.tts1HD.displayName, "TTS-1 HD (Quality)")
    XCTAssertEqual(TTSModel.gpt4oMiniTTS.displayName, "GPT-4o Mini TTS (Latest)")
  }

  // MARK: - SettingsManager Tests

  func testSettingsManagerSharedInstance() {
    let instance1 = SettingsManager.shared
    let instance2 = SettingsManager.shared
    XCTAssertTrue(instance1 === instance2, "SettingsManager should be a singleton")
  }

  func testSettingsManagerHasValidValues() {
    let settings = SettingsManager.shared

    // Voice should be a valid TTSVoice
    XCTAssertTrue(TTSVoice.allCases.contains(settings.selectedVoice))

    // Model should be a valid TTSModel
    XCTAssertTrue(TTSModel.allCases.contains(settings.selectedModel))

    // Speed should be within valid range (0.25 to 4.0)
    XCTAssertGreaterThanOrEqual(settings.speechSpeed, 0.25)
    XCTAssertLessThanOrEqual(settings.speechSpeed, 4.0)
  }

  func testIsConfiguredWhenNoAPIKey() {
    let settings = SettingsManager.shared
    let originalKey = settings.apiKey

    settings.apiKey = ""
    XCTAssertFalse(settings.isConfigured)

    // Restore
    settings.apiKey = originalKey
  }

  func testIsConfiguredWithAPIKey() {
    let settings = SettingsManager.shared
    let originalKey = settings.apiKey

    settings.apiKey = "sk-test-key-12345"
    XCTAssertTrue(settings.isConfigured)

    // Restore
    settings.apiKey = originalKey
  }

  func testSpeedBounds() {
    let settings = SettingsManager.shared
    let originalSpeed = settings.speechSpeed

    // Test that speed can be set within valid range
    settings.speechSpeed = 0.25
    XCTAssertEqual(settings.speechSpeed, 0.25, accuracy: 0.01)

    settings.speechSpeed = 4.0
    XCTAssertEqual(settings.speechSpeed, 4.0, accuracy: 0.01)

    settings.speechSpeed = 1.5
    XCTAssertEqual(settings.speechSpeed, 1.5, accuracy: 0.01)

    // Restore
    settings.speechSpeed = originalSpeed
  }
}
