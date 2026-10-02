# Changelog

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
