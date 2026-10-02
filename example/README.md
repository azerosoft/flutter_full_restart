# flutter_full_restart example

A small app by [Azerosoft](https://azerosoft.com) that shows what survives each kind of restart:

| Row | Changes after |
|-----|---------------|
| **Dart session started** | a full restart, and a UI restart on Android (which boots a new Flutter engine) |
| **This screen built** | every restart |
| **Taps kept in memory** | every restart |
| **Taps saved to disk** | nothing, unless **Wipe data** is on |

## Run it

```sh
flutter run
```

It runs on Android, iOS, macOS, Web, Windows and Linux. The iOS project already contains the URL scheme needed for a full restart (see `ios/Runner/Info.plist`).

## Learn more

- [Package documentation](https://pub.dev/packages/flutter_full_restart)
- [Source code and issues](https://github.com/azerosoft/flutter_full_restart)
