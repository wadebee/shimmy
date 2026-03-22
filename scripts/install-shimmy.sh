#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/repo/shimmy-env.sh
source "$SCRIPT_DIR/../lib/repo/shimmy-env.sh"

shimmy::log_init
shimmy::init_repo_vars "$(shimmy::repo_root_from_script_path "${BASH_SOURCE[0]}")"
shimmy::init_home_vars "$HOME"
shimmy::init_install_vars "${SHIMMY_INSTALL_DIR:-}"

INSTALL_MODE='copy'
UPDATE_BASHRC=1
UNINSTALL=0
REQUESTED_INSTALL_DIR="${SHIMMY_INSTALL_DIR:-}"
REQUESTED_SHIMS=()
SHELL_FILES_CREATED_PATHS=()

usage() {
  cat <<'EOF'
Install shimmy CLI shims into a user profile directory.

Usage:
  scripts/install-shimmy.sh [options]

Options:
  --install-dir <dir>    Destination directory for installed shims.
                         Default: ~/.config/shimmy
  --symlink              Install shims as symlinks to this repo.
  --copy                 Install shims by copying files (default).
  --uninstall            Remove shimmy artifacts instead of installing them.
  --shim <name>          Install only the named shim. Repeatable.
  --update-bashrc        Update ~/.bashrc, ~/.bash_profile, and ~/.bashrc_shimmy (default).
  --no-update-bashrc     Do not edit Bash startup files.
  --bashrc-file <file>   Bash rc file to update (default: ~/.bashrc).
  --bash-profile-file <file>
                         Bash profile file to update (default: ~/.bash_profile).
  --bash-shimmy-file <file>
                         Managed shim PATH file (default: ~/.bashrc_shimmy).
  -h, --help             Show help.
EOF
}

fail() {
  shimmy::log_error "$*"
  return 1
}

log_debug() {
  shimmy::log_debug "$*"
}

log_info() {
  shimmy::log_info "$*"
}

record_shell_file_created_path() {
  SHELL_FILES_CREATED_PATHS+=("$1")
}

remove_managed_path_dir() {
  local dir="$1"
  local description="$2"

  if [[ ! -e "$dir" ]]; then
    log_debug "$description directory not present; nothing to remove: $dir"
    return 0
  fi

  log_debug "Removing $description directory: $dir"
  rm -rf "$dir"
  shimmy::dir_parent_empty_remove "$(dirname "$dir")" "$HOME"
}

remove_install_dir() {
  if [[ ! -e "$SHIMMY_INSTALL_DIR" ]]; then
    log_debug "Install directory not present; nothing to remove: $SHIMMY_INSTALL_DIR"
    return 0
  fi
  log_debug "Removing install directory: $SHIMMY_INSTALL_DIR"
  rm -rf "$SHIMMY_INSTALL_DIR"
  shimmy::dir_parent_empty_remove "$(dirname "$SHIMMY_INSTALL_DIR")" "$HOME"
}

remove_shell_artifacts() {
  log_debug "Removing managed shell artifacts from Bash startup files"
  shimmy::managed_block_remove "$BASHRC_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
  shimmy::managed_block_remove "$BASH_PROFILE_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
  shimmy::managed_block_remove "$SHIMMY_BASH_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"

  if shimmy::is_install_manifest_path_listed "$INSTALL_MANIFEST_FILE" "created_shell_file" "$BASHRC_FILE"; then
    log_debug "Cleaning up shell file recorded as created: $BASHRC_FILE"
    shimmy::file_delete_if_empty "$BASHRC_FILE"
  else
    log_debug "Shell file was not recorded as created; leaving file in place: $BASHRC_FILE"
  fi
  if shimmy::is_install_manifest_path_listed "$INSTALL_MANIFEST_FILE" "created_shell_file" "$BASH_PROFILE_FILE"; then
    log_debug "Cleaning up shell file recorded as created: $BASH_PROFILE_FILE"
    shimmy::file_delete_if_empty "$BASH_PROFILE_FILE"
  else
    log_debug "Shell file was not recorded as created; leaving file in place: $BASH_PROFILE_FILE"
  fi
  # This file is shimmy-managed; remove it whenever uninstall leaves it empty,
  # even if it existed before install.
  shimmy::file_delete_if_empty "$SHIMMY_BASH_FILE"
}

remove_profile_dir_if_empty() {
  if [[ ! -d "$SHIMMY_INSTALL_DIR" ]]; then
    log_debug "Profile directory not present; nothing to remove: $SHIMMY_INSTALL_DIR"
    return 0
  fi
  if rmdir "$SHIMMY_INSTALL_DIR" 2>/dev/null; then
    log_debug "Removed empty profile directory: $SHIMMY_INSTALL_DIR"
  else
    log_debug "Profile directory not empty; leaving in place: $SHIMMY_INSTALL_DIR"
  fi
  shimmy::dir_parent_empty_remove "$(dirname "$SHIMMY_INSTALL_DIR")" "$HOME"
}

