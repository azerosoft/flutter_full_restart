// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include "include/flutter_full_restart/flutter_full_restart_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#include <glib/gstdio.h>
#include <gtk/gtk.h>

#include <cstdlib>
#include <cstring>
#include <string>

#include "flutter_full_restart_plugin_private.h"

#define FLUTTER_FULL_RESTART_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_full_restart_plugin_get_type(), \
                              FlutterFullRestartPlugin))

namespace {

// Keep in sync with lib/src/protocol.dart.
constexpr char kCommandChannel[] =
    "com.azerosoft.flutter_full_restart/commands";
constexpr char kSignalChannel[] = "com.azerosoft.flutter_full_restart/signals";
constexpr char kRestartMethod[] = "restart";
constexpr char kRebuildWidgetTreeSignal[] = "rebuildWidgetTree";

bool read_flag(FlValue* args, const gchar* key) {
  FlValue* value = fl_value_lookup_string(args, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL &&
         fl_value_get_bool(value);
}

FlMethodResponse* error_response(const gchar* code, const gchar* message) {
  return FL_METHOD_RESPONSE(fl_method_error_response_new(code, message, nullptr));
}

// basenameWithoutExtension(/proc/self/exe), as used by path_provider_linux.
std::string executable_name() {
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe == nullptr) {
    return std::string();
  }
  g_autofree gchar* base = g_path_get_basename(exe);
  std::string name(base);
  const size_t dot = name.rfind('.');
  if (dot != std::string::npos && dot > 0) {
    name.resize(dot);
  }
  return name;
}

std::string application_id() {
  GApplication* app = g_application_get_default();
  const gchar* id =
      app != nullptr ? g_application_get_application_id(app) : nullptr;
  return id != nullptr ? std::string(id) : std::string();
}

bool is_safe_folder_name(const std::string& name) {
  return !name.empty() && name != "." && name != ".." &&
         name.find('/') == std::string::npos;
}

void remove_recursively(const gchar* path) {
  if (g_file_test(path, G_FILE_TEST_IS_DIR) &&
      !g_file_test(path, G_FILE_TEST_IS_SYMLINK)) {
    g_autoptr(GDir) dir = g_dir_open(path, 0, nullptr);
    if (dir != nullptr) {
      const gchar* name;
      while ((name = g_dir_read_name(dir)) != nullptr) {
        g_autofree gchar* child = g_build_filename(path, name, nullptr);
        remove_recursively(child);
      }
    }
    if (g_rmdir(path) != 0) {
      g_debug("[flutter_full_restart] Could not delete %s", path);
    }
  } else if (g_unlink(path) != 0) {
    g_debug("[flutter_full_restart] Could not delete %s", path);
  }
}

// Clears the app's cache folder and, unless `keep_preferences`, its data
// folder (where shared_preferences keeps its file). Shared locations such as
// the Documents folder, /tmp and the Secret Service keyring are never touched.
gboolean wipe_app_data(gboolean keep_secure_storage, gboolean keep_preferences,
                       GError** error) {
  // The Secret Service keyring is shared by every app of the user, so there
  // is nothing app-specific to remove for secure storage.
  (void)keep_secure_storage;

  const std::string app_id = application_id();
  const std::string exe_name = executable_name();
  gboolean success = TRUE;

  const std::string cache = flutter_full_restart_app_folder(
      g_get_user_cache_dir(), app_id, exe_name);
  if (!cache.empty() &&
      !flutter_full_restart_delete_contents(cache.c_str(), error)) {
    success = FALSE;
    error = nullptr;  // Keep the first error.
  }
  if (!keep_preferences) {
    const std::string data = flutter_full_restart_app_folder(
        g_get_user_data_dir(), app_id, exe_name);
    if (!data.empty() &&
        !flutter_full_restart_delete_contents(data.c_str(), error)) {
      success = FALSE;
    }
  }
  return success;
}

// Starts a new instance of the executable with the same arguments. Returns an
// error response on failure, nullptr on success.
FlMethodResponse* relaunch_process() {
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* cmdline = nullptr;
  gsize length = 0;
  if (exe == nullptr ||
      !g_file_get_contents("/proc/self/cmdline", &cmdline, &length, nullptr)) {
    return error_response("RESTART_FAILED",
                          "Could not determine the executable to relaunch");
  }

  // /proc/self/cmdline holds the arguments separated by NUL bytes. Keep them,
  // but launch the resolved executable path instead of argv[0].
  g_autoptr(GPtrArray) argv = g_ptr_array_new_with_free_func(g_free);
  g_ptr_array_add(argv, g_strdup(exe));
  gsize offset = strlen(cmdline) + 1;
  while (offset < length) {
    const gchar* arg = cmdline + offset;
    g_ptr_array_add(argv, g_strdup(arg));
    offset += strlen(arg) + 1;
  }
  g_ptr_array_add(argv, nullptr);

  g_autoptr(GError) spawn_error = nullptr;
  if (!g_spawn_async(nullptr, reinterpret_cast<gchar**>(argv->pdata), nullptr,
                     G_SPAWN_DEFAULT, nullptr, nullptr, nullptr,
                     &spawn_error)) {
    return error_response("RESTART_FAILED", spawn_error->message);
  }
  return nullptr;
}

}  // namespace

