// flutter_full_restart by Azerosoft (https://azerosoft.com)
// Licensed under the MIT License. See the LICENSE file for details.

#include <fcntl.h>
#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>
#include <signal.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <unistd.h>

#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <string>

#include "include/flutter_full_restart/flutter_full_restart_plugin.h"
#include "flutter_full_restart_plugin_private.h"

namespace flutter_full_restart {
namespace test {

TEST(FlutterFullRestartPlugin, UnknownMethodIsNotImplemented) {
  bool exit_process = true;
  g_autoptr(FlMethodResponse) response =
      flutter_full_restart_handle_method_call("unknown", &exit_process);

  EXPECT_TRUE(FL_IS_METHOD_NOT_IMPLEMENTED_RESPONSE(response));
  EXPECT_FALSE(exit_process);
}

namespace {

constexpr char kWaitFdVariable[] = "FLUTTER_FULL_RESTART_WAIT_FD";

int64_t ElapsedMs(std::chrono::steady_clock::time_point start) {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::steady_clock::now() - start)
      .count();
}

bool IsOpen(int fd) { return fcntl(fd, F_GETFD) != -1; }

int PidfdOpen(pid_t pid) {
  return static_cast<int>(syscall(SYS_pidfd_open, pid, 0));
}

}  // namespace

TEST(FlutterFullRestartPlugin, WaitReturnsAtOnceWithoutVariable) {
  unsetenv(kWaitFdVariable);
  const auto start = std::chrono::steady_clock::now();
  flutter_full_restart_wait_for_previous_instance(5000);
  EXPECT_LT(ElapsedMs(start), 100);
}

TEST(FlutterFullRestartPlugin, WaitEndsWhenPreviousInstanceExits) {
  // A child process stands in for the previous instance.
  const pid_t child = fork();
  ASSERT_GE(child, 0);
  if (child == 0) {
    usleep(300 * 1000);
    _exit(0);
  }
  const int pidfd = PidfdOpen(child);
  ASSERT_GE(pidfd, 0);
  setenv(kWaitFdVariable, std::to_string(pidfd).c_str(), 1);

  const auto start = std::chrono::steady_clock::now();
  flutter_full_restart_wait_for_previous_instance(5000);
  const int64_t elapsed = ElapsedMs(start);
  waitpid(child, nullptr, 0);

  EXPECT_GE(elapsed, 250);
  EXPECT_LT(elapsed, 4000);
  EXPECT_EQ(getenv(kWaitFdVariable), nullptr);
  EXPECT_FALSE(IsOpen(pidfd));
}

TEST(FlutterFullRestartPlugin, WaitGivesUpAfterTimeout) {
  const pid_t child = fork();
  ASSERT_GE(child, 0);
  if (child == 0) {
    pause();
    _exit(0);
  }
  const int pidfd = PidfdOpen(child);
  ASSERT_GE(pidfd, 0);
  setenv(kWaitFdVariable, std::to_string(pidfd).c_str(), 1);

  const auto start = std::chrono::steady_clock::now();
  flutter_full_restart_wait_for_previous_instance(200);
  const int64_t elapsed = ElapsedMs(start);
  kill(child, SIGKILL);
  waitpid(child, nullptr, 0);

  EXPECT_GE(elapsed, 150);
  EXPECT_LT(elapsed, 2000);
  EXPECT_FALSE(IsOpen(pidfd));
}

TEST(FlutterFullRestartPlugin, WaitIgnoresValueThatIsNotAPidfd) {
  int fds[2];
  ASSERT_EQ(pipe2(fds, O_CLOEXEC), 0);
  for (const std::string& value : {std::string("abc"), std::string("12x"),
                                   std::string("1"), std::to_string(fds[0])}) {
    setenv(kWaitFdVariable, value.c_str(), 1);
    const auto start = std::chrono::steady_clock::now();
    flutter_full_restart_wait_for_previous_instance(5000);
    EXPECT_LT(ElapsedMs(start), 100) << value;
    EXPECT_EQ(getenv(kWaitFdVariable), nullptr) << value;
  }
  // A descriptor that is not a pidfd is left alone.
  EXPECT_TRUE(IsOpen(fds[0]));
  close(fds[0]);
  close(fds[1]);
}

}  // namespace test
}  // namespace flutter_full_restart
