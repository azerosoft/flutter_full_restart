// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include <flutter_linux/flutter_linux.h>

#include "include/flutter_full_restart/flutter_full_restart_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Handles a method call on the command channel. For "restart" this starts the
// new instance and sets `exit_process`; the caller responds, then exits.
FlMethodResponse* flutter_full_restart_handle_method_call(const gchar* method,
                                                         bool* exit_process);

// Called before main() in every process that loads the plugin. If this process
// was started by a restart, waits until the previous instance has exited, but
// at most `timeout_ms`. Otherwise returns at once.
void flutter_full_restart_wait_for_previous_instance(int timeout_ms);
