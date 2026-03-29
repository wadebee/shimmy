#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)

ACTIVATE_SCRIPT=$SCRIPT_DIR/activate-shimmy.sh
SOURCE_SHIMS_DIR=$ROOT_DIR/shims
SOURCE_IMAGES_DIR=$ROOT_DIR/images
SOURCE_REPO_LIB_DIR=$ROOT_DIR/lib/repo
SOURCE_SHIM_LIB_DIR=$ROOT_DIR/lib/shims
STARTUP_HELPER_FILE=$SOURCE_REPO_LIB_DIR/shimmy-startup.sh

DEFAULT_INSTALL_DIR=$HOME/.config/shimmy
SUPPORTED_SHIMS='aws jq netcat rg task terraform textual'

REQUESTED_INSTALL_DIR=
REQUESTED_SHIMS=
REQUESTED_SHELL=
REQUESTED_STARTUP_FILE=
SKIP_STARTUP=0
STARTUP_FILE_LABEL=
STARTUP_FILE_PATH=
STARTUP_SHELL=
PRESERVED_STARTUP_FILE_PATH=
PRESERVED_STARTUP_SHELL=
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
  --startup-file <path>  Override the startup file Shimmy updates during install
  --no-startup           Skip persistent startup-file updates during install
  --uninstall            Remove the current install instead of creating it
  -h, --help             Show help
EOF
}

supported_shim_list() {
  printf '%s\n' "$SUPPORTED_SHIMS"
}

selected_shim_list() {
  if [ -n "$REQUESTED_SHIMS" ]; then
    printf '%s\n' "$REQUESTED_SHIMS"
    return 0
  fi

  supported_shim_list
}

is_supported_shim() {
  requested_shim=$1

  for supported_shim in $SUPPORTED_SHIMS; do
    if [ "$supported_shim" = "$requested_shim" ]; then
      return 0
    fi
  done

  return 1
}

