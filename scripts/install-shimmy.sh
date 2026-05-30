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
SOURCE_PLUGIN_DIR=$ROOT_DIR/plugins
SOURCE_AGENT_SKILLS_DIR=$ROOT_DIR/.agents/skills
SOURCE_REPO_LIB_DIR=$ROOT_DIR/lib/repo
SOURCE_SHIM_LIB_DIR=$ROOT_DIR/lib/shims
CATALOG_HELPER_FILE=$SOURCE_REPO_LIB_DIR/shimmy-catalog.sh
PROFILE_HELPER_FILE=$SOURCE_REPO_LIB_DIR/shimmy-profile.sh
STARTUP_HELPER_FILE=$SOURCE_REPO_LIB_DIR/shimmy-startup.sh
SKILLS_SCRIPT=$SOURCE_SCRIPT_DIR/skills-shimmy.sh

DEFAULT_INSTALL_DIR=${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}

REQUESTED_INSTALL_DIR=
REQUESTED_MODE=
REQUESTED_SHIMS=
REQUESTED_SKILLS_TARGET=
REQUESTED_SHELL=
REQUESTED_STARTUP_FILES=
SKIP_STARTUP=0
SKIP_SKILLS=0
ADD_SHIMS=0
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

line_list_contains() {
  list_value=${1:-}
  line_value=$2

  while IFS= read -r existing_line; do
    [ -n "$existing_line" ] || continue
    if [ "$existing_line" = "$line_value" ]; then
      return 0
    fi
  done <<EOF
$list_value
EOF

  return 1
}

