@testable import Speakable
import XCTest

final class StreamingAudioPlayerTests: XCTestCase {
  // MARK: - StreamingAudioPlayer Tests

  func testStreamingAudioPlayerSharedInstance() {
    let instance1 = StreamingAudioPlayer.shared
    let instance2 = StreamingAudioPlayer.shared
    XCTAssertTrue(instance1 === instance2, "StreamingAudioPlayer should be a singleton")
  }

  func testStreamingAudioPlayerInitialState() {
    let player = StreamingAudioPlayer.shared
    player.stop()

    if case .idle = player.state {
      // Expected
    } else {
      XCTFail("Initial state should be idle")
    }

    XCTAssertFalse(player.isPlaying)
  }

  func testStreamingAudioPlayerStopResetsState() {
    let player = StreamingAudioPlayer.shared

    player.stop()

    if case .idle = player.state {
      // Expected
    } else {
      XCTFail("State should be idle after stop")
    }

    XCTAssertFalse(player.isPlaying)
  }

  func testStreamingAudioPlayerPauseAndResume() {
    let player = StreamingAudioPlayer.shared
    player.stop()

    // When idle, pause should set state to paused
    player.pause()
    if case .paused = player.state {
      // Expected
    } else {
      XCTFail("State should be paused after pause")
    }

    // Resume should set state to playing
    player.resume()
    if case .playing = player.state {
      // Expected
    } else {
      XCTFail("State should be playing after resume")
    }

    player.stop()
  }
}
