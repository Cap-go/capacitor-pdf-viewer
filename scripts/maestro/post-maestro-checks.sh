#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESULTS_DIR="${1:-$ROOT_DIR/maestro-results}"
ARTIFACTS_DIR="$RESULTS_DIR/artifacts"

find_shot() {
  local name="$1"
  find "$RESULTS_DIR" -type f -name "${name}*.png" 2>/dev/null | head -n 1
}

CUSTOM_SHOT="$(find_shot e2e-custom-bg-open || true)"
DEFAULT_SHOT="$(find_shot e2e-default-bg-open || true)"

if [[ -z "$CUSTOM_SHOT" || -z "$DEFAULT_SHOT" ]]; then
  echo "Maestro screenshots missing under $ARTIFACTS_DIR" >&2
  find "$ARTIFACTS_DIR" -type f -name '*.png' 2>/dev/null | head -20 >&2 || true
  exit 1
fi

echo "Custom color screenshot: $CUSTOM_SHOT"
echo "Default background screenshot: $DEFAULT_SHOT"

bun "$ROOT_DIR/scripts/maestro/check-margin-pixel.mjs" "$CUSTOM_SHOT" 51 85 119
if [[ "${CAPGO_MAESTRO_PIXEL_NEGATIVE:-0}" == "1" ]]; then
  set +e
  CAPGO_MAESTRO_PIXEL_SPOT=1 bun "$ROOT_DIR/scripts/maestro/check-margin-pixel.mjs" "$CUSTOM_SHOT" 0 0 0
  NEG_EXIT=$?
  set -e
  if [[ "$NEG_EXIT" -eq 0 ]]; then
    echo "Expected deliberate wrong-color pixel check to fail" >&2
    exit 1
  fi
  echo "Deliberate wrong-color pixel check failed as expected (exit $NEG_EXIT)"
fi

PLATFORM_SLUG="${CAPGO_MAESTRO_PLATFORM:-unknown}"
DOCS_DIR="$ROOT_DIR/docs/screenshots"
mkdir -p "$DOCS_DIR"
cp "$DEFAULT_SHOT" "$DOCS_DIR/bg-color-before-${PLATFORM_SLUG}.png"
cp "$CUSTOM_SHOT" "$DOCS_DIR/bg-color-after-${PLATFORM_SLUG}.png"