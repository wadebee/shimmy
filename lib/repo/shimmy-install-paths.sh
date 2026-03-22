#!/usr/bin/env bash

shimmy::_infer_install_dir_from_dir_basename() {
  local path="${1:-}"
  local expected_basename="${2:?expected basename is required}"

  path="$(shimmy::_trim_trailing_slash "$path")"
  [[ -n "$path" ]] || return 1
  [[ "$(basename "$path")" == "$expected_basename" ]] || return 1

  dirname "$path"
}

shimmy::_infer_install_dir_from_path_suffix() {
  local path="${1:-}"
  local expected_suffix="${2:?expected suffix is required}"
  local install_dir
  local suffix_pattern

  path="$(shimmy::_trim_trailing_slash "$path")"
  [[ -n "$path" ]] || return 1

  suffix_pattern="/${expected_suffix#/}"
  [[ "$path" == *"$suffix_pattern" ]] || return 1

  install_dir="${path%"$suffix_pattern"}"
  if [[ -z "$install_dir" ]]; then
    install_dir="/"
  fi

  printf '%s\n' "$install_dir"
}

shimmy::_default_path_from_install_dir() {
  local install_dir="${1:?install dir is required}"
  local subdir_name="${2:?subdir name is required}"

  printf '%s/%s\n' "$(shimmy::_trim_trailing_slash "$install_dir")" "$subdir_name"
}

shimmy::_resolve_install_path() {
  local current_value="${1:-}"
  local previous_install_dir="${2:-}"
  local subdir_name="${3:?subdir name is required}"
  local fallback_value="${4:?fallback value is required}"

  if [[ -z "$current_value" ]]; then
    printf '%s\n' "$fallback_value"
    return 0
  fi

  current_value="$(shimmy::_trim_trailing_slash "$current_value")"

  if [[ -n "$previous_install_dir" ]] && [[ "$current_value" == "$(shimmy::_default_path_from_install_dir "$previous_install_dir" "$subdir_name")" ]]; then
    printf '%s\n' "$fallback_value"
    return 0
  fi

  printf '%s\n' "$current_value"
}

shimmy::_resolve_shim_lib_path() {
  local current_value="${1:-}"
  local previous_install_dir="${2:-}"
  local fallback_value="${3:?fallback value is required}"
  local current_default_value

  if [[ -z "$current_value" ]]; then
    printf '%s\n' "$fallback_value"
    return 0
  fi

  current_value="$(shimmy::_trim_trailing_slash "$current_value")"

  if [[ -n "$previous_install_dir" ]]; then
    current_default_value="$(shimmy::_default_path_from_install_dir "$previous_install_dir" "lib/shims")"
    if [[ "$current_value" == "$current_default_value" ]]; then
      printf '%s\n' "$fallback_value"
      return 0
    fi
  fi

  printf '%s\n' "$current_value"
}

shimmy::_trim_trailing_slash() {
  local path="${1:-}"

  if [[ -z "$path" || "$path" == "/" ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  printf '%s\n' "${path%/}"
}

shimmy::init_install_vars() {
  local requested_install_dir="${1:-}"
  local previous_install_dir="${SHIMMY_INSTALL_DIR:-}"
  local current_shim_lib_dir="${SHIMMY_SHIM_LIB_DIR:-}"
  local default_images_dir
  local default_shim_dir
  local default_shim_lib_dir
  local install_dir

  if [[ -n "$requested_install_dir" ]]; then
    install_dir="$(shimmy::_trim_trailing_slash "$requested_install_dir")"
  elif [[ -n "${SHIMMY_INSTALL_DIR:-}" ]]; then
    install_dir="$(shimmy::_trim_trailing_slash "$SHIMMY_INSTALL_DIR")"
  elif install_dir="$(shimmy::_infer_install_dir_from_dir_basename "${SHIMMY_SHIM_DIR:-}" "shims")"; then
    :
  elif install_dir="$(shimmy::_infer_install_dir_from_dir_basename "${SHIMMY_IMAGES_DIR:-}" "images")"; then
    :
  elif install_dir="$(shimmy::_infer_install_dir_from_path_suffix "${SHIMMY_SHIM_LIB_DIR:-}" "lib/shims")"; then
    :
  else
    install_dir="$(shimmy::_trim_trailing_slash "$DEFAULT_INSTALL_DIR")"
  fi

  default_images_dir="$install_dir/images"
  default_shim_dir="$install_dir/shims"
  default_shim_lib_dir="$install_dir/lib/shims"

  SHIMMY_INSTALL_DIR="$install_dir"
  SHIMMY_IMAGES_DIR="$(shimmy::_resolve_install_path "${SHIMMY_IMAGES_DIR:-}" "$previous_install_dir" "images" "$default_images_dir")"
  SHIMMY_SHIM_DIR="$(shimmy::_resolve_install_path "${SHIMMY_SHIM_DIR:-}" "$previous_install_dir" "shims" "$default_shim_dir")"
  SHIMMY_SHIM_LIB_DIR="$(shimmy::_resolve_shim_lib_path "$current_shim_lib_dir" "$previous_install_dir" "$default_shim_lib_dir")"
  INSTALL_MANIFEST_FILE="$SHIMMY_INSTALL_DIR/install-manifest.txt"

  export SHIMMY_IMAGES_DIR SHIMMY_INSTALL_DIR SHIMMY_SHIM_DIR SHIMMY_SHIM_LIB_DIR
}
