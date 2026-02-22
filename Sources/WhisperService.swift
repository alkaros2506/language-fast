import Foundation

/// Runs whisper-cli as a subprocess and returns the transcribed text.
final class WhisperService {

    func transcribe(fileURL: URL) async throws -> String {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: Config.whisperPath)
            process.arguments = [
                "-m", Config.modelPath,
                "-f", fileURL.path,
                "--no-timestamps",
                "-t", "\(Config.threadCount)",
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

            guard process.terminationStatus == 0 else {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"
                throw TranscriptionError.failed(errMsg)
            }

            let text = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
