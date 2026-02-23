import Foundation

/// Persistent settings backed by UserDefaults.
/// Falls back to Config defaults for unset values.
final class Settings {
    static let shared = Settings()

    var onChange: (() -> Void)?

    // MARK: - Keys

    private enum Key: String {
        case whisperPath, modelPath, threadCount
        case maxRecordingDuration, doubleTapInterval
        case hotkeyUsagePage, hotkeyUsage, hotkeyDisplayName
    }

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Paths

    var whisperPath: String {
        get { defaults.string(forKey: Key.whisperPath.rawValue) ?? Config.defaultWhisperPath }
        set { defaults.set(newValue, forKey: Key.whisperPath.rawValue); onChange?() }
    }

    var modelPath: String {
        get { defaults.string(forKey: Key.modelPath.rawValue) ?? Config.defaultModelPath }
        set { defaults.set(newValue, forKey: Key.modelPath.rawValue); onChange?() }
    }

    // MARK: - Performance

    var threadCount: Int {
        get {
            let v = defaults.integer(forKey: Key.threadCount.rawValue)
            return v > 0 ? v : Config.defaultThreadCount
        }
        set { defaults.set(newValue, forKey: Key.threadCount.rawValue); onChange?() }
    }

    // MARK: - Recording

    var maxRecordingDuration: TimeInterval {
        get {
            let v = defaults.double(forKey: Key.maxRecordingDuration.rawValue)
            return v > 0 ? v : 60
        }
        set { defaults.set(newValue, forKey: Key.maxRecordingDuration.rawValue); onChange?() }
    }

    // MARK: - Hotkey

    var doubleTapInterval: TimeInterval {
        get {
            let v = defaults.double(forKey: Key.doubleTapInterval.rawValue)
            return v > 0 ? v : 0.35
        }
        set { defaults.set(newValue, forKey: Key.doubleTapInterval.rawValue); onChange?() }
    }

    var hotkeyUsagePage: UInt32 {
        get {
            let v = defaults.integer(forKey: Key.hotkeyUsagePage.rawValue)
            return v > 0 ? UInt32(v) : 0x07 // kHIDPage_KeyboardOrKeypad
        }
        set { defaults.set(Int(newValue), forKey: Key.hotkeyUsagePage.rawValue); onChange?() }
    }

    var hotkeyUsage: UInt32 {
        get {
            let v = defaults.integer(forKey: Key.hotkeyUsage.rawValue)
            return v > 0 ? UInt32(v) : 0xE0 // Left Control
        }
        set { defaults.set(Int(newValue), forKey: Key.hotkeyUsage.rawValue); onChange?() }
    }

    var hotkeyDisplayName: String {
        get { defaults.string(forKey: Key.hotkeyDisplayName.rawValue) ?? "Left Control" }
        set { defaults.set(newValue, forKey: Key.hotkeyDisplayName.rawValue); onChange?() }
    }

    // MARK: - Derived

    var modelName: String {
        URL(fileURLWithPath: modelPath).deletingPathExtension().lastPathComponent
    }
}
