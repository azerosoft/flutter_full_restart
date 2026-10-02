#!/usr/bin/env bash
# Recreates one platform folder of the example app with the template of the
# installed Flutter version. The committed folders come from the latest
# template, which older Flutter versions cannot build, so CI runs this before
# building the example on the oldest supported version.
#
# usage: .github/scripts/recreate_example_platform.sh <android|ios|macos|web|linux|windows>
set -euo pipefail

platform="$1"
cd "$(dirname "$0")/../../example"

rm -rf "$platform"
flutter create --org com.azerosoft --platforms="$platform" .

# Build the plugin's C++ unit tests together with the app, as the committed
# example does.
if [[ "$platform" == linux || "$platform" == windows ]]; then
  perl -0pi -e 's|^include\(flutter/generated_plugins\.cmake\)|set(include_flutter_full_restart_tests TRUE)\n$&|m' \
    "$platform/CMakeLists.txt"
  grep -q 'set(include_flutter_full_restart_tests TRUE)' "$platform/CMakeLists.txt"
fi
