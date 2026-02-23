import Cocoa

/// Logs tab: shows live log entries in a scrollable text view.
final class LogPrefsViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var previousOnNewEntry: ((LogEntry) -> Void)?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 360))

        // Scroll view with text view
        scrollView = NSScrollView(frame: NSRect(x: 20, y: 50, width: 460, height: 290))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 4)

        scrollView.documentView = textView
        container.addSubview(scrollView)

        // Buttons
        let clearBtn = NSButton(title: "Clear", target: self, action: #selector(clearLog))
        clearBtn.frame = NSRect(x: 20, y: 12, width: 80, height: 28)
        container.addSubview(clearBtn)

        let openBtn = NSButton(title: "Open Log File", target: self, action: #selector(openLogFile))
        openBtn.frame = NSRect(x: 110, y: 12, width: 120, height: 28)
        container.addSubview(openBtn)

        let copyBtn = NSButton(title: "Copy All", target: self, action: #selector(copyAll))
        copyBtn.frame = NSRect(x: 240, y: 12, width: 80, height: 28)
        container.addSubview(copyBtn)

        self.view = container
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Populate from existing entries
        let entries = Log.allEntries()
        let text = entries.map(\.formatted).joined(separator: "\n")
        textView.string = text
        scrollToBottom()

        // Subscribe to live updates
        Log.onNewEntry = { [weak self] entry in
            self?.appendEntry(entry)
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        Log.onNewEntry = nil
    }

    private func appendEntry(_ entry: LogEntry) {
        let text = (textView.string.isEmpty ? "" : "\n") + entry.formatted
        textView.textStorage?.append(NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.textColor
            ]
        ))
        scrollToBottom()
    }

    private func scrollToBottom() {
        textView.scrollToEndOfDocument(nil)
    }

    @objc private func clearLog() {
        Log.clearEntries()
        textView.string = ""
    }

    @objc private func openLogFile() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp/whisper-dictation.log"))
    }

    @objc private func copyAll() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(textView.string, forType: .string)
    }
}
