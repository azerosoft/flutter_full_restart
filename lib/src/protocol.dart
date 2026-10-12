// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

// Names shared between the Dart side and the native side of the plugin.
//
// Keep in sync with the native implementations in android/, ios/, macos/,
// windows/ and linux/.

/// Dart -> native: restart requests.
const String kCommandChannel = 'com.azerosoft.flutter_full_restart/commands';

/// Method on [kCommandChannel] that performs a full restart.
const String kRestartMethod = 'restart';
