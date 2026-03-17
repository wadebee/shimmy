#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/shimmy-env.sh
source "$SCRIPT_DIR/lib/shimmy-env.sh"

shimmy_init_repo_vars "$(shimmy_repo_root_from_script_path "${BASH_SOURCE[0]}")"
shimmy_init_home_vars "$HOME"
shimmy_init_install_vars "$DEFAULT_INSTALL_DIR"

INSTALL_MODE='copy'
UPDATE_BASHRC=1
UNINSTALL=0
PROFILE_CREATED_MESSAGES=()
PROFILE_WARNING_MESSAGES=()
PROFILE_CREATED_PATHS=()
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
  echo "Error: $*" >&2
  return 1
}

log_debug() {
  echo "Debug: $*" >&2
}

record_profile_created() {
  PROFILE_CREATED_MESSAGES+=("$1")
}

record_profile_created_path() {
  PROFILE_CREATED_PATHS+=("$1")
}

record_shell_file_created_path() {
  SHELL_FILES_CREATED_PATHS+=("$1")
}

record_profile_warning() {
  PROFILE_WARNING_MESSAGES+=("$1")
}

remove_managed_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp

  if [[ ! -f "$file" ]]; then
    log_debug "Skipping managed block removal; file not found: $file"
    return 0
  fi

  log_debug "Removing managed block from $file using markers [$start_marker] and [$end_marker]"
  tmp="$(mktemp)"
  awk '
    BEGIN { skip=0 }
    $0 == start_marker { skip=1; next }
    $0 == end_marker { skip=0; next }
    skip { next }
    { print }
  ' start_marker="$start_marker" end_marker="$end_marker" "$file" > "$tmp"
  mv "$tmp" "$file"
}

append_shimmy_path_block() {
  log_debug "Appending Shimmy PATH block to $SHIMMY_BASH_FILE pointed at dir $SHIMMY_SHIM_DIR"
  shimmy_render_path_block "$SHIMMY_SHIM_DIR" >> "$SHIMMY_BASH_FILE"
}

append_shell_init_block() {
  local file="$1"

  log_debug "Appending shell init block to $file"
  shimmy_render_shell_init_block "$SHIMMY_BASH_FILE" >> "$file"
}

copy_file_if_missing() {
  local src="$1"
  local dest="$2"

  if [[ -e "$dest" ]]; then
    log_debug "Leaving existing profile file unchanged: $dest"
    record_profile_warning "Warning: profile already exists at $dest; leaving unchanged."
    return
  fi

  log_debug "Installing profile file from $src to $dest"
  mkdir -p "$(dirname "$dest")"
  install -m 0644 "$src" "$dest"
  record_profile_created_path "$dest"
  record_profile_created "Created profile file: $dest"
}

install_repo_profile_files() {
  local src rel dest

  if [[ -f "$SOURCE_AGENTS" ]]; then
    log_debug "Installing repository AGENTS.md into profile directory"
    copy_file_if_missing "$SOURCE_AGENTS" "$SHIMMY_INSTALL_DIR/AGENTS.md"
  else
    log_debug "Repository AGENTS.md not found; skipping profile install"
  fi

  if [[ -d "$SOURCE_SHIMS_DIR" ]]; then
    log_debug "Installing shims from $SOURCE_SHIMS_DIR"
    while IFS= read -r src; do
      rel="${src#$SOURCE_SHIMS_DIR}"
      dest="$SHIMMY_INSTALL_DIR/$rel"
      log_debug "Installing shim from $src to $dest"
      # copy_file_if_missing "$src" "$dest"
    done < <(find "$SOURCE_DOCS_DIR" -type f | sort)
  else
    fail "Shims directory not found; cannot install"
  fi

  if [[ -d "$SOURCE_DOCS_DIR" ]]; then
    log_debug "Installing docs from $SOURCE_DOCS_DIR"
    while IFS= read -r src; do
      rel="${src#$SOURCE_DOCS_DIR}"
      dest="$SHIMMY_INSTALL_DIR/$rel"
      copy_file_if_missing "$src" "$dest"
    done < <(find "$SOURCE_DOCS_DIR" -type f | sort)
  else
    log_debug "Docs source directory not found; skipping docs profile install"
  fi

  if [[ -d "$SOURCE_SKILLS_DIR" ]]; then
    log_debug "Installing AI skills from $SOURCE_SKILLS_DIR"
    while IFS= read -r src; do
      rel="${src#$SOURCE_SKILLS_DIR}"
      dest="$SHIMMY_INSTALL_DIR/$rel"
      copy_file_if_missing "$src" "$dest"
    done < <(find "$SOURCE_SKILLS_DIR" -type f | sort)
  else
    log_debug "Skills source directory not found; skipping skill profile install"
  fi
}

