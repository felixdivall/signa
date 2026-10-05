// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Signa",
    platforms: [.macOS(.v14)],
    targets: [
        // Everything that is not a view: models, storage, icon engine, monitoring.
        .target(name: "SignaCore"),
        // The app shell and SwiftUI interface.
        .executableTarget(name: "Signa", dependencies: ["SignaCore"]),
        .testTarget(name: "SignaCoreTests", dependencies: ["SignaCore"]),
    ]
)
