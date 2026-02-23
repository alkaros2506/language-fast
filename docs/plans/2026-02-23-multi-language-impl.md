# Multi-Language Auto-Detect Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable auto-detect multilingual transcription by switching to `ggml-medium.bin` and passing `--language auto` to whisper-cli.

**Architecture:** Two-line change across Config.swift (default model filename) and WhisperService.swift (add --language auto flag). No UI or structural changes.

**Tech Stack:** Swift, whisper.cpp (CLI), macOS

---

### Task 1: Update default model to multilingual

**Files:**
- Modify: `Sources/Config.swift:28-31`

**Step 1: Change model filename from `ggml-base.en.bin` to `ggml-medium.bin`**

Replace all three occurrences of `ggml-base.en.bin` with `ggml-medium.bin` in the `defaultModelPath` computed property:

```swift
static var defaultModelPath: String {
    if let custom = env("WHISPER_DICTATION_MODEL") { return custom }
    let candidates = [
        "/opt/homebrew/share/whisper-cpp/models/ggml-medium.bin",
        "/usr/local/share/whisper-cpp/models/ggml-medium.bin",
        "\(NSHomeDirectory())/whisper.cpp/models/ggml-medium.bin",
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
        ?? candidates[0]
}
```

**Step 2: Build to verify no compile errors**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

**Step 3: Commit**

```bash
git add Sources/Config.swift
git commit -m "feat: switch default model to ggml-medium.bin for multilingual support"
```

---

### Task 2: Add --language auto flag to whisper-cli

**Files:**
- Modify: `Sources/WhisperService.swift:17-22`

**Step 1: Add `--language`, `auto` to the arguments array**

```swift
process.arguments = [
    "-m", modelPath,
    "-f", fileURL.path,
    "--no-timestamps",
    "--language", "auto",
    "-t", "\(threadCount)",
]
```

**Step 2: Build to verify no compile errors**

Run: `swift build -c release 2>&1 | tail -5`
Expected: `Build complete!`

**Step 3: Manual smoke test**

Run: `make bundle && open WhisperDictation.app`
- Double-tap hotkey, speak a few words in English, verify transcription works
- Double-tap hotkey, speak a few words in Greek, verify Greek text appears

**Step 4: Commit**

```bash
git add Sources/WhisperService.swift
git commit -m "feat: add --language auto for automatic language detection"
```

---

### Task 3: Ensure model is downloaded

**Step 1: Check if ggml-medium.bin exists**

Run: `ls -lh /opt/homebrew/share/whisper-cpp/models/ggml-medium.bin 2>/dev/null || echo "NOT FOUND"`

**Step 2: Download if missing**

Run: `whisper-cpp-download-ggml-model medium`

This downloads ~1.5GB. Wait for completion.

**Step 3: Verify model file**

Run: `ls -lh /opt/homebrew/share/whisper-cpp/models/ggml-medium.bin`
Expected: File exists, ~1.5GB size
