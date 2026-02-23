import Foundation

/// Runs whisper-cli as a subprocess and returns the transcribed text.
final class WhisperService {

    func transcribe(fileURL: URL) async throws -> String {
        let whisperPath = Settings.shared.whisperPath
        let modelPath = Settings.shared.modelPath
        let threadCount = Settings.shared.threadCount

        Log.whisper.info("Transcribing \(fileURL.lastPathComponent, privacy: .public) with \(whisperPath, privacy: .public)")
        Log.file("whisper-cli args: -m \(modelPath) -f \(fileURL.path) --no-timestamps -t \(threadCount)")

        return try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: whisperPath)
            process.arguments = [
                "-m", modelPath,
                "-f", fileURL.path,
                "--no-timestamps",
                "--language", "auto",
                "-t", "\(threadCount)",
            ]

            // Enable Metal acceleration on Apple Silicon
            var env = ProcessInfo.processInfo.environment
            if let metalPath = Config.metalResourcesPath {
                env["GGML_METAL_PATH_RESOURCES"] = metalPath
            }
            process.environment = env

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let exitCode = process.terminationStatus
            if exitCode != 0 {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
                Log.whisper.error("whisper-cli exited with status \(exitCode): \(errMsg, privacy: .public)")
                Log.file("whisper-cli FAILED (exit \(exitCode)): \(errMsg)")
                throw TranscriptionError.failed(errMsg)
            }

            let text = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            Log.whisper.info("Transcription result (\(text.count) chars): \(text, privacy: .public)")
            Log.file("Transcription OK (\(text.count) chars)")
            return text
        }.value
    }
}

enum TranscriptionError: Error, LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let msg):
            return "Transcription failed: \(msg)"
        }
    }
}
