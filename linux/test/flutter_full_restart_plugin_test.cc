// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include <flutter_linux/flutter_linux.h>
#include <glib/gstdio.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>
#include <unistd.h>

#include <string>

#include "include/flutter_full_restart/flutter_full_restart_plugin.h"
#include "flutter_full_restart_plugin_private.h"

namespace flutter_full_restart {
namespace test {

namespace {

std::string Join(const gchar* a, const gchar* b) {
  g_autofree gchar* path = g_build_filename(a, b, nullptr);
  return std::string(path);
}

void WriteFile(const std::string& path) {
  ASSERT_TRUE(g_file_set_contents(path.c_str(), "x", -1, nullptr));
}

void RemoveTree(const gchar* path) {
  g_autoptr(GFile) file = g_file_new_for_path(path);
  g_autoptr(GFileEnumerator) children = g_file_enumerate_children(
      file, G_FILE_ATTRIBUTE_STANDARD_NAME,
      G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, nullptr, nullptr);
  if (children != nullptr) {
    GFileInfo* info = nullptr;
    while ((info = g_file_enumerator_next_file(children, nullptr, nullptr)) !=
           nullptr) {
      g_autoptr(GFileInfo) owned = info;
      const std::string child = Join(path, g_file_info_get_name(info));
      if (g_file_test(child.c_str(), G_FILE_TEST_IS_DIR) &&
          !g_file_test(child.c_str(), G_FILE_TEST_IS_SYMLINK)) {
        RemoveTree(child.c_str());
      } else {
        g_unlink(child.c_str());
      }
    }
  }
  g_rmdir(path);
}

}  // namespace

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
  fl_value_set_string_take(args, "wipeData", fl_value_new_bool(FALSE));
  g_autoptr(FlMethodResponse) response =
      flutter_full_restart_handle_restart(args, &action);

  ASSERT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  ASSERT_EQ(fl_value_get_type(result), FL_VALUE_TYPE_BOOL);
  EXPECT_TRUE(fl_value_get_bool(result));
  EXPECT_EQ(action, FlutterFullRestartAction::kRebuildUi);
}

TEST(AppFolder, ResolvesLikePathProvider) {
  g_autofree gchar* base = g_dir_make_tmp("ffr_test_XXXXXX", nullptr);
  ASSERT_NE(base, nullptr);

  // Nothing exists yet.
  EXPECT_EQ(flutter_full_restart_app_folder(base, "com.example.app", "my_app"),
            "");

  // Legacy folder named after the executable.
  const std::string legacy = Join(base, "my_app");
  ASSERT_EQ(g_mkdir(legacy.c_str(), 0700), 0);
  EXPECT_EQ(flutter_full_restart_app_folder(base, "com.example.app", "my_app"),
            legacy);

  // The application id folder wins once it exists.
  const std::string by_id = Join(base, "com.example.app");
  ASSERT_EQ(g_mkdir(by_id.c_str(), 0700), 0);
  EXPECT_EQ(flutter_full_restart_app_folder(base, "com.example.app", "my_app"),
            by_id);

  // Without an application id the executable name is used.
  EXPECT_EQ(flutter_full_restart_app_folder(base, "", "my_app"), legacy);

  // Names that would escape the base folder are ignored.
  EXPECT_EQ(flutter_full_restart_app_folder(base, "..", ".."), "");
  EXPECT_EQ(flutter_full_restart_app_folder(base, "a/../..", ""), "");

  RemoveTree(base);
}

TEST(DeleteContents, KeepsTheFolderAndNeverFollowsSymlinks) {
  g_autofree gchar* base = g_dir_make_tmp("ffr_test_XXXXXX", nullptr);
  ASSERT_NE(base, nullptr);
  const std::string app = Join(base, "app");
  const std::string outside = Join(base, "outside");
  ASSERT_EQ(g_mkdir(app.c_str(), 0700), 0);
  ASSERT_EQ(g_mkdir(outside.c_str(), 0700), 0);

  WriteFile(Join(app.c_str(), "a.txt"));
  const std::string sub = Join(app.c_str(), "sub");
  ASSERT_EQ(g_mkdir(sub.c_str(), 0700), 0);
  WriteFile(Join(sub.c_str(), "b.txt"));
  const std::string kept = Join(outside.c_str(), "keep.txt");
  WriteFile(kept);
  ASSERT_EQ(symlink(outside.c_str(), Join(app.c_str(), "link").c_str()), 0);

  ASSERT_TRUE(flutter_full_restart_delete_contents(app.c_str(), nullptr));

  EXPECT_TRUE(g_file_test(app.c_str(), G_FILE_TEST_IS_DIR));
  g_autoptr(GDir) dir = g_dir_open(app.c_str(), 0, nullptr);
  ASSERT_NE(dir, nullptr);
  EXPECT_EQ(g_dir_read_name(dir), nullptr);
  EXPECT_TRUE(g_file_test(kept.c_str(), G_FILE_TEST_EXISTS));

  RemoveTree(base);
}

}  // namespace test
}  // namespace flutter_full_restart
