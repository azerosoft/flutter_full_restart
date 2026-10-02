<p align="center">
  <a href="https://azerosoft.com">
    <img src="https://raw.githubusercontent.com/azerosoft/flutter_full_restart/main/.github/assets/banner.png" alt="flutter_full_restart by Azerosoft" width="100%">
  </a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_full_restart"><img src="https://img.shields.io/pub/v/flutter_full_restart.svg?label=pub&color=2C55F0" alt="pub version"></a>
  <a href="https://pub.dev/packages/flutter_full_restart/score"><img src="https://img.shields.io/pub/points/flutter_full_restart?color=2C55F0" alt="pub points"></a>
  <a href="https://pub.dev/packages/flutter_full_restart/score"><img src="https://img.shields.io/pub/likes/flutter_full_restart?color=2C55F0" alt="pub likes"></a>
  <a href="https://github.com/azerosoft/flutter_full_restart/actions/workflows/ci.yml"><img src="https://github.com/azerosoft/flutter_full_restart/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/azerosoft/flutter_full_restart/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-2C55F0.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/publishers/azerosoft.com/packages"><img src="https://img.shields.io/badge/publisher-azerosoft.com-2C55F0.svg" alt="Publisher: azerosoft.com"></a>
</p>

<p align="center">
  Restart a Flutter app from Dart, on every platform.<br>
  Built and maintained by <a href="https://azerosoft.com"><b>Azerosoft</b></a>.
</p>

---

`flutter_full_restart` restarts your app the way a user would by closing and reopening it, or rebuilds just the UI in place. It can wipe app data on the way, which makes logout, account switching and "reset app" flows a single call.

```dart
await FullRestart.restart(wipeData: true, keepPreferences: true);
```

<p align="center">
  <img src="https://raw.githubusercontent.com/azerosoft/flutter_full_restart/main/.github/assets/demo-ios.webp" alt="UI restart, full restart and data wipe on iOS" width="300">
  <img src="https://raw.githubusercontent.com/azerosoft/flutter_full_restart/main/.github/assets/demo-android.webp" alt="UI restart, full restart and data wipe on Android" width="300">
</p>

<p align="center"><sub>UI restart, full restart and data wipe in the example app on iOS and Android.</sub></p>

## Contents

