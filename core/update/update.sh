#!/bin/sh
# Refresh Shimmy management and runtime assets.
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
COMMON_HELPER_FILE=$ROOT_DIR/core/common/common.sh
CATALOG_HELPER_FILE=$ROOT_DIR/core/catalog/catalog.sh
PROFILE_HELPER_FILE=$ROOT_DIR/core/profile/profile.sh
STARTUP_HELPER_FILE=$ROOT_DIR/core/startup/startup.sh
DEFAULT_INSTALL_DIR=${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}
PREVIOUS_SOURCE_REF=
UPDATE_SOURCE_CHECKOUT=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

if [ ! -f "$CATALOG_HELPER_FILE" ]; then
  fail "missing catalog helper: $CATALOG_HELPER_FILE"
fi

if [ ! -f "$COMMON_HELPER_FILE" ]; then
  fail "missing common helper: $COMMON_HELPER_FILE"
fi

if [ ! -f "$STARTUP_HELPER_FILE" ]; then
  fail "missing startup helper: $STARTUP_HELPER_FILE"
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
# shellcheck source=core/update/request.sh
. "$ROOT_DIR/core/update/request.sh"
# shellcheck source=core/update/selection.sh
. "$ROOT_DIR/core/update/selection.sh"
# shellcheck source=core/update/management.sh
. "$ROOT_DIR/core/update/management.sh"
# shellcheck source=core/update/profile.sh
. "$ROOT_DIR/core/update/profile.sh"
# shellcheck source=core/update/refresh.sh
. "$ROOT_DIR/core/update/refresh.sh"

shimmy_update_orchestration_run() {
  if [ -n "${SHIMMY_PROFILE_ACTIVE:-}" ]; then
    SHIMMY_PROFILE_ACTIVATED=1
  fi

  if [ "$UPDATE_ALL" -eq 1 ] && [ -n "$REQUESTED_SHIMS" ]; then
    fail "--all cannot be combined with --shim"
  fi

  install_dir=$(shimmy_update_install_dir_resolve)
  if [ "$UPDATE_ALL" -eq 1 ]; then
    SHIMMY_PROFILE_REQUESTED=default
  fi
  shimmy_update_profile_paths_resolve "$install_dir"
  install_dir=$SHIMMY_PROFILE_INSTALL_DIR
  manifest_file=$(shimmy_update_manifest_file_resolve)
  root_manifest_file=$install_dir/install-manifest.txt

  shimmy_install_layout_validate "$root_manifest_file" || fail "legacy Shimmy install layout detected; uninstall and reinstall"

  manifest_install_dir=$(shimmy_read_manifest_value "$root_manifest_file" install_dir || true)
  if [ -n "$manifest_install_dir" ]; then
    install_dir=$(shimmy_trim_path_trailing_slash "$manifest_install_dir")
    shimmy_update_profile_paths_resolve "$install_dir"
    manifest_file=$(shimmy_update_manifest_file_resolve)
    root_manifest_file=$install_dir/install-manifest.txt
  fi

  if [ "$UPDATE_ALL" -eq 1 ] && [ ! -f "$manifest_file" ]; then
    [ -f "$root_manifest_file" ] || fail "no shimmy install manifest found at $root_manifest_file; run ./shimmy install first"
    first_profile_name=$(shimmy_update_installed_profile_list "$root_manifest_file" | sed -n '1p')
    [ -n "$first_profile_name" ] || fail "no shimmy profiles found under $install_dir; run ./shimmy install first"
    SHIMMY_PROFILE_REQUESTED=$first_profile_name
    shimmy_update_profile_paths_resolve "$install_dir"
    manifest_file=$(shimmy_update_manifest_file_resolve)
  fi

  if [ ! -f "$manifest_file" ]; then
    if [ "$SHIMMY_PROFILE_NAME" = upstream ] && [ -z "${SHIMMY_UPSTREAM_CHECKOUT_DIR:-}" ]; then
      fail "no shimmy profile manifest found for profile upstream at $manifest_file; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
    fail "no shimmy profile manifest found for profile $SHIMMY_PROFILE_NAME at $manifest_file; run ./shimmy install first"
  fi

  if shimmy_update_is_installed_management "$install_dir"; then
    shimmy_update_management_run "$install_dir" "$manifest_file"
    exit 0
  fi

  if [ "$UPDATE_ALL" -eq 1 ]; then
    while IFS= read -r profile_name; do
      [ -n "$profile_name" ] || continue
      SHIMMY_PROFILE_REQUESTED=$profile_name
      shimmy_update_profile_paths_resolve "$install_dir"
      profile_manifest_file=$(shimmy_update_manifest_file_resolve)
      [ -f "$profile_manifest_file" ] || fail "no shimmy profile manifest found for profile $profile_name at $profile_manifest_file"
      profile_requests=$(shimmy_read_manifest_kinds "$profile_manifest_file")
  for version_name in $(shimmy_update_installed_kind_version_names "$profile_manifest_file"); do
        profile_requests=$(shimmy_append_line_list "$profile_requests" "$version_name")
      done
      profile_versions=$(shimmy_update_installed_kind_version_names "$profile_manifest_file")
      shimmy_update_profile_refresh_run "$profile_name" "$profile_manifest_file" "$profile_requests" "$profile_versions"
    done <<EOF
$(shimmy_update_installed_profile_list "$root_manifest_file")
EOF
    exit 0
  fi

  if [ -n "$REQUESTED_SHIMS" ]; then
    refresh_requests=
    refresh_versions=
    for requested_shim in $REQUESTED_SHIMS; do
      resolved_requests=$(shimmy_update_refresh_requests_for_shim "$manifest_file" "$requested_shim")
      while IFS= read -r refresh_request; do
        [ -n "$refresh_request" ] || continue
        if ! shimmy_contains_line_list "$refresh_requests" "$refresh_request"; then
          refresh_requests=$(shimmy_append_line_list "$refresh_requests" "$refresh_request")
        fi
        if shimmy_is_version "$refresh_request" && ! shimmy_contains_line_list "$refresh_versions" "$refresh_request"; then
          refresh_versions=$(shimmy_append_line_list "$refresh_versions" "$refresh_request")
        fi
      done <<EOF
$resolved_requests
EOF
    done
    shims_to_refresh=$refresh_requests
    versions_to_refresh=$refresh_versions
  else
    shims_to_refresh=$(shimmy_update_default_installed_kind_request_list "$manifest_file")
    versions_to_refresh=
    for refresh_request in $shims_to_refresh; do
      if shimmy_is_version "$refresh_request" && ! shimmy_contains_line_list "$versions_to_refresh" "$refresh_request"; then
        versions_to_refresh=$(shimmy_append_line_list "$versions_to_refresh" "$refresh_request")
      fi
    done
    [ -n "$shims_to_refresh" ] || fail "no default shim kinds are installed in profile $SHIMMY_PROFILE_NAME; run ./shimmy install first"
  fi

  shimmy_update_profile_refresh_run "$SHIMMY_PROFILE_NAME" "$manifest_file" "$shims_to_refresh" "$versions_to_refresh"
}

shimmy_update_run() {
  shimmy_update_request_reset
  shimmy_update_request_parse "$@"
  shimmy_update_orchestration_run
}