requested_shim_append() {
  requested_shim=$1

  if [ -n "$REQUESTED_SHIMS" ]; then
    REQUESTED_SHIMS="$REQUESTED_SHIMS $requested_shim"
  else
    REQUESTED_SHIMS=$requested_shim
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

if [ ! -f "$PROFILE_HELPER_FILE" ]; then
  fail "missing profile helper: $PROFILE_HELPER_FILE"
fi

# shellcheck source=lib/repo/shimmy-catalog.sh
. "$CATALOG_HELPER_FILE"
# shellcheck source=lib/repo/shimmy-profile.sh
. "$PROFILE_HELPER_FILE"
# shellcheck source=lib/repo/shimmy-startup.sh
. "$STARTUP_HELPER_FILE"

usage() {
  cat <<'EOF'
Install or uninstall Shimmy assets in a user-scoped location.

Usage:
  scripts/install-shimmy.sh [options]

Options:
  --install-dir <dir>    Base install directory. Default: ~/.config/shimmy
  --mode <name>          Install profile mode: default or upstream
  --shim <name>          Install only the named shim. Repeatable.
  --add-shim             Add named shims to an existing install without reinstalling
  --skills-target <name> Share Shimmy agent skills to repo, profile, or plugin
  --no-skills            Do not prompt for or share Shimmy agent skills
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

validate_skills_target() {
  case "$1" in
    repo|profile|plugin)
      ;;
    *)
      fail "unsupported skills target: $1"
      ;;
  esac
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

manifest_shim_list() {
  manifest_file=$1

  manifest_values "$manifest_file" shim || true
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

manifest_shims_append() {
  manifest_file=$1
  shim_list=$2
  manifest_tmp=$manifest_file.tmp.$$

  {
    while IFS= read -r manifest_line || [ -n "$manifest_line" ]; do
      printf '%s\n' "$manifest_line"
    done < "$manifest_file"

    while IFS= read -r shim_name; do
      [ -n "$shim_name" ] || continue
      printf 'shim=%s\n' "$shim_name"
    done <<EOF
$shim_list
EOF
  } > "$manifest_tmp"

  mv "$manifest_tmp" "$manifest_file"
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
  install_root=$(resolve_install_root)
  if ! shimmy_profile_paths_resolve "$REQUESTED_MODE" "$install_root" "$ROOT_DIR"; then
    fail "unsupported shimmy mode: ${REQUESTED_MODE:-${SHIMMY_MODE:-}}"
  fi

  SHIMMY_MODE_RESOLVED=$SHIMMY_PROFILE_MODE
  SHIMMY_INSTALL_DIR=$SHIMMY_PROFILE_INSTALL_DIR
  SHIMMY_DISPATCHER_DIR=$SHIMMY_PROFILE_DISPATCHER_DIR
  SHIMMY_PROFILE_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_PATH
  SHIMMY_LEGACY_MANIFEST_FILE=$(install_path_render "$SHIMMY_INSTALL_DIR" install-manifest.txt)
  SHIMMY_LEGACY_SHIM_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" shims)
  SHIMMY_LEGACY_IMAGES_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" images)
  SHIMMY_LEGACY_SHIM_LIB_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" lib/shims)
  SHIMMY_SHIM_DIR=$SHIMMY_PROFILE_BIN_DIR
  SHIMMY_IMAGES_DIR=$(install_path_render "$SHIMMY_PROFILE_DIR" images)
  SHIMMY_SHIM_LIB_DIR=$(install_path_render "$SHIMMY_PROFILE_DIR" lib/shims)
  SHIMMY_CONTROL_BIN_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" bin)
  SHIMMY_CONTROL_BIN=$(install_path_render "$SHIMMY_CONTROL_BIN_DIR" shimmy)
  SHIMMY_CONTROL_SOURCE_DIR=$(install_path_render "$SHIMMY_INSTALL_DIR" libexec/shimmy)
  SHIMMY_CONTROL_SCRIPT_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" scripts)
  SHIMMY_CONTROL_SHIMS_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" shims)
  SHIMMY_CONTROL_IMAGES_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" images)
  SHIMMY_CONTROL_REPO_LIB_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" lib/repo)
  SHIMMY_CONTROL_SHIM_LIB_DIR=$(install_path_render "$SHIMMY_CONTROL_SOURCE_DIR" lib/shims)
  SHIMMY_ACTIVATE_FILE=$(install_path_render "$SHIMMY_INSTALL_DIR" activate.sh)
  case "$SHIMMY_MODE_RESOLVED" in
    default)
      INSTALL_MANIFEST_FILE=$SHIMMY_LEGACY_MANIFEST_FILE
      ;;
    upstream)
      INSTALL_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_FILE
      ;;
  esac
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

install_agent_skill_assets() {
  [ -d "$SOURCE_AGENT_SKILLS_DIR" ] || return 0

  target_root=$SHIMMY_CONTROL_SOURCE_DIR/.agents/skills
  mkdir -p "$target_root"

  for source_path in "$SOURCE_AGENT_SKILLS_DIR"/shimmy-*; do
    [ -d "$source_path" ] || continue
    skill_name=$(basename "$source_path")
    install_directory_copy "$source_path" "$target_root/$skill_name"
  done
}

install_shim_management_assets() {
  shim_name=$1
  source_path=$SOURCE_SHIMS_DIR/$shim_name
  target_path=$SHIMMY_CONTROL_SHIMS_DIR/$shim_name

  [ -f "$source_path" ] || fail "missing shim source: $source_path"
  log_debug "Copying management source shim $shim_name to $target_path"
  install_file "$source_path" "$target_path"

  source_path=$SOURCE_IMAGES_DIR/$shim_name
  target_path=$SHIMMY_CONTROL_IMAGES_DIR/$shim_name
  if [ -d "$source_path" ]; then
    log_debug "Copying management source image support for $shim_name to $target_path"
    install_directory_copy "$source_path" "$target_path"
  fi
}

install_shim_runtime_assets() {
  shim_name=$1
  install_shim_runtime_assets_to "$shim_name" "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR"
}

install_shim_runtime_assets_to() {
  shim_name=$1
  shim_dir=$2
  images_dir=$3
  source_path=$SOURCE_SHIMS_DIR/$shim_name
  target_path=$shim_dir/$shim_name

  [ -f "$source_path" ] || fail "missing shim source: $source_path"
  log_debug "Copying shim $shim_name to $target_path"
  install_file "$source_path" "$target_path"

  source_path=$SOURCE_IMAGES_DIR/$shim_name
  target_path=$images_dir/$shim_name
  if [ -d "$source_path" ]; then
    log_debug "Copying image support for $shim_name to $target_path"
    install_directory_copy "$source_path" "$target_path"
  fi
}

install_control_assets() {
  [ -f "$SOURCE_CONTROL_FILE" ] || fail "missing source management launcher: $SOURCE_CONTROL_FILE"
  [ -d "$SOURCE_SCRIPT_DIR" ] || fail "missing source script directory: $SOURCE_SCRIPT_DIR"
  [ -d "$SOURCE_SHIMS_DIR" ] || fail "missing source shim directory: $SOURCE_SHIMS_DIR"
  [ -d "$SOURCE_IMAGES_DIR" ] || fail "missing source image support directory: $SOURCE_IMAGES_DIR"
  [ -d "$SOURCE_REPO_LIB_DIR" ] || fail "missing source repo helper directory: $SOURCE_REPO_LIB_DIR"

  if [ "$ROOT_DIR" != "$SHIMMY_CONTROL_SOURCE_DIR" ]; then
    rm -rf "$SHIMMY_CONTROL_SOURCE_DIR"
  fi

  mkdir -p "$SHIMMY_CONTROL_BIN_DIR" "$SHIMMY_CONTROL_SCRIPT_DIR" \
    "$SHIMMY_CONTROL_SHIMS_DIR" "$SHIMMY_CONTROL_IMAGES_DIR" \
    "$(dirname "$SHIMMY_CONTROL_REPO_LIB_DIR")"

  install_file "$SOURCE_CONTROL_FILE" "$SHIMMY_CONTROL_BIN"
  install_file "$SOURCE_CONTROL_FILE" "$SHIMMY_CONTROL_SOURCE_DIR/shimmy"

  for script_name in activate-shimmy.sh install-shimmy.sh netinfo-shimmy.sh skills-shimmy.sh status-shimmy.sh update-shimmy.sh; do
    source_path=$SOURCE_SCRIPT_DIR/$script_name
    target_path=$SHIMMY_CONTROL_SCRIPT_DIR/$script_name
    [ -f "$source_path" ] || fail "missing management script source: $source_path"
    install_file "$source_path" "$target_path"
  done

  install_directory_copy "$SOURCE_REPO_LIB_DIR" "$SHIMMY_CONTROL_REPO_LIB_DIR"
  install_directory_copy "$SOURCE_SHIM_LIB_DIR" "$SHIMMY_CONTROL_SHIM_LIB_DIR"
  install_directory_copy "$SOURCE_SHIMS_DIR" "$SHIMMY_CONTROL_SHIMS_DIR"
  install_directory_copy "$SOURCE_IMAGES_DIR" "$SHIMMY_CONTROL_IMAGES_DIR"
  if [ -d "$SOURCE_PLUGIN_DIR" ]; then
    install_directory_copy "$SOURCE_PLUGIN_DIR" "$SHIMMY_CONTROL_SOURCE_DIR/plugins"
  fi
  install_agent_skill_assets
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

skills_target_prompt() {
  [ -t 0 ] && [ -t 2 ] || return 1

  while :; do
    printf 'Share Shimmy agent skills? Choose target [repo/profile/plugin/none] (repo): ' >&2
    IFS= read -r skills_target_answer || return 1
    case "$skills_target_answer" in
      '')
        printf 'repo\n'
        return 0
        ;;
      repo|profile|plugin)
        printf '%s\n' "$skills_target_answer"
        return 0
        ;;
      none|skip|no)
        printf 'none\n'
        return 0
        ;;
      *)
        printf 'ERROR: enter repo, profile, plugin, or none\n' >&2
        ;;
    esac
  done
}

