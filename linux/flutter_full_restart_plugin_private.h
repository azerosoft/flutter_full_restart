// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include <flutter_linux/flutter_linux.h>

#include "include/flutter_full_restart/flutter_full_restart_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// What the plugin does after it has responded to a restart call.
enum class FlutterFullRestartAction { kNone, kRebuildUi, kExitProcess };

// Handles the "restart" method call. For a full restart this starts the new
// instance and sets `action` to kExitProcess; the caller responds, then exits.
FlMethodResponse* flutter_full_restart_handle_restart(
    FlValue* args, FlutterFullRestartAction* action);
