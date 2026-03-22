#!/usr/bin/env bash

shimmy_log_level_value() {
  case "${1:-info}" in
    debug) printf '10\n' ;;
    info) printf '20\n' ;;
    warn|warning) printf '30\n' ;;
    error) printf '40\n' ;;
    silent|quiet|none) printf '50\n' ;;
    *) printf '20\n' ;;
  esac
}

shimmy_log_normalize_level() {
  case "${1:-info}" in
    debug) printf 'debug\n' ;;
    info) printf 'info\n' ;;
    warn|warning) printf 'warn\n' ;;
    error) printf 'error\n' ;;
    silent|quiet|none) printf 'silent\n' ;;
    *) printf 'info\n' ;;
  esac
}

shimmy_log_init() {
  LOG_LEVEL="$(shimmy_log_normalize_level "${LOG_LEVEL:-info}")"
  export LOG_LEVEL
}

shimmy_should_log() {
  local message_level="${1:?message level is required}"
  local configured_level

  configured_level="$(shimmy_log_normalize_level "${LOG_LEVEL:-info}")"
  [[ "$(shimmy_log_level_value "$message_level")" -ge "$(shimmy_log_level_value "$configured_level")" ]]
}

shimmy_log() {
  local level="${1:?log level is required}"
  shift

  shimmy_should_log "$level" || return 0

  printf '%s: %s\n' "$(tr '[:lower:]' '[:upper:]' <<< "$level")" "$*" >&2
}

shimmy_log_debug() {
  shimmy_log debug "$@"
}

shimmy_log_info() {
  shimmy_log info "$@"
}

shimmy_log_warn() {
  shimmy_log warn "$@"
}

shimmy_log_error() {
  shimmy_log error "$@"
}

shimmy_repo_root_from_script_path() {
  local script_path="${1:?script path is required}"

  (
    cd -- "$(dirname -- "$script_path")/.." && pwd
  )
}

shimmy_init_repo_vars() {
  local root_dir="${1:?repository root is required}"

  SOURCE_ROOT_DIR="${root_dir%/}"
  SOURCE_SHIMS_DIR="$SOURCE_ROOT_DIR/shims"
  SOURCE_IMAGES_DIR="$SOURCE_ROOT_DIR/images"
  SOURCE_SHIM_LIB_DIR="$SOURCE_ROOT_DIR/lib/shims"
  SOURCE_DOCS_DIR="$SOURCE_ROOT_DIR/docs"
  SOURCE_SKILLS_DIR="$SOURCE_ROOT_DIR/.agents"
  SOURCE_AGENTS="$SOURCE_ROOT_DIR/AGENTS.md"
  ROOT_DIR="$SOURCE_ROOT_DIR"
}

shimmy_init_home_vars() {
  local home_dir="${1:-$HOME}"

  BASHRC_FILE="$home_dir/.bashrc"
  BASH_PROFILE_FILE="$home_dir/.bash_profile"
  SHIMMY_BASH_FILE="$home_dir/.bashrc_shimmy"
  DEFAULT_INSTALL_DIR="$home_dir/.config/shimmy"
}

shimmy_trim_trailing_slash() {
  local path="${1:-}"

  if [[ -z "$path" || "$path" == "/" ]]; then
    printf '%s\n' "$path"
    return 0
  fi

  printf '%s\n' "${path%/}"
}

shimmy_infer_install_dir_from_layout_dir() {
  local path="${1:-}"
  local expected_basename="${2:?expected basename is required}"

  path="$(shimmy_trim_trailing_slash "$path")"
  [[ -n "$path" ]] || return 1
  [[ "$(basename "$path")" == "$expected_basename" ]] || return 1

  dirname "$path"
}

shimmy_infer_install_dir_from_layout_suffix() {
  local path="${1:-}"
  local expected_suffix="${2:?expected suffix is required}"
  local suffix_pattern
  local install_dir

  path="$(shimmy_trim_trailing_slash "$path")"
  [[ -n "$path" ]] || return 1

  suffix_pattern="/${expected_suffix#/}"
  [[ "$path" == *"$suffix_pattern" ]] || return 1

  install_dir="${path%"$suffix_pattern"}"
  if [[ -z "$install_dir" ]]; then
    install_dir="/"
  fi

  printf '%s\n' "$install_dir"
}

shimmy_layout_dir_from_install_dir() {
  local install_dir="${1:?install dir is required}"
  local subdir_name="${2:?subdir name is required}"

  printf '%s/%s\n' "$(shimmy_trim_trailing_slash "$install_dir")" "$subdir_name"
}

shimmy_resolve_layout_dir() {
  local current_value="${1:-}"
  local previous_install_dir="${2:-}"
  local subdir_name="${3:?subdir name is required}"
  local fallback_value="${4:?fallback value is required}"

  if [[ -z "$current_value" ]]; then
    printf '%s\n' "$fallback_value"
    return 0
  fi

  current_value="$(shimmy_trim_trailing_slash "$current_value")"

  if [[ -n "$previous_install_dir" ]] && [[ "$current_value" == "$(shimmy_layout_dir_from_install_dir "$previous_install_dir" "$subdir_name")" ]]; then
    printf '%s\n' "$fallback_value"
    return 0
  fi

  printf '%s\n' "$current_value"
}

