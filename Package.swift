// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Knobs",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Knobs", targets: ["Knobs"]),
        .executable(name: "knobs-helper", targets: ["KnobsHelper"]),
        .executable(name: "smcprobe", targets: ["smcprobe"]),
    ],
    targets: [
        .target(name: "CSMC", path: "Sources/CSMC"),
        .target(name: "KnobsKit", dependencies: ["CSMC"], path: "Sources/KnobsKit"),
        .executableTarget(name: "KnobsHelper", dependencies: ["KnobsKit"], path: "Sources/KnobsHelper"),
        .executableTarget(name: "Knobs", dependencies: ["KnobsKit"], path: "Sources/Knobs"),
        .executableTarget(name: "smcprobe", dependencies: ["CSMC", "KnobsKit"], path: "Sources/smcprobe"),
    ]
)
