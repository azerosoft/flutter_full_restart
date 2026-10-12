// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include "flutter_full_restart_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <cwchar>
#include <memory>
#include <string>
#include <vector>

namespace flutter_full_restart {

namespace {

// Keep in sync with lib/src/protocol.dart.
constexpr char kCommandChannel[] =
    "com.azerosoft.flutter_full_restart/commands";
constexpr char kRestartMethod[] = "restart";

// Holds "<handle>:<process id>" of the previous instance in a new instance, see
// WaitForPreviousInstance.
constexpr wchar_t kWaitVariable[] = L"FLUTTER_FULL_RESTART_WAIT";
// How long a new instance waits at most for the previous one to exit.
constexpr DWORD kWaitTimeoutMs = 5000;

using flutter::EncodableValue;
using flutter::MethodResult;

void Log(const std::wstring& message) {
#ifndef NDEBUG
  ::OutputDebugStringW((L"[flutter_full_restart] " + message + L"\n").c_str());
#endif
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

// Starts `module_path` with `command_line`. When `wait_handle` is not null, the
// new process inherits it, and nothing else, and finds it through
// kWaitVariable.
bool StartProcess(const std::wstring& module_path, std::wstring command_line,
                  HANDLE wait_handle, PROCESS_INFORMATION* process_info) {
  if (wait_handle == nullptr) {
    STARTUPINFOW startup_info{};
    startup_info.cb = sizeof(startup_info);
    // CreateProcessW may modify the command line buffer, so it gets a copy.
    return ::CreateProcessW(module_path.c_str(), command_line.data(), nullptr,
                            nullptr, FALSE, 0, nullptr, nullptr, &startup_info,
                            process_info) != FALSE;
  }

  SIZE_T list_size = 0;
  ::InitializeProcThreadAttributeList(nullptr, 1, 0, &list_size);
  std::vector<unsigned char> list_buffer(list_size);
  auto* attributes =
      reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(list_buffer.data());
  if (list_size == 0 ||
      !::InitializeProcThreadAttributeList(attributes, 1, 0, &list_size)) {
    return false;
  }
  bool started = false;
  // Limits inheritance to the wait handle, even though bInheritHandles is TRUE.
  if (::UpdateProcThreadAttribute(attributes, 0,
                                  PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
                                  &wait_handle, sizeof(wait_handle), nullptr,
                                  nullptr)) {
    const std::wstring value =
        std::to_wstring(reinterpret_cast<std::uintptr_t>(wait_handle)) + L":" +
        std::to_wstring(::GetCurrentProcessId());
    // The new process copies this process's environment when it starts.
    if (::SetEnvironmentVariableW(kWaitVariable, value.c_str())) {
      STARTUPINFOEXW startup_info{};
      startup_info.StartupInfo.cb = sizeof(startup_info);
      startup_info.lpAttributeList = attributes;
      started = ::CreateProcessW(module_path.c_str(), command_line.data(),
                                 nullptr, nullptr, TRUE,
                                 EXTENDED_STARTUPINFO_PRESENT, nullptr, nullptr,
                                 &startup_info.StartupInfo,
                                 process_info) != FALSE;
      ::SetEnvironmentVariableW(kWaitVariable, nullptr);
    }
  }
  ::DeleteProcThreadAttributeList(attributes);
  return started;
}

// Runs once in every process that loads the plugin DLL, while Windows loads
// it, before wWinMain. It only calls kernel32 functions that are safe under
// the loader lock: waiting for another process to exit never needs this
// process's loader lock.
[[maybe_unused]] const bool kWaitedOnLoad =
    (WaitForPreviousInstance(kWaitTimeoutMs), true);

}  // namespace

void WaitForPreviousInstance(unsigned long timeout_ms) {
  wchar_t value[64];
  const DWORD length = ::GetEnvironmentVariableW(kWaitVariable, value, 64);
  if (length == 0 || length >= 64) {
    return;
  }
  // Children of this process must not wait again.
  ::SetEnvironmentVariableW(kWaitVariable, nullptr);

  wchar_t* end = nullptr;
  const unsigned long long handle_value = std::wcstoull(value, &end, 10);
  if (end == value || *end != L':') {
    return;
  }
  const wchar_t* pid_text = end + 1;
  const unsigned long process_id = std::wcstoul(pid_text, &end, 10);
  if (end == pid_text || *end != L'\0' || process_id == 0 ||
      process_id == ::GetCurrentProcessId()) {
    return;
  }
  // The value comes from the environment, so only use the handle if it really
  // is the inherited handle of the previous instance.
  HANDLE previous_instance =
      reinterpret_cast<HANDLE>(static_cast<std::uintptr_t>(handle_value));
  if (::GetProcessId(previous_instance) != process_id) {
    return;
  }
  ::WaitForSingleObject(previous_instance, timeout_ms);
  ::CloseHandle(previous_instance);
}

// static
void FlutterFullRestartPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto command_channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), kCommandChannel,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterFullRestartPlugin>();

  command_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterFullRestartPlugin::FlutterFullRestartPlugin() {}

FlutterFullRestartPlugin::~FlutterFullRestartPlugin() {}

void FlutterFullRestartPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  if (method_call.method_name() != kRestartMethod) {
    result->NotImplemented();
    return;
  }

  RelaunchProcess(std::move(result));
}

void FlutterFullRestartPlugin::RelaunchProcess(
    std::unique_ptr<MethodResult<EncodableValue>> result) {
  const std::wstring module_path = ModulePath();
  const std::wstring command_line = ::GetCommandLineW();

  // The new instance waits until this process has exited, so a single instance
  // check in the app does not see this process. It inherits a handle to this
  // process for that. If that fails, it starts without waiting.
  HANDLE wait_handle = nullptr;
  if (!::DuplicateHandle(::GetCurrentProcess(), ::GetCurrentProcess(),
                         ::GetCurrentProcess(), &wait_handle,
                         SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, TRUE,
                         0)) {
    wait_handle = nullptr;
  }
  PROCESS_INFORMATION process_info{};
  bool started = !module_path.empty() &&
                 StartProcess(module_path, command_line, wait_handle,
                              &process_info);
  if (!started && wait_handle != nullptr && !module_path.empty()) {
    started = StartProcess(module_path, command_line, nullptr, &process_info);
  }
  const DWORD error = started ? ERROR_SUCCESS : ::GetLastError();
  if (wait_handle != nullptr) {
    ::CloseHandle(wait_handle);
  }
  if (!started) {
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

}  // namespace flutter_full_restart
