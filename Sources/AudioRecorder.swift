import AVFoundation

/// Records microphone input and writes a 16 kHz mono 16-bit PCM WAV file
/// that whisper.cpp can consume directly.
final class AudioRecorder {

    private var engine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private let lock = NSLock()
    private var stopped = true

    private let outputURL: URL

    /// File format: 16 kHz, mono, signed 16-bit PCM (what whisper.cpp expects).
    private let fileSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    /// Processing format: Float32 at 16 kHz mono — matches AVAudioFile's default
    /// processing format so writes don't need internal conversion.
    private let processingFormat: AVAudioFormat

    init() {
        outputURL = URL(fileURLWithPath: Config.tempAudioPath)
        processingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
    }

    // MARK: - Public

    func start() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        Log.audio.info("Input device format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")
        Log.file("Audio input: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            Log.audio.error("No audio input device available")
            throw RecordingError.noInputDevice
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: processingFormat) else {
            throw RecordingError.converterFailed
        }

        // Remove stale temp file
        try? FileManager.default.removeItem(at: outputURL)

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: fileSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        lock.lock()
        self.engine = engine
        self.outputFile = outputFile
        self.stopped = false
        lock.unlock()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self else { return }
            self.processBuffer(buffer, converter: converter)
        }

        engine.prepare()
        try engine.start()
        Log.audio.info("Recording started → \(self.outputURL.path, privacy: .public)")
        Log.file("Recording started → \(self.outputURL.path)")
    }

    func stop() -> URL {
        // Mark stopped under lock — in-flight processBuffer calls will bail out
        lock.lock()
        stopped = true
        outputFile = nil
        lock.unlock()

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil

        let size = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
        Log.audio.info("Recording stopped — file size: \(size) bytes")
        Log.file("Recording stopped — file size: \(size) bytes")
        return outputURL
    }

    // MARK: - Private

    private func processBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        lock.lock()
        guard !stopped, let outputFile else {
            lock.unlock()
            return
        }

        let ratio = processingFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: processingFormat,
            frameCapacity: outputCapacity
        ) else {
            lock.unlock()
            return
        }

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
        lock.unlock()
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
