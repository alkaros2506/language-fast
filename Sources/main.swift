import Cocoa

// Log resolved configuration at launch so issues are visible immediately.
// View with:  log stream --predicate 'subsystem == "com.local.WhisperDictation"' --level debug
let settings = Settings.shared
Log.file("Starting WhisperDictation")
Log.general.info("Starting WhisperDictation")
Log.general.info("  whisper-cli : \(settings.whisperPath, privacy: .public)  exists=\(FileManager.default.fileExists(atPath: settings.whisperPath))")
Log.general.info("  model       : \(settings.modelPath, privacy: .public)  exists=\(FileManager.default.fileExists(atPath: settings.modelPath))")
Log.general.info("  threads     : \(settings.threadCount)")
Log.general.info("  temp audio  : \(Config.tempAudioPath, privacy: .public)")
if let metal = Config.metalResourcesPath {
    Log.general.info("  metal res   : \(metal, privacy: .public)")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon

let delegate = AppDelegate()
app.delegate = delegate
app.run()
