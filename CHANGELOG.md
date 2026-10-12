# Changelog

## [3.0.0](https://github.com/azerosoft/flutter_full_restart/compare/v2.1.0...v3.0.0) (2026-10-12)


### ⚠ BREAKING CHANGES

* **ios:** On iOS a full restart now needs the bundle identifier registered as a URL scheme in Info.plist, see iOS setup in the README. Without it `FullRestart.restart()` restarts nothing, returns `false` and prints a yellow warning with the Info.plist entry to add. Before, it restarted only the Flutter engine.
* The UI restart is removed. `RestartType`, `FullRestartScope` and `FullRestart.ensureInitialized()` are gone, and `FullRestart.restart()` and `FullRestartPlatform.restart()` take no arguments. Call `FullRestart.restart()` and remove `FullRestartScope` from `runApp`.

### Features

* **ios:** require the bundle identifier as a URL scheme ([c9fef1a](https://github.com/azerosoft/flutter_full_restart/commit/c9fef1ae4a4c5aca36db0c4e708a7e1f574d2c77))
* remove the UI restart ([c9fef1a](https://github.com/azerosoft/flutter_full_restart/commit/c9fef1ae4a4c5aca36db0c4e708a7e1f574d2c77))


### Bug Fixes

* **android:** show the splash screen icon on a restart on Android 12 and later ([c9fef1a](https://github.com/azerosoft/flutter_full_restart/commit/c9fef1ae4a4c5aca36db0c4e708a7e1f574d2c77))
* **ios, macos:** build with CocoaPods on Xcode versions that no longer support iOS 12 or macOS 10.14 ([c9fef1a](https://github.com/azerosoft/flutter_full_restart/commit/c9fef1ae4a4c5aca36db0c4e708a7e1f574d2c77))
* **ios, macos:** depend on Flutter's FlutterFramework package with Swift Package Manager on Flutter 3.41 and later ([c9fef1a](https://github.com/azerosoft/flutter_full_restart/commit/c9fef1ae4a4c5aca36db0c4e708a7e1f574d2c77))
* **ios:** stop flashing the old screen before the launch screen on a restart ([c9fef1a](https://github.com/azerosoft/flutter_full_restart/commit/c9fef1ae4a4c5aca36db0c4e708a7e1f574d2c77))
* **windows, linux:** wait for the old instance to exit before starting the new one, so single-instance apps restart ([c9fef1a](https://github.com/azerosoft/flutter_full_restart/commit/c9fef1ae4a4c5aca36db0c4e708a7e1f574d2c77))

## [2.1.0](https://github.com/azerosoft/flutter_full_restart/compare/v2.0.0...v2.1.0) (2026-10-08)


### Features

* **ios:** need no setup for a full restart ([beb0bee](https://github.com/azerosoft/flutter_full_restart/commit/beb0bee6d32e5388933cb2075456f2a1c6661544))

## [2.0.0](https://github.com/azerosoft/flutter_full_restart/compare/v1.0.1...v2.0.0) (2026-10-07)


### ⚠ BREAKING CHANGES

* `FullRestart.restart()` no longer takes `wipeData`, `keepPreferences` or `keepSecureStorage`, and `FullRestart.confirmAndRestart()` is removed. Clear app data yourself before calling `restart()`, and show your own dialog first if you want the user to confirm. `FullRestartPlatform.restart()` now takes only `killProcess`.

### Features

* make the package restart-only ([5017c64](https://github.com/azerosoft/flutter_full_restart/commit/5017c642782293cf083fea7d5562145a277ea2cc))

## [1.0.1](https://github.com/azerosoft/flutter_full_restart/compare/v1.0.0...v1.0.1) (2026-10-02)


### Documentation

* list the tested Flutter, Dart and platform versions ([a2e08e3](https://github.com/azerosoft/flutter_full_restart/commit/a2e08e354b591c24fb70416096ec028dbdcb76ec))

## 1.0.0

Initial release.

* `FullRestart.restart()`: full process restart (`RestartType.full`) or UI-only restart (`RestartType.ui`).
* Optional data wipe with `wipeData`, `keepPreferences` and `keepSecureStorage`.
* `FullRestart.confirmAndRestart()`: asks the user with a dialog before restarting.
* `FullRestartScope`: rebuilds the whole widget tree on a UI restart.
* `FullRestart.ensureInitialized(onUiRestart: ...)` for custom UI-restart handling.
* iOS: Swift Package Manager and CocoaPods support, privacy manifest included.
* macOS: Swift Package Manager and CocoaPods support; relaunches the app bundle for a full restart and wipes only the app's own folders, also outside the App Sandbox.
* Android: Java implementation that builds with AGP 7.x to 9.x, no Kotlin Gradle Plugin required.
* Web: page reload with browser storage wipe, WebAssembly compatible.
* Windows: relaunches the executable for a full restart, rebuilds the widget tree for a UI restart, and wipes the app's own AppData folders.
* Linux: relaunches the executable for a full restart, rebuilds the widget tree for a UI restart, and wipes the app's own XDG cache and data folders.
* Supports Flutter 3.22+ / Dart 3.4+.
