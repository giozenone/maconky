// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Maconky",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Maconky", targets: ["Maconky"])
    ],
    targets: [
        .executableTarget(
            name: "Maconky",
            path: "Sources/Maconky"
        )
    ]
)
