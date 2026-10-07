// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_full_restart.dart';

/// The contract every platform implementation of `flutter_full_restart`
/// fulfils.
///
/// Implementations must `extend` this class (not `implement` it), so that new
/// methods added here later are not breaking changes for them.
abstract class FullRestartPlatform extends PlatformInterface {
  /// Constructs a [FullRestartPlatform].
  FullRestartPlatform() : super(token: _token);

  static final Object _token = Object();

  static FullRestartPlatform _instance = MethodChannelFullRestart();

  /// The implementation used by `FullRestart`.
  ///
  /// Defaults to [MethodChannelFullRestart], used on every platform except
  /// the web, where the web implementation replaces it.
  static FullRestartPlatform get instance => _instance;

  /// Registers a platform implementation. Also handy for faking the plugin
  /// in tests.
  static set instance(FullRestartPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Performs the restart.
  ///
  /// [killProcess] is `true` for a full process restart and `false` for a
  /// UI-only restart.
  ///
  /// Completes with `true` once the platform has accepted the request.
  Future<bool> restart({required bool killProcess}) {
    throw UnimplementedError('restart() has not been implemented.');
  }
}
