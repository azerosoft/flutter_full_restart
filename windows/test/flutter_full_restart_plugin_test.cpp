// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <optional>
#include <string>
#include <variant>

#include "flutter_full_restart_plugin.h"

namespace flutter_full_restart {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(FlutterFullRestartPlugin, UnknownMethodIsNotImplemented) {
  FlutterFullRestartPlugin plugin(nullptr);
  bool not_implemented = false;
  plugin.HandleMethodCall(
      MethodCall("unknown", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          nullptr, nullptr, [&not_implemented]() { not_implemented = true; }));

  EXPECT_TRUE(not_implemented);
}

TEST(FlutterFullRestartPlugin, RestartWithoutArgumentsIsRejected) {
  FlutterFullRestartPlugin plugin(nullptr);
  std::string error_code;
  plugin.HandleMethodCall(
      MethodCall("restart", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          nullptr,
          [&error_code](const std::string& code, const std::string&,
                        const EncodableValue*) { error_code = code; },
          nullptr));

  EXPECT_EQ(error_code, "INVALID_ARGS");
}

TEST(FlutterFullRestartPlugin, UiRestartSucceedsWithoutKillingTheProcess) {
  FlutterFullRestartPlugin plugin(nullptr);
  bool accepted = false;
  plugin.HandleMethodCall(
      MethodCall("restart",
                 std::make_unique<EncodableValue>(EncodableMap{
                     {EncodableValue("killProcess"), EncodableValue(false)},
                     {EncodableValue("wipeData"), EncodableValue(false)},
                 })),
      std::make_unique<MethodResultFunctions<>>(
          [&accepted](const EncodableValue* result) {
            accepted = std::get<bool>(*result);
          },
          nullptr, nullptr));

  EXPECT_TRUE(accepted);
}

TEST(SanitizeDirectoryName, MatchesPathProviderRules) {
  EXPECT_EQ(SanitizeDirectoryName(std::nullopt), std::nullopt);
  EXPECT_EQ(SanitizeDirectoryName(std::wstring(L"")), std::nullopt);
  EXPECT_EQ(SanitizeDirectoryName(std::wstring(L"...")), std::nullopt);
  EXPECT_EQ(SanitizeDirectoryName(std::wstring(L"com.example")),
            std::wstring(L"com.example"));
  EXPECT_EQ(SanitizeDirectoryName(std::wstring(L"My:App?  ")),
            std::wstring(L"My_App_"));
  EXPECT_EQ(SanitizeDirectoryName(std::wstring(L"a/b\\c..")),
            std::wstring(L"a_b_c"));
  EXPECT_EQ(SanitizeDirectoryName(std::wstring(300, L'x'))->size(), 255u);
}

TEST(AppSpecificSubdirectory, IsARelativeFolderOfTheApp) {
  const std::wstring folder = AppSpecificSubdirectory();
  ASSERT_FALSE(folder.empty());
  EXPECT_EQ(folder.find(L".."), std::wstring::npos);
  EXPECT_EQ(folder.find(L':'), std::wstring::npos);
  EXPECT_NE(folder.front(), L'\\');
}

}  // namespace test
}  // namespace flutter_full_restart
