#!/bin/sh
# Dispatch an installed public tool within its enclosing profile.
set -eu

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

shim_name_validate() {
  case "${1:-}" in
    ''|.*|*/*|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

script_name=$(basename -- "$0")
script_dir=$(cd -- "$(dirname -- "$0")" && pwd -P)
case "$script_name" in
  dispatch-tool.sh)
    [ "$#" -gt 0 ] || fail "missing shim name for Shimmy dispatcher"
    shim_name=$1
    shift
    profile_root=$(cd -- "$script_dir/.." && pwd -P)
    ;;
  *)
    shim_name=$script_name
    profile_root=$(cd -- "$script_dir/.." && pwd -P)
    ;;
esac
shim_name_validate "$shim_name" || fail "invalid shim name for Shimmy dispatcher: $shim_name"

[ -f "$profile_root/lib/common/common.sh" ] || fail "missing Shimmy common helper"
[ -f "$profile_root/lib/profile/profile.sh" ] || fail "missing Shimmy profile helper"
[ -f "$profile_root/lib/registries/registries.sh" ] || fail "missing Shimmy registries helper"
# shellcheck source=lib/common/common.sh
. "$profile_root/lib/common/common.sh"
# shellcheck source=lib/profile/profile.sh
. "$profile_root/lib/profile/profile.sh"
# shellcheck source=lib/registries/registries.sh
. "$profile_root/lib/registries/registries.sh"

shimmy_profile_context_resolve "$profile_root" || fail "dispatcher is outside a canonical Shimmy profile root"
shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME" || fail "incomplete or damaged Shimmy profile at $SHIMMY_PROFILE_ROOT"
shimmy_manifest_tool_contains "$SHIMMY_PROFILE_MANIFEST_PATH" "$shim_name" || fail "$shim_name is not owned by profile $SHIMMY_PROFILE_NAME"

target_path=$profile_root/commands/run-tool.sh
[ -f "$target_path" ] && [ ! -L "$target_path" ] || fail "invalid Shimmy tool dispatcher target: $target_path"
[ -x "$target_path" ] || fail "Shimmy tool dispatcher target is not executable: $target_path"

exec "$target_path" "$shim_name" "$@"
