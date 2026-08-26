// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "secure-input-check",
    targets: [
        .executableTarget(
            name: "secure-input-check",
            path: "Sources/secure-input-check"
        )
    ]
)
