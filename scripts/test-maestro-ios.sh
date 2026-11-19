#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_DIR="$ROOT_DIR/example-app"
FLOW_PATH="${CAPGO_MAESTRO_FLOW_PATH:-$ROOT_DIR/example-app/.maestro/background-color}"
RESULTS_DIR="${CAPGO_MAESTRO_RESULTS_DIR:-$ROOT_DIR/maestro-results-ios}"
SKIP_BUILD="${CAPGO_MAESTRO_SKIP_BUILD:-0}"
USE_LOG_E2E="${CAPGO_MAESTRO_IOS_LOG:-1}"
APP_ID="app.capgo.pdfviewer"

export MAESTRO_DRIVER_STARTUP_TIMEOUT="${MAESTRO_DRIVER_STARTUP_TIMEOUT:-120000}"
export MAESTRO_CLI_NO_ANALYTICS="${MAESTRO_CLI_NO_ANALYTICS:-1}"

if [[ ! -d "$FLOW_PATH" && ! -f "$FLOW_PATH" ]]; then
  echo "Maestro flow path not found: $FLOW_PATH" >&2
  exit 1
fi

if [[ "$USE_LOG_E2E" != "1" ]] && ! command -v maestro >/dev/null 2>&1; then
  echo "maestro is required to run iOS Maestro tests." >&2
  exit 1
fi

wait_for_log_line() {
  local pattern="$1"
  local log_file="$2"
  local timeout_seconds="${3:-120}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    if [[ -f "$log_file" ]] && grep -Fq "$pattern" "$log_file"; then
      echo "Saw log: $pattern"
      return 0
    fi
  done

  echo "Timed out waiting for log: $pattern" >&2
  tail -120 "$log_file" >&2 2>/dev/null || true
  return 1
}

run_log_background_color_e2e() {
  local log_file="$RESULTS_DIR/ios-log.txt"

  : >"$log_file"
  xcrun simctl spawn "$SIMULATOR_ID" log stream --style compact --predicate 'composedMessage CONTAINS "CAPGO_E2E"' >>"$log_file" 2>/dev/null &
  local log_pid=$!

  xcrun simctl terminate "$SIMULATOR_ID" "$APP_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIMULATOR_ID" "$APP_ID"

  wait_for_log_line 'CAPGO_E2E E2E: auto start' "$log_file" 180
  wait_for_log_line 'CAPGO_E2E E2E: open-with-color ok' "$log_file" 60
  wait_for_log_line 'CAPGO_E2E E2E: open-without-color ok' "$log_file" 60
  wait_for_log_line 'CAPGO_E2E E2E: invalid-color ok' "$log_file" 60
  wait_for_log_line 'CAPGO_E2E E2E: auto complete' "$log_file" 60

  kill "$log_pid" >/dev/null 2>&1 || true

  cat >"$RESULTS_DIR/junit.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="background-color-ios-log" tests="3" failures="0" />
EOF
}

SIMULATOR_ID="${CAPGO_MAESTRO_IOS_SIMULATOR_ID:-$("$ROOT_DIR/scripts/maestro/select-ios-simulator.sh")}"
DERIVED_DATA_PATH="${CAPGO_MAESTRO_IOS_DERIVED_DATA_PATH:-${RUNNER_TEMP:-/tmp}/maestro-pdf-viewer-derived}"

if [[ -n "${CAPGO_MAESTRO_IOS_APP_PATH:-}" ]]; then
  APP_PATH="$CAPGO_MAESTRO_IOS_APP_PATH"
elif [[ "$SKIP_BUILD" == "1" ]]; then
  APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/App.app"
else
  APP_PATH=""
fi

if [[ "$SKIP_BUILD" != "1" ]]; then
  (cd "$ROOT_DIR" && bun run build)
  (
    cd "$EXAMPLE_DIR"
    bun install
    bun run build
    if [[ ! -d ios ]]; then
      bunx cap add ios
    fi
    bunx cap sync ios
  )
  rm -rf "$DERIVED_DATA_PATH"
  xcodebuild \
    -project "$EXAMPLE_DIR/ios/App/App.xcodeproj" \
    -scheme App \
    -configuration Debug \
    -destination "id=$SIMULATOR_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
fi

if [[ -z "${APP_PATH:-}" ]]; then
  APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/App.app"
fi
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected iOS simulator app at $APP_PATH" >&2
  exit 1
fi

xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl uninstall "$SIMULATOR_ID" "$APP_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"

rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

if [[ "$USE_LOG_E2E" == "1" ]]; then
  run_log_background_color_e2e
  exit 0
fi

maestro --device "$SIMULATOR_ID" test \
  "$FLOW_PATH" \
  --debug-output "$RESULTS_DIR/artifacts" \
  --flatten-debug-output \
  --format junit \
  --output "$RESULTS_DIR/junit.xml"