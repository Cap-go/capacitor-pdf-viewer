#!/usr/bin/env bash
# Shared pack-and-install flow for CI example-app verification and capture prep.
# Sources must set repo_root and tmp_root before calling pack_plugin_example_app.

pack_plugin_example_app() {
  local repo_root="$1"
  local tmp_root="$2"
  local pack_dir="$tmp_root/plugin-package"
  local packed_packages
  local plugin_name

  test_app="$tmp_root/plugin-example-app"

  cd "$repo_root"

  bun run build

  rm -rf "$pack_dir" "$test_app"
  mkdir -p "$pack_dir" "$test_app"
  bun pm pack --destination "$pack_dir" --quiet

  shopt -s nullglob
  packed_packages=("$pack_dir"/*.tgz)
  shopt -u nullglob
  if [ "${#packed_packages[@]}" -ne 1 ]; then
    echo "Expected exactly one package tarball, found ${#packed_packages[@]}"
    exit 1
  fi

  plugin_name="$(bun -e 'console.log(require("./package.json").name)')"
  cp -R example-app/. "$test_app/"
  cd "$test_app"
  bun remove "$plugin_name"
  bun add "${packed_packages[0]}"
}
