import Cocoa

// Log resolved configuration at launch so issues are visible immediately.
// View with:  log stream --predicate 'subsystem == "com.local.WhisperDictation"' --level debug
Log.general.info("Starting WhisperDictation")
Log.general.info("  whisper-cli : \(Config.whisperPath, privacy: .public)  exists=\(FileManager.default.fileExists(atPath: Config.whisperPath))")
Log.general.info("  model       : \(Config.modelPath, privacy: .public)  exists=\(FileManager.default.fileExists(atPath: Config.modelPath))")
Log.general.info("  threads     : \(Config.threadCount)")
Log.general.info("  temp audio  : \(Config.tempAudioPath, privacy: .public)")
if let metal = Config.metalResourcesPath {
    Log.general.info("  metal res   : \(metal, privacy: .public)")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon

let delegate = AppDelegate()
app.delegate = delegate
app.run()
