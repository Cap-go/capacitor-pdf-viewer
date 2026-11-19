#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_DIR="$ROOT_DIR/example-app"
APK_PATH="$EXAMPLE_DIR/android/app/build/outputs/apk/debug/app-debug.apk"
RESULTS_DIR="$ROOT_DIR/maestro-results"
FLOW_PATH="${CAPGO_MAESTRO_FLOW_PATH:-$ROOT_DIR/example-app/.maestro/background-color}"
APP_ID="app.capgo.pdfviewer"
SKIP_BUILD="${CAPGO_MAESTRO_SKIP_BUILD:-0}"

if [[ -f "$APK_PATH" ]]; then
  SKIP_BUILD=1
fi

if [[ ! -d "$FLOW_PATH" && ! -f "$FLOW_PATH" ]]; then
  echo "Maestro flow path not found: $FLOW_PATH" >&2
  exit 1
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is required to run Android Maestro tests." >&2
  exit 1
fi

USE_LOGCAT_E2E="${CAPGO_MAESTRO_ANDROID_LOGCAT:-1}"

if [[ "$USE_LOGCAT_E2E" != "1" ]] && ! command -v maestro >/dev/null 2>&1; then
  echo "maestro is required to run Android Maestro tests." >&2
  exit 1
fi

DEVICE_ID="${CAPGO_MAESTRO_ANDROID_DEVICE_ID:-$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "No Android device is available for Maestro." >&2
  exit 1
fi

wait_for_device() {
  local timeout_seconds="${CAPGO_MAESTRO_EMULATOR_BOOT_TIMEOUT_SECONDS:-180}"
  local deadline=$((SECONDS + timeout_seconds))

  adb -s "$DEVICE_ID" wait-for-device

  while ((SECONDS < deadline)); do
    local boot_completed
    boot_completed="$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "$boot_completed" == "1" ]]; then
      return 0
    fi
  done

  echo "Android device $DEVICE_ID did not finish booting within ${timeout_seconds} seconds." >&2
  exit 1
}

wait_for_logcat_line() {
  local pattern="$1"
  local timeout_seconds="${2:-120}"
  local deadline=$((SECONDS + timeout_seconds))

  while ((SECONDS < deadline)); do
    if adb -s "$DEVICE_ID" logcat -d 2>/dev/null | grep -Fq "$pattern"; then
      echo "Saw logcat: $pattern"
      return 0
    fi
  done

  echo "Timed out waiting for logcat: $pattern" >&2
  adb -s "$DEVICE_ID" logcat -d 2>/dev/null | tail -200 >&2 || true
  return 1
}

run_logcat_background_color_e2e() {
  local main_activity="${CAPGO_MAESTRO_ANDROID_MAIN_ACTIVITY:-.MainActivity}"

  adb -s "$DEVICE_ID" logcat -c >/dev/null 2>&1 || true
  adb -s "$DEVICE_ID" shell pm clear "$APP_ID" >/dev/null 2>&1 || true
  adb -s "$DEVICE_ID" shell am start -n "${APP_ID}/${main_activity}" -a android.intent.action.MAIN -c android.intent.category.LAUNCHER

  wait_for_logcat_line 'CAPGO_E2E E2E: auto start' 90
  wait_for_logcat_line 'CAPGO_E2E E2E: open-with-color ok' 120
  wait_for_logcat_line 'CAPGO_E2E E2E: open-without-color ok' 120
  wait_for_logcat_line 'CAPGO_E2E E2E: invalid-color ok' 120
  wait_for_logcat_line 'CAPGO_E2E E2E: auto complete' 120

  cat >"$RESULTS_DIR/junit.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="background-color-logcat" tests="3" failures="0" />
EOF
}

if [[ "$SKIP_BUILD" != "1" ]]; then
  if [[ ! -d "$ROOT_DIR/node_modules" ]]; then
    (cd "$ROOT_DIR" && bun install)
  fi

  (cd "$ROOT_DIR" && bun run build)

  (
    cd "$EXAMPLE_DIR"
    bun install
    bun run build
    if [[ ! -d android ]]; then
      bunx cap add android
    fi
    bunx cap sync android
    cd android
    ./gradlew assembleDebug
  )
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "Expected Android debug APK at $APK_PATH" >&2
  exit 1
fi

wait_for_device

adb -s "$DEVICE_ID" shell settings put global window_animation_scale 0 >/dev/null 2>&1 || true
adb -s "$DEVICE_ID" shell settings put global transition_animation_scale 0 >/dev/null 2>&1 || true
adb -s "$DEVICE_ID" shell settings put global animator_duration_scale 0 >/dev/null 2>&1 || true
adb -s "$DEVICE_ID" install -r "$APK_PATH"
adb -s "$DEVICE_ID" shell am force-stop "$APP_ID" >/dev/null 2>&1 || true

rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

if [[ "$USE_LOGCAT_E2E" == "1" ]]; then
  run_logcat_background_color_e2e
  exit 0
fi

ANDROID_SERIAL="$DEVICE_ID" MAESTRO_CLI_NO_ANALYTICS=1 maestro test \
  "$FLOW_PATH" \
  --debug-output "$RESULTS_DIR/artifacts" \
  --flatten-debug-output \
  --format junit \
  --output "$RESULTS_DIR/junit.xml"