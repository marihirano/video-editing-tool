// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "VideoEditingTool",
    platforms: [.macOS(.v14)],
    targets: [
        // Everything that isn't UI: project model, renderer, playback, export.
        .target(name: "EditorCore"),
        // The Mac app itself (SwiftUI windows and menus).
        .executableTarget(name: "VideoEditingTool", dependencies: ["EditorCore"]),
        // Self-checks, run with `swift run CoreChecks`. (XCTest and Swift Testing
        // don't run without Xcode, so this is a plain program.)
        .executableTarget(name: "CoreChecks", dependencies: ["EditorCore"]),
    ]
)
