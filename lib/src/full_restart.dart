// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/foundation.dart';
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
  /// [type] is [RestartType.full] (default) to kill the process and
  /// cold-start the app, or [RestartType.ui] to rebuild the UI inside the
  /// running process.
  ///
  /// Returns `true` when the platform accepted the request, `false` if the
  /// restart could not be started. Errors are logged, never thrown.
  static Future<bool> restart({RestartType type = RestartType.full}) async {
    ensureInitialized();
    try {
      return await FullRestartPlatform.instance.restart(
        killProcess: type == RestartType.full,
      );
    } catch (error) {
      debugPrint('[flutter_full_restart] restart failed: $error');
      return false;
    }
  }
}
