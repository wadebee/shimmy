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
# shellcheck source=lib/common/common.sh
. "$profile_root/lib/common/common.sh"
# shellcheck source=lib/profile/profile.sh
. "$profile_root/lib/profile/profile.sh"

shimmy_profile_context_resolve "$profile_root" || fail "dispatcher is outside a canonical Shimmy profile root"
shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME" || fail "incomplete or damaged Shimmy profile at $SHIMMY_PROFILE_ROOT"
shimmy_manifest_tool_contains "$SHIMMY_PROFILE_MANIFEST_PATH" "$shim_name" || fail "$shim_name is not owned by profile $SHIMMY_PROFILE_NAME"

if [ "$SHIMMY_PROFILE_NAME" = upstream ]; then
  source_checkout=$(shimmy_read_manifest_value "$SHIMMY_PROFILE_MANIFEST_PATH" source_checkout || true)
  upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_checkout" "$shim_name" || true)
  [ -z "$upstream_invalid_reason" ] || fail "invalid upstream Shimmy checkout ($upstream_invalid_reason): $source_checkout"
fi

target_path=$SHIMMY_PROFILE_IMPLEMENTATION_DIR/$shim_name
[ -f "$target_path" ] && [ ! -L "$target_path" ] || fail "invalid Shimmy implementation for $shim_name: $target_path"
[ -x "$target_path" ] || fail "Shimmy implementation is not executable: $target_path"

target_absolute=$(shimmy_resolve_path_absolute "$target_path")
dispatcher_absolute=$(shimmy_resolve_path_absolute "$profile_root/commands/dispatch-tool.sh")
[ "$target_absolute" != "$dispatcher_absolute" ] || fail "refusing recursive Shimmy dispatch for $shim_name"
exec "$target_path" "$@"
