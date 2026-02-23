import Cocoa
import IOKit
import IOKit.hid

/// Listens for double-tap of a configurable key via IOHIDManager.
/// Double-tap starts recording, single tap stops it.
final class HotkeyManager {

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    /// When set, next key-down is intercepted and reported via this callback,
    /// then capture clears itself. Used by the hotkey recorder UI.
    var captureNextKey: ((UInt32, UInt32, String) -> Void)?

    private var manager: IOHIDManager?
    private var isRecording = false

    // Double-tap detection
    private var lastKeyUpTime: Date = .distantPast
    private var keyIsDown = false
    private var recordingStartTime: Date = .distantPast
    private static let cooldownAfterStart: TimeInterval = 0.8

    // Debounce duplicate HID events from multiple devices
    private var lastEventTime: Date = .distantPast
    private var lastEventPressed = false
    private static let deduplicateWindow: TimeInterval = 0.05

    // MARK: - Computed from Settings

    private var hotkeyUsagePage: UInt32 { Settings.shared.hotkeyUsagePage }
    private var hotkeyUsage: UInt32 { Settings.shared.hotkeyUsage }
    private var doubleTapInterval: TimeInterval { Settings.shared.doubleTapInterval }

    // MARK: - Public

    func start() {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        // Match all HID devices — keyboard-only matching requires stricter permissions
        IOHIDManagerSetDeviceMatching(mgr, nil)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterInputValueCallback(mgr, { refcon, _, _, value in
            guard let refcon else { return }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            mgr.handleHIDValue(value)
        }, refcon)

        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let result = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnSuccess {
            let keyName = Settings.shared.hotkeyDisplayName
            Log.hotkey.info("IOHIDManager opened — double-tap \(keyName, privacy: .public) to dictate")
            Log.file("IOHIDManager opened — double-tap \(keyName) to dictate, tap to stop")
            self.manager = mgr
        } else {
            Log.hotkey.error("IOHIDManagerOpen failed: \(result)")
            Log.file("IOHIDManager FAILED: \(result)")
        }
    }

    func stop() {
        if let mgr = manager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            manager = nil
        }
    }

    /// Maps common HID keyboard usages to human-readable names.
    static func displayName(usagePage: UInt32, usage: UInt32) -> String {
        guard usagePage == 0x07 else { return "Key 0x\(String(usage, radix: 16, uppercase: true))" }
        switch usage {
        case 0xE0: return "Left Control"
        case 0xE1: return "Left Shift"
        case 0xE2: return "Left Option"
        case 0xE3: return "Left Command"
        case 0xE4: return "Right Control"
        case 0xE5: return "Right Shift"
        case 0xE6: return "Right Option"
        case 0xE7: return "Right Command"
        case 0x39: return "Caps Lock"
        case 0x29: return "Escape"
        case 0x2C: return "Space"
        case 0x28: return "Return"
        case 0x2B: return "Tab"
        case 0x2A: return "Delete"
        case 0x35: return "Grave Accent"
        case 0x04...0x1D:
            let letter = Character(UnicodeScalar(usage - 0x04 + UInt32(Character("A").asciiValue!))!)
            return String(letter)
        case 0x1E...0x27:
            let digits = ["1","2","3","4","5","6","7","8","9","0"]
            return digits[Int(usage - 0x1E)]
        case 0x3A...0x45:
            return "F\(usage - 0x3A + 1)"
        default: return "Key 0x\(String(usage, radix: 16, uppercase: true))"
        }
    }

    // MARK: - Private

    private func handleHIDValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let pressed = IOHIDValueGetIntegerValue(value) != 0

        // Capture mode: intercept next key-down for hotkey recorder
        if pressed, let capture = captureNextKey {
            let name = Self.displayName(usagePage: UInt32(usagePage), usage: UInt32(usage))
            Log.file("Captured key: page=0x\(String(usagePage, radix: 16)) usage=0x\(String(usage, radix: 16)) name=\(name)")
            captureNextKey = nil
            DispatchQueue.main.async {
                capture(UInt32(usagePage), UInt32(usage), name)
            }
            return
        }

        guard usagePage == hotkeyUsagePage,
              usage == hotkeyUsage else { return }

        DispatchQueue.main.async { [weak self] in
            self?.handleHotkeyEvent(pressed: pressed)
        }
    }

    /// Reset double-tap state. Call when the hotkey is changed.
    func resetState() {
        lastKeyUpTime = .distantPast
        keyIsDown = false
        isRecording = false
    }

    private func handleHotkeyEvent(pressed: Bool) {
        // Deduplicate events from multiple HID devices reporting the same key
        let now = Date()
        if pressed == lastEventPressed &&
            now.timeIntervalSince(lastEventTime) < Self.deduplicateWindow {
            return
        }
        lastEventTime = now
        lastEventPressed = pressed

        if pressed {
            keyIsDown = true
            Log.file("Hotkey DOWN")
        } else {
            keyIsDown = false
            let now = Date()

            if isRecording {
                // Ignore releases during cooldown after recording starts
                let sinceStart = now.timeIntervalSince(recordingStartTime)
                if sinceStart < Self.cooldownAfterStart {
                    Log.file("Hotkey UP ignored (cooldown \(String(format: "%.2f", sinceStart))s)")
                    return
                }
                isRecording = false
                Log.file("Hotkey tap → STOP recording")
                onKeyUp?()
            } else {
                let elapsed = now.timeIntervalSince(lastKeyUpTime)
                if elapsed < doubleTapInterval {
                    isRecording = true
                    recordingStartTime = now
                    Log.file("Double-tap → START recording (interval: \(String(format: "%.3f", elapsed))s)")
                    onKeyDown?()
                } else {
                    Log.file("Hotkey UP (single tap, elapsed: \(String(format: "%.3f", elapsed))s)")
                }
            }

            lastKeyUpTime = now
        }
    }
}
