#!/bin/sh
# Refresh the enclosing installed profile and selected tool images.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_CONTROL_ROOT=$ROOT_DIR

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

for helper_file in \
  "$ROOT_DIR/lib/common/common.sh" \
  "$ROOT_DIR/lib/catalog/catalog.sh" \
  "$ROOT_DIR/lib/profile/profile.sh" \
  "$ROOT_DIR/lib/registries/registries.sh"
do
  [ -f "$helper_file" ] || fail "missing update helper: $helper_file"
done

# shellcheck source=lib/common/common.sh
. "$ROOT_DIR/lib/common/common.sh"
# shellcheck source=lib/catalog/catalog.sh
. "$ROOT_DIR/lib/catalog/catalog.sh"
# shellcheck source=lib/profile/profile.sh
. "$ROOT_DIR/lib/profile/profile.sh"
# shellcheck source=lib/registries/registries.sh
. "$ROOT_DIR/lib/registries/registries.sh"
# shellcheck source=lib/update/request.sh
. "$ROOT_DIR/lib/update/request.sh"
# shellcheck source=lib/update/selection.sh
. "$ROOT_DIR/lib/update/selection.sh"
# shellcheck source=lib/update/management.sh
. "$ROOT_DIR/lib/update/management.sh"
# shellcheck source=lib/update/profile.sh
. "$ROOT_DIR/lib/update/profile.sh"
# shellcheck source=lib/update/refresh.sh
. "$ROOT_DIR/lib/update/refresh.sh"

shimmy_update_run() {
  shimmy_update_request_reset
  shimmy_update_request_parse "$@"
  shimmy_update_profile_validate
  if [ "$SHIMMY_PROFILE_NAME" = upstream ] && { [ "$REPAIR_STARTUP" -eq 1 ] || [ -n "$REQUESTED_SHELL" ] || [ -n "$REQUESTED_STARTUP_FILES" ]; }; then
    fail "upstream has no persistent startup integration; source $SHIMMY_PROFILE_ROOT/shell-init.sh after installation"
  fi

  selected_tools=$(shimmy_update_selected_tools_resolve "$SHIMMY_PROFILE_MANIFEST_PATH")
  shimmy_update_management_run "$SHIMMY_PROFILE_MANIFEST_PATH"
  shimmy_update_profile_materialization_run "$selected_tools"
  selected_versions=$(shimmy_update_selected_versions_resolve "$SHIMMY_PROFILE_MANIFEST_PATH" "$selected_tools")

  [ "$PULL_IMAGES" -eq 0 ] || shimmy_update_refresh_hooks_run pull "$selected_versions"
  [ "$BUILD_IMAGES" -eq 0 ] || shimmy_update_refresh_hooks_run build "$selected_versions"
}
