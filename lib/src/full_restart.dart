// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'full_restart_platform.dart';
import 'log.dart';

/// Restarts the running app.
///
/// ```dart
/// // Kill the process and start the app again (cold start).
/// await FullRestart.restart();
/// ```
abstract final class FullRestart {
  /// Kills the process and cold-starts the app, exactly like closing and
  /// reopening it.
  ///
  /// * Android: relaunches the launcher activity in a new task and exits the
  ///   process.
  /// * iOS: reopens the app through its own URL scheme and exits the process.
  ///   The app must register its bundle identifier as a URL scheme in
  ///   Info.plist (see the README). Without it nothing happens and a yellow
  ///   warning in the debug console explains the setup.
  /// * macOS: launches a new instance of the app bundle and exits.
  /// * Windows and Linux: start a new instance of the executable with the
  ///   same arguments and exit.
  /// * Web: reloads the page.
  ///
  /// Returns `true` when the platform accepted the request, `false` if the
  /// restart could not be started. The reason is printed to the debug
  /// console in yellow, never thrown.
  static Future<bool> restart() async {
    try {
      return await FullRestartPlatform.instance.restart();
    } catch (error) {
      logWarning('Restart failed: $error');
      return false;
    }
  }

  /// Whether [uri] is the link a full restart reopens the app with.
  ///
  /// On iOS a full restart reopens the app through `<bundle id>://`.
  /// Packages that read incoming links themselves, such as `app_links`,
  /// report that empty link after the restart. Skip it before routing:
  ///
  /// ```dart
  /// AppLinks().uriLinkStream.listen((Uri uri) {
  ///   if (FullRestart.isRestartLink(uri)) return;
  ///   router.go(uri.path);
  /// });
  /// ```
  ///
  /// Returns `true` for a link with a scheme and no host, path, query or
  /// fragment, and `false` for every other link.
  static bool isRestartLink(Uri uri) {
    return uri.hasScheme &&
        uri.host.isEmpty &&
        (uri.path.isEmpty || uri.path == '/') &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}
