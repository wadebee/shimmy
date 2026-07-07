#!/bin/sh
# Install or remove Shimmy profiles and runtime assets.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

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
INSTALL_MODULE_DIR=$SOURCE_CORE_DIR/install

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

for install_module_file in request.sh manifest.sh profile-assets.sh startup.sh uninstall.sh; do
  if [ ! -f "$INSTALL_MODULE_DIR/$install_module_file" ]; then
    fail "missing install module: $INSTALL_MODULE_DIR/$install_module_file"
  fi
done

# shellcheck source=core/common/common.sh
. "$COMMON_HELPER_FILE"
# shellcheck source=core/catalog/catalog.sh
. "$CATALOG_HELPER_FILE"
# shellcheck source=core/profile/profile.sh
. "$PROFILE_HELPER_FILE"
# shellcheck source=core/startup/startup.sh
. "$STARTUP_HELPER_FILE"
# shellcheck source=core/install/request.sh
. "$INSTALL_MODULE_DIR/request.sh"
# shellcheck source=core/install/manifest.sh
. "$INSTALL_MODULE_DIR/manifest.sh"
# shellcheck source=core/install/profile-assets.sh
. "$INSTALL_MODULE_DIR/profile-assets.sh"
# shellcheck source=core/install/startup.sh
. "$INSTALL_MODULE_DIR/startup.sh"
# shellcheck source=core/install/uninstall.sh
. "$INSTALL_MODULE_DIR/uninstall.sh"

podman_macos_guidance_log() {
  is_macos || return 0

  log_info "macOS Podman check: run 'podman info' in a normal shell before using Shimmy."
  log_info "If Podman is unreachable, run 'podman machine start' in that shell, then retry Shimmy."
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
  shimmy_install_startup_update
  share_management_skills

  log_info "Installed shimmy assets into $SHIMMY_INSTALL_DIR"
  log_info "Future shells will load Shimmy from: $(startup_file_summary_render "$STARTUP_FILE_PATHS")"
  log_info "Activate this install with: eval \"\$('$SHIMMY_CONTROL_BIN' activate)\""
  podman_macos_guidance_log
}

perform_shim_install() {
  [ "$UNINSTALL" -eq 0 ] || fail "--shim cannot be combined with --uninstall"
  [ -z "$REQUESTED_SKILLS_TARGET" ] || fail "--skills-target is not supported when installing shims into an existing environment"
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

  if [ "$SKIP_STARTUP" -eq 0 ] && { [ -n "$REQUESTED_SHELL" ] || [ -n "$REQUESTED_STARTUP_FILES" ]; }; then
    if [ -f "$SHIMMY_ROOT_MANIFEST_FILE" ]; then
      PRESERVED_STARTUP_SHELL=$(shimmy_read_manifest_value "$SHIMMY_ROOT_MANIFEST_FILE" startup_shell || true)
      PRESERVED_STARTUP_FILE_PATHS=$(shimmy_read_manifest_values "$SHIMMY_ROOT_MANIFEST_FILE" startup_file || true)
    fi
    resolve_startup_settings
    write_activate_file
    shimmy_install_startup_update
    write_root_manifest_file
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
  shimmy_install_startup_update

  log_info "Refreshed shimmy assets into $SHIMMY_INSTALL_DIR"
}

shimmy_install_run() {
  shimmy_install_request_parse "$@"

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
