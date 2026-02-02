@testable import Speakable
import XCTest

final class AudioPlayerTests: XCTestCase {
  // MARK: - AudioPlayerState Tests

  func testAudioPlayerStateIdle() {
    let state = AudioPlayerState.idle
    if case .idle = state {
      // Expected
    } else {
      XCTFail("Expected idle state")
    }
  }

  func testAudioPlayerStateError() {
    let error = NSError(domain: "test", code: 1, userInfo: nil)
    let state = AudioPlayerState.error(error)

    if case let .error(capturedError) = state {
      XCTAssertEqual((capturedError as NSError).code, 1)
    } else {
      XCTFail("Expected error state")
    }
  }

  // MARK: - AudioPlayer Tests

  func testAudioPlayerSharedInstance() {
    let instance1 = AudioPlayer.shared
    let instance2 = AudioPlayer.shared
    XCTAssertTrue(instance1 === instance2, "AudioPlayer should be a singleton")
  }

  func testAudioPlayerInitialState() {
    let player = AudioPlayer.shared
    player.stop() // Reset state

    if case .idle = player.state {
      // Expected
    } else {
      XCTFail("Initial state should be idle")
    }

    XCTAssertEqual(player.progress, 0)
    XCTAssertFalse(player.isPlaying)
  }

  func testAudioPlayerIsPlayingProperty() {
    let player = AudioPlayer.shared
    player.stop()

    XCTAssertFalse(player.isPlaying, "Should not be playing after stop")
  }

  func testAudioPlayerStopResetsState() {
    let player = AudioPlayer.shared

    player.stop()

    if case .idle = player.state {
      // Expected
    } else {
      XCTFail("State should be idle after stop")
    }

    XCTAssertEqual(player.progress, 0)
  }

  func testAudioPlayerWithInvalidData() {
    let player = AudioPlayer.shared
    let invalidData = Data([0x00, 0x01, 0x02]) // Invalid audio data

    player.play(invalidData)

    // Should result in error state
    // Note: The actual error may occur asynchronously
    // This test verifies that the player doesn't crash with invalid data
    player.stop()
  }
}
