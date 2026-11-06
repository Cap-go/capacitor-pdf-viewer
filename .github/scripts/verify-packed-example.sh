#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
case "$platform" in
  android | ios | web) ;;
  *)
    echo "Usage: $0 <android|ios|web>"
    exit 1
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_root="${RUNNER_TEMP:-$(mktemp -d)}"

# shellcheck source=pack-plugin-example.sh
source "$repo_root/.github/scripts/pack-plugin-example.sh"
pack_plugin_example_app "$repo_root" "$tmp_root"

bun run build

case "$platform" in
  android)
    if [ ! -d android ]; then
      bunx cap add android
    fi
    bunx cap sync android
    cd android
    ./gradlew build test
    ;;
  ios)
    if [ ! -d ios ]; then
      bunx cap add ios
    fi
    bunx cap sync ios
    xcodebuild -project ios/App/App.xcodeproj -scheme App -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO
    ;;
  web)
    ;;
esac
