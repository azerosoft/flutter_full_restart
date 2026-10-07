// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

/// Restart a running Flutter app from Dart.
///
/// * [FullRestart.restart] kills the process and cold-starts the app
///   ([RestartType.full]) or rebuilds the Flutter UI in place
///   ([RestartType.ui]).
/// * [FullRestartScope] wraps your app so a UI restart rebuilds the whole
///   widget tree from scratch.
library;

export 'src/full_restart.dart' show FullRestart;
export 'src/full_restart_platform.dart' show FullRestartPlatform;
export 'src/full_restart_scope.dart' show FullRestartScope;
export 'src/restart_type.dart' show RestartType;
