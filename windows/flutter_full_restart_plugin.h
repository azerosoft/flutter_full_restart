// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#ifndef FLUTTER_PLUGIN_FLUTTER_FULL_RESTART_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_FULL_RESTART_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_full_restart {

// Called while Windows loads the plugin DLL, before wWinMain. If this process
// was started by a restart, waits until the previous instance has exited, but
// at most `timeout_ms`. Otherwise returns at once.
void WaitForPreviousInstance(unsigned long timeout_ms);

// Windows side of flutter_full_restart.
class FlutterFullRestartPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  FlutterFullRestartPlugin();

  virtual ~FlutterFullRestartPlugin();

  // Disallow copy and assign.
  FlutterFullRestartPlugin(const FlutterFullRestartPlugin&) = delete;
  FlutterFullRestartPlugin& operator=(const FlutterFullRestartPlugin&) = delete;

  // Called when a method is called on the command channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  // Starts a new instance of the executable with the same command line, then
  // exits this process.
  void RelaunchProcess(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_full_restart

#endif  // FLUTTER_PLUGIN_FLUTTER_FULL_RESTART_PLUGIN_H_
