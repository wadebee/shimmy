#!/bin/sh
# Install or remove Shimmy profiles and runtime assets.
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)

ACTIVATE_SCRIPT=$SCRIPT_DIR/activate.sh
SOURCE_CONTROL_FILE=$ROOT_DIR/shimmy
SOURCE_COMMAND_DIR=$ROOT_DIR/commands
SOURCE_TOOLS_DIR=$ROOT_DIR/tools
SOURCE_CORE_DIR=$ROOT_DIR/core
SOURCE_TESTS_DIR=$ROOT_DIR/tests
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
SOURCE_PLUGIN_DIR=$ROOT_DIR/plugins
SOURCE_AGENT_SKILLS_DIR=$ROOT_DIR/.agents/skills
COMMON_HELPER_FILE=$SOURCE_CORE_DIR/common/common.sh
CATALOG_HELPER_FILE=$SOURCE_CORE_DIR/catalog/catalog.sh
PROFILE_HELPER_FILE=$SOURCE_CORE_DIR/profile/profile.sh
STARTUP_HELPER_FILE=$SOURCE_CORE_DIR/startup/startup.sh
SKILLS_SCRIPT=$SOURCE_COMMAND_DIR/skills.sh

DEFAULT_INSTALL_DIR=${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}

REQUESTED_INSTALL_DIR=
SHIMMY_PROFILE_REQUESTED=
REQUESTED_SHIMS=
REQUESTED_SKILLS_TARGET=
REQUESTED_SHELL=
REQUESTED_STARTUP_FILES=
SKIP_STARTUP=0
SKIP_SKILLS=0
REFRESH_SHIMS=0
SHIMMY_PROFILE_ACTIVATED=0
STARTUP_FILE_PATHS=
STARTUP_SHELL=
PRESERVED_STARTUP_FILE_PATHS=
PRESERVED_STARTUP_SHELL=
PRESERVED_SHIMMY_MANIFEST_LINES=
PROFILE_MANIFEST_KIND_VERSIONS=
PROFILE_MANIFEST_KINDS=
UNINSTALL=0

LOG_LEVEL=${LOG_LEVEL:-info}

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

if [ ! -f "$COMMON_HELPER_FILE" ]; then
  fail "missing common helper: $COMMON_HELPER_FILE"
fi

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

# shellcheck source=core/common/common.sh
. "$COMMON_HELPER_FILE"
# shellcheck source=core/catalog/catalog.sh
. "$CATALOG_HELPER_FILE"
# shellcheck source=core/profile/profile.sh
. "$PROFILE_HELPER_FILE"
# shellcheck source=core/startup/startup.sh
. "$STARTUP_HELPER_FILE"

usage() {
  cat <<'EOF'
Install or uninstall Shimmy assets in a user-scoped location.

Usage:
  commands/install.sh [options]

Options:
  --install-dir <dir>    Base install directory. Default: ~/.config/shimmy
  --profile <name>          Install profile: default or upstream
  --shim <name>          Install the named shim if missing. Repeatable.
  --skills-target <name> Share or remove Shimmy agent skills in repo, profile, or plugin
  --no-skills            Do not prompt for, share, or remove Shimmy agent skills
  --shell <name>         Override shell detection for startup-file updates
  --startup-file <path>  Override startup file updates. Repeatable.
  --no-startup           Skip persistent startup-file updates during install
  --uninstall            Remove a profile; requires --profile default or --profile upstream
  -h, --help             Show help
EOF
}

selected_shim_list() {
  if [ -n "$REQUESTED_SHIMS" ]; then
    printf '%s\n' "$REQUESTED_SHIMS"
    return 0
  fi

  shimmy_default_kind_list
}

version_label_list_render() {
  kind_name=$1
  separator=

  for version_label in $(shimmy_kind_version_label_list "$kind_name"); do
    printf '%s%s' "$separator" "$version_label"
    separator=', '
  done
  printf '\n'
}

kind_list_render() {
  separator=

  for kind_name in $(shimmy_kind_list); do
    printf '%s%s' "$separator" "$kind_name"
    separator=', '
  done
  printf '\n'
}

kind_version_entry_print() {
  entry_kind_name=$1
  entry_version_label=$2
  entry_version_name=$3

  printf '%s|%s|%s\n' "$entry_kind_name" "$entry_version_label" "$entry_version_name"
}

request_kind_version_entries_resolve() {
  requested_shim=$1

  case "$requested_shim" in
    *@*)
      kind_name=${requested_shim%%@*}
      version_label=${requested_shim#*@}
      shimmy_is_kind "$kind_name" || fail "unsupported shim kind: $kind_name. Available kinds: $(kind_list_render)"
      version_name=$(shimmy_kind_version_for_label "$kind_name" "$version_label" || true)
      if [ -z "$version_name" ]; then
        fail "unsupported $kind_name version: $version_label. Available $kind_name versions: $(version_label_list_render "$kind_name"). Default $kind_name version: $(shimmy_version_label "$(shimmy_kind_default_version "$kind_name")")"
      fi
      default_version=$(shimmy_kind_default_version "$kind_name")
      kind_version_entry_print "$kind_name" default "$default_version"
      kind_version_entry_print "$kind_name" "$(shimmy_version_label "$default_version")" "$default_version"
      kind_version_entry_print "$kind_name" "$version_label" "$version_name"
      ;;
    *)
      if shimmy_is_kind "$requested_shim"; then
        kind_name=$requested_shim
        default_version=$(shimmy_kind_default_version "$kind_name")
        kind_version_entry_print "$kind_name" default "$default_version"
        kind_version_entry_print "$kind_name" "$(shimmy_version_label "$default_version")" "$default_version"
      elif shimmy_is_version "$requested_shim"; then
        version_name=$requested_shim
        kind_name=$(shimmy_version_kind "$version_name")
        default_version=$(shimmy_kind_default_version "$kind_name")
        kind_version_entry_print "$kind_name" default "$default_version"
        kind_version_entry_print "$kind_name" "$(shimmy_version_label "$default_version")" "$default_version"
        kind_version_entry_print "$kind_name" "$(shimmy_version_label "$version_name")" "$version_name"
      else
        fail "unsupported shim kind: $requested_shim. Available kinds: $(kind_list_render)"
      fi
      ;;
  esac
}

