// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_full_restart",
    platforms: [
        .macOS("10.14")
    ],
    products: [
        .library(name: "flutter-full-restart", targets: ["flutter_full_restart"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_full_restart",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
