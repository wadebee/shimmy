#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)

SOURCE_SHIMS_DIR=$ROOT_DIR/shims
SOURCE_IMAGES_DIR=$ROOT_DIR/images
SOURCE_SHIM_LIB_DIR=$ROOT_DIR/lib/shims

DEFAULT_INSTALL_DIR=$HOME/.config/shimmy
SUPPORTED_SHIMS='aws jq netcat rg task terraform textual'

INSTALL_MODE=copy
REQUESTED_INSTALL_DIR=
REQUESTED_SHIMS=
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

usage() {
  cat <<'EOF'
Install or uninstall Shimmy assets in a user-scoped location.

Usage:
  scripts/install-shimmy.sh [options]

Options:
  --install-dir <dir>    Base install directory. Default: ~/.config/shimmy
  --copy                 Copy install assets (default)
  --symlink              Symlink install assets from the repo
  --shim <name>          Install only the named shim. Repeatable.
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

resolve_install_paths() {
  install_dir_candidate=

  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    install_dir_candidate=$REQUESTED_INSTALL_DIR
  elif [ -n "${SHIMMY_INSTALL_DIR:-}" ]; then
    install_dir_candidate=$SHIMMY_INSTALL_DIR
  else
    install_dir_candidate=$DEFAULT_INSTALL_DIR
  fi

  SHIMMY_INSTALL_DIR=$(trim_trailing_slash "$install_dir_candidate")
  SHIMMY_SHIM_DIR=$(trim_trailing_slash "${SHIMMY_SHIM_DIR:-$SHIMMY_INSTALL_DIR/shims}")
  SHIMMY_IMAGES_DIR=$(trim_trailing_slash "${SHIMMY_IMAGES_DIR:-$SHIMMY_INSTALL_DIR/images}")
  SHIMMY_SHIM_LIB_DIR=$(trim_trailing_slash "${SHIMMY_SHIM_LIB_DIR:-$SHIMMY_INSTALL_DIR/lib/shims}")
  INSTALL_MANIFEST_FILE=$SHIMMY_INSTALL_DIR/install-manifest.txt

  export SHIMMY_INSTALL_DIR SHIMMY_SHIM_DIR SHIMMY_IMAGES_DIR SHIMMY_SHIM_LIB_DIR
}

manifest_value() {
  manifest_file=$1
  key=$2

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$manifest_file" | sed -n '1p'
}

load_paths_from_manifest() {
  if [ ! -f "$INSTALL_MANIFEST_FILE" ]; then
    return 1
  fi

  SHIMMY_INSTALL_DIR=$(manifest_value "$INSTALL_MANIFEST_FILE" install_dir || printf '%s\n' "$SHIMMY_INSTALL_DIR")
  SHIMMY_SHIM_DIR=$(manifest_value "$INSTALL_MANIFEST_FILE" shim_dir || printf '%s\n' "$SHIMMY_SHIM_DIR")
  SHIMMY_IMAGES_DIR=$(manifest_value "$INSTALL_MANIFEST_FILE" images_dir || printf '%s\n' "$SHIMMY_IMAGES_DIR")
  SHIMMY_SHIM_LIB_DIR=$(manifest_value "$INSTALL_MANIFEST_FILE" shim_lib_dir || printf '%s\n' "$SHIMMY_SHIM_LIB_DIR")

  export SHIMMY_INSTALL_DIR SHIMMY_SHIM_DIR SHIMMY_IMAGES_DIR SHIMMY_SHIM_LIB_DIR
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

install_symlink() {
  source_path=$1
  target_path=$2

  rm -rf "$target_path"
  ln -s "$source_path" "$target_path"
}

write_manifest() {
  mkdir -p "$SHIMMY_INSTALL_DIR"

  {
    printf 'install_dir=%s\n' "$SHIMMY_INSTALL_DIR"
    printf 'shim_dir=%s\n' "$SHIMMY_SHIM_DIR"
    printf 'images_dir=%s\n' "$SHIMMY_IMAGES_DIR"
    printf 'shim_lib_dir=%s\n' "$SHIMMY_SHIM_LIB_DIR"
    printf 'install_mode=%s\n' "$INSTALL_MODE"
    for shim_name in $(selected_shim_list); do
      printf 'shim=%s\n' "$shim_name"
    done
  } > "$INSTALL_MANIFEST_FILE"
}

perform_install() {
  validate_requested_shims

  [ -d "$SOURCE_SHIMS_DIR" ] || fail "missing source shim directory: $SOURCE_SHIMS_DIR"
  [ -d "$SOURCE_SHIM_LIB_DIR" ] || fail "missing source shim helper directory: $SOURCE_SHIM_LIB_DIR"

  log_info "Installing shimmy into $SHIMMY_INSTALL_DIR using mode $INSTALL_MODE"

  mkdir -p "$SHIMMY_INSTALL_DIR"
  mkdir -p "$(dirname "$SHIMMY_SHIM_DIR")" "$(dirname "$SHIMMY_IMAGES_DIR")" "$(dirname "$SHIMMY_SHIM_LIB_DIR")"

  if [ "$INSTALL_MODE" = "copy" ]; then
    mkdir -p "$SHIMMY_SHIM_DIR"
    for shim_name in $(selected_shim_list); do
      source_path=$SOURCE_SHIMS_DIR/$shim_name
      target_path=$SHIMMY_SHIM_DIR/$shim_name
      [ -f "$source_path" ] || fail "missing shim source: $source_path"
      log_debug "Copying shim $shim_name to $target_path"
      install_file "$source_path" "$target_path"
    done

    mkdir -p "$SHIMMY_IMAGES_DIR"
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
  else
    rm -rf "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR" "$SHIMMY_SHIM_LIB_DIR"
    mkdir -p "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR" "$(dirname "$SHIMMY_SHIM_LIB_DIR")"
    for shim_name in $(selected_shim_list); do
      source_path=$SOURCE_SHIMS_DIR/$shim_name
      target_path=$SHIMMY_SHIM_DIR/$shim_name
      [ -f "$source_path" ] || fail "missing shim source: $source_path"
      log_debug "Symlinking shim $shim_name to $target_path"
      install_symlink "$source_path" "$target_path"
    done

    for shim_name in $(selected_shim_list); do
      source_path=$SOURCE_IMAGES_DIR/$shim_name
      target_path=$SHIMMY_IMAGES_DIR/$shim_name
      if [ -d "$source_path" ]; then
        log_debug "Symlinking image support for $shim_name to $target_path"
        install_symlink "$source_path" "$target_path"
      fi
    done

    log_debug "Symlinking shim helper directory to $SHIMMY_SHIM_LIB_DIR"
    install_symlink "$SOURCE_SHIM_LIB_DIR" "$SHIMMY_SHIM_LIB_DIR"
  fi

  write_manifest

  log_info "Installed shimmy assets into $SHIMMY_INSTALL_DIR"
  log_info "Activate this install with: eval \"\$(./shimmy shellenv --install-dir $SHIMMY_INSTALL_DIR)\""
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

  load_paths_from_manifest || true

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
        INSTALL_MODE=copy
        shift
        ;;
      --symlink)
        INSTALL_MODE=symlink
        shift
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
