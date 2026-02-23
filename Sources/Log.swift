import os.log
import Foundation

/// A single log entry with timestamp and message.
struct LogEntry {
    let timestamp: Date
    let message: String

    var formatted: String {
        let df = ISO8601DateFormatter()
        return "[\(df.string(from: timestamp))] \(message)"
    }
}

/// Unified logging for WhisperDictation.
/// View in Console.app: filter by subsystem "com.local.WhisperDictation"
/// Or from Terminal:  log stream --predicate 'subsystem == "com.local.WhisperDictation"' --level debug
/// File log:  tail -f /tmp/whisper-dictation.log
enum Log {
    static let general  = Logger(subsystem: "com.local.WhisperDictation", category: "general")
    static let hotkey   = Logger(subsystem: "com.local.WhisperDictation", category: "hotkey")
    static let audio    = Logger(subsystem: "com.local.WhisperDictation", category: "audio")
    static let whisper  = Logger(subsystem: "com.local.WhisperDictation", category: "whisper")

    /// Callback for live log updates (called on main thread).
    static var onNewEntry: ((LogEntry) -> Void)?

    // MARK: - Ring buffer

    private static let lock = NSLock()
    private static var entries: [LogEntry] = []
    private static let maxEntries = 500

    /// Returns a snapshot of all log entries.
    static func allEntries() -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    /// Clear all buffered entries.
    static func clearEntries() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    private static func addEntry(_ entry: LogEntry) {
        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()

        let callback = onNewEntry
        if Thread.isMainThread {
            callback?(entry)
        } else {
            DispatchQueue.main.async { callback?(entry) }
        }
    }

    /// Write to ring buffer, file, and optionally notify UI.
    static func file(_ msg: String) {
        let entry = LogEntry(timestamp: Date(), message: msg)
        addEntry(entry)

        let path = "/tmp/whisper-dictation.log"
        let line = "\(entry.formatted)\n"
        if let data = line.data(using: .utf8) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                FileManager.default.createFile(atPath: path, contents: data)
            }
        }
    }
}