share_management_skills() {
  [ "$SKIP_SKILLS" -eq 0 ] || return 0

  if [ ! -x "$SKILLS_SCRIPT" ]; then
    fail "missing skills helper: $SKILLS_SCRIPT"
  fi

  skills_target=$REQUESTED_SKILLS_TARGET
  if [ -z "$skills_target" ]; then
    skills_target=$(skills_target_prompt || true)
  fi

  case "$skills_target" in
    '')
      return 0
      ;;
    none)
      log_info "Skipped Shimmy management skill sharing"
      return 0
      ;;
  esac

  validate_skills_target "$skills_target"
  "$SKILLS_SCRIPT" install --target "$skills_target" --manifest "$INSTALL_MANIFEST_FILE"
}

write_activate_file() {
  "$ACTIVATE_SCRIPT" --install-dir "$SHIMMY_INSTALL_DIR" > "$SHIMMY_ACTIVATE_FILE"
  chmod 644 "$SHIMMY_ACTIVATE_FILE"
}

write_manifest() {
  shimmy_source_ref=$(source_ref_resolve)
  shimmy_source_url=$(source_url_resolve)
  shimmy_previous_source_ref=${SHIMMY_PREVIOUS_SOURCE_REF:-}
  if [ -z "$shimmy_previous_source_ref" ]; then
    shimmy_previous_source_ref=$(manifest_value "$INSTALL_MANIFEST_FILE" shimmy_previous_source_ref || true)
  fi

  write_manifest_file "$INSTALL_MANIFEST_FILE" "$shimmy_source_url" "$shimmy_source_ref" "$shimmy_previous_source_ref"

  if [ "$SHIMMY_MODE_RESOLVED" = default ] && [ "$SHIMMY_PROFILE_MANIFEST_FILE" != "$INSTALL_MANIFEST_FILE" ]; then
    write_manifest_file "$SHIMMY_PROFILE_MANIFEST_FILE" "$shimmy_source_url" "$shimmy_source_ref" "$shimmy_previous_source_ref"
  fi
}

