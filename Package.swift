// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhisperDictation",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WhisperDictation",
            path: "Sources"
        )
    ]
)
