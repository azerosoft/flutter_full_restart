// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

// Names shared between the Dart side and the native side of the plugin.
//
// Keep in sync with the native implementations in android/, ios/, macos/,
// windows/ and linux/.

/// Dart -> native: restart requests.
const String kCommandChannel = 'com.azerosoft.flutter_full_restart/commands';

/// Native -> Dart: notifications sent while a restart is in progress.
const String kSignalChannel = 'com.azerosoft.flutter_full_restart/signals';

/// Method on [kCommandChannel] that performs a restart.
const String kRestartMethod = 'restart';

/// Method on [kSignalChannel] asking Dart to rebuild its widget tree.
const String kRebuildWidgetTreeSignal = 'rebuildWidgetTree';

/// Argument of [kRestartMethod]: `true` for a full restart.
const String kKillProcessArg = 'killProcess';

/// Argument of [kRestartMethod]: delete app data before restarting.
const String kWipeDataArg = 'wipeData';

/// Argument of [kRestartMethod]: keep secure storage when wiping.
const String kKeepSecureStorageArg = 'keepSecureStorage';

/// Argument of [kRestartMethod]: keep preferences when wiping.
const String kKeepPreferencesArg = 'keepPreferences';
