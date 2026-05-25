#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)

ACTIVATE_SCRIPT=$SCRIPT_DIR/activate-shimmy.sh
SOURCE_CONTROL_FILE=$ROOT_DIR/shimmy
SOURCE_SCRIPT_DIR=$ROOT_DIR/scripts
SOURCE_SHIMS_DIR=$ROOT_DIR/shims
SOURCE_IMAGES_DIR=$ROOT_DIR/images
SOURCE_REPO_LIB_DIR=$ROOT_DIR/lib/repo
SOURCE_SHIM_LIB_DIR=$ROOT_DIR/lib/shims
CATALOG_HELPER_FILE=$SOURCE_REPO_LIB_DIR/shimmy-catalog.sh
STARTUP_HELPER_FILE=$SOURCE_REPO_LIB_DIR/shimmy-startup.sh

DEFAULT_INSTALL_DIR=${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}

REQUESTED_INSTALL_DIR=
REQUESTED_SHIMS=
REQUESTED_SHELL=
REQUESTED_STARTUP_FILES=
SKIP_STARTUP=0
STARTUP_FILE_PATHS=
STARTUP_SHELL=
PRESERVED_STARTUP_FILE_PATHS=
PRESERVED_STARTUP_SHELL=
PRESERVED_SHIMMY_MANIFEST_LINES=
UNINSTALL=0

LOG_LEVEL=${LOG_LEVEL:-info}

trim_trailing_slash() {
  path_value=${1:-}

  case "$path_value" in
    ''|/)
      printf '%s\n' "$path_value"
      ;;
    */)
      printf '%s\n' "${path_value%/}"
      ;;
    *)
      printf '%s\n' "$path_value"
      ;;
  esac
}

install_path_render() {
  install_dir=$1
  path_suffix=$2

  printf '%s/%s\n' "$(trim_trailing_slash "$install_dir")" "$path_suffix"
}

log_level_value() {
  case ${1:-info} in
    debug) printf '10\n' ;;
    info) printf '20\n' ;;
    warn|warning) printf '30\n' ;;
    error) printf '40\n' ;;
    silent|quiet|none) printf '50\n' ;;
    *) printf '20\n' ;;
  esac
}

log_level_enabled() {
  message_value=$(log_level_value "$1")
  configured_value=$(log_level_value "$LOG_LEVEL")
  [ "$message_value" -ge "$configured_value" ]
}

log_message() {
  level=$1
  shift

  log_level_enabled "$level" || return 0
  upper_level=$(printf '%s' "$level" | tr '[:lower:]' '[:upper:]')
  printf '%s: %s\n' "$upper_level" "$*" >&2
}

log_debug() {
  log_message debug "$@"
}

log_info() {
  log_message info "$@"
}

log_warn() {
  log_message warn "$@"
}

is_macos() {
  os_name=${SHIMMY_TEST_OS:-$(uname -s 2>/dev/null || printf unknown)}
  [ "$os_name" = Darwin ]
}

line_list_append() {
  list_value=${1:-}
  line_value=$2

  if [ -n "$list_value" ]; then
    printf '%s\n%s\n' "$list_value" "$line_value"
  else
    printf '%s\n' "$line_value"
  fi
}

fail() {
  log_message error "$*"
  exit 1
}

if [ ! -f "$STARTUP_HELPER_FILE" ]; then
  fail "missing startup helper: $STARTUP_HELPER_FILE"
fi

if [ ! -x "$ACTIVATE_SCRIPT" ]; then
  fail "missing activate helper: $ACTIVATE_SCRIPT"
fi

if [ ! -f "$CATALOG_HELPER_FILE" ]; then
  fail "missing catalog helper: $CATALOG_HELPER_FILE"
fi

# shellcheck source=lib/repo/shimmy-catalog.sh
. "$CATALOG_HELPER_FILE"
# shellcheck source=lib/repo/shimmy-startup.sh
. "$STARTUP_HELPER_FILE"

usage() {
  cat <<'EOF'
Install or uninstall Shimmy assets in a user-scoped location.

Usage:
  scripts/install-shimmy.sh [options]

Options:
  --install-dir <dir>    Base install directory. Default: ~/.config/shimmy
  --shim <name>          Install only the named shim. Repeatable.
  --shell <name>         Override shell detection for startup-file updates
  --startup-file <path>  Override startup file updates. Repeatable.
  --no-startup           Skip persistent startup-file updates during install
  --uninstall            Remove the current install instead of creating it
  -h, --help             Show help
EOF
}

selected_shim_list() {
  if [ -n "$REQUESTED_SHIMS" ]; then
    printf '%s\n' "$REQUESTED_SHIMS"
    return 0
  fi

  shimmy_supported_shim_list
}

