// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TwitchKit",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "TwitchKit", targets: ["TwitchKit"]),
    ],
    targets: [
        .target(
            name: "TwitchKit",
            path: "Sources/TwitchKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TwitchKitTests",
            dependencies: ["TwitchKit"],
            path: "Tests/TwitchKitTests"
        ),
    ]
)