selected_kind_version_entries() {
  selected_entries=

  for requested_shim in $(selected_shim_list); do
    requested_entries=$(request_kind_version_entries_resolve "$requested_shim") || return 1
    while IFS= read -r kind_version_entry; do
      [ -n "$kind_version_entry" ] || continue
      if ! shimmy_contains_line_list "$selected_entries" "$kind_version_entry"; then
        selected_entries=$(shimmy_append_line_list "$selected_entries" "$kind_version_entry")
      fi
    done <<EOF
$requested_entries
EOF
  done

  printf '%s\n' "$selected_entries"
}

kind_list_from_entries() {
  kind_version_entries=$1
  kind_names=

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    kind_name=${kind_version_entry%%|*}
    if ! shimmy_contains_line_list "$kind_names" "$kind_name"; then
      kind_names=$(shimmy_append_line_list "$kind_names" "$kind_name")
    fi
  done <<EOF
$kind_version_entries
EOF

  printf '%s\n' "$kind_names"
}

version_list_from_entries() {
  kind_version_entries=$1
  version_names=

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    version_name=${kind_version_entry##*|}
    if ! shimmy_contains_line_list "$version_names" "$version_name"; then
      version_names=$(shimmy_append_line_list "$version_names" "$version_name")
    fi
  done <<EOF
$kind_version_entries
EOF

  printf '%s\n' "$version_names"
}

validate_requested_shims() {
  selected_kind_version_entries >/dev/null
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
    printf '%s\n' "$(shimmy_trim_path_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(shimmy_trim_path_trailing_slash "$DEFAULT_INSTALL_DIR")"
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
          shimmy_install_manifest_version|shimmy_manifest_version|shimmy_profile_manifest_version|shimmy_profile_name|shimmy_source_url|shimmy_source_ref|shimmy_previous_source_ref|shimmy_skill)
            ;;
          *)
            printf '%s\n' "$manifest_line"
            ;;
        esac
        ;;
    esac
  done < "$manifest_file"
}

manifest_kind_state_append() {
  manifest_file=$1
  kind_list=$2
  kind_version_entry_list=$3
  manifest_tmp=$manifest_file.tmp.$$

  {
    while IFS= read -r manifest_line || [ -n "$manifest_line" ]; do
      printf '%s\n' "$manifest_line"
    done < "$manifest_file"

    while IFS= read -r kind_name; do
      [ -n "$kind_name" ] || continue
      printf 'kind=%s\n' "$kind_name"
    done <<EOF
$kind_list
EOF

    while IFS= read -r kind_version_entry; do
      [ -n "$kind_version_entry" ] || continue
      printf 'kind_version=%s\n' "$kind_version_entry"
    done <<EOF
$kind_version_entry_list
EOF
  } > "$manifest_tmp"

  mv "$manifest_tmp" "$manifest_file"
}

profile_manifest_kind_list() {
  if [ -n "$PROFILE_MANIFEST_KINDS" ]; then
    printf '%s\n' "$PROFILE_MANIFEST_KINDS"
    return 0
  fi

  kind_list_from_entries "$(selected_kind_version_entries)"
}

profile_manifest_kind_version_list() {
  if [ -n "$PROFILE_MANIFEST_KIND_VERSIONS" ]; then
    printf '%s\n' "$PROFILE_MANIFEST_KIND_VERSIONS"
    return 0
  fi

  selected_kind_version_entries
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
  if ! shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$install_root" "$ROOT_DIR"; then
    fail "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
  fi

  SHIMMY_PROFILE_RESOLVED=$SHIMMY_PROFILE_NAME
  SHIMMY_INSTALL_DIR=$SHIMMY_PROFILE_INSTALL_DIR
  SHIMMY_BIN_DIR=$SHIMMY_INSTALL_BIN_DIR
  SHIMMY_PROFILE_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_PATH
  SHIMMY_ROOT_MANIFEST_FILE=$(shimmy_join_path "$SHIMMY_INSTALL_DIR" install-manifest.txt)
  SHIMMY_CONTROL_BIN=$(shimmy_join_path "$SHIMMY_BIN_DIR" shimmy)
  SHIMMY_CORE_DIR=$SHIMMY_INSTALL_CORE_DIR
  SHIMMY_CORE_COMMAND_DIR=$(shimmy_join_path "$SHIMMY_CORE_DIR" commands)
  SHIMMY_CORE_DISPATCHER=$(shimmy_join_path "$SHIMMY_CORE_COMMAND_DIR" dispatch-tool.sh)
  SHIMMY_CORE_TOOLS_DIR=$(shimmy_join_path "$SHIMMY_CORE_DIR" tools)
  SHIMMY_ACTIVATE_FILE=$(shimmy_join_path "$SHIMMY_INSTALL_DIR" activate.sh)
  INSTALL_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_FILE
}

