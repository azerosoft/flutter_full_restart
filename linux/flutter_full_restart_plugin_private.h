// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include <flutter_linux/flutter_linux.h>

#include <string>

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

// The app's own folder below `base_dir`, resolved like path_provider_linux:
// `<application id>` if it exists, otherwise `<executable name>` if it exists.
// Returns an empty string when neither exists.
std::string flutter_full_restart_app_folder(const gchar* base_dir,
                                            const std::string& app_id,
                                            const std::string& exe_name);

// Deletes everything inside `dir` but keeps the folder itself. Symbolic links
// are removed, never followed.
gboolean flutter_full_restart_delete_contents(const gchar* dir,
                                              GError** error);