write_manifest_file() {
  manifest_file=$1
  shimmy_source_url=$2
  shimmy_source_ref=$3
  shimmy_previous_source_ref=$4

  mkdir -p "$(dirname "$manifest_file")"

  {
    printf 'mode=%s\n' "$SHIMMY_MODE_RESOLVED"
    printf 'install_dir=%s\n' "$SHIMMY_INSTALL_DIR"
    printf 'config_dir=%s\n' "$SHIMMY_PROFILE_CONFIG_DIR"
    printf 'dispatcher_dir=%s\n' "$SHIMMY_DISPATCHER_DIR"
    printf 'bin_dir=%s\n' "$SHIMMY_SHIM_DIR"
    printf 'manifest_path=%s\n' "$manifest_file"
    printf 'profile_implementation_dir=%s\n' "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"
    printf 'shim_source=copied-source-shim\n'
    if [ -n "$SHIMMY_PROFILE_SOURCE_CHECKOUT" ]; then
      printf 'source_checkout=%s\n' "$SHIMMY_PROFILE_SOURCE_CHECKOUT"
    fi
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
  } > "$manifest_file"
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
  log_info "Selected Shimmy mode: $SHIMMY_MODE_RESOLVED"

  mkdir -p "$SHIMMY_INSTALL_DIR"
  rm -rf "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR" "$SHIMMY_SHIM_LIB_DIR"
  if [ "$SHIMMY_MODE_RESOLVED" = default ]; then
    rm -rf "$SHIMMY_LEGACY_SHIM_DIR" "$SHIMMY_LEGACY_IMAGES_DIR" "$SHIMMY_LEGACY_SHIM_LIB_DIR"
  fi
  rm -f "$SHIMMY_CONTROL_BIN"
  mkdir -p "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR" "$(dirname "$SHIMMY_SHIM_LIB_DIR")" "$SHIMMY_DISPATCHER_DIR"
  if [ "$SHIMMY_MODE_RESOLVED" = default ]; then
    mkdir -p "$SHIMMY_LEGACY_SHIM_DIR" "$SHIMMY_LEGACY_IMAGES_DIR" "$(dirname "$SHIMMY_LEGACY_SHIM_LIB_DIR")"
  fi

  log_debug "Copying management command support to $SHIMMY_CONTROL_SOURCE_DIR"
  install_control_assets

  for shim_name in $(selected_shim_list); do
    install_shim_runtime_assets "$shim_name"
    if [ "$SHIMMY_MODE_RESOLVED" = default ]; then
      install_shim_runtime_assets_to "$shim_name" "$SHIMMY_LEGACY_SHIM_DIR" "$SHIMMY_LEGACY_IMAGES_DIR"
    fi
  done

  log_debug "Copying shared shim helper support to $SHIMMY_SHIM_LIB_DIR"
  install_directory_copy "$SOURCE_SHIM_LIB_DIR" "$SHIMMY_SHIM_LIB_DIR"
  if [ "$SHIMMY_MODE_RESOLVED" = default ]; then
    log_debug "Copying legacy shared shim helper support to $SHIMMY_LEGACY_SHIM_LIB_DIR"
    install_directory_copy "$SOURCE_SHIM_LIB_DIR" "$SHIMMY_LEGACY_SHIM_LIB_DIR"
  fi

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
  share_management_skills
  if [ "$SHIMMY_MODE_RESOLVED" = default ] && [ "$SHIMMY_PROFILE_MANIFEST_FILE" != "$INSTALL_MANIFEST_FILE" ]; then
    write_manifest_file "$SHIMMY_PROFILE_MANIFEST_FILE" "$(source_url_resolve)" "$(source_ref_resolve)" "$(manifest_value "$INSTALL_MANIFEST_FILE" shimmy_previous_source_ref || true)"
  fi

  log_info "Installed shimmy assets into $SHIMMY_INSTALL_DIR"
  log_info "Future shells will load Shimmy from: $(startup_file_summary_render "$STARTUP_FILE_PATHS")"
  log_info "Activate this install with: eval \"\$('$SHIMMY_CONTROL_BIN' activate)\""
  podman_macos_guidance_log
}

