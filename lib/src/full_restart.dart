// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'full_restart_platform.dart';
import 'full_restart_scope.dart';
import 'protocol.dart';
import 'rebuild_signal.dart';
import 'restart_type.dart';

/// Restarts the running app.
///
/// ```dart
/// // Kill the process and start the app again (cold start).
/// await FullRestart.restart();
///
/// // Keep the process, rebuild the Flutter UI from scratch.
/// await FullRestart.restart(type: RestartType.ui);
///
/// // Log out: wipe app data but keep the user's settings.
/// await FullRestart.restart(wipeData: true, keepPreferences: true);
/// ```
///
/// For UI-only restarts, wrap your app in a [FullRestartScope].
abstract final class FullRestart {
  static const MethodChannel _signals = MethodChannel(kSignalChannel);

  static bool _listening = false;
  static VoidCallback? _onUiRestart;

  /// Starts listening for rebuild requests from the native side.
  ///
  /// You rarely need to call this: [FullRestartScope] and [restart] do it
  /// for you. Call it yourself (after `WidgetsFlutterBinding.ensureInitialized()`)
  /// when you want to handle UI restarts on your own through [onUiRestart]
  /// instead of wrapping the app in a [FullRestartScope].
  ///
  /// Safe to call more than once. A non-null [onUiRestart] replaces the
  /// previously registered callback.
  static void ensureInitialized({VoidCallback? onUiRestart}) {
    if (onUiRestart != null) {
      _onUiRestart = onUiRestart;
    }
    if (_listening || kIsWeb) {
      return;
    }
    _signals.setMethodCallHandler(_handleSignal);
    _listening = true;
  }

  static Future<void> _handleSignal(MethodCall call) async {
    if (call.method != kRebuildWidgetTreeSignal) {
      return;
    }
    final VoidCallback? onUiRestart = _onUiRestart;
    if (onUiRestart != null) {
      onUiRestart();
    } else {
      widgetTreeGeneration.value++;
    }
  }

  /// Restarts the app.
  ///
  /// * [type]: [RestartType.full] (default) kills the process and cold-starts
  ///   the app; [RestartType.ui] rebuilds the UI inside the running process.
  /// * [wipeData]: delete app data (files, caches, databases, preferences,
  ///   keychain, cookies) before restarting.
  /// * [keepSecureStorage]: with [wipeData], keep the keychain on iOS and
  ///   macOS, and sessionStorage and cookies on the web.
  /// * [keepPreferences]: with [wipeData], keep preferences such as
  ///   UserDefaults, SharedPreferences and localStorage.
  ///
  /// Returns `true` when the platform accepted the request, `false` if the
  /// restart could not be started. Errors are logged, never thrown.
  static Future<bool> restart({
    RestartType type = RestartType.full,
    bool wipeData = false,
    bool keepSecureStorage = false,
    bool keepPreferences = false,
  }) async {
    ensureInitialized();
    try {
      return await FullRestartPlatform.instance.restart(
        killProcess: type == RestartType.full,
        wipeData: wipeData,
        keepSecureStorage: keepSecureStorage,
        keepPreferences: keepPreferences,
      );
    } catch (error) {
      debugPrint('[flutter_full_restart] restart failed: $error');
      return false;
    }
  }

  /// Asks the user for confirmation with an [AlertDialog] and restarts only
  /// if they agree.
  ///
  /// The restart options behave exactly like in [restart]. Returns `false`
  /// when the user cancels or dismisses the dialog.
  static Future<bool> confirmAndRestart(
    BuildContext context, {
    String title = 'Restart required',
    String message = 'The app needs to restart to apply the changes.',
    String confirmLabel = 'Restart now',
    String cancelLabel = 'Later',
    RestartType type = RestartType.full,
    bool wipeData = false,
    bool keepSecureStorage = false,
    bool keepPreferences = false,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return false;
    }
    return restart(
      type: type,
      wipeData: wipeData,
      keepSecureStorage: keepSecureStorage,
      keepPreferences: keepPreferences,
    );
  }
}
