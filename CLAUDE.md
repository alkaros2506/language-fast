# WhisperDictation

macOS menu-bar push-to-talk dictation app using whisper.cpp.

## Build & Run

```bash
swift build -c release
.build/release/WhisperDictation
```

## Architecture

- Swift Package (swift-tools-version 5.9), macOS 13+, no external Swift dependencies
- All sources in `Sources/` — single executable target
- `AppDelegate` orchestrates recording flow: hotkey → record → transcribe → inject text
- `HotkeyManager` uses IOHIDManager for global key detection (double-tap to start, single tap to stop)
- `WhisperService` shells out to `whisper-cli` as a subprocess
- `AudioRecorder` captures mic input to a temp WAV file
- `TextInjector` uses CGEvents to type transcribed text into the focused app
- `OverlayPanel` shows a floating recording/transcribing indicator
- `Settings` wraps UserDefaults; `Config` provides compile-time defaults and env var overrides
- Preferences UI: `PreferencesWindowController` with General, Hotkey, and Log tabs

## Key Details

- Default hotkey: Left Control (HID usage page 0x07, usage 0xE0)
- Default model: ggml-medium.bin with `--language auto`
- Metal acceleration enabled when `/opt/homebrew/share/whisper-cpp` exists
- Logging via unified `os.Logger` (subsystem: `com.local.WhisperDictation`) and file log
