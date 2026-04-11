// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VibeCode",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VibeBridge", targets: ["VibeBridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "Shared",
            path: "Shared"
        ),
        .executableTarget(
            name: "VibeBridge",
            dependencies: ["Shared"],
            path: "VibeBridge"
        ),
    ]
)
