// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'full_restart_platform.dart';
import 'log.dart';
import 'protocol.dart';

/// [FullRestartPlatform] implementation for every platform except the web,
/// backed by a method channel.
class MethodChannelFullRestart extends FullRestartPlatform {
  /// The channel used to talk to the native plugin.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel(kCommandChannel);

  @override
  Future<bool> restart() async {
    try {
      final bool? accepted = await channel.invokeMethod<bool>(kRestartMethod);
      return accepted ?? false;
    } on PlatformException catch (error) {
      // The native side explains what is missing, for example the URL scheme
      // on iOS.
      logWarning(error.message ?? error.code);
      return false;
    } catch (error) {
      logWarning('Native restart failed: $error');
      return false;
    }
  }
}
