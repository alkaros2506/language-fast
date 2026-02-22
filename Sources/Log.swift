import os.log

/// Unified logging for WhisperDictation.
/// View in Console.app: filter by subsystem "com.local.WhisperDictation"
/// Or from Terminal:  log stream --predicate 'subsystem == "com.local.WhisperDictation"' --level debug
enum Log {
    static let general  = Logger(subsystem: "com.local.WhisperDictation", category: "general")
    static let hotkey   = Logger(subsystem: "com.local.WhisperDictation", category: "hotkey")
    static let audio    = Logger(subsystem: "com.local.WhisperDictation", category: "audio")
    static let whisper  = Logger(subsystem: "com.local.WhisperDictation", category: "whisper")
}