validate_requested_shims() {
  for requested_shim in $(selected_shim_list); do
    shimmy_is_supported_shim "$requested_shim" || fail "unsupported shim on posix-rewrite branch: $requested_shim"
  done
}

resolve_install_root() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s\n' "$(trim_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(trim_trailing_slash "$DEFAULT_INSTALL_DIR")"
}

manifest_value() {
  manifest_file=$1
  key=$2

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$manifest_file" | sed -n '1p'
}

manifest_values() {
  manifest_file=$1
  key=$2

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$manifest_file"
}

manifest_shimmy_lines_preserve() {
  manifest_file=$1

  if [ ! -f "$manifest_file" ]; then
    return 0
  fi

  while IFS= read -r manifest_line; do
    case "$manifest_line" in
      shimmy_*=*)
        manifest_key=${manifest_line%%=*}
        case "$manifest_key" in
          shimmy_manifest_version|shimmy_source_url|shimmy_source_ref|shimmy_previous_source_ref)
            ;;
          *)
            printf '%s\n' "$manifest_line"
            ;;
        esac
        ;;
    esac
  done < "$manifest_file"
}

source_ref_resolve() {
  command -v git >/dev/null 2>&1 || return 0

  git -C "$ROOT_DIR" rev-parse --verify HEAD 2>/dev/null || true
}

source_url_resolve() {
  command -v git >/dev/null 2>&1 || return 0

  git -C "$ROOT_DIR" config --get remote.origin.url 2>/dev/null || true
}

resolve_install_paths() {
  SHIMMY_INSTALL_DIR=$(resolve_install_root)
  SHIMMY_SHIM_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" shims)
  SHIMMY_IMAGES_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" images)
  SHIMMY_SHIM_LIB_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" lib/shims)
  SHIMMY_CONTROL_BIN_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" bin)
  SHIMMY_CONTROL_BIN=$(install_path_render "$SHIMMY_CONTROL_BIN_DIR" shimmy)
  SHIMMY_CONTROL_SOURCE_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" libexec/shimmy)
  SHIMMY_CONTROL_SCRIPT_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" scripts)
  SHIMMY_CONTROL_SHIMS_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" shims)
  SHIMMY_CONTROL_IMAGES_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" images)
  SHIMMY_CONTROL_REPO_LIB_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" lib/repo)
  SHIMMY_CONTROL_SHIM_LIB_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" lib/shims)
  SHIMMY_ACTIVATE_FILE=$(install_path_render "$SHIMMY_INSTALL_DIR" activate.sh)
  INSTALL_MANIFEST_FILE=$(install_path_render "$SHIMMY_INSTALL_DIR" install-manifest.txt)
}

load_install_root_from_manifest() {
  if [ ! -f "$INSTALL_MANIFEST_FILE" ]; then
    return 1
  fi

  manifest_install_dir=$(manifest_value "$INSTALL_MANIFEST_FILE" install_dir || true)
  if [ -z "$manifest_install_dir" ]; then
    return 1
  fi

  SHIMMY_INSTALL_DIR=$(trim_trailing_slash "$manifest_install_dir")
  SHIMMY_SHIM_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" shims)
  SHIMMY_IMAGES_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" images)
  SHIMMY_SHIM_LIB_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" lib/shims)
  SHIMMY_CONTROL_BIN_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" bin)
  SHIMMY_CONTROL_BIN=$(install_path_render "$SHIMMY_CONTROL_BIN_DIR" shimmy)
  SHIMMY_CONTROL_SOURCE_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" libexec/shimmy)
  SHIMMY_CONTROL_SCRIPT_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" scripts)
  SHIMMY_CONTROL_SHIMS_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" shims)
  SHIMMY_CONTROL_IMAGES_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" images)
  SHIMMY_CONTROL_REPO_LIB_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" lib/repo)
  SHIMMY_CONTROL_SHIM_LIB_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" lib/shims)
  SHIMMY_ACTIVATE_FILE=$(install_path_render "$SHIMMY_INSTALL_DIR" activate.sh)
  INSTALL_MANIFEST_FILE=$(install_path_render "$SHIMMY_INSTALL_DIR" install-manifest.txt)
}

ensure_safe_remove_path() {
  path_value=$1

  case "$path_value" in
    ''|/)
      fail "refusing to remove unsafe path: $path_value"
      ;;
  esac
}

install_file() {
  source_path=$1
  target_path=$2

  if [ "$source_path" = "$target_path" ]; then
    chmod 755 "$target_path"
    return 0
  fi

  rm -f "$target_path"
  cp "$source_path" "$target_path"
  chmod 755 "$target_path"
}

