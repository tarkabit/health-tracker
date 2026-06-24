// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HealthTracker",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .executableTarget(
            name: "HealthTracker",
            dependencies: ["Yams"],
            path: "Sources/HealthTracker"
        )
    ]
)
