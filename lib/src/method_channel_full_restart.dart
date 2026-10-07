// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'full_restart_platform.dart';
import 'protocol.dart';

/// [FullRestartPlatform] implementation for every platform except the web,
/// backed by a method channel.
class MethodChannelFullRestart extends FullRestartPlatform {
  /// The channel used to talk to the native plugin.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel(kCommandChannel);

  @override
  Future<bool> restart({required bool killProcess}) async {
    try {
      final bool? accepted = await channel.invokeMethod<bool>(
        kRestartMethod,
        <String, bool>{kKillProcessArg: killProcess},
      );
      return accepted ?? false;
    } catch (error) {
      debugPrint('[flutter_full_restart] native restart failed: $error');
      return false;
    }
  }
}
