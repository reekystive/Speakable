import AVFoundation
import Foundation

/// Streaming audio player using AVAudioEngine for real-time PCM playback
final class StreamingAudioPlayer: ObservableObject {
  static let shared = StreamingAudioPlayer()

  @Published var state: AudioPlayerState = .idle
  @Published private(set) var isPlaying = false

  private let engine = AVAudioEngine()
  private let playerNode = AVAudioPlayerNode()

  // PCM format from OpenAI: 24kHz, 16-bit signed, little-endian, mono
  private let sampleRate: Double = 24000
  private let channels: AVAudioChannelCount = 1
  private lazy var audioFormat = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: sampleRate,
    channels: channels,
    interleaved: true
  )!

  private var streamTask: Task<Void, Never>?

  private init() {
    setupEngine()
  }

  private func setupEngine() {
    engine.attach(playerNode)
    engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
  }

  private func updateState(_ newState: AudioPlayerState, playing: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.state = newState
      self?.isPlaying = playing
    }
  }

  private func scheduleBufferSync(_ buffer: AVAudioPCMBuffer) {
    playerNode.scheduleBuffer(buffer, completionHandler: nil)
  }

  private struct StreamingConfig {
    let bytesPerSample = 2 // 16-bit
    let samplesPerBuffer = 12000 // 500ms at 24kHz
    var bytesPerBuffer: Int { samplesPerBuffer * bytesPerSample }
    var prebufferBytes: Int { bytesPerBuffer * 2 } // Prebuffer 1 second
  }

  private func scheduleAvailableBuffers(_ pendingData: inout Data, config: StreamingConfig) {
    while pendingData.count >= config.bytesPerBuffer {
      let chunk = pendingData.prefix(config.bytesPerBuffer)
      pendingData.removeFirst(config.bytesPerBuffer)
      if let buffer = createBuffer(from: Data(chunk)) {
        scheduleBufferSync(buffer)
      }
    }
  }

  private func scheduleRemainingData(_ pendingData: Data, config: StreamingConfig) {
    guard !pendingData.isEmpty, pendingData.count >= config.bytesPerSample else { return }
    let sampleCount = pendingData.count / config.bytesPerSample
    let usableBytes = sampleCount * config.bytesPerSample
    if let buffer = createBuffer(from: Data(pendingData.prefix(usableBytes))) {
      scheduleBufferSync(buffer)
    }
  }

  private func waitForPlaybackCompletion() async {
    while playerNode.isPlaying {
      try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
  }

  /// Start streaming playback from an AsyncBytes stream
  func startStreaming(_ stream: URLSession.AsyncBytes) {
    stop()
    state = .loading

    streamTask = Task { [weak self] in
      guard let self else { return }

      do {
        try engine.start()

        var pendingData = Data()
        let config = StreamingConfig()
        var hasStartedPlayback = false

        for try await byte in stream {
          if Task.isCancelled { break }
          pendingData.append(byte)

          if !hasStartedPlayback, pendingData.count >= config.prebufferBytes {
            scheduleAvailableBuffers(&pendingData, config: config)
            playerNode.play()
            hasStartedPlayback = true
            updateState(.playing, playing: true)
          } else if hasStartedPlayback {
            scheduleAvailableBuffers(&pendingData, config: config)
          }
        }

        // Handle short audio that didn't reach prebuffer threshold
        if !hasStartedPlayback, !pendingData.isEmpty {
          if let buffer = createBuffer(from: pendingData) {
            scheduleBufferSync(buffer)
          }
          playerNode.play()
          updateState(.playing, playing: true)
        } else {
          scheduleRemainingData(pendingData, config: config)
        }

        await waitForPlaybackCompletion()
        updateState(.idle, playing: false)
        engine.stop()
      } catch {
        updateState(.error(error), playing: false)
        engine.stop()
      }
    }
  }

  private func createBuffer(from data: Data) -> AVAudioPCMBuffer? {
    let frameCount = AVAudioFrameCount(data.count / 2) // 2 bytes per sample

    guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
      return nil
    }

    buffer.frameLength = frameCount

    data.withUnsafeBytes { rawBuffer in
      if let src = rawBuffer.baseAddress {
        memcpy(buffer.int16ChannelData![0], src, data.count)
      }
    }

    return buffer
  }

  func stop() {
    streamTask?.cancel()
    streamTask = nil
    playerNode.stop()
    engine.stop()
    state = .idle
    isPlaying = false
  }

  func pause() {
    playerNode.pause()
    state = .paused
    isPlaying = false
  }

  func resume() {
    playerNode.play()
    state = .playing
    isPlaying = true
  }
}
