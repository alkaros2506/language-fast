import Cocoa

/// Manages the Preferences window with 3 tabs: General, Hotkey, Logs.
final class PreferencesWindowController: NSWindowController {

    let generalPrefs = GeneralPrefsViewController()
    let hotkeyPrefs = HotkeyPrefsViewController()
    let logPrefs = LogPrefsViewController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "WhisperDictation Preferences"
        window.center()
        window.setFrameAutosaveName("PreferencesWindow")
        window.minSize = NSSize(width: 520, height: 400)

        self.init(window: window)

        let tabVC = NSTabViewController()
        tabVC.tabStyle = .toolbar

        let generalItem = NSTabViewItem(viewController: generalPrefs)
        generalItem.label = "General"
        generalItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "General")

        let hotkeyItem = NSTabViewItem(viewController: hotkeyPrefs)
        hotkeyItem.label = "Hotkey"
        hotkeyItem.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Hotkey")

        let logItem = NSTabViewItem(viewController: logPrefs)
        logItem.label = "Logs"
        logItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Logs")

        tabVC.addTabViewItem(generalItem)
        tabVC.addTabViewItem(hotkeyItem)
        tabVC.addTabViewItem(logItem)

        window.contentViewController = tabVC
    }
}
