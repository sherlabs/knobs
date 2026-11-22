// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GlowBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "GlowBar", path: "Sources/GlowBar")
    ]
)
