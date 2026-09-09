// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OhMyFriend",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OhMyFriend", targets: ["OhMyFriend"])
    ],
    targets: [
        .executableTarget(
            name: "OhMyFriend",
            path: "Sources/OhMyFriend"
        )
    ]
)
