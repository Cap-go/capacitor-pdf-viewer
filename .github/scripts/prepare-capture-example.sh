#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
case "$platform" in
  android | ios) ;;
  *)
    echo "Usage: $0 <android|ios>"
    exit 1
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_root="${RUNNER_TEMP:-$(mktemp -d)}"
path_file="${CAPTURE_EXAMPLE_PATH_FILE:-$tmp_root/capture-example-path.txt}"

# shellcheck source=pack-plugin-example.sh
source "$repo_root/.github/scripts/pack-plugin-example.sh"
pack_plugin_example_app "$repo_root" "$tmp_root"

case "$platform" in
  android)
    if [ ! -d android ]; then
      bunx cap add android
    fi
    ;;
  ios)
    if [ ! -d ios ]; then
      bunx cap add ios
    fi
    ;;
esac

mkdir -p "$(dirname "$path_file")"
printf '%s\n' "$test_app" > "$path_file"
