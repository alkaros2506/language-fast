import AVFoundation

/// Records microphone input and writes a 16 kHz mono 16-bit PCM WAV file
/// that whisper.cpp can consume directly.
final class AudioRecorder {

    private var engine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var converter: AVAudioConverter?

    private let outputURL: URL

    /// Target format expected by whisper.cpp: 16 kHz, mono, signed 16-bit PCM.
    private let targetFormat: AVAudioFormat

    init() {
        outputURL = URL(fileURLWithPath: Config.tempAudioPath)
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!
    }

    // MARK: - Public

    func start() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecordingError.noInputDevice
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecordingError.converterFailed
        }

        // Remove stale temp file
        try? FileManager.default.removeItem(at: outputURL)

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: targetFormat.settings
        )

        self.engine = engine
        self.outputFile = outputFile
        self.converter = converter

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() -> URL {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        outputFile = nil
        converter = nil
        return outputURL
    }

    // MARK: - Private

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter, let outputFile else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputCapacity
        ) else { return }

        var error: NSError?
        var hasData = true

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return buffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        if error == nil, outputBuffer.frameLength > 0 {
            try? outputFile.write(from: outputBuffer)
        }
    }
}

enum RecordingError: Error, LocalizedError {
    case noInputDevice
    case converterFailed

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "No audio input device found"
        case .converterFailed:
            return "Failed to create audio format converter"
        }
    }
}
