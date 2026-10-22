// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlycutCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FlycutCore", targets: ["FlycutCore"]),
    ],
    targets: [
        .target(name: "FlycutCore"),
        .testTarget(name: "FlycutCoreTests", dependencies: ["FlycutCore"]),
    ]
)
