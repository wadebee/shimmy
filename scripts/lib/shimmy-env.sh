#!/usr/bin/env bash

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
  SHIMMY_RUNTIME_DIR="$SHIMMY_INSTALL_DIR"
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

shimmy_render_shell_init_block() {
  local shimmy_bash_file="${1:?shimmy bash file is required}"

  printf '\n'
  printf '%s\n' "$SHELL_INIT_BLOCK_START"
  shimmy_shell_init_source_line "$shimmy_bash_file"
  printf '%s\n' "$SHELL_INIT_BLOCK_END"
}

shimmy_render_path_block() {
  local shim_dir="${1:?shim dir is required}"

  printf '\n'
  printf '%s\n' "$PATH_BLOCK_START"
  shimmy_path_block_guard_line "$shim_dir"
  printf '%s\n' '  case ":$PATH:" in'
  printf '%s\n' "    *\":$shim_dir:\"*) ;;"
  shimmy_path_block_export_line "$shim_dir"
  printf '%s\n' '  esac'
  printf '%s\n' 'fi'
  printf '%s\n' "$PATH_BLOCK_END"
}
