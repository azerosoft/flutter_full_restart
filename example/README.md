# flutter_full_restart example

A small app by [Azerosoft](https://azerosoft.com) that shows what each kind of restart resets:

| Shows | Changes after |
|-------|---------------|
| **Dart session started** | a full restart, and a UI restart on Android (which boots a new Flutter engine) |
| **Screen built** | every restart |

## Run it

```sh
flutter run
```

It runs on Android, iOS, macOS, Web, Windows and Linux. The iOS project registers the optional URL scheme (see `ios/Runner/Info.plist`), so a full restart there restarts the whole process. Remove it to try the setup-free full restart, which starts a new Flutter engine instead.

## Learn more

- [Package documentation](https://pub.dev/packages/flutter_full_restart)
- [Source code and issues](https://github.com/azerosoft/flutter_full_restart)
