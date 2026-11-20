#!/usr/bin/env bash

set -euo pipefail

preferred_names=(
  'Capgo Maestro iPhone'
  'iPhone SE (3rd generation)'
  'iPhone 15'
  'iPhone 14'
  'iPhone 16'
  'iPhone 13'
)

available_devices="$(xcrun simctl list devices available)"
device_line_regex='^[[:space:]]*(.*)[[:space:]]\(([0-9A-F-]{36})\)[[:space:]]\([^)]*\)[[:space:]]*$'

find_existing_device() {
  local preferred_name="$1"
  local line=""
  local name=""
  local simulator_id=""

  while IFS= read -r line; do
    if [[ "$line" =~ $device_line_regex ]]; then
      name="${BASH_REMATCH[1]}"
      simulator_id="${BASH_REMATCH[2]}"
      if [[ "$name" == "$preferred_name" ]]; then
        printf '%s\n' "$simulator_id"
        return 0
      fi
    fi
  done <<<"$available_devices"
}

for preferred_name in "${preferred_names[@]}"; do
  simulator_id="$(find_existing_device "$preferred_name")"
  if [[ -n "$simulator_id" ]]; then
    printf '%s\n' "$simulator_id"
    exit 0
  fi
done

while IFS= read -r line; do
  if [[ "$line" =~ $device_line_regex ]]; then
    name="${BASH_REMATCH[1]}"
    simulator_id="${BASH_REMATCH[2]}"
    if [[ "$name" == iPhone* ]]; then
      printf '%s\n' "$simulator_id"
      exit 0
    fi
  fi
done <<<"$available_devices"

echo "No available iPhone simulator found." >&2
exit 1