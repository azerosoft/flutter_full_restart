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

`flutter_full_restart` restarts your app the way a user would by closing and reopening it, or rebuilds just the UI in place.

```dart
await FullRestart.restart();                     // kill the process and cold-start the app
await FullRestart.restart(type: RestartType.ui); // rebuild the UI in place
```

<p align="center">
  <img src="https://raw.githubusercontent.com/azerosoft/flutter_full_restart/main/.github/assets/demo-ios.webp" alt="UI restart and full restart on iOS" width="300">
  <img src="https://raw.githubusercontent.com/azerosoft/flutter_full_restart/main/.github/assets/demo-android.webp" alt="UI restart and full restart on Android" width="300">
</p>

<p align="center"><sub>UI restart and full restart in the example app on iOS and Android.</sub></p>

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
- [Tested with](#tested-with)
- [Contributing](#contributing)
- [About Azerosoft](#about-azerosoft)

## Features

- **Full restart.** Kills the process and cold-starts the app, exactly like closing and reopening it. On iOS it starts a new Flutter engine instead, unless you [opt in to a process restart](#ios-restart-the-whole-process-optional).
- **UI restart.** Keeps the process and rebuilds the whole widget tree from scratch, for example after a language or theme change.
- **Every platform.** Android, iOS, macOS, Web (including WebAssembly), Windows and Linux.
- **No setup.** Add the package and call it. No platform needs native code or manifest changes.
- **Swift Package Manager ready.** iOS and macOS work with Swift Package Manager and CocoaPods, privacy manifest included.
- **Never throws.** Every call returns `true` or `false`, so a failed restart never crashes your app.

## Platform support

|                       | Android | iOS | macOS | Web | Windows | Linux |
|-----------------------|:-------:|:---:|:-----:|:---:|:-------:|:-----:|
| Full restart          | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| UI restart            | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Swift Package Manager | – | ✅ | ✅ | – | – | – |

On the web, both restart types reload the page.

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

No platform needs any setup. On iOS you can register a URL scheme so that a full restart restarts the native process too, see [iOS: restart the whole process](#ios-restart-the-whole-process-optional).

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

### Read links with app_links or a similar package

On iOS, when the app registers the [URL scheme](#ios-restart-the-whole-process-optional), a full restart reopens the app through an empty link (`<bundle id>://`). Flutter's own deep linking never sees it, but packages that read links themselves, such as [`app_links`](https://pub.dev/packages/app_links), report it after the restart. Skip it with `FullRestart.isRestartLink`:

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
| `FullRestart.restart({type})` | Restarts the app. Returns `true` when the platform accepted the request. |
| `FullRestart.isRestartLink(uri)` | Whether a link is the one a full restart reopens the app with on iOS. Use it to skip that link when you read links yourself. |
| `FullRestart.ensureInitialized({onUiRestart})` | Starts listening for UI restarts. Called for you by `FullRestartScope` and `restart`. |
| `FullRestartScope(child: ...)` | Rebuilds its subtree from scratch on a UI restart. |
| `RestartType.full` / `RestartType.ui` | Kill and relaunch the process, or rebuild the UI in place. |

Options of `restart`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `type` | `RestartType.full` | `full` kills the process and cold-starts the app. `ui` rebuilds the UI inside the running process. |

The full API reference is on [pub.dev](https://pub.dev/documentation/flutter_full_restart/latest/).

## How it works

### `RestartType.full`

- **Android:** starts the launcher activity in a new task and exits the process.
- **iOS:** starts a new Flutter engine in the running process, so `main()` runs again with fresh Dart state. If the app registers its bundle identifier as a URL scheme, it instead reopens the app through that scheme and exits, like the other platforms. See [iOS: restart the whole process](#ios-restart-the-whole-process-optional).
- **macOS:** launches a new instance of the app bundle and exits.
- **Windows and Linux:** start a new instance of the executable with the same arguments and exit.
- **Web:** reloads the page.

### `RestartType.ui`

- **Android:** recreates the Flutter activity, which boots a new Flutter engine, so `main()` runs again.
- **iOS:** replaces the root `FlutterViewController` on the same engine and rebuilds the widget tree via `FullRestartScope`.
- **macOS, Windows and Linux:** keep the window and the engine and rebuild the widget tree via `FullRestartScope`.
- **Web:** reloads the page.

## Platform setup

### iOS: restart the whole process (optional)

iOS works without any setup. There, a full restart starts a new Flutter engine inside the running process: `main()` runs again, all Dart state is gone and every plugin is registered again.

iOS lets an app reopen itself only through its own URL scheme. If the native side should start over too, register your bundle identifier as a URL scheme in `ios/Runner/Info.plist`. A full restart then reopens the app through that scheme and exits the old process, like on the other platforms:

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

The plugin keeps the URL it reopens the app with away from Flutter's deep linking, so your router never sees it. If you read links with a package such as `app_links`, skip it as shown in [Read links with app_links](#read-links-with-app_links-or-a-similar-package). Your app's other URLs are not affected.

| Full restart on iOS | Without the URL scheme (default) | With the URL scheme |
|---------------------|----------------------------------|---------------------|
| What starts over | The Flutter engine, in the same process | The whole process |
| Dart state and plugins | Reset | Reset |
| Native state (Swift and Objective-C objects, native SDKs) | Kept | Reset |
| Your code in `AppDelegate` (for example your own platform channels) | Not run again | Runs again |
| Downloaded [Shorebird](https://shorebird.dev) patches | Not applied | Applied |
| What the user sees | The new UI fades in | The home screen for a moment, then the app opens again |

Register the URL scheme if your app keeps state on the native side that must start over, sets up its own platform channels in `AppDelegate`, or uses Shorebird code push: Shorebird applies a patch only when the process restarts. On Android, a full restart always restarts the process, so patches are applied there without any setup.

Apple discourages apps from quitting on their own. With the URL scheme, trigger a full restart only in response to a user action, such as switching the language or the backend environment.

### Swift Package Manager

Nothing to configure. When Swift Package Manager is enabled (the default in recent Flutter versions), Flutter uses the plugin's `Package.swift` on iOS and macOS. Otherwise it falls back to CocoaPods. Both include a privacy manifest (`PrivacyInfo.xcprivacy`).

### Android

The Android side is written in Java on purpose: it builds with any Android Gradle Plugin from 7.x to 9.x, with or without the Kotlin Gradle Plugin. No setup is needed.

## Troubleshooting

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

The [example app](https://github.com/azerosoft/flutter_full_restart/tree/main/example) shows what each kind of restart resets: the time the Dart session started and the time the screen was built. The animations at the top of this page were recorded with it. It runs on all six platforms.

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