load_install_root_from_manifest() {
  if [ ! -f "$SHIMMY_ROOT_MANIFEST_FILE" ]; then
    return 1
  fi

  manifest_install_dir=$(shimmy_read_manifest_value "$SHIMMY_ROOT_MANIFEST_FILE" install_dir || true)
  if [ -z "$manifest_install_dir" ]; then
    return 1
  fi

  SHIMMY_INSTALL_DIR=$(shimmy_trim_path_trailing_slash "$manifest_install_dir")
  shimmy_profile_paths_resolve "$SHIMMY_PROFILE_RESOLVED" "$SHIMMY_INSTALL_DIR" "$ROOT_DIR" || return 1
  SHIMMY_BIN_DIR=$SHIMMY_INSTALL_BIN_DIR
  SHIMMY_PROFILE_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_PATH
  SHIMMY_CONTROL_BIN=$(shimmy_join_path "$SHIMMY_BIN_DIR" shimmy)
  SHIMMY_CORE_DIR=$SHIMMY_INSTALL_CORE_DIR
  SHIMMY_CORE_COMMAND_DIR=$(shimmy_join_path "$SHIMMY_CORE_DIR" commands)
  SHIMMY_CORE_DISPATCHER=$(shimmy_join_path "$SHIMMY_CORE_COMMAND_DIR" dispatch-tool.sh)
  SHIMMY_CORE_TOOLS_DIR=$(shimmy_join_path "$SHIMMY_CORE_DIR" tools)
  SHIMMY_ACTIVATE_FILE=$(shimmy_join_path "$SHIMMY_INSTALL_DIR" activate.sh)
  SHIMMY_ROOT_MANIFEST_FILE=$(shimmy_join_path "$SHIMMY_INSTALL_DIR" install-manifest.txt)
  INSTALL_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_FILE
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

  target_root=$SHIMMY_CORE_DIR/.agents/skills
  mkdir -p "$target_root"

  for source_path in "$SOURCE_AGENT_SKILLS_DIR"/shimmy-*; do
    [ -d "$source_path" ] || continue
    skill_name=$(basename "$source_path")
    install_directory_copy "$source_path" "$target_root/$skill_name"
  done
}

shim_name_kind_resolve() {
  shim_name=$1

  if shimmy_is_kind "$shim_name"; then
    printf '%s\n' "$shim_name"
    return 0
  fi

  shimmy_version_kind "$shim_name"
}

shim_name_version_label_resolve() {
  shim_name=$1

  if shimmy_is_kind "$shim_name"; then
    return 1
  fi

  shimmy_version_label "$shim_name"
}

shim_source_config_path_resolve() {
  shim_name=$1
  source_root=$2
  kind_name=$(shim_name_kind_resolve "$shim_name") || return 1

  if shimmy_is_kind "$shim_name"; then
    printf '%s/tools/%s/tool.conf\n' "$source_root" "$kind_name"
    return 0
  fi

  version_label=$(shim_name_version_label_resolve "$shim_name") || return 1
  printf '%s/tools/%s/versions/%s/smoke.conf\n' "$source_root" "$kind_name" "$version_label"
}

install_shim_management_assets() {
  # The control installation copies the complete metadata-driven tools tree.
  # Individual profile installation only creates launch wrappers and configs.
  :
}

install_shim_runtime_assets() {
  shim_name=$1
  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    install_shim_upstream_exec_wrapper "$shim_name"
  else
    install_shim_runtime_assets_to "$shim_name" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"
  fi
}

install_shim_config_assets() {
  shim_name=$1
  shim_config_source_root=$ROOT_DIR

  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    shim_config_source_root=$SHIMMY_PROFILE_SOURCE_CHECKOUT
  fi

  install_shim_config_assets_to "$shim_name" "$shim_config_source_root" "$SHIMMY_PROFILE_CONFIG_DIR/shims"
}

install_shim_config_assets_to() {
  shim_name=$1
  shim_config_source_root=$2
  shim_config_target_dir=$3
  shim_config_source_path=$(shim_source_config_path_resolve "$shim_name" "$shim_config_source_root") || fail "missing Shimmy metadata for $shim_name"
  shim_config_target_path=$shim_config_target_dir/$shim_name.conf

  [ -f "$shim_config_source_path" ] || fail "missing shim config source: $shim_config_source_path"
  mkdir -p "$shim_config_target_dir"
  log_debug "Copying shim config $shim_name to $shim_config_target_path"
  rm -f "$shim_config_target_path"
  cp "$shim_config_source_path" "$shim_config_target_path"
  chmod 644 "$shim_config_target_path"
}

install_shim_runtime_assets_to() {
  shim_name=$1
  shim_dir=$2
  target_path=$shim_dir/$shim_name

  mkdir -p "$shim_dir"
  render_shim_exec_wrapper "$shim_name" "$SHIMMY_CORE_DIR" > "$target_path"
  chmod 755 "$target_path"
}

install_shim_image_assets_to() {
  :
}

install_shim_dispatcher() {
  shim_name=$1
  dispatcher_path=$SHIMMY_BIN_DIR/$shim_name

  mkdir -p "$SHIMMY_BIN_DIR"
  rm -f "$dispatcher_path"
  ln -s ../core/commands/dispatch-tool.sh "$dispatcher_path"
}

install_shim_upstream_exec_wrapper() {
  shim_name=$1
  wrapper_path=$SHIMMY_PROFILE_IMPLEMENTATION_DIR/$shim_name

  mkdir -p "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"
  render_shim_upstream_exec_wrapper "$shim_name" > "$wrapper_path"
  chmod 755 "$wrapper_path"
}

render_shim_upstream_exec_wrapper() {
  shim_name=$1
  render_shim_exec_wrapper "$shim_name" "$SHIMMY_PROFILE_SOURCE_CHECKOUT"
}

