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
owns_tmp_root=false
if [ -z "${RUNNER_TEMP:-}" ]; then
  owns_tmp_root=true
fi

cleanup_tmp_on_failure() {
  local status=$?
  if [ "$status" -ne 0 ] && [ "$owns_tmp_root" = true ]; then
    rm -rf "$tmp_root"
  fi
}
trap cleanup_tmp_on_failure EXIT

path_file="${CAPTURE_EXAMPLE_PATH_FILE:-$tmp_root/capture-example-path.txt}"

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
    ;;
  ios)
    if [ ! -d ios ]; then
      bunx cap add ios
    fi
    bunx cap sync ios
    ;;
esac

mkdir -p "$(dirname "$path_file")"
printf '%s\n' "$test_app" > "$path_file"
