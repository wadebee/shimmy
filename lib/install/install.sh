#!/bin/sh
# Install or remove canonical profile-local Shimmy state.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_CONTROL_ROOT=$ROOT_DIR
INSTALL_MODULE_DIR=$ROOT_DIR/lib/install

REQUESTED_SHIMS=
REQUESTED_SHELL=
REQUESTED_STARTUP_FILES=
SKIP_STARTUP=0
STARTUP_OPTION_REQUESTED=0
STARTUP_FILE_PATHS=
STARTUP_SHELL=
PROFILE_MANIFEST_TOOL_VERSIONS=
PROFILE_MANIFEST_TOOLS=
EXISTING_PROFILE_TOOLS=
UNINSTALL=0
GLOBAL_UNINSTALL=0
PROFILE_EXISTS=0
SHIMMY_STAGE_ROOT=
SHIMMY_PROFILE_BACKUP_ROOT=
SHIMMY_PROFILE_DIRECTORIES_REPLACED=
SHIMMY_PROFILE_FILES_REPLACED=
SHIMMY_MANIFEST_COMMIT_TMP=
SHIMMY_SHELL_INIT_COMMIT_TMP=
SHIMMY_PROFILE_CATALOG_NAME=
SHIMMY_MATERIALIZATION_CATALOG_NAME=
SHIMMY_MATERIALIZATION_CATALOG_SOURCE_TYPE=
SHIMMY_MATERIALIZATION_CATALOG_SOURCE_PATH=
SHIMMY_MATERIALIZATION_CATALOG_GENERATION=
SHIMMY_MATERIALIZATION_CATALOG_SCHEMA=
SHIMMY_MATERIALIZATION_CATALOG_FINGERPRINT=
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

log_message() {
  level=$1
  shift
  [ "$(log_level_value "$level")" -ge "$(log_level_value "$LOG_LEVEL")" ] || return 0
  upper_level=$(printf '%s' "$level" | tr '[:lower:]' '[:upper:]')
  printf '%s: %s\n' "$upper_level" "$*" >&2
}

log_debug() { log_message debug "$@"; }
log_info() { log_message info "$@"; }
log_warn() { log_message warn "$@"; }
fail() { log_message error "$*"; exit 1; }

for helper_file in \
  "$ROOT_DIR/lib/common/common.sh" \
  "$ROOT_DIR/lib/catalog/catalog.sh" \
  "$ROOT_DIR/lib/profile/profile.sh" \
  "$ROOT_DIR/lib/startup/startup.sh"
do
  [ -f "$helper_file" ] || fail "missing shared helper: $helper_file"
done

# shellcheck source=lib/common/common.sh
. "$ROOT_DIR/lib/common/common.sh"
# shellcheck source=lib/catalog/catalog.sh
. "$ROOT_DIR/lib/catalog/catalog.sh"
# shellcheck source=lib/profile/profile.sh
. "$ROOT_DIR/lib/profile/profile.sh"
# shellcheck source=lib/startup/startup.sh
. "$ROOT_DIR/lib/startup/startup.sh"
# shellcheck source=lib/install/catalog-lifecycle.sh
. "$INSTALL_MODULE_DIR/catalog-lifecycle.sh"
# shellcheck source=lib/install/request.sh
. "$INSTALL_MODULE_DIR/request.sh"
# shellcheck source=lib/install/manifest.sh
. "$INSTALL_MODULE_DIR/manifest.sh"
# shellcheck source=lib/install/profile-assets.sh
. "$INSTALL_MODULE_DIR/profile-assets.sh"
# shellcheck source=lib/install/startup.sh
. "$INSTALL_MODULE_DIR/startup.sh"
# shellcheck source=lib/install/uninstall.sh
. "$INSTALL_MODULE_DIR/uninstall.sh"

