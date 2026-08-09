#!/bin/sh
# Install or remove one canonical profile-flat Shimmy installation.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
INSTALL_MODULE_DIR=$ROOT_DIR/lib/install

REQUESTED_SHIMS=
REQUESTED_SKILLS_TARGET=
REQUESTED_SHELL=
REQUESTED_STARTUP_FILES=
SKIP_STARTUP=0
STARTUP_OPTION_REQUESTED=0
SKIP_SKILLS=0
REFRESH_SHIMS=0
STARTUP_FILE_PATHS=
STARTUP_SHELL=
PROFILE_MANIFEST_KIND_VERSIONS=
PROFILE_MANIFEST_KINDS=
EXISTING_PROFILE_KINDS=
UNINSTALL=0
PROFILE_EXISTS=0
SHIMMY_STAGE_ROOT=
SHIMMY_PROFILE_BACKUP_ROOT=
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
    PROFILE_EXISTS=1
    EXISTING_PROFILE_KINDS=$(shimmy_read_manifest_kinds "$INSTALL_MANIFEST_FILE" || true)
    PROFILE_MANIFEST_KINDS=$EXISTING_PROFILE_KINDS
    PROFILE_MANIFEST_KIND_VERSIONS=$(shimmy_read_manifest_kind_versions "$INSTALL_MANIFEST_FILE" || true)
    return 0
  fi

  profile_root_is_empty "$SHIMMY_PROFILE_ROOT" || fail "refusing to install into non-empty unmanaged profile root: $SHIMMY_PROFILE_ROOT"
}

profile_selection_merge() {
  selected_entries=$(selected_kind_version_entries)
  selected_kinds=$(kind_list_from_entries "$selected_entries")
  PROFILE_MANIFEST_KINDS=$(line_list_merge "$PROFILE_MANIFEST_KINDS" "$selected_kinds")
  PROFILE_MANIFEST_KIND_VERSIONS=$(line_list_merge "$PROFILE_MANIFEST_KIND_VERSIONS" "$selected_entries")
}

profile_stage_prepare() {
  mkdir -p "$SHIMMY_CONFIG_ROOT" "$SHIMMY_PROFILES_ROOT"
  SHIMMY_STAGE_ROOT=$SHIMMY_PROFILES_ROOT/."$SHIMMY_PROFILE_RESOLVED".stage.$$
  [ ! -e "$SHIMMY_STAGE_ROOT" ] || fail "staging path already exists: $SHIMMY_STAGE_ROOT"
  profile_control_assets_stage

  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    profile_dispatcher_collision_validate "$kind_name"
    profile_shim_assets_stage "$kind_name"
    profile_dispatcher_stage "$kind_name"
  done <<EOF
$PROFILE_MANIFEST_KINDS
EOF
  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    version_name=${kind_version_entry##*|}
    profile_shim_assets_stage "$version_name"
  done <<EOF
$PROFILE_MANIFEST_KIND_VERSIONS
EOF

  profile_launcher_collision_validate
  write_activate_file "$SHIMMY_STAGE_ROOT/activate.sh"
  profile_manifest_render > "$SHIMMY_STAGE_ROOT/install-manifest.txt"
  chmod 644 "$SHIMMY_STAGE_ROOT/install-manifest.txt"
  shimmy_profile_manifest_validate "$SHIMMY_STAGE_ROOT/install-manifest.txt" "$SHIMMY_PROFILE_RESOLVED" || exit 1
}

profile_stage_cleanup() {
  if [ -n "$SHIMMY_PROFILE_BACKUP_ROOT" ] && [ -d "$SHIMMY_PROFILE_BACKUP_ROOT" ]; then
    profile_owned_files_restore
    profile_owned_directories_restore
    rmdir "$SHIMMY_PROFILE_BACKUP_ROOT/bin" 2>/dev/null || true
    rmdir "$SHIMMY_PROFILE_BACKUP_ROOT" 2>/dev/null || true
  fi
  [ -n "$SHIMMY_STAGE_ROOT" ] || return 0
  case "$SHIMMY_STAGE_ROOT" in
    "$SHIMMY_PROFILES_ROOT"/.*.stage.*) rm -rf "$SHIMMY_STAGE_ROOT" ;;
  esac
}

profile_external_integrations_apply() {
  if ! shimmy_install_startup_update; then
    fail "profile installed, but startup integration failed; retry with '$SHIMMY_CONTROL_BIN install --shell $STARTUP_SHELL'"
  fi

  [ "$SKIP_SKILLS" -eq 0 ] || return 0
  [ -n "$REQUESTED_SKILLS_TARGET" ] || return 0
  if ! "$SHIMMY_PROFILE_ROOT/commands/skills.sh" install --target "$REQUESTED_SKILLS_TARGET" --manifest "$INSTALL_MANIFEST_FILE"; then
    fail "profile installed, but skills integration failed; retry with '$SHIMMY_CONTROL_BIN skills install --target $REQUESTED_SKILLS_TARGET'"
  fi
}

perform_install() {
  validate_requested_shims
  shimmy_version_two_install_reject "$SHIMMY_CONFIG_ROOT" || exit 1
  profile_existing_state_read
  if [ "$PROFILE_EXISTS" -eq 1 ] && [ "$STARTUP_OPTION_REQUESTED" -eq 0 ]; then
    SKIP_STARTUP=1
  fi
  profile_source_checkout_resolve
  resolve_startup_settings
  profile_selection_merge
  profile_stage_prepare
  profile_assets_commit
  profile_stage_cleanup
  profile_external_integrations_apply

  log_info "Installed Shimmy $SHIMMY_PROFILE_RESOLVED profile at $SHIMMY_PROFILE_ROOT"
  log_info "Activate with: eval \"\$('${SHIMMY_CONTROL_BIN}' activate)\""
}

shimmy_install_run() {
  trap profile_stage_cleanup EXIT HUP INT TERM
  shimmy_install_request_parse "$@"
  shimmy_version_two_install_reject "$SHIMMY_CONFIG_ROOT" || exit 1

  if [ "$UNINSTALL" -eq 1 ]; then
    [ -z "$REQUESTED_SHIMS" ] || fail "--shim cannot be combined with --uninstall"
    perform_uninstall_profile
    return 0
  fi
  if [ "$REFRESH_SHIMS" -eq 1 ]; then
    [ -n "$REQUESTED_SHIMS" ] || fail "refresh must include --shim"
  fi
  perform_install
}
