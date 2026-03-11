# WhisperDictation

A macOS menu-bar app for push-to-talk dictation powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp). Double-tap a hotkey to start recording, tap again to stop — transcribed text is typed into the focused app.

## Features

- Push-to-talk with configurable hotkey (default: double-tap Left Control)
- Local speech-to-text via whisper.cpp (no cloud APIs)
- Metal acceleration on Apple Silicon
- Automatic language detection (multilingual medium model by default)
- Visual overlay showing recording/transcribing state
- Preferences UI for hotkey, model path, thread count, and more
- Menu-bar only (no Dock icon)

## Requirements

- macOS 13+
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) installed (`brew install whisper-cpp`)
- A GGML model file (medium model recommended: `brew install whisper-cpp` includes it)
- Accessibility permissions (for global hotkey and text injection)
- Microphone permission

## Installation

```bash
# Install whisper.cpp
brew install whisper-cpp

# Build the app
swift build -c release

# Run
.build/release/WhisperDictation
```

## Configuration

Settings are accessible from the menu-bar icon (Preferences...) or via environment variables:

| Environment Variable | Description |
|---|---|
| `WHISPER_DICTATION_BINARY` | Path to `whisper-cli` binary |
| `WHISPER_DICTATION_MODEL` | Path to `.bin` model file |
| `WHISPER_DICTATION_THREADS` | Number of CPU threads for inference |

## Usage

1. Launch the app — a microphone icon appears in the menu bar
2. Double-tap the hotkey (Left Control by default) to start recording
3. Speak, then tap the hotkey once to stop
4. Transcribed text is typed into the currently focused app

## Logging

```bash
# View real-time logs
log stream --predicate 'subsystem == "com.local.WhisperDictation"' --level debug
```

File log is also written to `~/Library/Logs/WhisperDictation.log`.
