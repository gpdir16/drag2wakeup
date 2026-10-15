// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "drag2wakeup",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "drag2wakeup", path: "Sources/drag2wakeup")
    ]
)
