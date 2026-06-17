#!/bin/sh
set -eu

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

path_absolute_resolve() {
  path_value=${1:-}

  if [ -z "$path_value" ]; then
    return 1
  fi

  case "$path_value" in
    /*)
      ;;
    *)
      path_value=$(pwd -P)/$path_value
      ;;
  esac

  path_dir=$(dirname -- "$path_value")
  path_base=$(basename -- "$path_value")

  if [ -d "$path_dir" ]; then
    (
      cd -- "$path_dir" && printf '%s/%s\n' "$(pwd -P)" "$path_base"
    )
    return 0
  fi

  printf '%s\n' "$path_value"
}

script_path_resolve() {
  script_name=$1

  case "$script_name" in
    */*)
      path_absolute_resolve "$script_name"
      return 0
      ;;
  esac

  old_ifs=$IFS
  IFS=:
  for path_dir in ${PATH:-}; do
    [ -n "$path_dir" ] || path_dir=.
    if [ -e "$path_dir/$script_name" ]; then
      IFS=$old_ifs
      path_absolute_resolve "$path_dir/$script_name"
      return 0
    fi
  done
  IFS=$old_ifs

  return 1
}

shim_name_validate() {
  shim_name=$1

  case "$shim_name" in
    ''|.*|*/*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

script_path=$(script_path_resolve "$0") || fail "unable to resolve dispatcher path: $0"
script_name=$(basename -- "$script_path")
script_dir=$(
  cd -- "$(dirname -- "$script_path")" && pwd -P
)

case "$script_name" in
  dispatch-shimmy.sh)
    [ "$#" -gt 0 ] || fail "missing shim name for Shimmy dispatcher"
    shim_name=$1
    shift
    install_dir=$(
      cd -- "$script_dir/../.." && pwd -P
    )
    ;;
  *)
    shim_name=$script_name
    install_dir=$(
      cd -- "$script_dir/.." && pwd -P
    )
    ;;
esac

shim_name_validate "$shim_name" || fail "invalid shim name for Shimmy dispatcher: $shim_name"

common_helper=$install_dir/core/lib/repo/shimmy-common.sh
profile_helper=$install_dir/core/lib/repo/shimmy-profile.sh
central_dispatcher=$install_dir/core/scripts/dispatch-shimmy.sh

[ -f "$common_helper" ] || fail "missing Shimmy common helper: $common_helper"
[ -f "$profile_helper" ] || fail "missing Shimmy profile helper: $profile_helper"

# shellcheck source=lib/repo/shimmy-common.sh
. "$common_helper"
# shellcheck source=lib/repo/shimmy-profile.sh
. "$profile_helper"

if ! shimmy_profile_paths_resolve "" "$install_dir" "$install_dir"; then
  fail "unsupported SHIMMY_PROFILE_ACTIVE: ${SHIMMY_PROFILE_ACTIVE:-}"
fi

manifest_file=$SHIMMY_PROFILE_MANIFEST_PATH
if ! shimmy_profile_structure_validate "$manifest_file" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"; then
  install_hint=$(shimmy_profile_install_hint "$SHIMMY_PROFILE_NAME")
  fail "incomplete Shimmy profile for profile $SHIMMY_PROFILE_NAME: expected manifest at $manifest_file and implementation directory at $SHIMMY_PROFILE_IMPLEMENTATION_DIR; repair with $install_hint"
fi

if [ "$SHIMMY_PROFILE_NAME" = upstream ]; then
  source_checkout=$(shimmy_read_manifest_value "$manifest_file" source_checkout || true)
  upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_checkout" "$shim_name" || true)
  if [ -n "$upstream_invalid_reason" ]; then
    fail "invalid upstream Shimmy checkout ($upstream_invalid_reason): $source_checkout; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
  fi
fi

target_dir=$(shimmy_read_manifest_value "$manifest_file" profile_implementation_dir || true)
if [ -z "$target_dir" ]; then
  target_dir=$SHIMMY_PROFILE_IMPLEMENTATION_DIR
fi

target_path=$target_dir/$shim_name

[ -f "$target_path" ] || fail "no Shimmy profile implementation for $shim_name in profile $SHIMMY_PROFILE_NAME: $target_path"

entry_path=$(shimmy_resolve_path_absolute "$0")
target_absolute=$(shimmy_resolve_path_absolute "$target_path")
central_absolute=$(shimmy_resolve_path_absolute "$central_dispatcher")

if [ "$target_absolute" = "$entry_path" ] || [ "$target_absolute" = "$central_absolute" ]; then
  fail "refusing recursive Shimmy dispatch for $shim_name: $target_path"
fi

if [ -L "$target_path" ]; then
  fail "refusing symlinked Shimmy profile implementation: $target_path"
fi
[ -x "$target_path" ] || fail "Shimmy profile implementation is not executable: $target_path"

exec "$target_path" "$@"
