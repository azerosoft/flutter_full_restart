// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <chrono>
#include <cstdint>
#include <memory>
#include <string>
#include <thread>

#include "flutter_full_restart_plugin.h"

namespace flutter_full_restart {
namespace test {

namespace {

using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

constexpr wchar_t kWaitVariable[] = L"FLUTTER_FULL_RESTART_WAIT";

int64_t ElapsedMs(std::chrono::steady_clock::time_point start) {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::steady_clock::now() - start)
      .count();
}

bool WaitVariableIsSet() {
  wchar_t value[8];
  return ::GetEnvironmentVariableW(kWaitVariable, value, 8) != 0;
}

void SetWaitVariable(HANDLE process, DWORD process_id) {
  const std::wstring value =
      std::to_wstring(reinterpret_cast<std::uintptr_t>(process)) + L":" +
      std::to_wstring(process_id);
  ::SetEnvironmentVariableW(kWaitVariable, value.c_str());
}

// Starts a suspended process that stands in for the previous instance. It
// never runs; the test ends it with TerminateProcess.
PROCESS_INFORMATION StartStandIn() {
  wchar_t system_dir[MAX_PATH];
  ::GetSystemDirectoryW(system_dir, MAX_PATH);
  const std::wstring cmd = std::wstring(system_dir) + L"\\cmd.exe";
  std::wstring command_line = L"cmd.exe /c exit";
  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_info{};
  ::CreateProcessW(cmd.c_str(), command_line.data(), nullptr, nullptr, FALSE,
                   CREATE_SUSPENDED | CREATE_NO_WINDOW, nullptr, nullptr,
                   &startup_info, &process_info);
  return process_info;
}

}  // namespace

TEST(FlutterFullRestartPlugin, UnknownMethodIsNotImplemented) {
  FlutterFullRestartPlugin plugin;
  bool not_implemented = false;
  plugin.HandleMethodCall(
      MethodCall("unknown", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          nullptr, nullptr, [&not_implemented]() { not_implemented = true; }));

  EXPECT_TRUE(not_implemented);
}

TEST(FlutterFullRestartPlugin, WaitReturnsAtOnceWithoutVariable) {
  ::SetEnvironmentVariableW(kWaitVariable, nullptr);
  const auto start = std::chrono::steady_clock::now();
  WaitForPreviousInstance(5000);
  EXPECT_LT(ElapsedMs(start), 100);
}

TEST(FlutterFullRestartPlugin, WaitEndsWhenPreviousInstanceExits) {
  PROCESS_INFORMATION stand_in = StartStandIn();
  ASSERT_NE(stand_in.hProcess, nullptr);
  // WaitForPreviousInstance closes the handle it is given.
  HANDLE wait_handle = nullptr;
  ASSERT_TRUE(::DuplicateHandle(::GetCurrentProcess(), stand_in.hProcess,
                                ::GetCurrentProcess(), &wait_handle, 0, FALSE,
                                DUPLICATE_SAME_ACCESS));
  SetWaitVariable(wait_handle, stand_in.dwProcessId);

  std::thread previous_instance([process = stand_in.hProcess]() {
    std::this_thread::sleep_for(std::chrono::milliseconds(300));
    ::TerminateProcess(process, 0);
  });
  const auto start = std::chrono::steady_clock::now();
  WaitForPreviousInstance(5000);
  const int64_t elapsed = ElapsedMs(start);
  previous_instance.join();
  ::CloseHandle(stand_in.hThread);
  ::CloseHandle(stand_in.hProcess);

  EXPECT_GE(elapsed, 250);
  EXPECT_LT(elapsed, 4000);
  EXPECT_FALSE(WaitVariableIsSet());
}

TEST(FlutterFullRestartPlugin, WaitGivesUpAfterTimeout) {
  PROCESS_INFORMATION stand_in = StartStandIn();
  ASSERT_NE(stand_in.hProcess, nullptr);
  HANDLE wait_handle = nullptr;
  ASSERT_TRUE(::DuplicateHandle(::GetCurrentProcess(), stand_in.hProcess,
                                ::GetCurrentProcess(), &wait_handle, 0, FALSE,
                                DUPLICATE_SAME_ACCESS));
  SetWaitVariable(wait_handle, stand_in.dwProcessId);

  const auto start = std::chrono::steady_clock::now();
  WaitForPreviousInstance(200);
  const int64_t elapsed = ElapsedMs(start);
  ::TerminateProcess(stand_in.hProcess, 0);
  ::CloseHandle(stand_in.hThread);
  ::CloseHandle(stand_in.hProcess);

  EXPECT_GE(elapsed, 150);
  EXPECT_LT(elapsed, 2000);
}

TEST(FlutterFullRestartPlugin, WaitIgnoresValueThatIsNotThePreviousInstance) {
  PROCESS_INFORMATION stand_in = StartStandIn();
  ASSERT_NE(stand_in.hProcess, nullptr);
  const std::wstring handle_text =
      std::to_wstring(reinterpret_cast<std::uintptr_t>(stand_in.hProcess));
  const std::wstring values[] = {
      L"abc",
      handle_text,
      handle_text + L":0",
      handle_text + L":x",
      // The right handle with the wrong process id.
      handle_text + L":" + std::to_wstring(stand_in.dwProcessId + 4),
  };
  for (const std::wstring& value : values) {
    ::SetEnvironmentVariableW(kWaitVariable, value.c_str());
    const auto start = std::chrono::steady_clock::now();
    WaitForPreviousInstance(5000);
    EXPECT_LT(ElapsedMs(start), 100);
    EXPECT_FALSE(WaitVariableIsSet());
  }
  // A handle that does not match is left open.
  EXPECT_NE(::WaitForSingleObject(stand_in.hProcess, 0), WAIT_FAILED);
  ::TerminateProcess(stand_in.hProcess, 0);
  ::CloseHandle(stand_in.hThread);
  ::CloseHandle(stand_in.hProcess);
}

}  // namespace test
}  // namespace flutter_full_restart
