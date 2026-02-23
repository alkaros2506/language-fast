# Multi-Language Support via Auto-Detect

**Date:** 2026-02-23
**Status:** Approved

## Goal

Support dictation in English and Greek (and any other Whisper-supported language) by switching from the English-only base model to a multilingual model with automatic language detection.

## Approach

Swap the default model from `ggml-base.en.bin` to `ggml-medium.bin` and pass `--language auto` to `whisper-cli`. Whisper auto-detects the spoken language per recording and transcribes accordingly. No UI changes required.

## Changes

### Config.swift
- Change default model filename from `ggml-base.en.bin` to `ggml-medium.bin`
- Search paths remain: `/opt/homebrew/share/whisper-cpp/models/`, `/usr/local/share/whisper-cpp/models/`, `~/whisper.cpp/models/`

### WhisperService.swift
- Add `--language auto` to the `whisper-cli` argument list

### Makefile
- Update model filename references in comments/docs if any

## Model Acquisition

Users download the medium model via:
```
whisper-cpp-download-ggml-model medium
```
Or manually place `ggml-medium.bin` in one of the search paths.

## What Doesn't Change

- Audio recording format (16 kHz mono PCM)
- Hotkey system
- Settings/Preferences UI (`modelPath` already supports custom paths)
- Text injection (Unicode handles Greek natively)

## Trade-offs

- Model size increases from ~150MB to ~1.5GB
- Inference is slightly slower than English-only base model
- Auto-detect may occasionally misidentify very short phrases
- Future enhancement: add `--language` hint option if auto-detect proves unreliable