shimmy_resolve_shim_lib_dir() {
  local current_value="${1:-}"
  local previous_install_dir="${2:-}"
  local fallback_value="${3:?fallback value is required}"
  local current_default_value

  if [[ -z "$current_value" ]]; then
    printf '%s\n' "$fallback_value"
    return 0
  fi

  current_value="$(shimmy_trim_trailing_slash "$current_value")"

  if [[ -n "$previous_install_dir" ]]; then
    current_default_value="$(shimmy_layout_dir_from_install_dir "$previous_install_dir" "lib/shims")"
    if [[ "$current_value" == "$current_default_value" ]]; then
      printf '%s\n' "$fallback_value"
      return 0
    fi
  fi

  printf '%s\n' "$current_value"
}

shimmy_init_install_vars() {
  local requested_install_dir="${1:-}"
  local previous_install_dir="${SHIMMY_INSTALL_DIR:-}"
  local install_dir
  local default_images_dir
  local default_shim_dir
  local default_shim_lib_dir
  local current_shim_lib_dir="${SHIMMY_SHIM_LIB_DIR:-}"

  if [[ -n "$requested_install_dir" ]]; then
    install_dir="$(shimmy_trim_trailing_slash "$requested_install_dir")"
  elif [[ -n "${SHIMMY_INSTALL_DIR:-}" ]]; then
    install_dir="$(shimmy_trim_trailing_slash "$SHIMMY_INSTALL_DIR")"
  elif install_dir="$(shimmy_infer_install_dir_from_layout_dir "${SHIMMY_SHIM_DIR:-}" "shims")"; then
    :
  elif install_dir="$(shimmy_infer_install_dir_from_layout_dir "${SHIMMY_IMAGES_DIR:-}" "images")"; then
    :
  elif install_dir="$(shimmy_infer_install_dir_from_layout_suffix "${SHIMMY_SHIM_LIB_DIR:-}" "lib/shims")"; then
    :
  else
    install_dir="$(shimmy_trim_trailing_slash "$DEFAULT_INSTALL_DIR")"
  fi

  default_images_dir="$install_dir/images"
  default_shim_dir="$install_dir/shims"
  default_shim_lib_dir="$install_dir/lib/shims"

  SHIMMY_INSTALL_DIR="$install_dir"
  SHIMMY_IMAGES_DIR="$(shimmy_resolve_layout_dir "${SHIMMY_IMAGES_DIR:-}" "$previous_install_dir" "images" "$default_images_dir")"
  SHIMMY_SHIM_DIR="$(shimmy_resolve_layout_dir "${SHIMMY_SHIM_DIR:-}" "$previous_install_dir" "shims" "$default_shim_dir")"
  SHIMMY_SHIM_LIB_DIR="$(shimmy_resolve_shim_lib_dir "$current_shim_lib_dir" "$previous_install_dir" "$default_shim_lib_dir")"
  INSTALL_MANIFEST_FILE="$SHIMMY_INSTALL_DIR/install-manifest.txt"

  export SHIMMY_INSTALL_DIR SHIMMY_IMAGES_DIR SHIMMY_SHIM_DIR SHIMMY_SHIM_LIB_DIR
}

shimmy_manifest_file_for_install_dir() {
  local install_dir="${1:?install dir is required}"

  printf '%s/install-manifest.txt\n' "$(shimmy_trim_trailing_slash "$install_dir")"
}

shimmy_manifest_value() {
  local manifest_file="${1:?manifest file is required}"
  local key="${2:?manifest key is required}"

  [[ -f "$manifest_file" ]] || return 1

  sed -n "s/^${key}=//p" "$manifest_file" | head -n 1
}

shimmy_apply_install_layout_from_manifest() {
  local manifest_file="${1:-$INSTALL_MANIFEST_FILE}"
  local install_dir
  local shim_dir
  local images_dir
  local shim_lib_dir

  [[ -f "$manifest_file" ]] || return 1

  install_dir="$(shimmy_manifest_value "$manifest_file" install_dir || true)"
  shim_dir="$(shimmy_manifest_value "$manifest_file" shim_dir || true)"
  images_dir="$(shimmy_manifest_value "$manifest_file" images_dir || true)"
  shim_lib_dir="$(shimmy_manifest_value "$manifest_file" shim_lib_dir || true)"

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

  shimmy_init_install_vars "$SHIMMY_INSTALL_DIR"
}

