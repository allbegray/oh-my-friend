// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "OhMineFriend",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OhMineFriend",
            targets: ["OhMineFriend"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OhMineFriend",
            path: "Sources/OhMineFriend"
        )
    ]
)