install_directory_copy() {
  source_path=$1
  target_path=$2

  if [ "$source_path" = "$target_path" ]; then
    return 0
  fi

  rm -rf "$target_path"
  cp -R "$source_path" "$target_path"
}

install_control_assets() {
  [ -f "$SOURCE_CONTROL_FILE" ] || fail "missing source management launcher: $SOURCE_CONTROL_FILE"
  [ -d "$SOURCE_SCRIPT_DIR" ] || fail "missing source script directory: $SOURCE_SCRIPT_DIR"
  [ -d "$SOURCE_REPO_LIB_DIR" ] || fail "missing source repo helper directory: $SOURCE_REPO_LIB_DIR"

  if [ "$ROOT_DIR" != "$SHIMMY_CONTROL_SOURCE_DIR" ]; then
    rm -rf "$SHIMMY_CONTROL_SOURCE_DIR"
  fi

  mkdir -p "$SHIMMY_CONTROL_BIN_DIR" "$SHIMMY_CONTROL_SCRIPT_DIR" \
    "$SHIMMY_CONTROL_SHIMS_DIR" "$SHIMMY_CONTROL_IMAGES_DIR" \
    "$(dirname "$SHIMMY_CONTROL_REPO_LIB_DIR")"

  install_file "$SOURCE_CONTROL_FILE" "$SHIMMY_CONTROL_BIN"
  install_file "$SOURCE_CONTROL_FILE" "$SHIMMY_CONTROL_SOURCE_DIR/shimmy"

  for script_name in activate-shimmy.sh install-shimmy.sh netinfo-shimmy.sh status-shimmy.sh update-shimmy.sh; do
    source_path=$SOURCE_SCRIPT_DIR/$script_name
    target_path=$SHIMMY_CONTROL_SCRIPT_DIR/$script_name
    [ -f "$source_path" ] || fail "missing management script source: $source_path"
    install_file "$source_path" "$target_path"
  done

  install_directory_copy "$SOURCE_REPO_LIB_DIR" "$SHIMMY_CONTROL_REPO_LIB_DIR"
  install_directory_copy "$SOURCE_SHIM_LIB_DIR" "$SHIMMY_CONTROL_SHIM_LIB_DIR"
}

startup_file_summary_render() {
  startup_file_paths=${1:-}

  if [ -z "$startup_file_paths" ]; then
    printf 'manual activation only\n'
    return 0
  fi

  separator=
  while IFS= read -r startup_file_path; do
    [ -n "$startup_file_path" ] || continue
    printf '%s%s' "$separator" "$startup_file_path"
    separator=', '
  done <<EOF
$startup_file_paths
EOF
  printf '\n'
}

podman_macos_guidance_log() {
  is_macos || return 0

  log_info "macOS Podman check: run 'podman info' in a normal shell before using Shimmy."
  log_info "If Podman is unreachable, run 'podman machine start' in that shell, then retry Shimmy."
}

write_activate_file() {
  "$ACTIVATE_SCRIPT" --install-dir "$SHIMMY_INSTALL_DIR" > "$SHIMMY_ACTIVATE_FILE"
  chmod 644 "$SHIMMY_ACTIVATE_FILE"
}

write_manifest() {
  mkdir -p "$SHIMMY_INSTALL_DIR"

  shimmy_source_ref=$(source_ref_resolve)
  shimmy_source_url=$(source_url_resolve)
  shimmy_previous_source_ref=${SHIMMY_PREVIOUS_SOURCE_REF:-}
  if [ -z "$shimmy_previous_source_ref" ]; then
    shimmy_previous_source_ref=$(manifest_value "$INSTALL_MANIFEST_FILE" shimmy_previous_source_ref || true)
  fi

  {
    printf 'install_dir=%s\n' "$SHIMMY_INSTALL_DIR"
    printf 'control_bin=%s\n' "$SHIMMY_CONTROL_BIN"
    printf 'activate_file=%s\n' "$SHIMMY_ACTIVATE_FILE"
    if [ -n "$STARTUP_SHELL" ]; then
      printf 'startup_shell=%s\n' "$STARTUP_SHELL"
    fi
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      printf 'startup_file=%s\n' "$startup_file_path"
    done <<EOF
$STARTUP_FILE_PATHS
EOF
    for shim_name in $(selected_shim_list); do
      printf 'shim=%s\n' "$shim_name"
    done
    printf 'shimmy_manifest_version=1\n'
    if [ -n "$shimmy_source_url" ]; then
      printf 'shimmy_source_url=%s\n' "$shimmy_source_url"
    fi
    if [ -n "$shimmy_source_ref" ]; then
      printf 'shimmy_source_ref=%s\n' "$shimmy_source_ref"
    fi
    if [ -n "$shimmy_previous_source_ref" ]; then
      printf 'shimmy_previous_source_ref=%s\n' "$shimmy_previous_source_ref"
    fi
    if [ -n "$PRESERVED_SHIMMY_MANIFEST_LINES" ]; then
      printf '%s\n' "$PRESERVED_SHIMMY_MANIFEST_LINES"
    fi
  } > "$INSTALL_MANIFEST_FILE"
}