std::string flutter_full_restart_app_folder(const gchar* base_dir,
                                            const std::string& app_id,
                                            const std::string& exe_name) {
  const std::string id = app_id.empty() ? exe_name : app_id;
  for (const std::string& name : {id, exe_name}) {
    if (!is_safe_folder_name(name)) {
      continue;
    }
    g_autofree gchar* path = g_build_filename(base_dir, name.c_str(), nullptr);
    if (g_file_test(path, G_FILE_TEST_IS_DIR) &&
        !g_file_test(path, G_FILE_TEST_IS_SYMLINK)) {
      return std::string(path);
    }
  }
  return std::string();
}

gboolean flutter_full_restart_delete_contents(const gchar* dir,
                                              GError** error) {
  g_autoptr(GDir) handle = g_dir_open(dir, 0, error);
  if (handle == nullptr) {
    return FALSE;
  }
  const gchar* name;
  while ((name = g_dir_read_name(handle)) != nullptr) {
    g_autofree gchar* path = g_build_filename(dir, name, nullptr);
    remove_recursively(path);
  }
  return TRUE;
}

FlMethodResponse* flutter_full_restart_handle_restart(
    FlValue* args, FlutterFullRestartAction* action) {
  *action = FlutterFullRestartAction::kNone;
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return error_response("INVALID_ARGS", "Invalid arguments provided");
  }
  const bool kill_process = read_flag(args, "killProcess");
  const bool wipe_data = read_flag(args, "wipeData");
  const bool keep_secure_storage = read_flag(args, "keepSecureStorage");
  const bool keep_preferences = read_flag(args, "keepPreferences");

  if (wipe_data) {
    g_autoptr(GError) error = nullptr;
    if (!wipe_app_data(keep_secure_storage, keep_preferences, &error)) {
      return error_response("DATA_CLEAR_ERROR",
                            error != nullptr ? error->message
                                             : "Could not wipe app data");
    }
  }

  if (kill_process) {
    FlMethodResponse* failure = relaunch_process();
    if (failure != nullptr) {
      return failure;
    }
    *action = FlutterFullRestartAction::kExitProcess;
  } else {
    *action = FlutterFullRestartAction::kRebuildUi;
  }
  g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

struct _FlutterFullRestartPlugin {
  GObject parent_instance;
  FlMethodChannel* signal_channel;
};

G_DEFINE_TYPE(FlutterFullRestartPlugin, flutter_full_restart_plugin,
              g_object_get_type())

// Called when a method call is received from Flutter.
static void flutter_full_restart_plugin_handle_method_call(
    FlutterFullRestartPlugin* self, FlMethodCall* method_call) {
  if (strcmp(fl_method_call_get_name(method_call), kRestartMethod) != 0) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  FlutterFullRestartAction action = FlutterFullRestartAction::kNone;
  g_autoptr(FlMethodResponse) response = flutter_full_restart_handle_restart(
      fl_method_call_get_args(method_call), &action);
  fl_method_call_respond(method_call, response, nullptr);

  if (action == FlutterFullRestartAction::kExitProcess) {
    exit(0);
  }
  if (action == FlutterFullRestartAction::kRebuildUi &&
      self->signal_channel != nullptr) {
    fl_method_channel_invoke_method(self->signal_channel,
                                    kRebuildWidgetTreeSignal, nullptr,
                                    nullptr, nullptr, nullptr);
  }
}

static void flutter_full_restart_plugin_dispose(GObject* object) {
  FlutterFullRestartPlugin* self = FLUTTER_FULL_RESTART_PLUGIN(object);
  g_clear_object(&self->signal_channel);
  G_OBJECT_CLASS(flutter_full_restart_plugin_parent_class)->dispose(object);
}

static void flutter_full_restart_plugin_class_init(
    FlutterFullRestartPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_full_restart_plugin_dispose;
}

static void flutter_full_restart_plugin_init(FlutterFullRestartPlugin* self) {
  self->signal_channel = nullptr;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlutterFullRestartPlugin* plugin = FLUTTER_FULL_RESTART_PLUGIN(user_data);
  flutter_full_restart_plugin_handle_method_call(plugin, method_call);
}

void flutter_full_restart_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  FlutterFullRestartPlugin* plugin = FLUTTER_FULL_RESTART_PLUGIN(
      g_object_new(flutter_full_restart_plugin_get_type(), nullptr));

  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  plugin->signal_channel =
      fl_method_channel_new(messenger, kSignalChannel, FL_METHOD_CODEC(codec));

  g_autoptr(FlMethodChannel) command_channel =
      fl_method_channel_new(messenger, kCommandChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(command_channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