write_install_manifest() {
  log_debug "Writing install manifest to $INSTALL_MANIFEST_FILE"
  mkdir -p "$SHIMMY_INSTALL_DIR"

  {
    printf 'install_dir=%s\n' "$SHIMMY_INSTALL_DIR"
    printf 'bashrc_file=%s\n' "$BASHRC_FILE"
    printf 'bash_profile_file=%s\n' "$BASH_PROFILE_FILE"
    printf 'bash_shimmy_file=%s\n' "$SHIMMY_BASH_FILE"
    for path in "${SHELL_FILES_CREATED_PATHS[@]}"; do
      printf 'created_shell_file=%s\n' "$path"
    done
    for path in "${PROFILE_CREATED_PATHS[@]}"; do
      printf 'created_profile_file=%s\n' "$path"
    done
  } > "$INSTALL_MANIFEST_FILE"
}

remove_file_if_empty() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    log_debug "Skipping empty-file cleanup; file not found: $file"
    return 0
  fi
  if ! grep -q '[^[:space:]]' "$file"; then
    log_debug "Removing empty file: $file"
    rm -f "$file"
  else
    log_debug "Keeping non-empty file: $file"
  fi
}

manifest_lists_path() {
  local key="$1"
  local path="$2"

  if [[ ! -f "$INSTALL_MANIFEST_FILE" ]]; then
    log_debug "Manifest not found while checking $key for path $path"
    return 1
  fi

  if grep -Fx -- "$key=$path" "$INSTALL_MANIFEST_FILE" >/dev/null; then
    log_debug "Manifest contains $key entry for $path"
    return 0
  fi

  log_debug "Manifest does not contain $key entry for $path"
  return 1
}

remove_empty_parent_dirs() {
  local dir="$1"
  local stop_dir="$2"

  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if rmdir "$dir" 2>/dev/null; then
      log_debug "Removed empty directory: $dir"
    else
      log_debug "Stopped removing parent directories at non-empty or inaccessible path: $dir"
      break
    fi
    if [[ "$dir" == "$stop_dir" ]]; then
      log_debug "Reached directory cleanup boundary: $stop_dir"
      break
    fi
    dir="$(dirname "$dir")"
  done
}

remove_manifest_profile_files() {
  local line path

  if [[ ! -f "$INSTALL_MANIFEST_FILE" ]]; then
    log_debug "No install manifest found; skipping managed profile file removal"
    return 0
  fi

  log_debug "Removing profile files listed in manifest $INSTALL_MANIFEST_FILE"
  while IFS= read -r line; do
    case "$line" in
      created_profile_file=*)
        path="${line#created_profile_file=}"
        log_debug "Removing manifest-managed profile file: $path"
        rm -f "$path"
        remove_empty_parent_dirs "$(dirname "$path")" "$SHIMMY_INSTALL_DIR"
        ;;
      *)
        log_debug "Ignoring manifest entry during profile cleanup: $line"
        ;;
    esac
  done < "$INSTALL_MANIFEST_FILE"
}

remove_install_dir() {
  if [[ ! -e "$SHIMMY_INSTALL_DIR" ]]; then
    log_debug "Install directory not present; nothing to remove: $SHIMMY_INSTALL_DIR"
    return 0
  fi
  log_debug "Removing install directory: $SHIMMY_INSTALL_DIR"
  rm -rf "$SHIMMY_INSTALL_DIR"
  remove_empty_parent_dirs "$(dirname "$SHIMMY_INSTALL_DIR")" "$HOME"
}

remove_shell_artifacts() {
  log_debug "Removing managed shell artifacts from Bash startup files"
  remove_managed_block "$BASHRC_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
  remove_managed_block "$BASH_PROFILE_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
  remove_managed_block "$SHIMMY_BASH_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"

  if manifest_lists_path "created_shell_file" "$BASHRC_FILE"; then
    log_debug "Cleaning up shell file recorded as created: $BASHRC_FILE"
    remove_file_if_empty "$BASHRC_FILE"
  else
    log_debug "Shell file was not recorded as created; leaving file in place: $BASHRC_FILE"
  fi
  if manifest_lists_path "created_shell_file" "$BASH_PROFILE_FILE"; then
    log_debug "Cleaning up shell file recorded as created: $BASH_PROFILE_FILE"
    remove_file_if_empty "$BASH_PROFILE_FILE"
  else
    log_debug "Shell file was not recorded as created; leaving file in place: $BASH_PROFILE_FILE"
  fi
  if manifest_lists_path "created_shell_file" "$SHIMMY_BASH_FILE"; then
    log_debug "Cleaning up shell file recorded as created: $SHIMMY_BASH_FILE"
    remove_file_if_empty "$SHIMMY_BASH_FILE"
  else
    log_debug "Shell file was not recorded as created; leaving file in place: $SHIMMY_BASH_FILE"
  fi
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
  remove_empty_parent_dirs "$(dirname "$SHIMMY_INSTALL_DIR")" "$HOME"
}