shimmy_find_install_manifest() {
  local -a install_dirs=()
  local candidate_install_dir
  local manifest_file

  if [[ -n "${INSTALL_MANIFEST_FILE:-}" && -f "${INSTALL_MANIFEST_FILE:-}" ]]; then
    printf '%s\n' "$INSTALL_MANIFEST_FILE"
    return 0
  fi

  if [[ -n "${SHIMMY_INSTALL_DIR:-}" ]]; then
    install_dirs+=("$(shimmy_trim_trailing_slash "$SHIMMY_INSTALL_DIR")")
  fi
  if candidate_install_dir="$(shimmy_infer_install_dir_from_layout_dir "${SHIMMY_SHIM_DIR:-}" "shims")"; then
    install_dirs+=("$candidate_install_dir")
  fi
  if candidate_install_dir="$(shimmy_infer_install_dir_from_layout_dir "${SHIMMY_IMAGES_DIR:-}" "images")"; then
    install_dirs+=("$candidate_install_dir")
  fi
  if candidate_install_dir="$(shimmy_infer_install_dir_from_layout_suffix "${SHIMMY_SHIM_LIB_DIR:-}" "lib/shims")"; then
    install_dirs+=("$candidate_install_dir")
  fi
  if [[ -n "${DEFAULT_INSTALL_DIR:-}" ]]; then
    install_dirs+=("$(shimmy_trim_trailing_slash "$DEFAULT_INSTALL_DIR")")
  fi

  for candidate_install_dir in "${install_dirs[@]}"; do
    [[ -n "$candidate_install_dir" ]] || continue
    manifest_file="$(shimmy_manifest_file_for_install_dir "$candidate_install_dir")"
    if [[ -f "$manifest_file" ]]; then
      printf '%s\n' "$manifest_file"
      return 0
    fi
  done

  return 1
}

shimmy_discover_install_layout() {
  local requested_install_dir="${1:-}"
  local manifest_file

  shimmy_init_install_vars "$requested_install_dir"

  manifest_file="$(shimmy_find_install_manifest || true)"
  if [[ -n "$manifest_file" ]]; then
    shimmy_apply_install_layout_from_manifest "$manifest_file"
  fi
}

SHELL_INIT_BLOCK_START="# >>> shimmy shell init >>>"
SHELL_INIT_BLOCK_END="# <<< shimmy shell init <<<"
PATH_BLOCK_START="# >>> shimmy shims >>>"
PATH_BLOCK_END="# <<< shimmy shims <<<"

shimmy_shell_init_source_line() {
  local shimmy_bash_file="${1:?shimmy bash file is required}"

  printf 'if [ -f "%s" ]; then . "%s"; fi\n' "$shimmy_bash_file" "$shimmy_bash_file"
}

shimmy_path_block_guard_line() {
  local shim_dir="${1:?shim dir is required}"

  printf 'if [ -d "%s" ]; then\n' "$shim_dir"
}

shimmy_path_block_export_line() {
  local shim_dir="${1:?shim dir is required}"

  printf '    *) export PATH="$PATH:%s" ;;\n' "$shim_dir"
}

shimmy_install_dir_export_line() {
  local install_dir="${1:?install dir is required}"

  printf 'export SHIMMY_INSTALL_DIR="%s"\n' "$install_dir"
}

shimmy_shim_dir_export_line() {
  local shim_dir="${1:?shim dir is required}"

  printf 'export SHIMMY_SHIM_DIR="%s"\n' "$shim_dir"
}

shimmy_images_dir_export_line() {
  local images_dir="${1:?images dir is required}"

  printf 'export SHIMMY_IMAGES_DIR="%s"\n' "$images_dir"
}

shimmy_shim_lib_dir_export_line() {
  local shim_lib_dir="${1:?shim lib dir is required}"

  printf 'export SHIMMY_SHIM_LIB_DIR="%s"\n' "$shim_lib_dir"
}

shimmy_render_shell_init_block() {
  local shimmy_bash_file="${1:?shimmy bash file is required}"

  printf '\n'
  printf '%s\n' "$SHELL_INIT_BLOCK_START"
  shimmy_shell_init_source_line "$shimmy_bash_file"
  printf '%s\n' "$SHELL_INIT_BLOCK_END"
}

shimmy_render_path_block() {
  local shim_dir="${1:?shim dir is required}"
  local install_dir="${2:?install dir is required}"
  local images_dir="${3:?images dir is required}"
  local shim_lib_dir="${4:?shim lib dir is required}"

  printf '\n'
  printf '%s\n' "$PATH_BLOCK_START"
  shimmy_install_dir_export_line "$install_dir"
  shimmy_shim_dir_export_line "$shim_dir"
  shimmy_images_dir_export_line "$images_dir"
  shimmy_shim_lib_dir_export_line "$shim_lib_dir"
  shimmy_path_block_guard_line "$shim_dir"
  printf '%s\n' '  case ":$PATH:" in'
  printf '%s\n' "    *\":$shim_dir:\"*) ;;"
  shimmy_path_block_export_line "$shim_dir"
  printf '%s\n' '  esac'
  printf '%s\n' 'fi'
  printf '%s\n' "$PATH_BLOCK_END"
}
