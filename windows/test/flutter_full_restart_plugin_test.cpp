// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
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
                 })),
      std::make_unique<MethodResultFunctions<>>(
          [&accepted](const EncodableValue* result) {
            accepted = std::get<bool>(*result);
          },
          nullptr, nullptr));

  EXPECT_TRUE(accepted);
}

}  // namespace test
}  // namespace flutter_full_restart
