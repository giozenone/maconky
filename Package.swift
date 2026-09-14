// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Overwatch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Overwatch", targets: ["Overwatch"])
    ],
    targets: [
        .executableTarget(
            name: "Overwatch",
            path: "Sources/Overwatch"
        )
    ]
)
