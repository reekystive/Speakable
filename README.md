# OpenAI TTS Service for macOS

A native macOS menu bar app that adds a system-wide "Speak with OpenAI TTS" service to the right-click context menu. Select any text, right-click, and have it spoken aloud using OpenAI's Text-to-Speech API.

## Features

- **System Service Integration** - Adds "Services → Speak with OpenAI TTS" to the right-click menu in any app
- **Speak Window** - Floating input panel for quick text-to-speech (⌘N from menu bar)
- **Global Hotkey** - Speak clipboard content from anywhere with a custom shortcut
- **Multiple TTS Models** - Support for `tts-1`, `tts-1-hd`, and `gpt-4o-mini-tts`
- **13 Voice Options** - Alloy, Ash, Ballad, Cedar, Coral, Echo, Fable, Marin, Nova, Onyx, Sage, Shimmer, Verse
- **Voice Instructions** - Custom voice styling with `gpt-4o-mini-tts` model
- **Adjustable Speed** - 0.25x to 4.0x playback speed
- **Secure Storage** - API key stored in macOS Keychain
- **Menu Bar Controls** - Pause, resume, and stop playback from the menu bar
- **Real-time Streaming** - Audio plays as it generates with PCM streaming

## Requirements

- macOS 13.0+
- OpenAI API key

## Installation

### Build from Source

1. Install dependencies:

```bash
brew install xcodegen swiftformat swiftlint xcbeautify
```

2. Clone and build:

```bash
git clone https://github.com/yourusername/macos-openai-tts-service.git
cd macos-openai-tts-service
xcodegen generate
open OpenAITTS.xcodeproj
```

3. Build and run (⌘R) in Xcode

### Enable the Service

After first launch:

1. Open **System Settings → Keyboard → Keyboard Shortcuts → Services**
2. Find **"Speak with OpenAI TTS"** under **Text**
3. Enable the checkbox

## Usage

1. Launch the app (it runs in the menu bar)
2. Click the speaker icon in the menu bar → **Settings**
3. Enter your OpenAI API key
4. Use any of these methods to speak text:
   - **Speak Window**: Click menu bar → **Speak...** (or ⌘N), type text, press Enter
   - **System Service**: Select text in any app → Right-click → **Services → Speak with OpenAI TTS**
   - **Global Hotkey**: Set a shortcut in Settings to speak clipboard content from anywhere

## Configuration

| Setting | Description |
|---------|-------------|
| API Key | Your OpenAI API key (stored in Keychain) |
| Voice | Choose from 11 available voices |
| Model | TTS-1 (fast), TTS-1 HD (quality), or GPT-4o Mini TTS (latest) |
| Speed | Playback speed from 0.25x to 4.0x |
| Voice Instructions | Custom instructions for GPT-4o Mini TTS model |

## Development

### Project Structure

```
OpenAITTS/
├── Sources/
│   ├── OpenAITTSApp.swift          # App entry point
│   ├── AppDelegate.swift           # Service provider & hotkey registration
│   ├── SettingsView.swift          # Settings UI
│   ├── MenuBarView.swift           # Menu bar UI
│   ├── SpeakView.swift             # Speak window UI
│   ├── SpeakWindow.swift           # Custom floating panel
│   ├── SpeakWindowController.swift # Window lifecycle management
│   ├── API/
│   │   └── OpenAIClient.swift      # OpenAI TTS API client
│   ├── Audio/
│   │   ├── AudioPlayer.swift       # MP3 audio playback
│   │   └── StreamingAudioPlayer.swift  # Real-time PCM streaming
│   ├── Services/
│   │   └── TTSServiceProvider.swift    # macOS Service handler
│   └── Settings/
│       ├── SettingsManager.swift   # Settings & Keychain
│       └── HotkeySettings.swift    # Global hotkey definitions
├── Resources/
│   ├── Info.plist                  # NSServices configuration
│   └── OpenAITTS.entitlements
└── OpenAITTSTests/                 # Unit tests
```

### Commands

```bash
# Generate Xcode project
xcodegen generate

# Format code
swiftformat .

# Lint code
swiftlint

# Build
xcodebuild -project OpenAITTS.xcodeproj -scheme OpenAITTS build | xcbeautify

# Test
xcodebuild -project OpenAITTS.xcodeproj -scheme OpenAITTS test | xcbeautify
```

## License

MIT
