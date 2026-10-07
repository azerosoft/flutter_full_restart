// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'dart:async';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/full_restart_platform.dart';

/// Web implementation of `flutter_full_restart`.
///
/// A browser tab cannot kill its own process, so both restart types reload
/// the page.
class FlutterFullRestartWeb extends FullRestartPlatform {
  /// Constructs the web implementation.
  FlutterFullRestartWeb();

  /// Called by the generated plugin registrant.
  static void registerWith(Registrar registrar) {
    FullRestartPlatform.instance = FlutterFullRestartWeb();
  }

  @override
  Future<bool> restart({required bool killProcess}) async {
    try {
      // Reload in a microtask so this Future completes first.
      // `location.replace(sameUrl)` does not reload in most browsers, so
      // both restart types use `reload()`.
      scheduleMicrotask(() => web.window.location.reload());
      return true;
    } catch (_) {
      return false;
    }
  }
}
