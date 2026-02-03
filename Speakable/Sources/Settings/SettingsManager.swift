import Foundation
import Security

// MARK: - Voice Options

enum TTSVoice: String, CaseIterable, Identifiable {
  case alloy
  case ash
  case ballad
  case coral
  case echo
  case fable
  case marin
  case cedar
  case nova
  case onyx
  case sage
  case shimmer
  case verse

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .marin:
      "Marin (Recommended)"
    case .cedar:
      "Cedar (Recommended)"
    default:
      rawValue.capitalized
    }
  }
}

// MARK: - Model Options

enum TTSModel: String, CaseIterable, Identifiable {
  case tts1 = "tts-1"
  case tts1HD = "tts-1-hd"
  case gpt4oMiniTTS = "gpt-4o-mini-tts"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .tts1:
      "TTS-1 (Fast)"
    case .tts1HD:
      "TTS-1 HD (Quality)"
    case .gpt4oMiniTTS:
      "GPT-4o Mini TTS (Latest)"
    }
  }

  var supportsInstructions: Bool {
    self == .gpt4oMiniTTS
  }
}

// MARK: - Settings Manager

final class SettingsManager: ObservableObject {
  static let shared = SettingsManager()

  // Use Bundle ID as keychain service to separate Debug/Release builds
  private let keychainService = Bundle.main.bundleIdentifier ?? "sh.lennon.Speakable"
  private let keychainAccount = "openai-api-key"

  private let voiceKey = "selectedVoice"
  private let modelKey = "selectedModel"
  private let speedKey = "speechSpeed"
  private let instructionsKey = "voiceInstructions"

  @Published var apiKey: String {
    didSet {
      saveAPIKeyToKeychain(apiKey)
    }
  }

  @Published var selectedVoice: TTSVoice {
    didSet {
      UserDefaults.standard.set(selectedVoice.rawValue, forKey: voiceKey)
    }
  }

  @Published var selectedModel: TTSModel {
    didSet {
      UserDefaults.standard.set(selectedModel.rawValue, forKey: modelKey)
    }
  }

  @Published var speechSpeed: Double {
    didSet {
      UserDefaults.standard.set(speechSpeed, forKey: speedKey)
    }
  }

  @Published var voiceInstructions: String {
    didSet {
      UserDefaults.standard.set(voiceInstructions, forKey: instructionsKey)
    }
  }

  var isConfigured: Bool {
    !apiKey.isEmpty
  }

  private init() {
    apiKey = ""
    selectedVoice = .alloy
    selectedModel = .gpt4oMiniTTS
    speechSpeed = 1.0
    voiceInstructions = ""

    loadSettings()
  }

  private func loadSettings() {
    apiKey = loadAPIKeyFromKeychain() ?? ""

    if let voiceRaw = UserDefaults.standard.string(forKey: voiceKey),
       let voice = TTSVoice(rawValue: voiceRaw)
    {
      selectedVoice = voice
    }

    if let modelRaw = UserDefaults.standard.string(forKey: modelKey),
       let model = TTSModel(rawValue: modelRaw)
    {
      selectedModel = model
    }

    let savedSpeed = UserDefaults.standard.double(forKey: speedKey)
    if savedSpeed > 0 {
      speechSpeed = savedSpeed
    }

    if let instructions = UserDefaults.standard.string(forKey: instructionsKey) {
      voiceInstructions = instructions
    }
  }

  // MARK: - Keychain Operations

  private func saveAPIKeyToKeychain(_ key: String) {
    let data = key.data(using: .utf8)!

    // Delete existing item first
    let deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecUseDataProtectionKeychain as String: false,
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    guard !key.isEmpty else { return }

    // Add new item - use legacy keychain for dev compatibility
    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecValueData as String: data,
      kSecUseDataProtectionKeychain as String: false,
    ]

    let status = SecItemAdd(addQuery as CFDictionary, nil)
    if status != errSecSuccess {
      print("Failed to save API key to Keychain: \(status)")
    }
  }

  private func loadAPIKeyFromKeychain() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecUseDataProtectionKeychain as String: false,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess,
          let data = result as? Data,
          let key = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return key
  }

  func clearAPIKey() {
    apiKey = ""
  }
}