shim_is_requested() {
  local shim_name="$1"
  local requested

  if [[ "${#REQUESTED_SHIMS[@]}" -eq 0 ]]; then
    return 0
  fi

  for requested in "${REQUESTED_SHIMS[@]}"; do
    if [[ "$requested" == "$shim_name" ]]; then
      return 0
    fi
  done

  return 1
}

install_shim_helper_support() {
  local image_dest="$SHIMMY_IMAGES_DIR"
  local shim_lib_dest="$SHIMMY_SHIM_LIB_DIR"
  local image_src image_name

  log_debug "Refreshing local container image support in $image_dest using mode $INSTALL_MODE"
  rm -rf "$image_dest"
  log_debug "Refreshing shared shim helper support in $shim_lib_dest using mode $INSTALL_MODE"
  rm -rf "$shim_lib_dest"

  if [[ "$INSTALL_MODE" == "copy" ]]; then
    mkdir -p "$image_dest"
    while IFS= read -r image_src; do
      image_name="$(basename "$image_src")"
      if shim_is_requested "$image_name"; then
        log_debug "Copying local container image support from $image_src to $image_dest/$image_name"
        cp -a "$image_src" "$image_dest/$image_name"
      fi
    done < <(find "$SOURCE_IMAGES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
    log_debug "Copying shared shim helper support from $SOURCE_SHIM_LIB_DIR to $shim_lib_dest"
    mkdir -p "$shim_lib_dest"
    cp -a "$SOURCE_SHIM_LIB_DIR"/. "$shim_lib_dest"/
  else
    mkdir -p "$image_dest"
    while IFS= read -r image_src; do
      image_name="$(basename "$image_src")"
      if shim_is_requested "$image_name"; then
        log_debug "Symlinking local container image support from $image_src to $image_dest/$image_name"
        ln -s "$image_src" "$image_dest/$image_name"
      fi
    done < <(find "$SOURCE_IMAGES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
    log_debug "Symlinking shared shim helper support from $SOURCE_SHIM_LIB_DIR to $shim_lib_dest"
    mkdir -p "$(dirname "$shim_lib_dest")"
    ln -s "$SOURCE_SHIM_LIB_DIR" "$shim_lib_dest"
  fi
}

perform_install() {
  local dest shim src

  log_info "Starting install into $SHIMMY_INSTALL_DIR with mode $INSTALL_MODE"
  [[ -d "$SOURCE_SHIMS_DIR" ]] || fail "shim source directory not found: $SOURCE_SHIMS_DIR"
  [[ -d "$SOURCE_IMAGES_DIR" ]] || fail "local container image source directory not found: $SOURCE_IMAGES_DIR"
  [[ -d "$SOURCE_SHIM_LIB_DIR" ]] || fail "shim helper library directory not found: $SOURCE_SHIM_LIB_DIR"

  mkdir -p "$SHIMMY_SHIM_DIR"
  while IFS= read -r src; do
    shim="$(basename "$src")"
    if ! shim_is_requested "$shim"; then
      log_debug "Skipping unrequested shim: $shim"
      continue
    fi
    dest="$SHIMMY_SHIM_DIR/$shim"
    [[ -f "$src" ]] || fail "missing shim: $src"

    if [[ "$INSTALL_MODE" == "copy" ]]; then
      log_debug "Copying shim $shim from $src to $dest"
      install -m 0755 "$src" "$dest"
    else
      log_debug "Symlinking shim $shim from $src to $dest"
      ln -sfn "$src" "$dest"
    fi
  done < <(find "$SOURCE_SHIMS_DIR" -type f | sort)

  install_shim_helper_support

  if [[ "$UPDATE_BASHRC" == "1" ]]; then
    log_debug "Updating Bash startup files"
    mkdir -p "$(dirname "$BASHRC_FILE")" "$(dirname "$BASH_PROFILE_FILE")" "$(dirname "$SHIMMY_BASH_FILE")"
    if [[ -e "$BASHRC_FILE" ]]; then
      log_debug "Using existing bashrc file: $BASHRC_FILE"
    else
      log_debug "Recording new bashrc file for cleanup tracking: $BASHRC_FILE"
      record_shell_file_created_path "$BASHRC_FILE"
    fi
    if [[ -e "$BASH_PROFILE_FILE" ]]; then
      log_debug "Using existing bash profile file: $BASH_PROFILE_FILE"
    else
      log_debug "Recording new bash profile file for cleanup tracking: $BASH_PROFILE_FILE"
      record_shell_file_created_path "$BASH_PROFILE_FILE"
    fi
    if [[ -e "$SHIMMY_BASH_FILE" ]]; then
      log_debug "Using existing shimmy shell file: $SHIMMY_BASH_FILE"
    else
      log_debug "Recording new shimmy shell file for cleanup tracking: $SHIMMY_BASH_FILE"
      record_shell_file_created_path "$SHIMMY_BASH_FILE"
    fi
    touch "$BASHRC_FILE"
    touch "$BASH_PROFILE_FILE"
    touch "$SHIMMY_BASH_FILE"

    shimmy::managed_block_remove "$BASHRC_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
    shimmy::managed_block_remove "$BASH_PROFILE_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
    shimmy::managed_block_remove "$SHIMMY_BASH_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"
    shimmy::managed_block_remove "$BASHRC_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"
    shimmy::managed_block_remove "$BASH_PROFILE_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"

    shimmy::shell_init_block_append "$BASHRC_FILE" "$SHIMMY_BASH_FILE"
    shimmy::shell_init_block_append "$BASH_PROFILE_FILE" "$SHIMMY_BASH_FILE"
    shimmy::path_block_append \
      "$SHIMMY_BASH_FILE" \
      "$SHIMMY_SHIM_DIR" \
      "$SHIMMY_INSTALL_DIR" \
      "$SHIMMY_IMAGES_DIR" \
      "$SHIMMY_SHIM_LIB_DIR"
  else
    log_debug "Skipping Bash startup file updates because Bash profile management was not requested"
    if [[ -d "$SHIMMY_SHIM_DIR" ]]; then
      case ":$PATH:" in
        *":$SHIMMY_SHIM_DIR:"*) ;;
        *) export PATH="$PATH:$SHIMMY_SHIM_DIR" ;;
      esac
    fi
  fi

  shimmy::install_manifest_write \
    "$INSTALL_MANIFEST_FILE" \
    "$SHIMMY_INSTALL_DIR" \
    "$SHIMMY_SHIM_DIR" \
    "$SHIMMY_IMAGES_DIR" \
    "$SHIMMY_SHIM_LIB_DIR" \
    "$INSTALL_MODE" \
    "$UPDATE_BASHRC" \
    "$BASHRC_FILE" \
    "$BASH_PROFILE_FILE" \
    "$SHIMMY_BASH_FILE" \
    "REQUESTED_SHIMS" \
    "SHELL_FILES_CREATED_PATHS"

  log_info "Installed shims into $SHIMMY_INSTALL_DIR ($INSTALL_MODE)."
}