render_shim_exec_wrapper() {
  shim_name=$1
  source_root=$2
  kind_name=$(shim_name_kind_resolve "$shim_name") || fail "missing Shimmy tool metadata for $shim_name"
  quoted_kind_name=$(shimmy_quote_shell_word "$kind_name")
  quoted_source_root=$(shimmy_quote_shell_word "$source_root")

  if shimmy_is_kind "$shim_name"; then
    target_rel=commands/run-tool.sh
    target_args='$shimmy_tool_kind "$@"'
  else
    version_label=$(shim_name_version_label_resolve "$shim_name") || fail "missing version label for $shim_name"
    target_rel=tools/$kind_name/versions/$version_label/run.sh
    target_args='"$@"'
  fi
  quoted_target_rel=$(shimmy_quote_shell_word "$target_rel")

  cat <<EOF
#!/bin/sh
set -eu

shimmy_tool_kind=$quoted_kind_name
shimmy_source_root=$quoted_source_root
shimmy_runtime_target=\$shimmy_source_root/$target_rel

if [ ! -x "\$shimmy_runtime_target" ]; then
  printf 'ERROR: missing Shimmy tool runtime: %s\n' "\$shimmy_runtime_target" >&2
  exit 1
fi

exec "\$shimmy_runtime_target" $target_args
EOF
}

install_control_assets() {
  [ -f "$SOURCE_CONTROL_FILE" ] || fail "missing source management launcher: $SOURCE_CONTROL_FILE"
  [ -d "$SOURCE_COMMAND_DIR" ] || fail "missing source command directory: $SOURCE_COMMAND_DIR"
  [ -d "$SOURCE_CORE_DIR" ] || fail "missing source core directory: $SOURCE_CORE_DIR"
  [ -d "$SOURCE_TOOLS_DIR" ] || fail "missing source tool directory: $SOURCE_TOOLS_DIR"

  if [ "$ROOT_DIR" != "$SHIMMY_CORE_DIR" ]; then
    rm -rf "$SHIMMY_CORE_DIR"
  fi

  mkdir -p "$SHIMMY_BIN_DIR" "$SHIMMY_CORE_DIR"

  install_file "$SOURCE_CONTROL_FILE" "$SHIMMY_CONTROL_BIN"
  install_file "$SOURCE_CONTROL_FILE" "$SHIMMY_CORE_DIR/shimmy"

  install_directory_copy "$SOURCE_COMMAND_DIR" "$SHIMMY_CORE_DIR/commands"
  install_directory_copy "$SOURCE_CORE_DIR" "$SHIMMY_CORE_DIR/core"
  install_directory_copy "$SOURCE_TOOLS_DIR" "$SHIMMY_CORE_DIR/tools"
  install_directory_copy "$SOURCE_TESTS_DIR" "$SHIMMY_CORE_DIR/tests"
  if [ -d "$ROOT_DIR/agent" ]; then
    install_directory_copy "$ROOT_DIR/agent" "$SHIMMY_CORE_DIR/agent"
  fi
  if [ -d "$SOURCE_PLUGIN_DIR" ]; then
    install_directory_copy "$SOURCE_PLUGIN_DIR" "$SHIMMY_CORE_DIR/plugins"
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
  quoted_bin_dir=$(shimmy_quote_shell_word "$SHIMMY_BIN_DIR")

  {
    printf "SHIMMY_PROFILE_ACTIVE='default'\n"
    printf 'export SHIMMY_PROFILE_ACTIVE\n'
    printf 'shimmy_activate_bin_dir=%s\n' "$quoted_bin_dir"
    printf 'if [ -d "$shimmy_activate_bin_dir" ]; then\n'
    printf '  case ":${PATH:-}:" in\n'
    printf '    *:"$shimmy_activate_bin_dir":*) ;;\n'
    printf '    *) PATH=$shimmy_activate_bin_dir${PATH:+":$PATH"} ;;\n'
    printf '  esac\n'
    printf 'fi\n'
    printf 'unset shimmy_activate_bin_dir\n'
    printf "shimmy_activate_podman_dir='/opt/podman/bin'\n"
    printf 'if [ -x "$shimmy_activate_podman_dir/podman" ]; then\n'
    printf '  case ":${PATH:-}:" in\n'
    printf '    *:"$shimmy_activate_podman_dir":*) ;;\n'
    printf '    *)\n'
    printf '      if ! command -v podman >/dev/null 2>&1; then\n'
    printf '        PATH=${PATH:+$PATH:}$shimmy_activate_podman_dir\n'
    printf '      fi\n'
    printf '      ;;\n'
    printf '  esac\n'
    printf 'fi\n'
    printf 'unset shimmy_activate_podman_dir\n'
    printf 'export PATH\n'
  } > "$SHIMMY_ACTIVATE_FILE"
  chmod 644 "$SHIMMY_ACTIVATE_FILE"
}

write_manifest() {
  shimmy_source_ref=$(source_ref_resolve)
  shimmy_source_url=$(source_url_resolve)
  shimmy_previous_source_ref=${SHIMMY_PREVIOUS_SOURCE_REF:-}
  if [ -z "$shimmy_previous_source_ref" ]; then
    shimmy_previous_source_ref=$(shimmy_read_manifest_value "$INSTALL_MANIFEST_FILE" shimmy_previous_source_ref || true)
  fi

  write_root_manifest_file
  write_profile_manifest_file "$INSTALL_MANIFEST_FILE" "$shimmy_source_url" "$shimmy_source_ref" "$shimmy_previous_source_ref"
}

