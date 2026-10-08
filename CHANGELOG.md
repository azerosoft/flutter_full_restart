# Changelog

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
