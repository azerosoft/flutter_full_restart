// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/foundation.dart';

const String _yellow = '\x1B[33m';
const String _reset = '\x1B[0m';

/// Prints [message] to the debug console in yellow, so the developer notices
/// why a restart did not happen.
///
/// Each line is colored on its own, because some consoles reset the color at
/// every line break.
void logWarning(String message) {
  for (final String line in message.split('\n')) {
    debugPrint('$_yellow[flutter_full_restart] $line$_reset');
  }
}
