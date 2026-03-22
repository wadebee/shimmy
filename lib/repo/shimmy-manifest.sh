#!/usr/bin/env bash

shimmy::_find_install_manifest() {
  local -a install_dirs=()
  local candidate_install_dir
  local manifest_file

  if [[ -n "${INSTALL_MANIFEST_FILE:-}" && -f "${INSTALL_MANIFEST_FILE:-}" ]]; then
    printf '%s\n' "$INSTALL_MANIFEST_FILE"
    return 0
  fi

  if [[ -n "${SHIMMY_INSTALL_DIR:-}" ]]; then
    install_dirs+=("$(shimmy::_trim_trailing_slash "$SHIMMY_INSTALL_DIR")")
  fi
  if candidate_install_dir="$(shimmy::_infer_install_dir_from_layout_dir "${SHIMMY_SHIM_DIR:-}" "shims")"; then
    install_dirs+=("$candidate_install_dir")
  fi
  if candidate_install_dir="$(shimmy::_infer_install_dir_from_layout_dir "${SHIMMY_IMAGES_DIR:-}" "images")"; then
    install_dirs+=("$candidate_install_dir")
  fi
  if candidate_install_dir="$(shimmy::_infer_install_dir_from_layout_suffix "${SHIMMY_SHIM_LIB_DIR:-}" "lib/shims")"; then
    install_dirs+=("$candidate_install_dir")
  fi
  if [[ -n "${DEFAULT_INSTALL_DIR:-}" ]]; then
    install_dirs+=("$(shimmy::_trim_trailing_slash "$DEFAULT_INSTALL_DIR")")
  fi

  for candidate_install_dir in "${install_dirs[@]}"; do
    [[ -n "$candidate_install_dir" ]] || continue
    manifest_file="$(shimmy::_manifest_file_for_install_dir "$candidate_install_dir")"
    if [[ -f "$manifest_file" ]]; then
      printf '%s\n' "$manifest_file"
      return 0
    fi
  done

  return 1
}

shimmy::_manifest_file_for_install_dir() {
  local install_dir="${1:?install dir is required}"

  printf '%s/install-manifest.txt\n' "$(shimmy::_trim_trailing_slash "$install_dir")"
}

shimmy::apply_install_layout_from_manifest() {
  local manifest_file="${1:-$INSTALL_MANIFEST_FILE}"
  local images_dir
  local install_dir
  local shim_dir
  local shim_lib_dir

  [[ -f "$manifest_file" ]] || return 1

  install_dir="$(shimmy::manifest_value "$manifest_file" install_dir || true)"
  shim_dir="$(shimmy::manifest_value "$manifest_file" shim_dir || true)"
  images_dir="$(shimmy::manifest_value "$manifest_file" images_dir || true)"
  shim_lib_dir="$(shimmy::manifest_value "$manifest_file" shim_lib_dir || true)"

  [[ -n "$install_dir" ]] || return 1

  SHIMMY_INSTALL_DIR="$install_dir"
  if [[ -n "$shim_dir" ]]; then
    SHIMMY_SHIM_DIR="$shim_dir"
  fi
  if [[ -n "$images_dir" ]]; then
    SHIMMY_IMAGES_DIR="$images_dir"
  fi
  if [[ -n "$shim_lib_dir" ]]; then
    SHIMMY_SHIM_LIB_DIR="$shim_lib_dir"
  fi

  shimmy::init_install_vars "$SHIMMY_INSTALL_DIR"
}

shimmy::discover_install_layout() {
  local requested_install_dir="${1:-}"
  local manifest_file

  shimmy::init_install_vars "$requested_install_dir"

  manifest_file="$(shimmy::_find_install_manifest || true)"
  if [[ -n "$manifest_file" ]]; then
    shimmy::apply_install_layout_from_manifest "$manifest_file"
  fi
}

shimmy::manifest_value() {
  local manifest_file="${1:?manifest file is required}"
  local key="${2:?manifest key is required}"

  [[ -f "$manifest_file" ]] || return 1

  sed -n "s/^${key}=//p" "$manifest_file" | head -n 1
}
