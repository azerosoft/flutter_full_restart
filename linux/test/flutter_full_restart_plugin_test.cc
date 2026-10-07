// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include "include/flutter_full_restart/flutter_full_restart_plugin.h"
#include "flutter_full_restart_plugin_private.h"

namespace flutter_full_restart {
namespace test {

TEST(FlutterFullRestartPlugin, RejectsNonMapArguments) {
  FlutterFullRestartAction action = FlutterFullRestartAction::kRebuildUi;
  g_autoptr(FlValue) args = fl_value_new_null();
  g_autoptr(FlMethodResponse) response =
      flutter_full_restart_handle_restart(args, &action);

  ASSERT_TRUE(FL_IS_METHOD_ERROR_RESPONSE(response));
  EXPECT_STREQ(
      fl_method_error_response_get_code(FL_METHOD_ERROR_RESPONSE(response)),
      "INVALID_ARGS");
  EXPECT_EQ(action, FlutterFullRestartAction::kNone);
}

TEST(FlutterFullRestartPlugin, UiRestartAsksForARebuild) {
  FlutterFullRestartAction action = FlutterFullRestartAction::kNone;
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "killProcess", fl_value_new_bool(FALSE));
  g_autoptr(FlMethodResponse) response =
      flutter_full_restart_handle_restart(args, &action);

  ASSERT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  ASSERT_EQ(fl_value_get_type(result), FL_VALUE_TYPE_BOOL);
  EXPECT_TRUE(fl_value_get_bool(result));
  EXPECT_EQ(action, FlutterFullRestartAction::kRebuildUi);
}

}  // namespace test
}  // namespace flutter_full_restart
