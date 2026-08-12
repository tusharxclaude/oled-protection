// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "eventtap-logger",
    targets: [
        .executableTarget(
            name: "eventtap-logger",
            path: "Sources/eventtap-logger"
        )
    ]
)
