// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OLEDGuard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "OLEDGuard",
            path: "Sources/OLEDGuard"
        ),
        .testTarget(
            name: "OLEDGuardTests",
            dependencies: ["OLEDGuard"]
        ),
    ]
)
