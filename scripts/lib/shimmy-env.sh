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
  SOURCE_RUNTIME_DIR="$SOURCE_ROOT_DIR/runtime"
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

shimmy_init_install_vars() {
  local install_dir="${1:-$DEFAULT_INSTALL_DIR}"

  SHIMMY_INSTALL_DIR="${install_dir%/}"
  SHIMMY_IMAGES_DIR="$SHIMMY_INSTALL_DIR/images"
  SHIMMY_SHIM_DIR="$SHIMMY_INSTALL_DIR/shims"
  SHIMMY_RUNTIME_DIR="$SHIMMY_INSTALL_DIR/runtime"
  INSTALL_MANIFEST_FILE="$SHIMMY_INSTALL_DIR/install-manifest.txt"

  export SHIMMY_INSTALL_DIR SHIMMY_IMAGES_DIR SHIMMY_SHIM_DIR SHIMMY_RUNTIME_DIR
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

shimmy_runtime_dir_export_line() {
  local runtime_dir="${1:?runtime dir is required}"

  printf 'export SHIMMY_RUNTIME_DIR="%s"\n' "$runtime_dir"
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
  local runtime_dir="${4:?runtime dir is required}"

  printf '\n'
  printf '%s\n' "$PATH_BLOCK_START"
  shimmy_install_dir_export_line "$install_dir"
  shimmy_shim_dir_export_line "$shim_dir"
  shimmy_images_dir_export_line "$images_dir"
  shimmy_runtime_dir_export_line "$runtime_dir"
  shimmy_path_block_guard_line "$shim_dir"
  printf '%s\n' '  case ":$PATH:" in'
  printf '%s\n' "    *\":$shim_dir:\"*) ;;"
  shimmy_path_block_export_line "$shim_dir"
  printf '%s\n' '  esac'
  printf '%s\n' 'fi'
  printf '%s\n' "$PATH_BLOCK_END"
}
