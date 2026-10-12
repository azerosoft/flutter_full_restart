// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

/// Restart a running Flutter app from Dart.
///
/// [FullRestart.restart] kills the process and cold-starts the app, exactly
/// like closing and reopening it.
library;

export 'src/full_restart.dart' show FullRestart;
export 'src/full_restart_platform.dart' show FullRestartPlatform;
