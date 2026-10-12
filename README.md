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

`flutter_full_restart` restarts your app the way a user would by closing and reopening it.

```dart
await FullRestart.restart(); // kill the process and cold-start the app
```

<p align="center">
  <img src="https://raw.githubusercontent.com/azerosoft/flutter_full_restart/main/.github/assets/demo-ios.webp" alt="Full restart on iOS" width="300">
  <img src="https://raw.githubusercontent.com/azerosoft/flutter_full_restart/main/.github/assets/demo-android.webp" alt="Full restart on Android" width="300">
</p>

<p align="center"><sub>The example app on iOS and Android.</sub></p>

## Contents

- [Features](#features)
- [Platform support](#platform-support)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Read links with app_links](#read-links-with-app_links-or-a-similar-package)
- [API overview](#api-overview)
- [How it works](#how-it-works)
- [Platform setup](#platform-setup)
- [Troubleshooting](#troubleshooting)
- [Example app](#example-app)
- [Tested with](#tested-with)
- [Contributing](#contributing)
- [About Azerosoft](#about-azerosoft)

## Features

- **Full restart.** Kills the process and cold-starts the app, exactly like closing and reopening it. Dart state, plugins and native state all start over.
- **Every platform.** Android, iOS, macOS, Web (including WebAssembly), Windows and Linux.
- **Almost no setup.** Only iOS needs one entry in `Info.plist`, see [iOS setup](#ios-setup). Without it a restart does nothing and a yellow warning in the debug console tells you what to add.
- **Swift Package Manager ready.** iOS and macOS work with Swift Package Manager and CocoaPods, privacy manifest included.
- **Never throws.** Every call returns `true` or `false`, so a failed restart never crashes your app. The reason for a `false` is printed to the debug console in yellow.

## Platform support

Works on Android, iOS, macOS, Web, Windows and Linux.

- On iOS, a full restart needs the URL scheme described in [iOS setup](#ios-setup). No other platform needs any setup.
- On iOS and macOS, the plugin works with both Swift Package Manager and CocoaPods.
- On the web, a full restart reloads the page.

## Requirements

| | Minimum |
|-|---------|
| Dart | 3.4 |
| Flutter | 3.22 |
| Android | API 21, any Android Gradle Plugin from 7.x to 9.x |
| iOS | 12.0 |
| macOS | 10.14 |
| Windows | Windows 10, x64 |
| Linux | GTK 3, x64 or arm64 |

## Installation

```sh
flutter pub add flutter_full_restart
```

On iOS, register the URL scheme described in [iOS setup](#ios-setup). No other platform needs any setup.

## Usage

Restart from anywhere:

```dart
import 'package:flutter_full_restart/flutter_full_restart.dart';

await FullRestart.restart();
```

It kills the process and launches the app again. Use it after installing an update, switching the language or the backend environment, or anything else that needs a clean start.

When the restart cannot be started, `restart()` returns `false`, nothing happens in the app, and the reason is printed to the debug console in yellow:

```text
[flutter_full_restart] Full restart is not available on iOS: Info.plist does not register the bundle identifier as a URL scheme.
```

## Read links with app_links or a similar package

On iOS, a full restart reopens the app through an empty link (`<bundle id>://`). Flutter's own deep linking never sees it, but packages that read links themselves, such as [`app_links`](https://pub.dev/packages/app_links), report it after the restart. Skip it with `FullRestart.isRestartLink`:

```dart
AppLinks().uriLinkStream.listen((Uri uri) {
  if (FullRestart.isRestartLink(uri)) return; // the link of a full restart
  router.go(uri.path); // https://example.com/product/42 -> /product/42
});
```

Your other links, with or without the app running, arrive as usual.

## API overview

| API | Description |
|-----|-------------|
| `FullRestart.restart()` | Kills the process and cold-starts the app. Returns `true` when the platform accepted the request. |
| `FullRestart.isRestartLink(uri)` | Whether a link is the one a full restart reopens the app with on iOS. Use it to skip that link when you read links yourself. |

The full API reference is on [pub.dev](https://pub.dev/documentation/flutter_full_restart/latest/).

## How it works

- **Android:** starts the launcher activity in a new task and exits the process.
- **iOS:** reopens the app through its own URL scheme (`<bundle id>://`) and exits the process. Without the [URL scheme](#ios-setup) nothing happens and a yellow warning is printed.
- **macOS:** launches a new instance of the app bundle and exits.
- **Windows and Linux:** start a new instance of the executable with the same arguments and exit. The new instance waits until the old one has exited, so apps that allow only one instance restart too.
- **Web:** reloads the page.

## Platform setup

### iOS setup

iOS lets an app reopen itself only through its own URL scheme, so register your bundle identifier as a URL scheme in `ios/Runner/Info.plist`:

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

A full restart then reopens the app through that scheme and exits the old process, like on the other platforms. The user sees the home screen for a moment, then the app opens again.

Without this entry, `FullRestart.restart()` returns `false`, the app keeps running as it is, and the debug console shows a yellow warning with the snippet above.

The plugin keeps the URL it reopens the app with away from Flutter's deep linking, so your router never sees it. If you read links with a package such as `app_links`, skip it as shown in [Read links with app_links](#read-links-with-app_links-or-a-similar-package). Your app's other URLs are not affected.

Because the whole process restarts, your code in `AppDelegate` runs again and downloaded [Shorebird](https://shorebird.dev) patches are applied.

Apple discourages apps from quitting on their own. Trigger a full restart only in response to a user action, such as switching the language or the backend environment.

### Swift Package Manager

Nothing to configure. When Swift Package Manager is enabled (the default in recent Flutter versions), Flutter uses the plugin's `Package.swift` on iOS and macOS. Otherwise it falls back to CocoaPods. Both include a privacy manifest (`PrivacyInfo.xcprivacy`).

### Android

The Android side is written in Java on purpose: it builds with any Android Gradle Plugin from 7.x to 9.x, with or without the Kotlin Gradle Plugin. No setup is needed, and downloaded Shorebird patches are applied after a restart.

## Troubleshooting

<details>
<summary><b>Nothing happens when I restart on iOS</b></summary>

Look for the yellow `[flutter_full_restart]` warning in the debug console. It means `Info.plist` does not register the bundle identifier as a URL scheme. Add the entry from [iOS setup](#ios-setup) and rebuild the app (a hot restart is not enough).
</details>

## Example app

The [example app](https://github.com/azerosoft/flutter_full_restart/tree/main/example) shows the time the Dart session started, which changes after every full restart. It runs on all six platforms.

```sh
cd example
flutter run
```

## Tested with

The minimum and maximum versions this package was tested with, as of October 2026. Versions in between were not all tested one by one, but they are expected to work as well. On every push, [GitHub Actions](https://github.com/azerosoft/flutter_full_restart/actions/workflows/ci.yml) runs the tests and builds the example for all platforms, once with Flutter 3.22.3 and once with the latest stable release.

### Flutter and Dart

| | Minimum | Maximum |
|-|--------|--------|
| Flutter | 3.22.3 | 3.47.6 |
| Dart | 3.4.4 | 3.13.5 |

### Android

| | Minimum | Maximum |
|-|--------|--------|
| Android Gradle Plugin | 7.3.0 | 9.1.0 |
| Gradle | 7.6.3 | 9.3.1 |
| Kotlin (app) | 1.7.10 | 2.4.0 |
| JDK | 17 | 17 |
| `compileSdk` | 34 | 36 |
| `minSdk` (app) | 21 | 24 |

### iOS

| | Minimum | Maximum |
|-|--------|--------|
| Xcode | 16.4 | 27.0 |
| iOS SDK | 18.5 | 27.0 |
| Deployment target | 12.0 | 15.0 |
| CocoaPods | 1.16.2 | 1.17.0 |
| Xcode with Swift Package Manager | 26.6 | 27.0 |

### macOS

| | Minimum | Maximum |
|-|--------|--------|
| macOS | 15.7 | 27.0 |
| Xcode | 16.4 | 27.0 |
| macOS SDK | 15.5 | 27.0 |
| Deployment target | 10.14 | 12.0 |
| CocoaPods | 1.16.2 | 1.17.0 |
| Xcode with Swift Package Manager | 26.6 | 27.0 |

### Windows

| | Minimum | Maximum |
|-|--------|--------|
| Windows | Server 2022 | Server 2025 |
| Visual Studio | 2022 (17.14) | 2026 (18.10) |
| CMake | 3.31.6 | 4.4.3 |

### Linux

| | Minimum | Maximum |
|-|--------|--------|
| Ubuntu | 24.04 | 24.04 |
| GTK | 3.24.41 | 3.24.41 |
| Clang | 18 | 18 |
| CMake | 3.31.6 | 3.31.6 |

### Web

| | Minimum | Maximum |
|-|--------|--------|
| Build | JavaScript and WebAssembly | JavaScript and WebAssembly |

### Tried by hand

The example app was also started on these systems and the restarts were tried by hand:

| Platform | System |
|----------|--------|
| Android | Android API 37.2 emulator (Pixel 10) |
| iOS | iOS 27.0 simulator (iPhone 17) |
| macOS | macOS 27.0, with and without App Sandbox |
| Windows | Windows Server 2025 |
| Linux | Ubuntu 24.04 (arm64) |
| Web | Chromium 152 (WebAssembly build) |

The Windows and Linux C++ unit tests also run on every push, on Windows Server 2022 and 2025 and on Ubuntu 24.04 (x64).

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
