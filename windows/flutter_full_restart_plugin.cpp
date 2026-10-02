// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include "flutter_full_restart_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <shlobj.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cwctype>
#include <filesystem>
#include <memory>
#include <optional>
#include <string>
#include <system_error>
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

// Reads a VERSIONINFO string (e.g. "CompanyName") with the same language and
// code page lookups as path_provider_windows.
std::optional<std::wstring> VersionString(std::vector<BYTE>& info,
                                          const wchar_t* key) {
  for (const wchar_t* code_page : {L"040904e4", L"040904b0"}) {
    const std::wstring query =
        std::wstring(L"\\StringFileInfo\\") + code_page + L"\\" + key;
    LPVOID value = nullptr;
    UINT length = 0;
    if (::VerQueryValueW(info.data(), query.c_str(), &value, &length) &&
        value != nullptr) {
      return std::wstring(static_cast<const wchar_t*>(value));
    }
  }
  return std::nullopt;
}

std::optional<std::filesystem::path> KnownFolder(REFKNOWNFOLDERID folder_id) {
  PWSTR raw_path = nullptr;
  std::optional<std::filesystem::path> result;
  if (SUCCEEDED(::SHGetKnownFolderPath(folder_id, KF_FLAG_DEFAULT, nullptr,
                                       &raw_path)) &&
      raw_path != nullptr) {
    result = std::filesystem::path(raw_path);
  }
  ::CoTaskMemFree(raw_path);
  return result;
}

// Deletes everything inside `directory` but keeps the folder itself. Items
// that cannot be deleted (e.g. a file another process holds open) are skipped;
// failing to read the folder is reported.
std::error_code DeleteContents(const std::filesystem::path& directory) {
  std::error_code error;
  if (!std::filesystem::exists(directory, error)) {
    return error;
  }
  std::vector<std::filesystem::path> entries;
  for (std::filesystem::directory_iterator it(directory, error), end;
       !error && it != end; it.increment(error)) {
    entries.push_back(it->path());
  }
  if (error) {
    Log(L"Could not read " + directory.wstring());
    return error;
  }
  for (const auto& entry : entries) {
    std::error_code remove_error;
    std::filesystem::remove_all(entry, remove_error);
    if (remove_error) {
      Log(L"Could not delete " + entry.wstring());
    }
  }
  return {};
}

}  // namespace

std::optional<std::wstring> SanitizeDirectoryName(
    const std::optional<std::wstring>& raw) {
  if (!raw) {
    return std::nullopt;
  }
  std::wstring name = *raw;
  for (wchar_t& c : name) {
    if (c != L'\0' && std::wcschr(L"<>:\"/\\|?*", c) != nullptr) {
      c = L'_';
    }
  }
  while (!name.empty() && std::iswspace(name.back())) {
    name.pop_back();
  }
  while (!name.empty() && name.back() == L'.') {
    name.pop_back();
  }
  constexpr size_t kMaxComponentLength = 255;
  if (name.size() > kMaxComponentLength) {
    name.resize(kMaxComponentLength);
  }
  if (name.empty()) {
    return std::nullopt;
  }
  return name;
}

std::wstring AppSpecificSubdirectory() {
  const std::wstring module_path = ModulePath();
  if (module_path.empty()) {
    return std::wstring();
  }

  std::optional<std::wstring> company_name;
  std::optional<std::wstring> product_name;
  DWORD unused = 0;
  const DWORD info_size =
      ::GetFileVersionInfoSizeW(module_path.c_str(), &unused);
  if (info_size != 0) {
    std::vector<BYTE> info(info_size);
    if (::GetFileVersionInfoW(module_path.c_str(), 0, info_size,
                              info.data())) {
      company_name = SanitizeDirectoryName(VersionString(info, L"CompanyName"));
      product_name = SanitizeDirectoryName(VersionString(info, L"ProductName"));
    }
  }
  if (!product_name) {
    product_name = std::filesystem::path(module_path).stem().wstring();
  }
  if (product_name->empty()) {
    return std::wstring();
  }
  return company_name
             ? (std::filesystem::path(*company_name) / *product_name).wstring()
             : *product_name;
}

std::error_code WipeAppData(bool keep_secure_storage, bool keep_preferences) {
  // Credentials in the Windows Credential Manager are shared by every app of
  // the user, so there is nothing app-specific to remove for secure storage.
  (void)keep_secure_storage;

  const std::wstring app_folder = AppSpecificSubdirectory();
  if (app_folder.empty()) {
    // Never clear %APPDATA% or %LOCALAPPDATA% themselves.
    return std::make_error_code(std::errc::invalid_argument);
  }

  std::error_code first_error;
  const auto clear = [&](REFKNOWNFOLDERID root_id) {
    const std::optional<std::filesystem::path> root = KnownFolder(root_id);
    if (!root) {
      return;
    }
    const std::error_code error = DeleteContents(*root / app_folder);
    if (error && !first_error) {
      first_error = error;
    }
  };

  clear(FOLDERID_LocalAppData);
  if (!keep_preferences) {
    clear(FOLDERID_RoamingAppData);
  }
  return first_error;
}

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
  const bool kill_process = ReadFlag(*arguments, "killProcess");
  const bool wipe_data = ReadFlag(*arguments, "wipeData");
  const bool keep_secure_storage = ReadFlag(*arguments, "keepSecureStorage");
  const bool keep_preferences = ReadFlag(*arguments, "keepPreferences");

  if (wipe_data) {
    const std::error_code error =
        WipeAppData(keep_secure_storage, keep_preferences);
    if (error) {
      result->Error("DATA_CLEAR_ERROR", error.message());
      return;
    }
  }

  if (kill_process) {
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
