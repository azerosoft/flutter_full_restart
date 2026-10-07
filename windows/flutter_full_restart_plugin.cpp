// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include "flutter_full_restart_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <variant>
#include <vector>

namespace flutter_full_restart {

namespace {

// Keep in sync with lib/src/protocol.dart.
constexpr char kCommandChannel[] =
    "com.azerosoft.flutter_full_restart/commands";
constexpr char kSignalChannel[] = "com.azerosoft.flutter_full_restart/signals";
constexpr char kRestartMethod[] = "restart";
constexpr char kRebuildWidgetTreeSignal[] = "rebuildWidgetTree";

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodResult;

void Log(const std::wstring& message) {
#ifndef NDEBUG
  ::OutputDebugStringW((L"[flutter_full_restart] " + message + L"\n").c_str());
#endif
}

bool ReadFlag(const EncodableMap& arguments, const char* key) {
  const auto it = arguments.find(EncodableValue(key));
  if (it == arguments.end()) {
    return false;
  }
  const bool* value = std::get_if<bool>(&it->second);
  return value != nullptr && *value;
}

std::wstring ModulePath() {
  std::vector<wchar_t> buffer(MAX_PATH);
  while (true) {
    const DWORD length = ::GetModuleFileNameW(
        nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
    if (length == 0) {
      return std::wstring();
    }
    if (length < buffer.size()) {
      return std::wstring(buffer.data(), length);
    }
    buffer.resize(buffer.size() * 2);
  }
}

}  // namespace

// static
void FlutterFullRestartPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto command_channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), kCommandChannel,
          &flutter::StandardMethodCodec::GetInstance());
  auto signal_channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), kSignalChannel,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin =
      std::make_unique<FlutterFullRestartPlugin>(std::move(signal_channel));

  command_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterFullRestartPlugin::FlutterFullRestartPlugin(
    std::unique_ptr<flutter::MethodChannel<EncodableValue>> signal_channel)
    : signal_channel_(std::move(signal_channel)) {}

FlutterFullRestartPlugin::~FlutterFullRestartPlugin() {}

void FlutterFullRestartPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  if (method_call.method_name() != kRestartMethod) {
    result->NotImplemented();
    return;
  }

  const auto* arguments = std::get_if<EncodableMap>(method_call.arguments());
  if (arguments == nullptr) {
    result->Error("INVALID_ARGS", "Invalid arguments provided");
    return;
  }

  if (ReadFlag(*arguments, "killProcess")) {
    RelaunchProcess(std::move(result));
  } else {
    RebuildUserInterface(std::move(result));
  }
}

void FlutterFullRestartPlugin::RelaunchProcess(
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  const std::wstring module_path = ModulePath();
  // CreateProcessW may modify the command line buffer, so pass a copy.
  std::wstring command_line = ::GetCommandLineW();

  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_info{};
  if (module_path.empty() ||
      !::CreateProcessW(module_path.c_str(), command_line.data(), nullptr,
                        nullptr, FALSE, 0, nullptr, nullptr, &startup_info,
                        &process_info)) {
    const DWORD error = ::GetLastError();
    result->Error("RESTART_FAILED",
                  "Could not start a new instance of the app (Windows error " +
                      std::to_string(error) + ")");
    return;
  }
  // Let the new instance bring its window to the front; Windows would
  // otherwise keep it behind other windows once this process is gone.
  ::AllowSetForegroundWindow(process_info.dwProcessId);
  ::CloseHandle(process_info.hThread);
  ::CloseHandle(process_info.hProcess);

  result->Success(EncodableValue(true));
  Log(L"New instance started, exiting");
  ::ExitProcess(0);
}

void FlutterFullRestartPlugin::RebuildUserInterface(
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  result->Success(EncodableValue(true));
  if (signal_channel_) {
    signal_channel_->InvokeMethod(kRebuildWidgetTreeSignal, nullptr);
  }
}

}  // namespace flutter_full_restart
