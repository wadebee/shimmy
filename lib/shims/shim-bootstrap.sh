#!/usr/bin/env bash

shimmy::shim_helper_source() {
  local helper_file_name="${1:?helper file name is required}"
  local helper_file_path

  helper_file_path="${SHIMMY_SHIM_LIB_DIR:?SHIMMY_SHIM_LIB_DIR must be set}/$helper_file_name"
  if [[ ! -f "$helper_file_path" ]]; then
    printf 'ERROR: missing shim helper: %s\n' "$helper_file_path" >&2
    return 1
  fi

  # shellcheck disable=SC1090
  source "$helper_file_path"
}

shimmy::shim_layout_init() {
  local script_path="${1:?script path is required}"
  local shim_install_dir
  local shim_script_dir

  shim_script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd)"
  if [[ -n "${SHIMMY_INSTALL_DIR:-}" ]]; then
    shim_install_dir="${SHIMMY_INSTALL_DIR%/}"
  else
    shim_install_dir="$(cd -- "$shim_script_dir/.." && pwd)"
  fi

  SHIMMY_INSTALL_DIR="$shim_install_dir"
  SHIMMY_IMAGES_DIR="${SHIMMY_IMAGES_DIR:-$SHIMMY_INSTALL_DIR/images}"
  SHIMMY_SHIM_LIB_DIR="${SHIMMY_SHIM_LIB_DIR:-$SHIMMY_INSTALL_DIR/lib/shims}"

  export SHIMMY_IMAGES_DIR SHIMMY_INSTALL_DIR SHIMMY_SHIM_LIB_DIR
}
