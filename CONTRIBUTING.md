# Contributing to flutter_full_restart

Thanks for taking the time to contribute! `flutter_full_restart` is built and maintained by [Azerosoft](https://azerosoft.com), and we welcome bug reports, ideas and pull requests from everyone.

By participating in this project you agree to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Report a bug.** Open a [bug report](https://github.com/azerosoft/flutter_full_restart/issues/new?template=bug_report.yml). Include the platform, the Flutter version (`flutter --version`) and the smallest code that reproduces the problem.
- **Suggest a feature.** Open a [feature request](https://github.com/azerosoft/flutter_full_restart/issues/new?template=feature_request.yml) and describe the problem you want to solve.
- **Send a pull request.** For anything larger than a small fix, please open an issue first so we can agree on the approach before you spend time on it.
- **Report a security issue privately.** See [SECURITY.md](SECURITY.md). Please don't open public issues for vulnerabilities.

## Development setup

You need Flutter 3.22 or newer.

```sh
git clone https://github.com/azerosoft/flutter_full_restart.git
cd flutter_full_restart
flutter pub get
```

Run the checks that CI runs:

```sh
dart format --output=none --set-exit-if-changed lib test example/lib example/test
flutter analyze
flutter test
(cd example && flutter test)
```

CI also builds the example for every platform, once with Flutter 3.22.3 and once with the latest stable release. The example's platform folders come from the latest Flutter template, so the 3.22.3 jobs first recreate them with `.github/scripts/recreate_example_platform.sh`.

Try your change in the example app on the platforms it affects:

```sh
cd example
flutter run -d <device>
```

## Where things live

| Path | What it contains |
|------|------------------|
| `lib/` | Public Dart API (`FullRestart`, `FullRestartScope`, `RestartType`) and the web implementation |
| `lib/src/protocol.dart` | Channel, method and argument names shared with the native code |
| `android/` | Android implementation (Java) |
| `ios/`, `macos/` | iOS and macOS implementations (Swift, Swift Package Manager and CocoaPods) |
| `windows/`, `linux/` | Windows and Linux implementations (C++) with their unit tests in `test/` |
| `example/` | Demo app used for manual testing and screenshots |

When you change a channel, method or argument name, update `lib/src/protocol.dart` and every native implementation together.

The Windows and Linux C++ unit tests are built together with the example app:

```sh
cd example
flutter build windows --debug   # then run build\windows\x64\plugins\flutter_full_restart\Debug\flutter_full_restart_test.exe
flutter build linux --debug     # then run build/linux/<arch>/debug/plugins/flutter_full_restart/flutter_full_restart_test
```

## Guidelines

- Keep behaviour the same on every platform unless a platform cannot support it, and document any difference in the README.
- Never delete data outside the app's own folders. Shared locations (Documents, temp folders, shared keychains) must stay untouched.
- Add or update tests for every change in behaviour.
- Keep `flutter analyze` free of issues and the code formatted with `dart format`.
- Update `README.md` for user-facing changes. `CHANGELOG.md` is written from the commit messages when a version is released, so don't edit it by hand.
- Write commit messages in the [Conventional Commits](https://www.conventionalcommits.org) style, for example `fix(android): keep databases when keepPreferences is set`. They decide the next version, see [Releasing](#releasing).

## Pull request checklist

- [ ] The change is covered by tests.
- [ ] `flutter analyze` reports no issues and the code is formatted.
- [ ] README is updated where needed.
- [ ] The change was tried on the platforms it affects.

## Releasing

Releases are made with [release-please](https://github.com/googleapis/release-please). The commit messages since the last release decide the next version:

| Commit message | Version after 1.2.3 |
|----------------|---------------------|
| `fix: ...` | 1.2.4 |
| `feat: ...` | 1.3.0 |
| `feat!: ...`, or a `BREAKING CHANGE:` footer | 2.0.0 |
| `docs:`, `ci:`, `test:`, `refactor:`, `chore:` | no new version |

After CI passes on `main`, release-please opens a release pull request, or updates the one that is already open, with the new version in `pubspec.yaml` and the new `CHANGELOG.md` entry. Nothing is released until that pull request is merged. Merging it creates the `vX.Y.Z` tag and the GitHub release, and the package is then published to pub.dev.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE) of this project.