validate_requested_shims() {
  for requested_shim in $(selected_shim_list); do
    is_supported_shim "$requested_shim" || fail "unsupported shim on posix-rewrite branch: $requested_shim"
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

resolve_install_paths() {
  SHIMMY_INSTALL_DIR=$(resolve_install_root)
  SHIMMY_SHIM_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" shims)
  SHIMMY_IMAGES_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" images)
  SHIMMY_SHIM_LIB_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" lib/shims)
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

  rm -f "$target_path"
  cp "$source_path" "$target_path"
  chmod 755 "$target_path"
}

install_directory_copy() {
  source_path=$1
  target_path=$2

  rm -rf "$target_path"
  cp -R "$source_path" "$target_path"
}

write_manifest() {
  mkdir -p "$SHIMMY_INSTALL_DIR"

  {
    printf 'install_dir=%s\n' "$SHIMMY_INSTALL_DIR"
    if [ -n "$STARTUP_SHELL" ]; then
      printf 'startup_shell=%s\n' "$STARTUP_SHELL"
    fi
    if [ -n "$STARTUP_FILE_PATH" ]; then
      printf 'startup_file=%s\n' "$STARTUP_FILE_PATH"
    fi
    for shim_name in $(selected_shim_list); do
      printf 'shim=%s\n' "$shim_name"
    done
  } > "$INSTALL_MANIFEST_FILE"
}

resolve_startup_settings() {
  if [ "$SKIP_STARTUP" -eq 1 ]; then
    if [ -n "$PRESERVED_STARTUP_FILE_PATH" ]; then
      STARTUP_SHELL=$PRESERVED_STARTUP_SHELL
      STARTUP_FILE_PATH=$PRESERVED_STARTUP_FILE_PATH
      STARTUP_FILE_LABEL=$PRESERVED_STARTUP_FILE_PATH
    else
      STARTUP_SHELL=
      STARTUP_FILE_PATH=
      STARTUP_FILE_LABEL=
    fi
    return 0
  fi

  STARTUP_SHELL=$(shimmy_shell_name_normalize "$REQUESTED_SHELL") || fail "unable to resolve startup shell"
  STARTUP_FILE_PATH=$(shimmy_startup_file_path_resolve "$STARTUP_SHELL" "$REQUESTED_STARTUP_FILE" "$HOME") || fail "unable to resolve startup file path"
  STARTUP_FILE_LABEL=$(shimmy_startup_file_label_render "$STARTUP_SHELL" "$REQUESTED_STARTUP_FILE") || fail "unable to resolve startup file label"
}

perform_install() {
  validate_requested_shims
  if [ -f "$INSTALL_MANIFEST_FILE" ]; then
    PRESERVED_STARTUP_SHELL=$(manifest_value "$INSTALL_MANIFEST_FILE" startup_shell || true)
    PRESERVED_STARTUP_FILE_PATH=$(manifest_value "$INSTALL_MANIFEST_FILE" startup_file || true)
  fi
  resolve_startup_settings

  [ -d "$SOURCE_SHIMS_DIR" ] || fail "missing source shim directory: $SOURCE_SHIMS_DIR"
  [ -d "$SOURCE_SHIM_LIB_DIR" ] || fail "missing source shim helper directory: $SOURCE_SHIM_LIB_DIR"

  log_info "Installing shimmy into $SHIMMY_INSTALL_DIR"

  mkdir -p "$SHIMMY_INSTALL_DIR"
  rm -rf "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR" "$SHIMMY_SHIM_LIB_DIR"
  mkdir -p "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR" "$(dirname "$SHIMMY_SHIM_LIB_DIR")"

  for shim_name in $(selected_shim_list); do
    source_path=$SOURCE_SHIMS_DIR/$shim_name
    target_path=$SHIMMY_SHIM_DIR/$shim_name
    [ -f "$source_path" ] || fail "missing shim source: $source_path"
    log_debug "Copying shim $shim_name to $target_path"
    install_file "$source_path" "$target_path"
  done

  for shim_name in $(selected_shim_list); do
    source_path=$SOURCE_IMAGES_DIR/$shim_name
    target_path=$SHIMMY_IMAGES_DIR/$shim_name
    if [ -d "$source_path" ]; then
      log_debug "Copying image support for $shim_name to $target_path"
      install_directory_copy "$source_path" "$target_path"
    fi
  done

  log_debug "Copying shared shim helper support to $SHIMMY_SHIM_LIB_DIR"
  install_directory_copy "$SOURCE_SHIM_LIB_DIR" "$SHIMMY_SHIM_LIB_DIR"

  if [ -n "$STARTUP_FILE_PATH" ]; then
    activate_block=$(shimmy_activate_block_read "$ACTIVATE_SCRIPT" "$SHIMMY_INSTALL_DIR") || fail "unable to render activate block for startup file"
    shimmy_startup_file_update "$STARTUP_FILE_PATH" "$activate_block"
    log_info "Updated startup file: $STARTUP_FILE_LABEL"
  fi

  write_manifest

  log_info "Installed shimmy assets into $SHIMMY_INSTALL_DIR"
  log_info "Future shells will load Shimmy from: ${STARTUP_FILE_LABEL:-manual activation only}"
  log_info "Activate this install with: eval \"\$(./shimmy activate --install-dir '$SHIMMY_INSTALL_DIR')\""
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
  startup_file_to_remove=$(manifest_value "$INSTALL_MANIFEST_FILE" startup_file || true)

  if [ -n "$startup_file_to_remove" ]; then
    shimmy_startup_block_remove "$startup_file_to_remove"
    log_info "Removed managed Shimmy startup block from: $startup_file_to_remove"
  fi

  remove_path_if_present "$SHIMMY_SHIM_DIR" "shim"
  remove_path_if_present "$SHIMMY_IMAGES_DIR" "image"
  remove_path_if_present "$SHIMMY_SHIM_LIB_DIR" "shim helper"
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
        REQUESTED_STARTUP_FILE=$2
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
