import Foundation

/// Default configuration for WhisperDictation.
/// These provide fallback values for Settings.
/// Override paths via environment variables:
///   WHISPER_DICTATION_BINARY  - path to whisper-cli
///   WHISPER_DICTATION_MODEL   - path to .bin model file
///   WHISPER_DICTATION_THREADS - number of CPU threads for inference
enum Config {

    // MARK: - Whisper binary

    static var defaultWhisperPath: String {
        if let custom = env("WHISPER_DICTATION_BINARY") { return custom }
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
            "/opt/homebrew/bin/main",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
            ?? candidates[0]
    }

    // MARK: - Model

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

    // MARK: - Metal acceleration

    static var metalResourcesPath: String? {
        let path = "/opt/homebrew/share/whisper-cpp"
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    // MARK: - Recording

    static let tempAudioPath = NSTemporaryDirectory() + "whisper-dictation.wav"

    // MARK: - Performance

    static var defaultThreadCount: Int {
        if let custom = env("WHISPER_DICTATION_THREADS"),
           let n = Int(custom) { return n }
        return min(ProcessInfo.processInfo.activeProcessorCount, 8)
    }

    // MARK: - Helpers

    private static func env(_ key: String) -> String? {
        let val = ProcessInfo.processInfo.environment[key]
        return (val?.isEmpty ?? true) ? nil : val
    }
}
