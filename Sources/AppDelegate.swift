import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService()
    private let hotkeyManager = HotkeyManager()
    private var isRecording = false
    private var recordingTimer: Timer?

    // MARK: - State

    private enum State {
        case idle, recording, transcribing, error
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupHotkey()
        checkAccessibility()
    }

    // MARK: - Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateState(.idle)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Whisper Dictation", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Hold Right Option to dictate",
            action: nil, keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Model: \(Config.modelName)",
            action: nil, keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit", action: #selector(quit), keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyManager.onKeyDown = { [weak self] in
            DispatchQueue.main.async { self?.startRecording() }
        }
        hotkeyManager.onKeyUp = { [weak self] in
            DispatchQueue.main.async { self?.stopAndTranscribe() }
        }
        hotkeyManager.start()
    }

    // MARK: - Permissions

    private func checkAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        Log.general.info("Accessibility trusted: \(trusted)")
        if !trusted {
            Log.general.warning("Accessibility permissions required — global hotkey will not work until granted.")
        }
    }

    // MARK: - Recording flow

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        updateState(.recording)
        NSSound(named: "Tink")?.play()

        do {
            try audioRecorder.start()
            // Safety cap: auto-stop after max duration
            recordingTimer = Timer.scheduledTimer(
                withTimeInterval: Config.maxRecordingDuration,
                repeats: false
            ) { [weak self] _ in
                self?.stopAndTranscribe()
            }
        } catch {
            Log.audio.error("Recording failed: \(error.localizedDescription, privacy: .public)")
            isRecording = false
            updateState(.error)
        }
    }

    private func stopAndTranscribe() {
        guard isRecording else { return }
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        let audioURL = audioRecorder.stop()
        updateState(.transcribing)
        NSSound(named: "Pop")?.play()

        Task {
            do {
                let text = try await whisperService.transcribe(fileURL: audioURL)
                await MainActor.run {
                    if !text.isEmpty {
                        TextInjector.type(text)
                    }
                    updateState(.idle)
                }
            } catch {
                await MainActor.run {
                    Log.whisper.error("Transcription error: \(error.localizedDescription, privacy: .public)")
                    updateState(.error)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.updateState(.idle)
                    }
                }
            }
        }
    }

    // MARK: - UI

    private func updateState(_ state: State) {
        guard let button = statusItem.button else { return }
        let name: String
        let label: String
        switch state {
        case .idle:
            name = "mic"
            label = "Dictation idle"
        case .recording:
            name = "mic.fill"
            label = "Recording"
        case .transcribing:
            name = "ellipsis.circle"
            label = "Transcribing"
        case .error:
            name = "exclamationmark.triangle"
            label = "Error"
        }
        button.image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: label
        )
    }

    // MARK: - Actions

    @objc private func quit() {
        hotkeyManager.stop()
        NSApplication.shared.terminate(nil)
    }
}