resolve_startup_settings() {
  if [ "$SKIP_STARTUP" -eq 1 ]; then
    if [ -n "$PRESERVED_STARTUP_FILE_PATHS" ]; then
      STARTUP_SHELL=$PRESERVED_STARTUP_SHELL
      STARTUP_FILE_PATHS=$PRESERVED_STARTUP_FILE_PATHS
    else
      STARTUP_SHELL=
      STARTUP_FILE_PATHS=
    fi
    return 0
  fi

  STARTUP_SHELL=$(shimmy_shell_name_normalize "$REQUESTED_SHELL") || fail "unable to resolve startup shell"
  if [ -n "$REQUESTED_STARTUP_FILES" ]; then
    STARTUP_FILE_PATHS=$REQUESTED_STARTUP_FILES
  else
    STARTUP_FILE_PATHS=$(shimmy_startup_file_path_list_resolve "$STARTUP_SHELL" "$HOME") || fail "unable to resolve startup file path"
  fi
}

perform_install() {
  validate_requested_shims
  if [ -f "$INSTALL_MANIFEST_FILE" ]; then
    PRESERVED_STARTUP_SHELL=$(manifest_value "$INSTALL_MANIFEST_FILE" startup_shell || true)
    PRESERVED_STARTUP_FILE_PATHS=$(manifest_values "$INSTALL_MANIFEST_FILE" startup_file || true)
    PRESERVED_SHIMMY_MANIFEST_LINES=$(manifest_shimmy_lines_preserve "$INSTALL_MANIFEST_FILE")
  fi
  resolve_startup_settings

  [ -d "$SOURCE_SHIMS_DIR" ] || fail "missing source shim directory: $SOURCE_SHIMS_DIR"
  [ -d "$SOURCE_IMAGES_DIR" ] || fail "missing source image support directory: $SOURCE_IMAGES_DIR"
  [ -d "$SOURCE_SHIM_LIB_DIR" ] || fail "missing source shim helper directory: $SOURCE_SHIM_LIB_DIR"

  log_info "Installing shimmy into $SHIMMY_INSTALL_DIR"

  mkdir -p "$SHIMMY_INSTALL_DIR"
  rm -rf "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR" "$SHIMMY_SHIM_LIB_DIR"
  rm -f "$SHIMMY_CONTROL_BIN"
  mkdir -p "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR" "$(dirname "$SHIMMY_SHIM_LIB_DIR")"

  log_debug "Copying management command support to $SHIMMY_CONTROL_SOURCE_DIR"
  install_control_assets

  for shim_name in $(selected_shim_list); do
    source_path=$SOURCE_SHIMS_DIR/$shim_name
    target_path=$SHIMMY_SHIM_DIR/$shim_name
    [ -f "$source_path" ] || fail "missing shim source: $source_path"
    log_debug "Copying shim $shim_name to $target_path"
    install_file "$source_path" "$target_path"

    control_target_path=$SHIMMY_CONTROL_SHIMS_DIR/$shim_name
    log_debug "Copying management source shim $shim_name to $control_target_path"
    install_file "$source_path" "$control_target_path"
  done

  for shim_name in $(selected_shim_list); do
    source_path=$SOURCE_IMAGES_DIR/$shim_name
    target_path=$SHIMMY_IMAGES_DIR/$shim_name
    if [ -d "$source_path" ]; then
      log_debug "Copying image support for $shim_name to $target_path"
      install_directory_copy "$source_path" "$target_path"

      control_target_path=$SHIMMY_CONTROL_IMAGES_DIR/$shim_name
      log_debug "Copying management source image support for $shim_name to $control_target_path"
      install_directory_copy "$source_path" "$control_target_path"
    fi
  done

  log_debug "Copying shared shim helper support to $SHIMMY_SHIM_LIB_DIR"
  install_directory_copy "$SOURCE_SHIM_LIB_DIR" "$SHIMMY_SHIM_LIB_DIR"

  write_activate_file

  if [ -n "$STARTUP_FILE_PATHS" ]; then
    activate_block=$(shimmy_activate_source_block_render "$SHIMMY_ACTIVATE_FILE") || fail "unable to render activate block for startup file"
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      shimmy_startup_file_update "$startup_file_path" "$activate_block"
      log_info "Updated startup file: $startup_file_path"
    done <<EOF
$STARTUP_FILE_PATHS
EOF
  fi

  write_manifest

  log_info "Installed shimmy assets into $SHIMMY_INSTALL_DIR"
  log_info "Future shells will load Shimmy from: $(startup_file_summary_render "$STARTUP_FILE_PATHS")"
  log_info "Activate this install with: eval \"\$('$SHIMMY_CONTROL_BIN' activate)\""
  podman_macos_guidance_log
}

