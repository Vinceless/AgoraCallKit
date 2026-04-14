// swift-tools-version: 5.0

import PackageDescription

let package = Package(
    name: "AgoraCallKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "AgoraCallKit",
            targets: ["AgoraCallKit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/AgoraIO/AgoraRtcEngine_iOS.git",
            .upToNextMajor(from: "4.0.0")
        )
    ],
    targets: [
        .target(
            name: "AgoraCallKit",
            dependencies: [
                .product(name: "AgoraRtcKit", package: "AgoraRtcEngine_iOS")
            ],
            path: "Sources",
            exclude: ["Test"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
