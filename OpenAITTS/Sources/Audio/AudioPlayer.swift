import AVFoundation
import Foundation

// MARK: - Audio Player State

enum AudioPlayerState {
  case idle
  case loading
  case playing
  case paused
  case error(Error)
}

// MARK: - Audio Player

final class AudioPlayer: NSObject, ObservableObject {
  static let shared = AudioPlayer()

  @Published private(set) var state: AudioPlayerState = .idle
  @Published private(set) var progress: Double = 0

  private var player: AVAudioPlayer?
  private var audioQueue: [Int: Data] = [:]
  private var currentIndex = 0
  private var progressTimer: Timer?
  private var totalExpectedChunks = 0
  private var streamingTask: Task<Void, Never>?

  override private init() {
    super.init()
  }

  /// Play audio from Data
  func play(_ audioData: Data) {
    stop()
    audioQueue = [0: audioData]
    currentIndex = 0
    totalExpectedChunks = 1
    playCurrentTrack()
  }

  /// Play multiple audio chunks sequentially
  func playSequence(_ audioChunks: [Data]) {
    stop()
    audioQueue = Dictionary(uniqueKeysWithValues: audioChunks.enumerated().map { ($0.offset, $0.element) })
    currentIndex = 0
    totalExpectedChunks = audioChunks.count
    playCurrentTrack()
  }

  /// Start streaming playback - play first chunk immediately while more chunks load
  func startStreaming(firstChunk: Data, totalChunks: Int) {
    stop()
    audioQueue = [0: firstChunk]
    currentIndex = 0
    totalExpectedChunks = totalChunks
    playCurrentTrack()
  }

  /// Append a chunk at specific index during streaming playback
  func appendChunk(at index: Int, data: Data) {
    audioQueue[index] = data

    // If we finished playing current and the next chunk is now available, continue
    if case .loading = state, audioQueue[currentIndex] != nil {
      playCurrentTrack()
    }
  }

  private func playCurrentTrack() {
    guard let audioData = audioQueue[currentIndex] else {
      // If we're still expecting more chunks, wait
      if currentIndex < totalExpectedChunks {
        state = .loading
        return
      }
      state = .idle
      progress = 0
      return
    }

    do {
      player = try AVAudioPlayer(data: audioData)
      player?.delegate = self
      player?.prepareToPlay()
      player?.play()
      state = .playing
      startProgressTimer()
    } catch {
      state = .error(error)
      print("Failed to play audio: \(error.localizedDescription)")
    }
  }

  func pause() {
    player?.pause()
    state = .paused
    stopProgressTimer()
  }

  func resume() {
    player?.play()
    state = .playing
    startProgressTimer()
  }

  func stop() {
    streamingTask?.cancel()
    streamingTask = nil
    stopProgressTimer()
    player?.stop()
    player = nil
    audioQueue = [:]
    currentIndex = 0
    totalExpectedChunks = 0
    state = .idle
    progress = 0
  }

  func togglePlayPause() {
    switch state {
    case .playing:
      pause()
    case .paused:
      resume()
    default:
      break
    }
  }

  var isPlaying: Bool {
    if case .playing = state {
      return true
    }
    return false
  }

  var isActive: Bool {
    switch state {
    case .idle:
      false
    default:
      true
    }
  }

  func setLoading() {
    state = .loading
  }

  func setError(_ error: Error) {
    state = .error(error)
  }

  // MARK: - Progress Timer

  private func startProgressTimer() {
    stopProgressTimer()
    progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.updateProgress()
    }
  }

  private func stopProgressTimer() {
    progressTimer?.invalidate()
    progressTimer = nil
  }

  private func updateProgress() {
    guard let player, player.duration > 0 else {
      progress = 0
      return
    }

    let trackProgress = player.currentTime / player.duration
    let totalTracks = Double(max(totalExpectedChunks, audioQueue.count))
    let completedTracks = Double(currentIndex)

    progress = (completedTracks + trackProgress) / totalTracks
  }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayer: AVAudioPlayerDelegate {
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      currentIndex += 1

      if audioQueue[currentIndex] != nil {
        // Next chunk is ready
        playCurrentTrack()
      } else if currentIndex < totalExpectedChunks {
        // Still waiting for more chunks
        state = .loading
      } else {
        stopProgressTimer()
        state = .idle
        progress = 0
      }
    }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    DispatchQueue.main.async { [weak self] in
      if let error {
        self?.state = .error(error)
      }
      self?.stopProgressTimer()
    }
  }
}
