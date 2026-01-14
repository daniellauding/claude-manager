// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeManager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClaudeManager", targets: ["ClaudeManager"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeManager",
            path: "Sources"
        )
    ]
)