- [Features](#features)
- [Platform support](#platform-support)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Usage](#usage)
- [API overview](#api-overview)
- [How it works](#how-it-works)
- [Platform setup](#platform-setup)
- [Troubleshooting](#troubleshooting)
- [Example app](#example-app)
- [Contributing](#contributing)
- [About Azerosoft](#about-azerosoft)

## Features

- **Full restart.** Kills the process and cold-starts the app, exactly like closing and reopening it.
- **UI restart.** Keeps the process and rebuilds the whole widget tree from scratch, for example after a language or theme change.
- **Safe data wipe.** Deletes the app's files, caches, databases, preferences, keychain items and cookies, with switches to keep preferences or secure storage. Folders shared with the user or other apps are never touched.
- **Confirmation dialog.** One call that asks the user before restarting.
- **Every platform.** Android, iOS, macOS, Web (including WebAssembly), Windows and Linux.
- **Swift Package Manager ready.** iOS and macOS work with Swift Package Manager and CocoaPods, privacy manifest included.
- **Never throws.** Every call returns `true` or `false`, so a failed restart never crashes your app.

## Platform support

|                       | Android | iOS | macOS | Web | Windows | Linux |
|-----------------------|:-------:|:---:|:-----:|:---:|:-------:|:-----:|
| Full restart          | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| UI restart            | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Data wipe             | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Swift Package Manager | – | ✅ | ✅ | – | – | – |

On the web, both restart types reload the page, and the data wipe clears browser storage.

## Requirements

| | Minimum |
|-|---------|
| Flutter / Dart | 3.22 / 3.4 |
| Android | API 21, any Android Gradle Plugin from 7.x to 9.x |
| iOS | 12.0 |
| macOS | 10.14 |
| Windows | Windows 10, x64 |
| Linux | GTK 3, x64 or arm64 |

## Installation

```sh
flutter pub add flutter_full_restart
```

On iOS, add the URL scheme described in [iOS setup](#ios-setup). The other platforms need no setup.

## Quick start

Wrap your app in `FullRestartScope` so a UI restart can rebuild everything:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_full_restart/flutter_full_restart.dart';

void main() {
  runApp(const FullRestartScope(child: MyApp()));
}
```

Then restart from anywhere:

```dart
await FullRestart.restart();
```

## Usage

### Full restart

Kills the process and launches the app again. Use it after installing an update, changing the backend environment or anything else that needs a clean start.

```dart
await FullRestart.restart();
```

### UI restart

Keeps the process and rebuilds the Flutter UI from scratch. Every `State` below `FullRestartScope` is disposed and created again.

```dart
await FullRestart.restart(type: RestartType.ui);
```

### Restart with a data wipe

Typical for logout: clear the user's data, keep app-wide settings.

```dart
await FullRestart.restart(
  wipeData: true,
  keepPreferences: true,    // keep SharedPreferences / UserDefaults
  keepSecureStorage: false, // clear tokens in the keychain
);
```

See [What `wipeData` deletes](#what-wipedata-deletes) for the exact folders on each platform.

### Ask the user first

```dart
final bool restarted = await FullRestart.confirmAndRestart(
  context,
  title: 'Update installed',
  message: 'Restart now to finish updating?',
  confirmLabel: 'Restart',
  cancelLabel: 'Later',
);
```

### Handle UI restarts yourself

If you would rather not wrap the app in `FullRestartScope`, register a callback. It runs instead of the automatic rebuild:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FullRestart.ensureInitialized(onUiRestart: () {
    // For example: reset your state management and go to the first screen.
  });
  runApp(const MyApp());
}
```

## API overview

| API | Description |
|-----|-------------|
| `FullRestart.restart({type, wipeData, keepPreferences, keepSecureStorage})` | Restarts the app. Returns `true` when the platform accepted the request. |
| `FullRestart.confirmAndRestart(context, {title, message, confirmLabel, cancelLabel, ...})` | Shows an `AlertDialog` and restarts only if the user confirms. Returns `false` when they cancel. |
| `FullRestart.ensureInitialized({onUiRestart})` | Starts listening for UI restarts. Called for you by `FullRestartScope` and `restart`. |
| `FullRestartScope(child: ...)` | Rebuilds its subtree from scratch on a UI restart. |
| `RestartType.full` / `RestartType.ui` | Kill and relaunch the process, or rebuild the UI in place. |

Options of `restart` and `confirmAndRestart`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `type` | `RestartType.full` | `full` kills the process and cold-starts the app. `ui` rebuilds the UI inside the running process. |
| `wipeData` | `false` | Delete app data before restarting. |
| `keepPreferences` | `false` | With `wipeData`: keep SharedPreferences, UserDefaults and localStorage. |
| `keepSecureStorage` | `false` | With `wipeData`: keep the keychain on iOS and macOS, and sessionStorage and cookies on the web. |

The full API reference is on [pub.dev](https://pub.dev/documentation/flutter_full_restart/latest/).

## How it works

### `RestartType.full`

- **Android:** starts the launcher activity in a new task and exits the process.
- **iOS:** opens the app's own URL scheme, moves the app to the background and exits.
- **macOS:** launches a new instance of the app bundle and exits.
- **Windows and Linux:** start a new instance of the executable with the same arguments and exit.
- **Web:** reloads the page.

### `RestartType.ui`

- **Android:** recreates the Flutter activity, which boots a new Flutter engine, so `main()` runs again.
- **iOS:** replaces the root `FlutterViewController` on the same engine and rebuilds the widget tree via `FullRestartScope`.
- **macOS, Windows and Linux:** keep the window and the engine and rebuild the widget tree via `FullRestartScope`.
- **Web:** reloads the page.

### What `wipeData` deletes

| | Always | Unless `keepPreferences` | Unless `keepSecureStorage` |
|-|--------|--------------------------|----------------------------|
| **Android** | cache directory | files directory, `shared_prefs`, all databases | – ¹ |
| **iOS** | Documents, Caches, tmp, cookies, URL cache | UserDefaults | keychain items |
| **macOS** | `~/Library/Caches/<bundle id>`, cookies, URL cache; inside the App Sandbox also Documents, Caches and tmp ² | UserDefaults, `~/Library/Application Support/<bundle id>` | the app's items in the data protection keychain ² |
| **Web** | Cache Storage | localStorage | sessionStorage, cookies |
| **Windows** | app cache folder `%LOCALAPPDATA%\<company>\<product>` | app support folder `%APPDATA%\<company>\<product>` (where `shared_preferences` keeps its file) | – ³ |
| **Linux** | app cache folder `~/.cache/<app id>` | app data folder `~/.local/share/<app id>` (where `shared_preferences` keeps its file) | – ⁴ |

IndexedDB on the web is cleared only when neither flag is set.

¹ Android has no keychain. Packages such as `flutter_secure_storage` keep their data in shared preferences, so they are wiped unless `keepPreferences` is set. When `keepPreferences` is set, databases whose name contains `keychain` are kept.

² Outside the App Sandbox, Documents and the temporary folder belong to the user and to other apps, so only the `<bundle id>` folders are cleared. The legacy file-based macOS keychain is shared by all apps and never touched. The system may recreate an empty URL cache database in the cache folder right after the wipe; it contains no data.

³ The Windows Credential Manager is shared by every app of the user, so it is never touched. Neither are shared folders such as Documents or `%TEMP%`. `<company>\<product>` is the same folder `path_provider` returns, taken from the executable's version info.

⁴ The Secret Service keyring used by `flutter_secure_storage` on Linux is shared by every app of the user, so it is never touched. Neither are shared folders such as Documents or `/tmp`. `<app id>` is the folder `path_provider` returns (the GTK application id, or the executable name for older apps), and `$XDG_CACHE_HOME` / `$XDG_DATA_HOME` are respected.

## Platform setup

### iOS setup

A full restart reopens the app through a URL scheme equal to its bundle identifier. Add this to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    </array>
  </dict>
</array>
```

Without it, a full restart returns `false` and logs `URL_SCHEME_ERROR`. UI restarts and data wipes work without it.

Apple discourages apps from quitting on their own. Trigger a full restart only in response to a user action, such as switching language or logging out.

### Swift Package Manager

Nothing to configure. When Swift Package Manager is enabled (the default in recent Flutter versions), Flutter uses the plugin's `Package.swift` on iOS and macOS. Otherwise it falls back to CocoaPods. Both include a privacy manifest (`PrivacyInfo.xcprivacy`).

### Android

The Android side is written in Java on purpose: it builds with any Android Gradle Plugin from 7.x to 9.x, with or without the Kotlin Gradle Plugin. No setup is needed.

## Troubleshooting

<details>
<summary><b>A back button appears after a full restart on iOS</b></summary>

Flutter's deep linking (on by default since Flutter 3.27) treats the relaunch URL as a navigation to `/` and pushes a second home route. If your app does not use deep links, turn it off in `Info.plist`:

```xml
<key>FlutterDeepLinkingEnabled</key>
<false/>
```

If you do use deep links, make your router treat `/` as "go to the first screen" rather than "push a screen".
</details>

<details>
<summary><b>"The iOS deployment target is set to 12.0, but the range of supported deployment target versions is 15.0 to …"</b></summary>

Recent Xcode versions reject old deployment targets. Newer Flutter versions fix pod targets automatically. On older Flutter versions, raise every pod's target in `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

For macOS, do the same in `macos/Podfile` with `flutter_additional_macos_build_settings(target)` and `MACOSX_DEPLOYMENT_TARGET`, using the minimum version from the error message.
</details>

<details>
<summary><b>My Windows or Linux app allows only one instance</b></summary>

The new instance is started just before the old one exits. If your app enforces a single instance (for example with a named mutex on Windows, or a GTK application without `G_APPLICATION_NON_UNIQUE` on Linux), release it before calling `FullRestart.restart()` or let the check tolerate an instance that is shutting down. Apps created with `flutter create` allow multiple instances, so they are not affected.
</details>

<details>
<summary><b>A UI restart on iOS or a desktop platform does not reset my state</b></summary>

Wrap the app in `FullRestartScope`, or pass `onUiRestart` to `FullRestart.ensureInitialized`. State kept outside the widget tree (globals, singletons) is not reset by a UI restart. Use a full restart for that.
</details>

## Example app

The [example app](https://github.com/azerosoft/flutter_full_restart/tree/main/example) shows what survives each kind of restart: the Dart session start time, a counter kept in memory and a counter saved to disk. The animations at the top of this page were recorded with it. It runs on all six platforms.

```sh
cd example
flutter run
```

## Tested with

| Platform | Tested with |
|----------|-------------|
| Flutter | 3.22.3 and 3.47 |
| Android | AGP 7.3, 8.11 and 9.1 |
| iOS | Xcode 27, Swift Package Manager and CocoaPods |
| macOS | macOS 27, Swift Package Manager and CocoaPods, with and without App Sandbox |
| Windows | Windows Server 2025, Visual Studio 2022 Build Tools |
| Linux | Ubuntu 24.04 (arm64) |

Every push runs analysis, tests and example builds for all platforms on [GitHub Actions](https://github.com/azerosoft/flutter_full_restart/actions/workflows/ci.yml).

## Contributing

Bug reports, ideas and pull requests are welcome. Please read the [contributing guide](https://github.com/azerosoft/flutter_full_restart/blob/main/CONTRIBUTING.md) and our [code of conduct](https://github.com/azerosoft/flutter_full_restart/blob/main/CODE_OF_CONDUCT.md) first.

- [Report a bug](https://github.com/azerosoft/flutter_full_restart/issues/new?template=bug_report.yml)
- [Request a feature](https://github.com/azerosoft/flutter_full_restart/issues/new?template=feature_request.yml)
- [Report a security issue](https://github.com/azerosoft/flutter_full_restart/blob/main/SECURITY.md) (privately, please)

## About Azerosoft

<a href="https://azerosoft.com">
  <img src="https://raw.githubusercontent.com/azerosoft/flutter_full_restart/main/.github/assets/made-by-azerosoft.png" alt="Azerosoft" width="320">
</a>

[Azerosoft](https://azerosoft.com) is a design and development studio from Baku, Azerbaijan. We design interfaces and build websites, web and mobile apps, backends, CRM systems and 2D games. We use our packages in our own projects and maintain them for everyone.

- Website: [azerosoft.com](https://azerosoft.com)
- All our packages: [pub.dev/publishers/azerosoft.com](https://pub.dev/publishers/azerosoft.com/packages)
- GitHub: [github.com/azerosoft](https://github.com/azerosoft)
- Email: [hello@azerosoft.com](mailto:hello@azerosoft.com)

Building something with Flutter? [Tell us about your project](https://azerosoft.com).

## License

Released under the [MIT License](https://github.com/azerosoft/flutter_full_restart/blob/main/LICENSE).
