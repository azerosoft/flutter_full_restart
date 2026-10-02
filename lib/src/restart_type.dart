// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

/// How deep a restart goes.
enum RestartType {
  /// Kills the app process and launches the app again, exactly like a cold
  /// start. Every isolate, plugin and native object is recreated.
  ///
  /// * Android: relaunches the launcher activity in a new task and exits the
  ///   process.
  /// * iOS: reopens the app through its own URL scheme and exits. The app
  ///   must register its bundle identifier as a URL scheme (see README).
  /// * macOS: launches a new instance of the app bundle and exits.
  /// * Web: reloads the page.
  /// * Windows and Linux: start a new instance of the executable with the
  ///   same arguments and exit.
  full,

  /// Keeps the process alive and rebuilds the Flutter UI from scratch.
  ///
  /// * Android: recreates the Flutter activity, which starts a fresh
  ///   Flutter engine.
  /// * iOS: swaps in a new `FlutterViewController` on the existing engine and
  ///   asks `FullRestartScope` to rebuild the widget tree.
  /// * macOS, Windows and Linux: keep the window and engine and ask
  ///   `FullRestartScope` to rebuild the widget tree.
  /// * Web: reloads the page.
  ui,
}