perform_uninstall() {
  log_debug "Starting uninstall for install dir $SHIMMY_INSTALL_DIR"
  shimmy::install_manifest_profile_files_delete "$INSTALL_MANIFEST_FILE" "$SHIMMY_INSTALL_DIR"
  remove_shell_artifacts
  log_debug "Removing install manifest file: $INSTALL_MANIFEST_FILE"
  rm -f "$INSTALL_MANIFEST_FILE"
  if ! shimmy::is_path_within "$SHIMMY_INSTALL_DIR" "$SHIMMY_SHIM_DIR"; then
    remove_managed_path_dir "$SHIMMY_SHIM_DIR" "shim"
  fi
  if ! shimmy::is_path_within "$SHIMMY_INSTALL_DIR" "$SHIMMY_IMAGES_DIR"; then
    remove_managed_path_dir "$SHIMMY_IMAGES_DIR" "image"
  fi
  if ! shimmy::is_path_within "$SHIMMY_INSTALL_DIR" "$SHIMMY_SHIM_LIB_DIR"; then
    remove_managed_path_dir "$SHIMMY_SHIM_LIB_DIR" "shim helper library"
  fi
  remove_install_dir
  remove_profile_dir_if_empty

  log_info "Removed shimmy artifacts from $SHIMMY_INSTALL_DIR."
  log_info "Cleaned Bash startup files: $BASHRC_FILE, $BASH_PROFILE_FILE, $SHIMMY_BASH_FILE."
}

# Parse command line arguments into vars for conditional logic  
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      [[ $# -ge 2 ]] || fail "missing value for --install-dir"
      REQUESTED_INSTALL_DIR="$2"
      shift 2
      ;;
    --symlink)
      INSTALL_MODE="symlink"
      shift
      ;;
    --copy)
      INSTALL_MODE="copy"
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    --shim)
      [[ $# -ge 2 ]] || fail "missing value for --shim"
      REQUESTED_SHIMS+=("$2")
      shift 2
      ;;
    --update-bashrc)
      UPDATE_BASHRC=1
      shift
      ;;
    --no-update-bashrc)
      UPDATE_BASHRC=0
      shift
      ;;
    --bashrc-file)
      [[ $# -ge 2 ]] || fail "missing value for --bashrc-file"
      BASHRC_FILE="$2"
      shift 2
      ;;
    --bash-profile-file)
      [[ $# -ge 2 ]] || fail "missing value for --bash-profile-file"
      BASH_PROFILE_FILE="$2"
      shift 2
      ;;
    --bash-shimmy-file)
      [[ $# -ge 2 ]] || fail "missing value for --bash-shimmy-file"
      SHIMMY_BASH_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

shimmy::init_install_vars "$REQUESTED_INSTALL_DIR"

if [[ "$UNINSTALL" -eq 1 ]]; then
  shimmy::apply_install_paths_from_manifest "$INSTALL_MANIFEST_FILE" || true
  perform_uninstall
else
  perform_install
fi