root_profile_list_resolve() {
  profile_names=

  for manifest_file in "$SHIMMY_INSTALL_DIR"/profiles/*/install-manifest.txt; do
    [ -f "$manifest_file" ] || continue
    profile_name=$(basename "$(dirname "$manifest_file")")
    if ! shimmy_contains_line_list "$profile_names" "$profile_name"; then
      profile_names=$(shimmy_append_line_list "$profile_names" "$profile_name")
    fi
  done

  if ! shimmy_contains_line_list "$profile_names" "$SHIMMY_PROFILE_RESOLVED"; then
    profile_names=$(shimmy_append_line_list "$profile_names" "$SHIMMY_PROFILE_RESOLVED")
  fi

  printf '%s\n' "$profile_names"
}

write_root_manifest_file() {
  mkdir -p "$(dirname "$SHIMMY_ROOT_MANIFEST_FILE")"

  {
    printf 'shimmy_install_manifest_version=2\n'
    printf 'shimmy_layout=metadata-tree\n'
    printf 'install_dir=%s\n' "$SHIMMY_INSTALL_DIR"
    printf 'bin_dir=%s\n' "$SHIMMY_BIN_DIR"
    printf 'control_bin=%s\n' "$SHIMMY_CONTROL_BIN"
    printf 'activate_file=%s\n' "$SHIMMY_ACTIVATE_FILE"
    printf 'shimmy_profile_default=default\n'
    for kind_name in $(shimmy_default_kind_list); do
      printf 'default_kind=%s\n' "$kind_name"
    done
    while IFS= read -r profile_name; do
      [ -n "$profile_name" ] || continue
      printf 'profile=%s\n' "$profile_name"
    done <<EOF
$(root_profile_list_resolve)
EOF
    if [ -n "$STARTUP_SHELL" ]; then
      printf 'startup_shell=%s\n' "$STARTUP_SHELL"
    fi
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      printf 'startup_file=%s\n' "$startup_file_path"
    done <<EOF
$STARTUP_FILE_PATHS
EOF
  } > "$SHIMMY_ROOT_MANIFEST_FILE"
}

write_profile_manifest_file() {
  manifest_file=$1
  shimmy_source_url=$2
  shimmy_source_ref=$3
  shimmy_previous_source_ref=$4

  mkdir -p "$(dirname "$manifest_file")"

  {
      printf 'shimmy_profile_manifest_version=2\n'
      printf 'shimmy_layout=metadata-tree\n'
      printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_RESOLVED"
      printf 'config_dir=%s\n' "$SHIMMY_PROFILE_CONFIG_DIR"
      printf 'profile_implementation_dir=%s\n' "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"
    case "$SHIMMY_PROFILE_RESOLVED" in
      upstream)
        printf 'shim_source=generated-exec-wrapper\n'
        ;;
      default)
        printf 'shim_source=metadata-dispatch-wrapper\n'
        ;;
    esac
    if [ -n "$SHIMMY_PROFILE_SOURCE_CHECKOUT" ]; then
      printf 'source_checkout=%s\n' "$SHIMMY_PROFILE_SOURCE_CHECKOUT"
    fi
    for kind_name in $(profile_manifest_kind_list); do
      printf 'kind=%s\n' "$kind_name"
    done
    for kind_version_entry in $(profile_manifest_kind_version_list); do
      printf 'kind_version=%s\n' "$kind_version_entry"
    done
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
  shimmy_install_layout_validate "$SHIMMY_ROOT_MANIFEST_FILE" || fail "legacy Shimmy install layout detected; uninstall and reinstall"
  if [ -f "$SHIMMY_ROOT_MANIFEST_FILE" ]; then
    PRESERVED_STARTUP_SHELL=$(shimmy_read_manifest_value "$SHIMMY_ROOT_MANIFEST_FILE" startup_shell || true)
    PRESERVED_STARTUP_FILE_PATHS=$(shimmy_read_manifest_values "$SHIMMY_ROOT_MANIFEST_FILE" startup_file || true)
  fi
  if [ -f "$INSTALL_MANIFEST_FILE" ]; then
    PRESERVED_SHIMMY_MANIFEST_LINES=$(manifest_shimmy_lines_preserve "$INSTALL_MANIFEST_FILE")
  fi
  resolve_startup_settings

  [ -d "$SOURCE_TOOLS_DIR" ] || fail "missing source tool directory: $SOURCE_TOOLS_DIR"
  [ -d "$SOURCE_CORE_DIR" ] || fail "missing source core directory: $SOURCE_CORE_DIR"

  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$SHIMMY_PROFILE_SOURCE_CHECKOUT" || true)
    if [ -n "$upstream_invalid_reason" ]; then
      fail "invalid upstream Shimmy checkout ($upstream_invalid_reason): $SHIMMY_PROFILE_SOURCE_CHECKOUT; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
  fi

  log_info "Installing shimmy into $SHIMMY_INSTALL_DIR"
  log_info "Selected Shimmy profile: $SHIMMY_PROFILE_RESOLVED"

  mkdir -p "$SHIMMY_INSTALL_DIR"
  rm -rf "$SHIMMY_PROFILE_IMPLEMENTATION_DIR" "$SHIMMY_PROFILE_CONFIG_DIR"
  rm -f "$SHIMMY_CONTROL_BIN"
  mkdir -p "$SHIMMY_PROFILE_IMPLEMENTATION_DIR" "$SHIMMY_PROFILE_CONFIG_DIR/shims" "$SHIMMY_BIN_DIR"

  log_debug "Copying management command support to $SHIMMY_CORE_DIR"
  install_control_assets

  selected_kind_version_entries_value=$(selected_kind_version_entries)
  for kind_name in $(kind_list_from_entries "$selected_kind_version_entries_value"); do
    install_shim_runtime_assets "$kind_name"
    install_shim_config_assets "$kind_name"
    install_shim_dispatcher "$kind_name"
  done
  for version_name in $(version_list_from_entries "$selected_kind_version_entries_value"); do
    install_shim_runtime_assets "$version_name"
    install_shim_config_assets "$version_name"
  done

  write_manifest
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

  share_management_skills

  log_info "Installed shimmy assets into $SHIMMY_INSTALL_DIR"
  log_info "Future shells will load Shimmy from: $(startup_file_summary_render "$STARTUP_FILE_PATHS")"
  log_info "Activate this install with: eval \"\$('$SHIMMY_CONTROL_BIN' activate)\""
  podman_macos_guidance_log
}

perform_shim_install() {
  [ "$UNINSTALL" -eq 0 ] || fail "--shim cannot be combined with --uninstall"
  [ -z "$REQUESTED_SKILLS_TARGET" ] || fail "--skills-target is not supported when installing shims into an existing environment"
  [ -z "$REQUESTED_SHELL" ] || fail "--shell is not supported when installing shims into an existing environment"
  [ -z "$REQUESTED_STARTUP_FILES" ] || fail "--startup-file is not supported when installing shims into an existing environment"
  [ -f "$INSTALL_MANIFEST_FILE" ] || fail "no shimmy install manifest found at $INSTALL_MANIFEST_FILE; run ./shimmy install first"
  shimmy_install_layout_validate "$SHIMMY_ROOT_MANIFEST_FILE" || fail "legacy Shimmy install layout detected; uninstall and reinstall"

  load_install_root_from_manifest || true
  validate_requested_shims

  [ -d "$SOURCE_TOOLS_DIR" ] || fail "missing source tool directory: $SOURCE_TOOLS_DIR"
  [ -d "$SOURCE_CORE_DIR" ] || fail "missing source core directory: $SOURCE_CORE_DIR"

  mkdir -p "$SHIMMY_PROFILE_IMPLEMENTATION_DIR" "$SHIMMY_PROFILE_CONFIG_DIR/shims" "$SHIMMY_BIN_DIR" \
    "$SHIMMY_CORE_TOOLS_DIR"

  installed_kinds=$(shimmy_read_manifest_kinds "$INSTALL_MANIFEST_FILE" || true)
  installed_kind_versions=$(shimmy_read_manifest_kind_versions "$INSTALL_MANIFEST_FILE" || true)
  selected_kind_version_entries_value=$(selected_kind_version_entries)
  kinds_to_append=
  kind_versions_to_append=

  for kind_name in $(kind_list_from_entries "$selected_kind_version_entries_value"); do
    install_shim_runtime_assets "$kind_name"
    install_shim_config_assets "$kind_name"
    install_shim_dispatcher "$kind_name"
    install_shim_management_assets "$kind_name"

    if shimmy_contains_line_list "$installed_kinds" "$kind_name" || shimmy_contains_line_list "$kinds_to_append" "$kind_name"; then
      log_warn "Shim kind already installed: $kind_name; run shimmy update --shim $kind_name to refresh it"
    else
      kinds_to_append=$(shimmy_append_line_list "$kinds_to_append" "$kind_name")
      log_info "Installed shim kind: $kind_name"
    fi
  done

  for version_name in $(version_list_from_entries "$selected_kind_version_entries_value"); do
    install_shim_runtime_assets "$version_name"
    install_shim_config_assets "$version_name"
    install_shim_management_assets "$version_name"
  done

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    if shimmy_contains_line_list "$installed_kind_versions" "$kind_version_entry" || shimmy_contains_line_list "$kind_versions_to_append" "$kind_version_entry"; then
      continue
    fi
    kind_versions_to_append=$(shimmy_append_line_list "$kind_versions_to_append" "$kind_version_entry")
    log_info "Installed shim version: $kind_version_entry"
  done <<EOF
$selected_kind_version_entries_value
EOF

  if [ -n "$kinds_to_append" ] || [ -n "$kind_versions_to_append" ]; then
    manifest_kind_state_append "$INSTALL_MANIFEST_FILE" "$kinds_to_append" "$kind_versions_to_append"
  fi
}

perform_shim_refresh() {
  [ -n "$REQUESTED_SHIMS" ] || fail "refresh must include --shim"
  [ "$UNINSTALL" -eq 0 ] || fail "--refresh-shims cannot be combined with --uninstall"
  [ -z "$REQUESTED_SKILLS_TARGET" ] || fail "--skills-target is not supported when refreshing shims"
  [ -f "$INSTALL_MANIFEST_FILE" ] || fail "no shimmy profile manifest found at $INSTALL_MANIFEST_FILE; run ./shimmy install first"
  shimmy_install_layout_validate "$SHIMMY_ROOT_MANIFEST_FILE" || fail "legacy Shimmy install layout detected; uninstall and reinstall"

  load_install_root_from_manifest || true
  validate_requested_shims

  installed_kinds=$(shimmy_read_manifest_kinds "$INSTALL_MANIFEST_FILE" || true)
  installed_kind_versions=$(shimmy_read_manifest_kind_versions "$INSTALL_MANIFEST_FILE" || true)
  selected_kind_version_entries_value=$(selected_kind_version_entries)

  for kind_name in $(kind_list_from_entries "$selected_kind_version_entries_value"); do
    if ! shimmy_contains_line_list "$installed_kinds" "$kind_name"; then
      fail "$kind_name not installed; run shimmy install --shim $kind_name"
    fi
  done

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    if ! shimmy_contains_line_list "$installed_kind_versions" "$kind_version_entry"; then
      kind_name=${kind_version_entry%%|*}
      version_label=${kind_version_entry#*|}
      version_label=${version_label%%|*}
      if [ "$version_label" != default ]; then
        fail "$kind_name@$version_label not installed; run shimmy install --shim $kind_name@$version_label"
      fi
    fi
  done <<EOF
$selected_kind_version_entries_value
EOF

  PROFILE_MANIFEST_KINDS=$installed_kinds
  PROFILE_MANIFEST_KIND_VERSIONS=$installed_kind_versions

  if [ -f "$SHIMMY_ROOT_MANIFEST_FILE" ]; then
    PRESERVED_STARTUP_SHELL=$(shimmy_read_manifest_value "$SHIMMY_ROOT_MANIFEST_FILE" startup_shell || true)
    PRESERVED_STARTUP_FILE_PATHS=$(shimmy_read_manifest_values "$SHIMMY_ROOT_MANIFEST_FILE" startup_file || true)
  fi
  PRESERVED_SHIMMY_MANIFEST_LINES=$(manifest_shimmy_lines_preserve "$INSTALL_MANIFEST_FILE")
  resolve_startup_settings

  [ -d "$SOURCE_TOOLS_DIR" ] || fail "missing source tool directory: $SOURCE_TOOLS_DIR"
  [ -d "$SOURCE_CORE_DIR" ] || fail "missing source core directory: $SOURCE_CORE_DIR"

  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$SHIMMY_PROFILE_SOURCE_CHECKOUT" || true)
    if [ -n "$upstream_invalid_reason" ]; then
      fail "invalid upstream Shimmy checkout ($upstream_invalid_reason): $SHIMMY_PROFILE_SOURCE_CHECKOUT; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
  fi

  log_info "Refreshing shimmy assets in $SHIMMY_INSTALL_DIR"
  log_info "Selected Shimmy profile: $SHIMMY_PROFILE_RESOLVED"

  mkdir -p "$SHIMMY_INSTALL_DIR" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR" "$SHIMMY_PROFILE_CONFIG_DIR/shims" "$SHIMMY_BIN_DIR"

  log_debug "Copying management command support to $SHIMMY_CORE_DIR"
  install_control_assets

  for kind_name in $(kind_list_from_entries "$selected_kind_version_entries_value"); do
    install_shim_runtime_assets "$kind_name"
    install_shim_config_assets "$kind_name"
    install_shim_dispatcher "$kind_name"
  done
  for version_name in $(version_list_from_entries "$selected_kind_version_entries_value"); do
    install_shim_runtime_assets "$version_name"
    install_shim_config_assets "$version_name"
  done

  write_manifest
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

  log_info "Refreshed shimmy assets into $SHIMMY_INSTALL_DIR"
}

remove_path_if_present() {
  path_value=$1
  description=$2

  if [ ! -e "$path_value" ] && [ ! -L "$path_value" ]; then
    return 0
  fi

  shimmy_validate_remove_path_safe "$path_value" || fail "refusing to remove unsafe path: $path_value"
  log_debug "Removing $description path: $path_value"
  rm -rf "$path_value"
}

remove_empty_install_dirs() {
  if [ -d "$SHIMMY_INSTALL_DIR/profiles" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/profiles" 2>/dev/null || true
  fi
  if [ -d "$SHIMMY_INSTALL_DIR/bin" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/bin" 2>/dev/null || true
  fi
  if [ -d "$SHIMMY_INSTALL_DIR/core" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/core" 2>/dev/null || true
  fi

  if [ -d "$SHIMMY_INSTALL_DIR" ]; then
    shimmy_validate_remove_path_safe "$SHIMMY_INSTALL_DIR" || fail "refusing to remove unsafe path: $SHIMMY_INSTALL_DIR"
    if rmdir "$SHIMMY_INSTALL_DIR" 2>/dev/null; then
      log_debug "Removed empty install directory: $SHIMMY_INSTALL_DIR"
    fi
  fi
}

write_root_manifest_existing_profiles() {
  [ -f "$SHIMMY_ROOT_MANIFEST_FILE" ] || return 0

  startup_shell=$(shimmy_read_manifest_value "$SHIMMY_ROOT_MANIFEST_FILE" startup_shell || true)
  startup_files=$(shimmy_read_manifest_values "$SHIMMY_ROOT_MANIFEST_FILE" startup_file || true)

  {
    printf 'shimmy_install_manifest_version=2\n'
    printf 'shimmy_layout=metadata-tree\n'
    printf 'install_dir=%s\n' "$SHIMMY_INSTALL_DIR"
    printf 'bin_dir=%s\n' "$SHIMMY_BIN_DIR"
    printf 'control_bin=%s\n' "$SHIMMY_CONTROL_BIN"
    printf 'activate_file=%s\n' "$SHIMMY_ACTIVATE_FILE"
    printf 'shimmy_profile_default=default\n'
    for kind_name in $(shimmy_default_kind_list); do
      printf 'default_kind=%s\n' "$kind_name"
    done
    for manifest_file in "$SHIMMY_INSTALL_DIR"/profiles/*/install-manifest.txt; do
      [ -f "$manifest_file" ] || continue
      printf 'profile=%s\n' "$(basename "$(dirname "$manifest_file")")"
    done
    if [ -n "$startup_shell" ]; then
      printf 'startup_shell=%s\n' "$startup_shell"
    fi
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      printf 'startup_file=%s\n' "$startup_file_path"
    done <<EOF
$startup_files
EOF
  } > "$SHIMMY_ROOT_MANIFEST_FILE"
}