remove_path_if_present() {
  path_value=$1
  description=$2

  if [ ! -e "$path_value" ]; then
    return 0
  fi

  ensure_safe_remove_path "$path_value"
  log_debug "Removing $description path: $path_value"
  rm -rf "$path_value"
}

perform_uninstall() {
  log_info "Removing shimmy install rooted at $SHIMMY_INSTALL_DIR"

  load_install_root_from_manifest || true
  startup_files_to_remove=$(manifest_values "$INSTALL_MANIFEST_FILE" startup_file || true)

  if [ -n "$startup_files_to_remove" ]; then
    while IFS= read -r startup_file_to_remove; do
      [ -n "$startup_file_to_remove" ] || continue
      shimmy_startup_block_remove "$startup_file_to_remove"
      log_info "Removed managed Shimmy startup block from: $startup_file_to_remove"
    done <<EOF
$startup_files_to_remove
EOF
  fi

  remove_path_if_present "$SHIMMY_SHIM_DIR" "shim"
  remove_path_if_present "$SHIMMY_IMAGES_DIR" "image"
  remove_path_if_present "$SHIMMY_SHIM_LIB_DIR" "shim helper"
  remove_path_if_present "$SHIMMY_CONTROL_BIN" "management command"
  remove_path_if_present "$SHIMMY_CONTROL_SOURCE_DIR" "management support"
  remove_path_if_present "$SHIMMY_ACTIVATE_FILE" "activation"
  remove_path_if_present "$INSTALL_MANIFEST_FILE" "manifest"

  if [ -d "$SHIMMY_INSTALL_DIR/lib" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/lib" 2>/dev/null || true
  fi
  if [ -d "$SHIMMY_INSTALL_DIR/images" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/images" 2>/dev/null || true
  fi
  if [ -d "$SHIMMY_INSTALL_DIR/shims" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/shims" 2>/dev/null || true
  fi
  if [ -d "$SHIMMY_INSTALL_DIR/bin" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/bin" 2>/dev/null || true
  fi
  if [ -d "$SHIMMY_INSTALL_DIR/libexec" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/libexec" 2>/dev/null || true
  fi

  if [ -d "$SHIMMY_INSTALL_DIR" ]; then
    ensure_safe_remove_path "$SHIMMY_INSTALL_DIR"
    if rmdir "$SHIMMY_INSTALL_DIR" 2>/dev/null; then
      log_debug "Removed empty install directory: $SHIMMY_INSTALL_DIR"
    fi
  fi

  log_info "Removed shimmy assets from $SHIMMY_INSTALL_DIR"
}

main() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        [ "$#" -ge 2 ] || fail "missing value for --install-dir"
        REQUESTED_INSTALL_DIR=$2
        shift 2
        ;;
      --copy)
        shift
        ;;
      --symlink)
        fail "symlink install mode has been removed on the posix-rewrite branch"
        ;;
      --shim)
        [ "$#" -ge 2 ] || fail "missing value for --shim"
        if [ -n "$REQUESTED_SHIMS" ]; then
          REQUESTED_SHIMS="$REQUESTED_SHIMS $2"
        else
          REQUESTED_SHIMS=$2
        fi
        shift 2
        ;;
      --shell)
        [ "$#" -ge 2 ] || fail "missing value for --shell"
        REQUESTED_SHELL=$2
        shift 2
        ;;
      --startup-file)
        [ "$#" -ge 2 ] || fail "missing value for --startup-file"
        REQUESTED_STARTUP_FILES=$(line_list_append "$REQUESTED_STARTUP_FILES" "$2")
        shift 2
        ;;
      --no-startup)
        SKIP_STARTUP=1
        shift
        ;;
      --uninstall)
        UNINSTALL=1
        shift
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

  resolve_install_paths

  if [ "$UNINSTALL" -eq 1 ]; then
    perform_uninstall
  else
    perform_install
  fi
}

main "$@"
