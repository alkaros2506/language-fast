import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService()
    private let hotkeyManager = HotkeyManager()
    private let overlay = OverlayPanel()
    private var isRecording = false
    private var recordingFromPrefs = false
    private var recordingTimer: Timer?
    private var preferencesWindowController: PreferencesWindowController?

    // MARK: - State

    private enum State {
        case idle, recording, transcribing, error
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.file("applicationDidFinishLaunching")
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
            title: "Double-tap \(Settings.shared.hotkeyDisplayName) to dictate, tap to stop",
            action: nil, keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Model: \(Settings.shared.modelName)",
            action: nil, keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","
        ))
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
        Log.file("Accessibility trusted: \(trusted)")
        if !trusted {
            Log.general.warning("Accessibility permissions required — global hotkey will not work until granted.")
            Log.file("WARNING: Accessibility not granted")
        }
    }

    // MARK: - Recording flow

    private func startRecording() {
        Log.file("startRecording called, isRecording=\(isRecording)")
        guard !isRecording else {
            Log.file("startRecording SKIPPED — already recording")
            return
        }
        isRecording = true
        updateState(.recording)
        Log.file("Playing Tink sound")
        NSSound(named: "Tink")?.play()

        do {
            try audioRecorder.start()
            Log.file("Audio recording started")
            // Safety cap: auto-stop after max duration
            recordingTimer = Timer.scheduledTimer(
                withTimeInterval: Settings.shared.maxRecordingDuration,
                repeats: false
            ) { [weak self] _ in
                self?.stopAndTranscribe()
            }
        } catch {
            Log.file("Recording FAILED: \(error.localizedDescription)")
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
        Log.file("Transcribing audio...")

        Task {
            do {
                let text = try await whisperService.transcribe(fileURL: audioURL)
                await MainActor.run {
                    if !text.isEmpty {
                        if self.recordingFromPrefs {
                            // Show result in prefs status label
                            self.preferencesWindowController?.generalPrefs.updateStatus("Result: \(text)")
                        } else {
                            // Inject into the focused app
                            TextInjector.type(text)
                        }
                    }
                    self.recordingFromPrefs = false
                    self.updateState(.idle, skipPrefsStatus: true)
                }
            } catch {
                await MainActor.run {
                    Log.whisper.error("Transcription error: \(error.localizedDescription, privacy: .public)")
                    Log.file("Transcription error: \(error.localizedDescription)")
                    updateState(.error)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.updateState(.idle)
                    }
                }
            }
        }
    }

    // MARK: - UI

    private func updateState(_ state: State, skipPrefsStatus: Bool = false) {
        guard let button = statusItem.button else { return }
        let name: String
        let label: String
        switch state {
        case .idle:
            name = "mic"
            label = "Dictation idle"
            overlay.hide()
            if !skipPrefsStatus { preferencesWindowController?.generalPrefs.updateStatus("Idle") }
        case .recording:
            name = "mic.fill"
            label = "Recording"
            overlay.show(state: .recording)
            if !skipPrefsStatus { preferencesWindowController?.generalPrefs.updateStatus("Recording") }
        case .transcribing:
            name = "ellipsis.circle"
            label = "Transcribing"
            overlay.show(state: .transcribing)
            if !skipPrefsStatus { preferencesWindowController?.generalPrefs.updateStatus("Transcribing") }
        case .error:
            name = "exclamationmark.triangle"
            label = "Error"
            overlay.hide()
            if !skipPrefsStatus { preferencesWindowController?.generalPrefs.updateStatus("Error") }
        }
        Log.file("State → \(label)")
        button.image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: label
        )
    }

    // MARK: - Preferences

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
            // Wire up Click to Record
            preferencesWindowController?.generalPrefs.onStartRecording = { [weak self] in
                self?.recordingFromPrefs = true
                self?.startRecording()
            }
            preferencesWindowController?.generalPrefs.onStopRecording = { [weak self] in
                self?.stopAndTranscribe()
            }
            // Wire up hotkey capture
            preferencesWindowController?.hotkeyPrefs.hotkeyManager = hotkeyManager
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions

    @objc private func quit() {
        hotkeyManager.stop()
        NSApplication.shared.terminate(nil)
    }
}
