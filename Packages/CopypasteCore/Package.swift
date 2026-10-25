// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopypasteCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CopypasteCore", targets: ["CopypasteCore"]),
    ],
    targets: [
        .target(name: "CopypasteCore"),
        .testTarget(name: "CopypasteCoreTests", dependencies: ["CopypasteCore"]),
    ]
)
