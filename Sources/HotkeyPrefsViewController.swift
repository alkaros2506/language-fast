import Cocoa

/// Hotkey tab: shows current hotkey, allows recording a new one, configures double-tap interval.
final class HotkeyPrefsViewController: NSViewController {

    private var currentKeyLabel: NSTextField!
    private var recordButton: NSButton!
    private var intervalStepper: NSStepper!
    private var intervalLabel: NSTextField!

    /// Set by AppDelegate to access the HotkeyManager for capture mode.
    var hotkeyManager: HotkeyManager?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 360))
        var y: CGFloat = 280

        // Current Hotkey
        addLabel("Current Hotkey:", at: y, in: container)
        currentKeyLabel = NSTextField(labelWithString: Settings.shared.hotkeyDisplayName)
        currentKeyLabel.frame = NSRect(x: 155, y: y, width: 200, height: 20)
        currentKeyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        container.addSubview(currentKeyLabel)
        y -= 40

        // Record New Hotkey button
        recordButton = NSButton(title: "Record New Hotkey", target: self, action: #selector(recordHotkey))
        recordButton.frame = NSRect(x: 155, y: y, width: 160, height: 28)
        recordButton.bezelStyle = .rounded
        container.addSubview(recordButton)
        y -= 50

        // Double-tap Interval
        addLabel("Double-tap Interval:", at: y, in: container)
        let interval = Settings.shared.doubleTapInterval
        intervalLabel = NSTextField(labelWithString: String(format: "%.2f s", interval))
        intervalLabel.frame = NSRect(x: 155, y: y, width: 60, height: 20)
        container.addSubview(intervalLabel)

        intervalStepper = NSStepper()
        intervalStepper.frame = NSRect(x: 220, y: y, width: 19, height: 20)
        intervalStepper.minValue = 0.15
        intervalStepper.maxValue = 1.0
        intervalStepper.increment = 0.05
        intervalStepper.doubleValue = interval
        intervalStepper.target = self
        intervalStepper.action = #selector(intervalChanged)
        container.addSubview(intervalStepper)

        let secLabel = NSTextField(labelWithString: "seconds")
        secLabel.frame = NSRect(x: 245, y: y, width: 60, height: 20)
        container.addSubview(secLabel)
        y -= 50

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 20, y: y + 10, width: 460, height: 1)
        container.addSubview(sep)
        y -= 10

        // Info label
        let info = NSTextField(wrappingLabelWithString: "Changes take effect immediately. No restart needed.")
        info.frame = NSRect(x: 20, y: y, width: 460, height: 20)
        info.textColor = .secondaryLabelColor
        info.font = NSFont.systemFont(ofSize: 11)
        container.addSubview(info)

        self.view = container
    }

    // MARK: - Actions

    @objc private func recordHotkey() {
        recordButton.title = "Press any key..."
        recordButton.isEnabled = false

        hotkeyManager?.captureNextKey = { [weak self] usagePage, usage, name in
            Settings.shared.hotkeyUsagePage = usagePage
            Settings.shared.hotkeyUsage = usage
            Settings.shared.hotkeyDisplayName = name

            self?.hotkeyManager?.resetState()
            self?.currentKeyLabel.stringValue = name
            self?.recordButton.title = "Record New Hotkey"
            self?.recordButton.isEnabled = true
            Log.file("Hotkey changed to: \(name) (page=0x\(String(usagePage, radix: 16)) usage=0x\(String(usage, radix: 16)))")
        }
    }

    @objc private func intervalChanged() {
        let v = intervalStepper.doubleValue
        intervalLabel.stringValue = String(format: "%.2f s", v)
        Settings.shared.doubleTapInterval = v
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
}
