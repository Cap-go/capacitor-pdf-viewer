#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_DIR="$ROOT_DIR/example-app"
FLOW_PATH="${CAPGO_MAESTRO_FLOW_PATH:-$ROOT_DIR/example-app/.maestro/background-color}"
RESULTS_DIR="${CAPGO_MAESTRO_RESULTS_DIR:-$ROOT_DIR/maestro-results-ios}"
SKIP_BUILD="${CAPGO_MAESTRO_SKIP_BUILD:-0}"
USE_LOG_E2E="${CAPGO_MAESTRO_IOS_LOG:-0}"
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

if [[ "${CAPGO_MAESTRO_IOS_SKIP_BOOT:-0}" != "1" ]]; then
  xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIMULATOR_ID" -b
fi
xcrun simctl uninstall "$SIMULATOR_ID" "$APP_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"

rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

MAESTRO_WS="$RESULTS_DIR/maestro-workspace"
rm -rf "$MAESTRO_WS"
mkdir -p "$MAESTRO_WS"
cp "$ROOT_DIR/example-app/.maestro/background-color/background-color-auto.yaml" "$MAESTRO_WS/"
cat > "$MAESTRO_WS/config.yaml" <<EOF
testOutputDir: $RESULTS_DIR
flows:
  - background-color-auto.yaml
EOF

if [[ "$USE_LOG_E2E" == "1" ]]; then
  echo "CAPGO_MAESTRO_IOS_LOG=1 is deprecated; use Maestro flows." >&2
  exit 1
fi

maestro --device "$SIMULATOR_ID" test \
  "$MAESTRO_WS" \
  --debug-output "$RESULTS_DIR/artifacts" \
  --flatten-debug-output \
  --format junit \
  --output "$RESULTS_DIR/junit.xml"

export CAPGO_MAESTRO_PLATFORM=ios
bash "$ROOT_DIR/scripts/maestro/post-maestro-checks.sh" "$RESULTS_DIR"