import Cocoa

/// Pastes text into the currently focused application by writing to the
/// system pasteboard and simulating Cmd+V.
enum TextInjector {

    static func type(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        // Brief pause so the pasteboard update is visible to the target app
        usleep(50_000) // 50 ms

        let src = CGEventSource(stateID: .hidSystemState)

        // Virtual key code 0x09 = 'v'
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let vUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags   = .maskCommand

        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}
