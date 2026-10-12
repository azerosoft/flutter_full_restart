// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// Flutter 3.41 and later generate a local "FlutterFramework" package next to
// this plugin when they build with Swift Package Manager, and expect plugins to
// depend on it. Older Flutter versions don't generate it, so depend on it only
// when it exists. CocoaPods builds don't read this file.
//
// Flutter links this plugin into its packages folder with a symlink, so the
// path is normalized before the check; otherwise ".." would follow the
// symlink and look next to the plugin's real folder instead.
let flutterFrameworkPath = "../FlutterFramework"
let hasFlutterFramework = FileManager.default.fileExists(
    atPath: URL(fileURLWithPath: Context.packageDirectory)
        .appendingPathComponent(flutterFrameworkPath)
        .appendingPathComponent("Package.swift")
        .standardized
        .path
)

let package = Package(
    name: "flutter_full_restart",
    platforms: [
        .macOS("10.14")
    ],
    products: [
        .library(name: "flutter-full-restart", targets: ["flutter_full_restart"])
    ],
    dependencies: hasFlutterFramework
        ? [.package(name: "FlutterFramework", path: flutterFrameworkPath)]
        : [],
    targets: [
        .target(
            name: "flutter_full_restart",
            dependencies: hasFlutterFramework
                ? [.product(name: "FlutterFramework", package: "FlutterFramework")]
                : [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