install_image_support() {
  local image_dest="$SHIMMY_INSTALL_DIR"

  log_debug "Refreshing local container image support in $image_dest using mode $INSTALL_MODE"
  rm -rf "$image_dest"

  if [[ "$INSTALL_MODE" == "copy" ]]; then
    log_debug "Copying local container image support from $SOURCE_IMAGES_DIR to $image_dest"
    mkdir -p "$image_dest"
    cp -a "$SOURCE_IMAGES_DIR"/. "$image_dest"/
  else
    log_debug "Symlinking local container image support from $SOURCE_IMAGES_DIR to $image_dest"
    ln -s "$SOURCE_IMAGES_DIR" "$image_dest"
  fi
}

perform_install() {
  local dest shim src

  log_debug "Starting install into $SHIMMY_INSTALL_DIR with mode $INSTALL_MODE"
  [[ -d "$SOURCE_SHIMS_DIR" ]] || fail "shim source directory not found: $SOURCE_SHIMS_DIR"
  [[ -d "$SOURCE_IMAGES_DIR" ]] || fail "local container image source directory not found: $SOURCE_IMAGES_DIR"

  mkdir -p "$SHIMMY_SHIM_DIR"
  while IFS= read -r src; do
    shim="$(basename "$src")"
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

  install_image_support

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

    remove_managed_block "$BASHRC_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
    remove_managed_block "$BASH_PROFILE_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
    remove_managed_block "$SHIMMY_BASH_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"
    remove_managed_block "$BASHRC_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"
    remove_managed_block "$BASH_PROFILE_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"

    append_shell_init_block "$BASHRC_FILE"
    append_shell_init_block "$BASH_PROFILE_FILE"
    append_shimmy_path_block
  else
    log_debug "Skipping Bash startup file updates because Bash profile management was not requested"
    if [[ -d "$SHIMMY_SHIM_DIR" ]]; then
      case ":$PATH:" in
        *":$SHIMMY_SHIM_DIR:"*) ;;
        *) export PATH="$PATH:$SHIMMY_SHIM_DIR" ;;
      esac
    fi
  fi

  # install_repo_profile_files
  write_install_manifest

  echo "Installed shims into $SHIMMY_INSTALL_DIR ($INSTALL_MODE)."
  # if [[ "$UPDATE_BASHRC" -eq 1 ]]; then
  #   echo "Updated Bash startup files: $BASHRC_FILE, $BASH_PROFILE_FILE, $SHIMMY_BASH_FILE."
  #   echo "Run: source \"$SHIMMY_BASH_FILE\""
  # else
  #   echo "Add this path manually if needed: $SHIMMY_INSTALL_DIR"
  # fi

  # if [[ "${#PROFILE_CREATED_MESSAGES[@]}" -gt 0 ]]; then
  #   printf '%s\n' "${PROFILE_CREATED_MESSAGES[@]}"
  # fi

  # if [[ "${#PROFILE_WARNING_MESSAGES[@]}" -gt 0 ]]; then
  #   printf '%s\n' "${PROFILE_WARNING_MESSAGES[@]}"
  # fi
}

perform_uninstall() {
  log_debug "Starting uninstall for install dir $SHIMMY_INSTALL_DIR"
  remove_manifest_profile_files
  remove_shell_artifacts
  log_debug "Removing install manifest file: $INSTALL_MANIFEST_FILE"
  rm -f "$INSTALL_MANIFEST_FILE"
  remove_install_dir
  remove_profile_dir_if_empty

  echo "Removed shimmy artifacts from $SHIMMY_INSTALL_DIR."
  echo "Cleaned Bash startup files: $BASHRC_FILE, $BASH_PROFILE_FILE, $SHIMMY_BASH_FILE."
}

# Parse command line arguments into vars for conditional logic  
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      [[ $# -ge 2 ]] || fail "missing value for --install-dir"
      SHIMMY_INSTALL_DIR="$2"
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

shimmy_init_install_vars "$SHIMMY_INSTALL_DIR"

if [[ "$UNINSTALL" -eq 1 ]]; then
  perform_uninstall
else
  perform_install
fi
