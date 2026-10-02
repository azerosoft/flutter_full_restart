// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include "include/flutter_full_restart/flutter_full_restart_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_full_restart_plugin.h"

void FlutterFullRestartPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_full_restart::FlutterFullRestartPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
