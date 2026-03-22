#!/usr/bin/env bash

shimmy::init_home_vars() {
  local home_dir="${1:-$HOME}"

  BASHRC_FILE="$home_dir/.bashrc"
  BASH_PROFILE_FILE="$home_dir/.bash_profile"
  SHIMMY_BASH_FILE="$home_dir/.bashrc_shimmy"
  DEFAULT_INSTALL_DIR="$home_dir/.config/shimmy"
}

shimmy::init_repo_vars() {
  local root_dir="${1:?repository root is required}"

  SOURCE_ROOT_DIR="${root_dir%/}"
  SOURCE_SHIMS_DIR="$SOURCE_ROOT_DIR/shims"
  SOURCE_IMAGES_DIR="$SOURCE_ROOT_DIR/images"
  SOURCE_SHIM_LIB_DIR="$SOURCE_ROOT_DIR/lib/shims"
  SOURCE_DOCS_DIR="$SOURCE_ROOT_DIR/docs"
  SOURCE_SKILLS_DIR="$SOURCE_ROOT_DIR/.agents"
  SOURCE_AGENTS="$SOURCE_ROOT_DIR/AGENTS.md"
  SOURCE_CONTRIBUTING="$SOURCE_ROOT_DIR/CONTRIBUTING.md"
  ROOT_DIR="$SOURCE_ROOT_DIR"
}

shimmy::repo_root_from_script_path() {
  local script_path="${1:?script path is required}"

  (
    cd -- "$(dirname -- "$script_path")/.." && pwd
  )
}
