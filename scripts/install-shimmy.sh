#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/repo/shimmy-env.sh
source "$SCRIPT_DIR/../lib/repo/shimmy-env.sh"

shimmy_log_init
shimmy_init_repo_vars "$(shimmy_repo_root_from_script_path "${BASH_SOURCE[0]}")"
shimmy_init_home_vars "$HOME"
shimmy_init_install_vars "${SHIMMY_INSTALL_DIR:-}"

INSTALL_MODE='copy'
UPDATE_BASHRC=1
UNINSTALL=0
REQUESTED_INSTALL_DIR="${SHIMMY_INSTALL_DIR:-}"
REQUESTED_SHIMS=()
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
  shimmy_log_error "$*"
  return 1
}

log_debug() {
  shimmy_log_debug "$*"
}

log_info() {
  shimmy_log_info "$*"
}

log_warn() {
  shimmy_log_warn "$*"
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
  shimmy_render_path_block \
    "$SHIMMY_SHIM_DIR" \
    "$SHIMMY_INSTALL_DIR" \
    "$SHIMMY_IMAGES_DIR" \
    "$SHIMMY_SHIM_LIB_DIR" >> "$SHIMMY_BASH_FILE"
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
    record_profile_warning "profile already exists at $dest; leaving unchanged."
    log_warn "profile already exists at $dest; leaving unchanged."
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

  if [[ -f "$SOURCE_CONTRIBUTING" ]]; then
    log_debug "Installing repository CONTRIBUTING.md into profile directory"
    copy_file_if_missing "$SOURCE_CONTRIBUTING" "$SHIMMY_INSTALL_DIR/CONTRIBUTING.md"
  else
    log_debug "Repository CONTRIBUTING.md not found; skipping profile install"
  fi

  if [[ -f "$SOURCE_AGENTS" ]]; then
    log_debug "Installing repository AGENTS.md into profile directory"
    copy_file_if_missing "$SOURCE_AGENTS" "$SHIMMY_INSTALL_DIR/AGENTS.md"
  else
    log_debug "Repository AGENTS.md not found; skipping profile install"
  fi

  if [[ -d "$SOURCE_SHIMS_DIR" ]]; then
    log_info "Installing shims from $SOURCE_SHIMS_DIR"
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
    log_info "Installing AI skills from $SOURCE_SKILLS_DIR"
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
    printf 'shim_dir=%s\n' "$SHIMMY_SHIM_DIR"
    printf 'images_dir=%s\n' "$SHIMMY_IMAGES_DIR"
    printf 'shim_lib_dir=%s\n' "$SHIMMY_SHIM_LIB_DIR"
    printf 'install_mode=%s\n' "$INSTALL_MODE"
    printf 'update_bashrc=%s\n' "$UPDATE_BASHRC"
    printf 'bashrc_file=%s\n' "$BASHRC_FILE"
    printf 'bash_profile_file=%s\n' "$BASH_PROFILE_FILE"
    printf 'bash_shimmy_file=%s\n' "$SHIMMY_BASH_FILE"
    for shim in "${REQUESTED_SHIMS[@]}"; do
      printf 'requested_shim=%s\n' "$shim"
    done
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

path_is_within() {
  local parent="${1:?parent path is required}"
  local child="${2:?child path is required}"

  parent="${parent%/}"
  child="${child%/}"

  [[ "$child" == "$parent" || "$child" == "$parent"/* ]]
}

remove_managed_layout_dir() {
  local dir="$1"
  local description="$2"

  if [[ ! -e "$dir" ]]; then
    log_debug "$description directory not present; nothing to remove: $dir"
    return 0
  fi

  log_debug "Removing $description directory: $dir"
  rm -rf "$dir"
  remove_empty_parent_dirs "$(dirname "$dir")" "$HOME"
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
  # This file is shimmy-managed; remove it whenever uninstall leaves it empty,
  # even if it existed before install.
  remove_file_if_empty "$SHIMMY_BASH_FILE"
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

  log_info "Installed shims into $SHIMMY_INSTALL_DIR ($INSTALL_MODE)."
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
  if ! path_is_within "$SHIMMY_INSTALL_DIR" "$SHIMMY_SHIM_DIR"; then
    remove_managed_layout_dir "$SHIMMY_SHIM_DIR" "shim"
  fi
  if ! path_is_within "$SHIMMY_INSTALL_DIR" "$SHIMMY_IMAGES_DIR"; then
    remove_managed_layout_dir "$SHIMMY_IMAGES_DIR" "image"
  fi
  if ! path_is_within "$SHIMMY_INSTALL_DIR" "$SHIMMY_SHIM_LIB_DIR"; then
    remove_managed_layout_dir "$SHIMMY_SHIM_LIB_DIR" "shim helper library"
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

shimmy_init_install_vars "$REQUESTED_INSTALL_DIR"

if [[ "$UNINSTALL" -eq 1 ]]; then
  shimmy_apply_install_layout_from_manifest "$INSTALL_MANIFEST_FILE" || true
  perform_uninstall
else
  perform_install
fi
