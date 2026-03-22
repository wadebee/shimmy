#!/usr/bin/env bash

PATH_BLOCK_END="# <<< shimmy shims <<<"
PATH_BLOCK_START="# >>> shimmy shims >>>"
SHELL_INIT_BLOCK_END="# <<< shimmy shell init <<<"
SHELL_INIT_BLOCK_START="# >>> shimmy shell init >>>"

shimmy::images_dir_export_line() {
  local images_dir="${1:?images dir is required}"

  printf 'export SHIMMY_IMAGES_DIR="%s"\n' "$images_dir"
}

shimmy::install_dir_export_line() {
  local install_dir="${1:?install dir is required}"

  printf 'export SHIMMY_INSTALL_DIR="%s"\n' "$install_dir"
}

shimmy::path_block_export_line() {
  local shim_dir="${1:?shim dir is required}"

  printf '    *) export PATH="$PATH:%s" ;;\n' "$shim_dir"
}

shimmy::path_block_guard_line() {
  local shim_dir="${1:?shim dir is required}"

  printf 'if [ -d "%s" ]; then\n' "$shim_dir"
}

shimmy::render_path_block() {
  local shim_dir="${1:?shim dir is required}"
  local install_dir="${2:?install dir is required}"
  local images_dir="${3:?images dir is required}"
  local shim_lib_dir="${4:?shim lib dir is required}"

  printf '\n'
  printf '%s\n' "$PATH_BLOCK_START"
  shimmy::install_dir_export_line "$install_dir"
  shimmy::shim_dir_export_line "$shim_dir"
  shimmy::images_dir_export_line "$images_dir"
  shimmy::shim_lib_dir_export_line "$shim_lib_dir"
  shimmy::path_block_guard_line "$shim_dir"
  printf '%s\n' '  case ":$PATH:" in'
  printf '%s\n' "    *\":$shim_dir:\"*) ;;"
  shimmy::path_block_export_line "$shim_dir"
  printf '%s\n' '  esac'
  printf '%s\n' 'fi'
  printf '%s\n' "$PATH_BLOCK_END"
}

shimmy::render_shell_init_block() {
  local shimmy_bash_file="${1:?shimmy bash file is required}"

  printf '\n'
  printf '%s\n' "$SHELL_INIT_BLOCK_START"
  shimmy::shell_init_source_line "$shimmy_bash_file"
  printf '%s\n' "$SHELL_INIT_BLOCK_END"
}

shimmy::shell_init_source_line() {
  local shimmy_bash_file="${1:?shimmy bash file is required}"

  printf 'if [ -f "%s" ]; then . "%s"; fi\n' "$shimmy_bash_file" "$shimmy_bash_file"
}

shimmy::shim_dir_export_line() {
  local shim_dir="${1:?shim dir is required}"

  printf 'export SHIMMY_SHIM_DIR="%s"\n' "$shim_dir"
}

shimmy::shim_lib_dir_export_line() {
  local shim_lib_dir="${1:?shim lib dir is required}"

  printf 'export SHIMMY_SHIM_LIB_DIR="%s"\n' "$shim_lib_dir"
}
