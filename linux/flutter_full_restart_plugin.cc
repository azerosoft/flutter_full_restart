// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include "include/flutter_full_restart/flutter_full_restart_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

#include <climits>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "flutter_full_restart_plugin_private.h"

#define FLUTTER_FULL_RESTART_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_full_restart_plugin_get_type(), \
                              FlutterFullRestartPlugin))

namespace {

// Keep in sync with lib/src/protocol.dart.
constexpr char kCommandChannel[] =
    "com.azerosoft.flutter_full_restart/commands";
constexpr char kRestartMethod[] = "restart";

// Names the pidfd a new instance waits on, see
// flutter_full_restart_wait_for_previous_instance.
constexpr char kWaitFdVariable[] = "FLUTTER_FULL_RESTART_WAIT_FD";
// How long a new instance waits at most for the previous one to exit.
constexpr int kWaitTimeoutMs = 5000;

FlMethodResponse* error_response(const gchar* code, const gchar* message) {
  return FL_METHOD_RESPONSE(fl_method_error_response_new(code, message, nullptr));
}

// Runs in the new instance between fork() and exec(), so it may only make
// async-signal-safe calls. GLib marks every inherited descriptor close-on-exec
// before this runs; keep the pidfd open.
void keep_fd_in_child(gpointer user_data) {
  const int fd = GPOINTER_TO_INT(user_data);
  const int flags = fcntl(fd, F_GETFD);
  if (flags != -1) {
    fcntl(fd, F_SETFD, flags & ~FD_CLOEXEC);
  }
}

int64_t monotonic_ms() {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return static_cast<int64_t>(now.tv_sec) * 1000 + now.tv_nsec / 1000000;
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

  // The new instance waits until this process has exited, so a single instance
  // check in the app does not see this process. It gets a pidfd for this
  // process, which becomes readable only after this process has exited and
  // released everything it held (files, locks, sockets). If no pidfd can be
  // created (Linux before 5.3), the new instance starts without waiting.
  // pidfd_open sets close-on-exec, so only the new instance keeps it.
  int pidfd = -1;
#ifdef SYS_pidfd_open
  pidfd = static_cast<int>(syscall(SYS_pidfd_open, getpid(), 0));
#endif
  g_auto(GStrv) envp = g_get_environ();
  if (pidfd >= 0) {
    g_autofree gchar* fd_text = g_strdup_printf("%d", pidfd);
    envp = g_environ_setenv(envp, kWaitFdVariable, fd_text, TRUE);
  }

  g_autoptr(GError) spawn_error = nullptr;
  const gboolean spawned = g_spawn_async(
      nullptr, reinterpret_cast<gchar**>(argv->pdata), envp, G_SPAWN_DEFAULT,
      pidfd >= 0 ? keep_fd_in_child : nullptr, GINT_TO_POINTER(pidfd), nullptr,
      &spawn_error);
  if (pidfd >= 0) {
    close(pidfd);
  }
  if (!spawned) {
    return error_response("RESTART_FAILED", spawn_error->message);
  }
  return nullptr;
}

// Whether `fd` is a pidfd. Uses only system calls, since it runs before main().
bool is_pidfd(int fd) {
  char path[64];
  snprintf(path, sizeof(path), "/proc/self/fd/%d", fd);
  char target[64];
  const ssize_t length = readlink(path, target, sizeof(target) - 1);
  if (length <= 0) {
    return false;
  }
  target[length] = '\0';
  return strcmp(target, "anon_inode:[pidfd]") == 0;
}

// Runs once in every process that loads the plugin, before main(), so it
// comes before any single instance check in the app.
__attribute__((constructor)) void wait_on_load() {
  flutter_full_restart_wait_for_previous_instance(kWaitTimeoutMs);
}

}  // namespace

void flutter_full_restart_wait_for_previous_instance(int timeout_ms) {
  const char* value = getenv(kWaitFdVariable);
  if (value == nullptr) {
    return;
  }
  char* end = nullptr;
  errno = 0;
  const long fd = strtol(value, &end, 10);
  const bool valid = errno == 0 && end != value && *end == '\0' && fd > 2 &&
                     fd <= INT_MAX;
  // Children of this process must not wait again.
  unsetenv(kWaitFdVariable);
  // The value comes from the environment, so only trust it if it names a
  // pidfd.
  if (!valid || !is_pidfd(static_cast<int>(fd))) {
    return;
  }

  // A pidfd becomes readable once its process has exited and released
  // everything it held.
  const int64_t deadline = monotonic_ms() + timeout_ms;
  while (true) {
    const int64_t remaining = deadline - monotonic_ms();
    if (remaining <= 0) {
      break;
    }
    struct pollfd poll_fd = {static_cast<int>(fd), POLLIN, 0};
    const int ready = poll(&poll_fd, 1, static_cast<int>(remaining));
    if (ready < 0 && errno == EINTR) {
      continue;
    }
    break;
  }
  close(static_cast<int>(fd));
}

FlMethodResponse* flutter_full_restart_handle_method_call(const gchar* method,
                                                         bool* exit_process) {
  *exit_process = false;
  if (strcmp(method, kRestartMethod) != 0) {
    return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  FlMethodResponse* failure = relaunch_process();
  if (failure != nullptr) {
    return failure;
  }
  *exit_process = true;
  g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

struct _FlutterFullRestartPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterFullRestartPlugin, flutter_full_restart_plugin,
              g_object_get_type())

// Called when a method call is received from Flutter.
static void flutter_full_restart_plugin_handle_method_call(
    FlutterFullRestartPlugin* self, FlMethodCall* method_call) {
  bool exit_process = false;
  g_autoptr(FlMethodResponse) response = flutter_full_restart_handle_method_call(
      fl_method_call_get_name(method_call), &exit_process);
  fl_method_call_respond(method_call, response, nullptr);

  if (exit_process) {
    exit(0);
  }
}

static void flutter_full_restart_plugin_class_init(
    FlutterFullRestartPluginClass* klass) {}

static void flutter_full_restart_plugin_init(FlutterFullRestartPlugin* self) {}

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

  g_autoptr(FlMethodChannel) command_channel =
      fl_method_channel_new(messenger, kCommandChannel, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(command_channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