profile_root_is_empty() {
  profile_root=$1
  [ -d "$profile_root" ] || return 0
  for profile_entry in "$profile_root"/* "$profile_root"/.[!.]* "$profile_root"/..?*; do
    [ -e "$profile_entry" ] || [ -L "$profile_entry" ] || continue
    return 1
  done
  return 0
}

profile_catalog_prepare() {
  if [ "$PROFILE_EXISTS" -eq 1 ]; then
    SHIMMY_PROFILE_CATALOG_NAME=$(shimmy_read_manifest_value "$INSTALL_MANIFEST_FILE" catalog || true)
    shimmy_catalog_profile_resolve "$INSTALL_MANIFEST_FILE" "$SHIMMY_CONFIG_ROOT" || fail "$SHIMMY_CATALOG_ERROR"
    return 0
  fi

  SHIMMY_PROFILE_CATALOG_NAME=$SHIMMY_PROFILE_RESOLVED
  if [ "$SHIMMY_PROFILE_RESOLVED" = default ] && [ -f "$SHIMMY_CONFIG_ROOT/catalogs/default/registry.conf" ]; then
    shimmy_catalog_registry_resolve "$SHIMMY_CONFIG_ROOT" default || fail "$SHIMMY_CATALOG_ERROR"
    return 0
  fi

  catalog_checkout_candidate=$ROOT_DIR
  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    catalog_checkout_candidate=${SHIMMY_UPSTREAM_CHECKOUT_DIR:-$ROOT_DIR}
  fi
  shimmy_catalog_checkout_resolve "$catalog_checkout_candidate" "$SHIMMY_PROFILE_CATALOG_NAME" || fail "$SHIMMY_CATALOG_ERROR"
}

profile_catalog_register() {
  [ "$PROFILE_EXISTS" -eq 0 ] || return 0

  case "$SHIMMY_PROFILE_RESOLVED" in
    default)
      if [ ! -f "$SHIMMY_CONFIG_ROOT/catalogs/default/registry.conf" ]; then
        shimmy_catalog_default_initialize "$SHIMMY_CONFIG_ROOT" "$ROOT_DIR" || fail "$SHIMMY_CATALOG_ERROR"
      else
        shimmy_catalog_registry_resolve "$SHIMMY_CONFIG_ROOT" default || fail "$SHIMMY_CATALOG_ERROR"
      fi
      ;;
    upstream)
      upstream_catalog_checkout=${SHIMMY_UPSTREAM_CHECKOUT_DIR:-$ROOT_DIR}
      shimmy_catalog_upstream_register "$SHIMMY_CONFIG_ROOT" "$upstream_catalog_checkout" || fail "$SHIMMY_CATALOG_ERROR"
      ;;
  esac
}

line_list_merge() {
  existing_lines=$1
  additional_lines=$2
  merged_lines=$existing_lines
  while IFS= read -r additional_line; do
    [ -n "$additional_line" ] || continue
    shimmy_contains_line_list "$merged_lines" "$additional_line" || merged_lines=$(shimmy_append_line_list "$merged_lines" "$additional_line")
  done <<EOF
$additional_lines
EOF
  printf '%s\n' "$merged_lines"
}

tool_version_line_list_merge() {
  existing_lines=$1
  additional_lines=$2
  merged_lines=$existing_lines

  while IFS= read -r additional_line; do
    [ -n "$additional_line" ] || continue
    shimmy_contains_line_list "$merged_lines" "$additional_line" && continue
    additional_tool=${additional_line%%|*}
    additional_remainder=${additional_line#*|}
    additional_label=${additional_remainder%%|*}
    retained_lines=
    while IFS= read -r existing_line; do
      [ -n "$existing_line" ] || continue
      existing_tool=${existing_line%%|*}
      existing_remainder=${existing_line#*|}
      existing_label=${existing_remainder%%|*}
      if [ "$existing_tool" = "$additional_tool" ] && [ "$existing_label" = "$additional_label" ]; then
        continue
      fi
      retained_lines=$(shimmy_append_line_list "$retained_lines" "$existing_line")
    done <<EOF
$merged_lines
EOF
    merged_lines=$(shimmy_append_line_list "$retained_lines" "$additional_line")
  done <<EOF
$additional_lines
EOF
  printf '%s\n' "$merged_lines"
}

profile_source_checkout_resolve() {
  [ "$SHIMMY_PROFILE_RESOLVED" = upstream ] || { SHIMMY_PROFILE_SOURCE_CHECKOUT=; return 0; }

  if [ "$PROFILE_EXISTS" -eq 1 ]; then
    SHIMMY_PROFILE_SOURCE_CHECKOUT=$(shimmy_read_manifest_value "$INSTALL_MANIFEST_FILE" source_checkout || true)
  else
    checkout_candidate=${SHIMMY_UPSTREAM_CHECKOUT_DIR:-$ROOT_DIR}
    SHIMMY_PROFILE_SOURCE_CHECKOUT=$(shimmy_resolve_path_absolute "$checkout_candidate") || fail "unable to resolve upstream source checkout"
  fi
  upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$SHIMMY_PROFILE_SOURCE_CHECKOUT" || true)
  [ -z "$upstream_invalid_reason" ] || fail "invalid upstream Shimmy checkout ($upstream_invalid_reason): $SHIMMY_PROFILE_SOURCE_CHECKOUT"
}

profile_existing_state_read() {
  if [ -f "$INSTALL_MANIFEST_FILE" ] || [ -L "$INSTALL_MANIFEST_FILE" ]; then
    shimmy_profile_manifest_validate "$INSTALL_MANIFEST_FILE" "$SHIMMY_PROFILE_RESOLVED" || exit 1
    shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_RESOLVED" ||
      fail "legacy, mixed, or damaged Shimmy profile at $SHIMMY_PROFILE_ROOT; uninstall it with the Shimmy version that created it, then recreate that profile"
    PROFILE_EXISTS=1
    EXISTING_PROFILE_TOOLS=$(shimmy_manifest_tool_list_read "$INSTALL_MANIFEST_FILE" || true)
    PROFILE_MANIFEST_TOOLS=$EXISTING_PROFILE_TOOLS
    PROFILE_MANIFEST_TOOL_VERSIONS=$(shimmy_manifest_tool_version_list_read "$INSTALL_MANIFEST_FILE" || true)
    return 0
  fi

  profile_root_is_empty "$SHIMMY_PROFILE_ROOT" || fail "refusing to install into non-empty unmanaged profile root: $SHIMMY_PROFILE_ROOT"
}

profile_selection_merge() {
  selected_entries=$(selected_tool_version_entries)
  selected_tools=$(tool_list_from_entries "$selected_entries")
  PROFILE_MANIFEST_TOOLS=$(line_list_merge "$PROFILE_MANIFEST_TOOLS" "$selected_tools")
  PROFILE_MANIFEST_TOOL_VERSIONS=$(tool_version_line_list_merge "$PROFILE_MANIFEST_TOOL_VERSIONS" "$selected_entries")
}

profile_stage_prepare() {
  mkdir -p "$SHIMMY_CONFIG_ROOT" "$SHIMMY_PROFILES_ROOT"
  SHIMMY_STAGE_ROOT=$SHIMMY_PROFILES_ROOT/."$SHIMMY_PROFILE_RESOLVED".stage.$$
  [ ! -e "$SHIMMY_STAGE_ROOT" ] || fail "staging path already exists: $SHIMMY_STAGE_ROOT"
  profile_control_assets_stage
  profile_materialization_assets_stage

  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    profile_dispatcher_collision_validate "$tool_name"
    profile_shim_assets_stage "$tool_name"
    profile_dispatcher_stage "$tool_name"
  done <<EOF
$PROFILE_MANIFEST_TOOLS
EOF
  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    version_name=${tool_version_entry##*|}
    profile_shim_assets_stage "$version_name"
  done <<EOF
$PROFILE_MANIFEST_TOOL_VERSIONS
EOF

  profile_launcher_collision_validate
  profile_shell_init_collision_validate
  write_shell_init_file "$SHIMMY_STAGE_ROOT/shell-init.sh"
  profile_manifest_render > "$SHIMMY_STAGE_ROOT/install-manifest.txt"
  chmod 644 "$SHIMMY_STAGE_ROOT/install-manifest.txt"
  shimmy_profile_manifest_validate "$SHIMMY_STAGE_ROOT/install-manifest.txt" "$SHIMMY_PROFILE_RESOLVED" || exit 1
  shimmy_profile_structure_validate "$SHIMMY_STAGE_ROOT" "$SHIMMY_PROFILE_RESOLVED" ||
    fail "staged profile materialization is incomplete or invalid"
  profile_materialization_catalog_snapshot_validate
}

profile_stage_cleanup() {
  shimmy_catalog_lifecycle_cleanup
  shimmy_catalog_lock_release
  profile_commit_temporary_files_cleanup
  if [ -n "$SHIMMY_PROFILE_BACKUP_ROOT" ] && [ -d "$SHIMMY_PROFILE_BACKUP_ROOT" ]; then
    profile_commit_restore
  fi
  [ -n "$SHIMMY_STAGE_ROOT" ] || return 0
  case "$SHIMMY_STAGE_ROOT" in
    "$SHIMMY_PROFILES_ROOT"/.*.stage.*) rm -rf "$SHIMMY_STAGE_ROOT" ;;
  esac
}

perform_install() {
  profile_existing_state_read
  profile_catalog_prepare
  validate_requested_shims
  profile_catalog_register
  shimmy_catalog_registry_resolve "$SHIMMY_CONFIG_ROOT" "$SHIMMY_PROFILE_CATALOG_NAME" || fail "$SHIMMY_CATALOG_ERROR"
  validate_requested_shims
  profile_materialization_catalog_snapshot_record
  if [ "$PROFILE_EXISTS" -eq 1 ] && [ "$STARTUP_OPTION_REQUESTED" -eq 0 ] && [ -z "${SHIMMY_BOOTSTRAP_PROFILE:-}" ]; then
    SKIP_STARTUP=1
  fi
  profile_source_checkout_resolve
  resolve_startup_settings
  if [ "${SHIMMY_UPDATE_MANAGEMENT_REFRESH:-0}" -ne 1 ]; then
    profile_selection_merge
  fi
  profile_stage_prepare
  profile_assets_commit
  profile_stage_cleanup
  if ! shimmy_install_startup_update; then
    fail "profile installed, but startup integration failed; retry with the checkout bootstrap or an installed shim install using explicit startup options"
  fi

  log_info "Installed Shimmy $SHIMMY_PROFILE_RESOLVED profile at $SHIMMY_PROFILE_ROOT"
  log_info "Initialize this shell with: . '$SHIMMY_SHELL_INIT_FILE'"
}

shimmy_install_run() {
  trap profile_stage_cleanup EXIT HUP INT TERM
  shimmy_install_request_parse "$@"

  if [ "$UNINSTALL" -eq 1 ]; then
    [ -z "$REQUESTED_SHIMS" ] || fail "--shim cannot be combined with --uninstall"
    if [ "$GLOBAL_UNINSTALL" -eq 1 ]; then
      perform_uninstall_global
    else
      perform_uninstall_profile
    fi
    return 0
  fi
  [ "$GLOBAL_UNINSTALL" -eq 0 ] || fail "--global requires --uninstall"
  [ -n "$REQUESTED_SHIMS" ] || fail "install requires at least one --shim <tool>"
  perform_install
}
