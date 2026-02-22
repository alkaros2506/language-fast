import Cocoa

/// Listens for the Right Option key via a CGEventTap to implement push-to-talk.
///
/// Requires Accessibility permissions:
///   System Settings → Privacy & Security → Accessibility → add WhisperDictation
final class HotkeyManager {

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isKeyDown = false

    // Right Option key: virtual keycode 61, device flag 0x40 (NX_DEVICERALTKEYMASK)
    private static let triggerKeyCode: CGKeyCode = 61
    private static let triggerDeviceFlag: UInt64 = 0x40

    // MARK: - Public

    func start() {
        let eventMask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon)
                    .takeUnretainedValue()
                mgr.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            Log.hotkey.error("Failed to create event tap — Accessibility permission not granted.")
            Log.hotkey.error("  → Open System Settings > Privacy & Security > Accessibility")
            Log.hotkey.error("  → Add WhisperDictation to the list.")
            return
        }

        eventTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.hotkey.info("Event tap created — listening for Right Option (keyCode \(Self.triggerKeyCode))")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Private

    private func handle(type: CGEventType, event: CGEvent) {
        // Re-enable the tap if macOS disabled it due to timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == Self.triggerKeyCode else { return }

        let pressed = (event.flags.rawValue & Self.triggerDeviceFlag) != 0

        if pressed && !isKeyDown {
            isKeyDown = true
            Log.hotkey.debug("Right Option DOWN — start recording")
            onKeyDown?()
        } else if !pressed && isKeyDown {
            isKeyDown = false
            Log.hotkey.debug("Right Option UP — stop recording")
            onKeyUp?()
        }
    }
}