is_shimmy_public_dispatcher() {
  dispatcher_path=$1

  [ -L "$dispatcher_path" ] || return 1
  command -v readlink >/dev/null 2>&1 || return 1

  dispatcher_target=$(readlink "$dispatcher_path" 2>/dev/null || true)
  [ "$dispatcher_target" = ../core/commands/dispatch-tool.sh ] && return 0
  [ "$dispatcher_target" = "$SHIMMY_CORE_DISPATCHER" ] && return 0

  return 1
}

remove_shimmy_public_dispatchers() {
  [ -d "$SHIMMY_BIN_DIR" ] || return 0

  for dispatcher_path in "$SHIMMY_BIN_DIR"/*; do
    [ -e "$dispatcher_path" ] || [ -L "$dispatcher_path" ] || continue
    [ "$(basename "$dispatcher_path")" != shimmy ] || continue
    if is_shimmy_public_dispatcher "$dispatcher_path"; then
      remove_path_if_present "$dispatcher_path" "public dispatcher"
    fi
  done
}

uninstall_skills_target_remove() {
  [ "$SKIP_SKILLS" -eq 0 ] || return 0
  [ -n "$REQUESTED_SKILLS_TARGET" ] || return 0

  if [ ! -x "$SKILLS_SCRIPT" ]; then
    fail "missing skills helper: $SKILLS_SCRIPT"
  fi

  "$SKILLS_SCRIPT" uninstall --target "$REQUESTED_SKILLS_TARGET"
}

uninstall_startup_file_list_resolve() {
  profile_manifest_file=$1
  startup_file_paths=

  if [ -f "$SHIMMY_ROOT_MANIFEST_FILE" ]; then
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      if ! shimmy_contains_line_list "$startup_file_paths" "$startup_file_path"; then
        startup_file_paths=$(shimmy_append_line_list "$startup_file_paths" "$startup_file_path")
      fi
    done <<EOF
$(shimmy_read_manifest_values "$SHIMMY_ROOT_MANIFEST_FILE" startup_file || true)
EOF
  fi

  if [ -f "$profile_manifest_file" ]; then
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      if ! shimmy_contains_line_list "$startup_file_paths" "$startup_file_path"; then
        startup_file_paths=$(shimmy_append_line_list "$startup_file_paths" "$startup_file_path")
      fi
    done <<EOF
$(shimmy_read_manifest_values "$profile_manifest_file" startup_file || true)
EOF
  fi

  printf '%s\n' "$startup_file_paths"
}

perform_uninstall_profile() {
  uninstall_manifest_file=$SHIMMY_PROFILE_MANIFEST_FILE
  if [ ! -f "$uninstall_manifest_file" ] && [ ! -d "$SHIMMY_PROFILE_DIR" ]; then
    log_info "No shimmy $SHIMMY_PROFILE_RESOLVED profile found at $SHIMMY_PROFILE_DIR; checking install root cleanup"
  fi

  log_info "Removing shimmy $SHIMMY_PROFILE_RESOLVED profile rooted at $SHIMMY_PROFILE_DIR"

  kinds_to_check=$(shimmy_read_manifest_kinds "$uninstall_manifest_file" || true)
  startup_files_to_remove=$(uninstall_startup_file_list_resolve "$uninstall_manifest_file")

  uninstall_skills_target_remove
  remove_path_if_present "$SHIMMY_PROFILE_DIR" "profile"

  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    if shimmy_contains_profile_kind_other "$SHIMMY_INSTALL_DIR" "$kind_name" "$uninstall_manifest_file"; then
      continue
    fi
    remove_path_if_present "$SHIMMY_BIN_DIR/$kind_name" "dispatcher"
  done <<EOF
$kinds_to_check
EOF

  if [ "$(shimmy_count_profile_manifests "$SHIMMY_INSTALL_DIR")" -eq 0 ]; then
    remove_shimmy_public_dispatchers
    if [ -n "$startup_files_to_remove" ]; then
      while IFS= read -r startup_file_to_remove; do
        [ -n "$startup_file_to_remove" ] || continue
        shimmy_startup_block_remove "$startup_file_to_remove" "$SHIMMY_STARTUP_BLOCK_START" "$SHIMMY_STARTUP_BLOCK_END"
        log_info "Removed managed Shimmy startup block from: $startup_file_to_remove"
      done <<EOF
$startup_files_to_remove
EOF
    fi
    remove_path_if_present "$SHIMMY_CONTROL_BIN" "management command"
    remove_path_if_present "$SHIMMY_CORE_DIR" "management support"
    remove_path_if_present "$SHIMMY_ACTIVATE_FILE" "activation"
    remove_path_if_present "$SHIMMY_ROOT_MANIFEST_FILE" "root manifest"
  else
    write_root_manifest_existing_profiles
  fi

  remove_empty_install_dirs

  log_info "Removed shimmy $SHIMMY_PROFILE_RESOLVED profile from $SHIMMY_INSTALL_DIR"
}

shimmy_install_run() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        [ "$#" -ge 2 ] || fail "missing value for --install-dir"
        REQUESTED_INSTALL_DIR=$2
        shift 2
        ;;
      --profile)
        [ "$#" -ge 2 ] || fail "missing value for --profile"
        SHIMMY_PROFILE_REQUESTED=$2
        SHIMMY_PROFILE_ACTIVATED=1
        shift 2
        ;;
      --copy)
        shift
        ;;
      --refresh-shims)
        REFRESH_SHIMS=1
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
        REQUESTED_STARTUP_FILES=$(shimmy_append_line_list "$REQUESTED_STARTUP_FILES" "$2")
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

  if [ -n "${SHIMMY_PROFILE_ACTIVE:-}" ]; then
    SHIMMY_PROFILE_ACTIVATED=1
  fi

  resolve_install_paths

  if [ "$REFRESH_SHIMS" -eq 1 ]; then
    perform_shim_refresh
  elif [ "$UNINSTALL" -eq 1 ]; then
    if [ "$SHIMMY_PROFILE_ACTIVATED" -eq 0 ]; then
      fail "uninstall requires --profile default or --profile upstream"
    fi
    perform_uninstall_profile
  elif [ -f "$INSTALL_MANIFEST_FILE" ]; then
    perform_shim_install
  else
    perform_install
  fi
}
