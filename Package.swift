// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TwitchKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "TwitchKit", targets: ["TwitchKit"]),
        .executable(name: "TwitchKitSmokeTest", targets: ["TwitchKitSmokeTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "TwitchKit",
            path: "Sources/TwitchKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "TwitchKitSmokeTest",
            dependencies: ["TwitchKit"],
            path: "Examples/SmokeTest",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TwitchKitTests",
            dependencies: ["TwitchKit"],
            path: "Tests/TwitchKitTests"
        ),
    ]
)
