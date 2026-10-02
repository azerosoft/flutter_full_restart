// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

import 'package:flutter/foundation.dart';

/// Bumped every time the native side asks for a widget tree rebuild.
///
/// [FullRestartScope] keys its subtree with this value, so each bump throws
/// away the old tree and builds a fresh one.
final ValueNotifier<int> widgetTreeGeneration = ValueNotifier<int>(0);
