import Cocoa

/// General tab: configure paths, thread count, max duration, and test recording.
final class GeneralPrefsViewController: NSViewController {

    private var whisperPathField: NSTextField!
    private var modelPathField: NSTextField!
    private var threadStepper: NSStepper!
    private var threadLabel: NSTextField!
    private var durationStepper: NSStepper!
    private var durationLabel: NSTextField!
    private var recordButton: NSButton!
    private var statusLabel: NSTextField!

    /// Set by AppDelegate to wire up Click to Record.
    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    private var isRecording = false

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 360))
        var y: CGFloat = 310

        // Whisper CLI Path
        addLabel("Whisper CLI Path:", at: y, in: container)
        whisperPathField = addTextField(at: y, width: 260, in: container)
        whisperPathField.stringValue = Settings.shared.whisperPath
        let whisperBrowse = NSButton(title: "Browse...", target: self, action: #selector(browseWhisper))
        whisperBrowse.frame = NSRect(x: 420, y: y - 2, width: 70, height: 24)
        whisperBrowse.controlSize = .small
        whisperBrowse.font = NSFont.systemFont(ofSize: 11)
        container.addSubview(whisperBrowse)
        y -= 36

        // Model Path
        addLabel("Model Path:", at: y, in: container)
        modelPathField = addTextField(at: y, width: 260, in: container)
        modelPathField.stringValue = Settings.shared.modelPath
        let modelBrowse = NSButton(title: "Browse...", target: self, action: #selector(browseModel))
        modelBrowse.frame = NSRect(x: 420, y: y - 2, width: 70, height: 24)
        modelBrowse.controlSize = .small
        modelBrowse.font = NSFont.systemFont(ofSize: 11)
        container.addSubview(modelBrowse)
        y -= 36

        // Thread Count
        addLabel("Thread Count:", at: y, in: container)
        threadLabel = NSTextField(labelWithString: "\(Settings.shared.threadCount)")
        threadLabel.frame = NSRect(x: 150, y: y, width: 30, height: 20)
        container.addSubview(threadLabel)

        threadStepper = NSStepper()
        threadStepper.frame = NSRect(x: 185, y: y, width: 19, height: 20)
        threadStepper.minValue = 1
        threadStepper.maxValue = Double(ProcessInfo.processInfo.activeProcessorCount)
        threadStepper.integerValue = Settings.shared.threadCount
        threadStepper.target = self
        threadStepper.action = #selector(threadCountChanged)
        container.addSubview(threadStepper)
        y -= 36

        // Max Duration
        addLabel("Max Duration (s):", at: y, in: container)
        durationLabel = NSTextField(labelWithString: "\(Int(Settings.shared.maxRecordingDuration))")
        durationLabel.frame = NSRect(x: 150, y: y, width: 40, height: 20)
        container.addSubview(durationLabel)

        durationStepper = NSStepper()
        durationStepper.frame = NSRect(x: 195, y: y, width: 19, height: 20)
        durationStepper.minValue = 5
        durationStepper.maxValue = 300
        durationStepper.increment = 5
        durationStepper.integerValue = Int(Settings.shared.maxRecordingDuration)
        durationStepper.target = self
        durationStepper.action = #selector(durationChanged)
        container.addSubview(durationStepper)
        y -= 46

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 20, y: y + 10, width: 460, height: 1)
        container.addSubview(sep)
        y -= 10

        // Click to Record button
        recordButton = NSButton(title: "Click to Record", target: self, action: #selector(toggleRecording))
        recordButton.frame = NSRect(x: 20, y: y, width: 140, height: 28)
        recordButton.bezelStyle = .rounded
        container.addSubview(recordButton)

        statusLabel = NSTextField(labelWithString: "Status: Idle")
        statusLabel.frame = NSRect(x: 170, y: y + 4, width: 200, height: 20)
        container.addSubview(statusLabel)

        self.view = container
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        saveFields()
    }

    func updateStatus(_ status: String) {
        statusLabel?.stringValue = "Status: \(status)"
        if status == "Idle" || status == "Error" {
            isRecording = false
            recordButton?.title = "Click to Record"
        }
    }

    // MARK: - Actions

    @objc private func browseWhisper() {
        browseFile(title: "Select whisper-cli") { [weak self] path in
            self?.whisperPathField.stringValue = path
            Settings.shared.whisperPath = path
        }
    }

    @objc private func browseModel() {
        browseFile(title: "Select Whisper model") { [weak self] path in
            self?.modelPathField.stringValue = path
            Settings.shared.modelPath = path
        }
    }

    @objc private func threadCountChanged() {
        let v = threadStepper.integerValue
        threadLabel.stringValue = "\(v)"
        Settings.shared.threadCount = v
    }

    @objc private func durationChanged() {
        let v = durationStepper.integerValue
        durationLabel.stringValue = "\(v)"
        Settings.shared.maxRecordingDuration = TimeInterval(v)
    }

    @objc private func toggleRecording() {
        if isRecording {
            isRecording = false
            recordButton.title = "Click to Record"
            statusLabel.stringValue = "Status: Stopping..."
            onStopRecording?()
        } else {
            isRecording = true
            recordButton.title = "Stop Recording"
            statusLabel.stringValue = "Status: Recording"
            onStartRecording?()
        }
    }

    private func saveFields() {
        let whisper = whisperPathField.stringValue
        let model = modelPathField.stringValue
        if !whisper.isEmpty { Settings.shared.whisperPath = whisper }
        if !model.isEmpty { Settings.shared.modelPath = model }
    }

    // MARK: - Helpers

    @discardableResult
    private func addLabel(_ text: String, at y: CGFloat, in container: NSView) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: 20, y: y, width: 130, height: 20)
        label.alignment = .right
        container.addSubview(label)
        return label
    }

    private func addTextField(at y: CGFloat, width: CGFloat, in container: NSView) -> NSTextField {
        let field = NSTextField()
        field.frame = NSRect(x: 155, y: y, width: width, height: 22)
        field.font = NSFont.systemFont(ofSize: 12)
        container.addSubview(field)
        return field
    }

    private func browseFile(title: String, handler: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                handler(url.path)
            }
        }
    }
}
