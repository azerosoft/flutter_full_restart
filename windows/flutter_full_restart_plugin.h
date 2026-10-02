// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#ifndef FLUTTER_PLUGIN_FLUTTER_FULL_RESTART_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_FULL_RESTART_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>
#include <string>
#include <system_error>

namespace flutter_full_restart {

// Windows side of flutter_full_restart.
class FlutterFullRestartPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit FlutterFullRestartPlugin(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
          signal_channel);

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

  // Asks Dart to rebuild its widget tree (handled by FullRestartScope).
  void RebuildUserInterface(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      signal_channel_;
};

// Applies the same rules as path_provider_windows to a VERSIONINFO string so
// the folder names match the ones used by path_provider and
// shared_preferences. Returns nullopt for missing or empty names.
std::optional<std::wstring> SanitizeDirectoryName(
    const std::optional<std::wstring>& raw);

// The app's own folder below %APPDATA% / %LOCALAPPDATA%, e.g.
// "com.example\my_app" (company\product from the executable's VERSIONINFO,
// falling back to the executable name).
std::wstring AppSpecificSubdirectory();

// Deletes the app's own data folders. The cache folder below %LOCALAPPDATA% is
// always cleared; the support folder below %APPDATA% (where
// shared_preferences keeps its file) only when `keep_preferences` is false.
// Shared locations such as Documents, %TEMP% and the Windows Credential
// Manager are never touched.
std::error_code WipeAppData(bool keep_secure_storage, bool keep_preferences);

}  // namespace flutter_full_restart

#endif  // FLUTTER_PLUGIN_FLUTTER_FULL_RESTART_PLUGIN_H_