perform_shim_install() {
  [ -n "$REQUESTED_SHIMS" ] || fail "install must include the name of an available shim"
  [ "$UNINSTALL" -eq 0 ] || fail "--add-shim cannot be combined with --uninstall"
  [ "$SKIP_STARTUP" -eq 0 ] || fail "--no-startup is not supported when installing shims into an existing environment"
  [ "$SKIP_SKILLS" -eq 0 ] || fail "--no-skills is not supported when installing shims into an existing environment"
  [ -z "$REQUESTED_SKILLS_TARGET" ] || fail "--skills-target is not supported when installing shims into an existing environment"
  [ -z "$REQUESTED_SHELL" ] || fail "--shell is not supported when installing shims into an existing environment"
  [ -z "$REQUESTED_STARTUP_FILES" ] || fail "--startup-file is not supported when installing shims into an existing environment"
  [ -f "$INSTALL_MANIFEST_FILE" ] || fail "no shimmy install manifest found at $INSTALL_MANIFEST_FILE; run ./shimmy install first"

  load_install_root_from_manifest || true
  validate_requested_shims

  [ -d "$SOURCE_SHIMS_DIR" ] || fail "missing source shim directory: $SOURCE_SHIMS_DIR"
  [ -d "$SOURCE_IMAGES_DIR" ] || fail "missing source image support directory: $SOURCE_IMAGES_DIR"
  [ -d "$SOURCE_SHIM_LIB_DIR" ] || fail "missing source shim helper directory: $SOURCE_SHIM_LIB_DIR"

  mkdir -p "$SHIMMY_SHIM_DIR" "$SHIMMY_IMAGES_DIR" "$(dirname "$SHIMMY_SHIM_LIB_DIR")" \
    "$SHIMMY_CONTROL_SHIMS_DIR" "$SHIMMY_CONTROL_IMAGES_DIR"

  installed_shims=$(manifest_shim_list "$INSTALL_MANIFEST_FILE")
  shims_to_append=

  for shim_name in $(selected_shim_list); do
    install_shim_runtime_assets "$shim_name"
    install_shim_management_assets "$shim_name"

    if line_list_contains "$installed_shims" "$shim_name" || line_list_contains "$shims_to_append" "$shim_name"; then
      log_info "Refreshed installed shim: $shim_name"
      continue
    fi

    shims_to_append=$(line_list_append "$shims_to_append" "$shim_name")
    log_info "Installed shim: $shim_name"
  done

  log_debug "Copying shared shim helper support to $SHIMMY_SHIM_LIB_DIR"
  install_directory_copy "$SOURCE_SHIM_LIB_DIR" "$SHIMMY_SHIM_LIB_DIR"

  if [ -n "$shims_to_append" ]; then
    manifest_shims_append "$INSTALL_MANIFEST_FILE" "$shims_to_append"
  fi
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
  [ "$SKIP_SKILLS" -eq 0 ] || fail "--no-skills is not supported with --uninstall"
  [ -z "$REQUESTED_SKILLS_TARGET" ] || fail "--skills-target is not supported with --uninstall"

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
  remove_path_if_present "$SHIMMY_PROFILE_DIR" "profile"

  if [ -d "$SHIMMY_INSTALL_DIR/lib" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/lib" 2>/dev/null || true
  fi
  if [ -d "$SHIMMY_INSTALL_DIR/profiles" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/profiles" 2>/dev/null || true
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
      --mode)
        [ "$#" -ge 2 ] || fail "missing value for --mode"
        REQUESTED_MODE=$2
        shift 2
        ;;
      --copy)
        shift
        ;;
      --add-shim)
        ADD_SHIMS=1
        shift
        ;;
      --skills-target)
        [ "$#" -ge 2 ] || fail "missing value for --skills-target"
        REQUESTED_SKILLS_TARGET=$2
        validate_skills_target "$REQUESTED_SKILLS_TARGET"
        shift 2
        ;;
      --no-skills)
        SKIP_SKILLS=1
        shift
        ;;
      --symlink)
        fail "symlink install mode has been removed on the posix-rewrite branch"
        ;;
      --shim)
        [ "$#" -ge 2 ] || fail "missing value for --shim"
        requested_shim_append "$2"
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
        if [ "$ADD_SHIMS" -eq 1 ]; then
          requested_shim_append "$1"
          shift
        else
          fail "unknown argument: $1"
        fi
        ;;
    esac
  done

  resolve_install_paths

  if [ "$ADD_SHIMS" -eq 1 ]; then
    perform_shim_install
  elif [ "$UNINSTALL" -eq 1 ]; then
    perform_uninstall
  else
    perform_install
  fi
}

main "$@"
