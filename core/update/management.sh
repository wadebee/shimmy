#!/bin/sh
# Installed-management source refresh for update requests.

shimmy_update_is_installed_management() {
  install_dir=$1

  [ -n "${SHIMMY_CONTROL_INSTALL_DIR:-}" ] || return 1

  installed_control_dir=$install_dir/core
  [ -x "$installed_control_dir/shimmy" ] || return 1
  [ -d "$installed_control_dir/commands" ] || return 1
  [ -d "$installed_control_dir/core" ] || return 1
  [ -d "$installed_control_dir/tools" ] || return 1

  root_dir_real=$(cd -- "$ROOT_DIR" && pwd) || return 1
  installed_control_dir_real=$(cd -- "$installed_control_dir" && pwd) || return 1

  [ "$root_dir_real" = "$installed_control_dir_real" ]
}

shimmy_update_management_run() {
  install_dir=$1
  manifest_file=$2

  source_url=$(shimmy_read_manifest_value "$manifest_file" shimmy_source_url || true)
  [ -n "$source_url" ] || fail "no shimmy_source_url found in $manifest_file; run update from a Shimmy source checkout"
  command -v git >/dev/null 2>&1 || fail "git is required for installed shimmy update"

  temp_parent=${TMPDIR:-/tmp}
  update_tmp_dir=$(mktemp -d "$temp_parent/shimmy-self-update.XXXXXX") || fail "unable to create temporary update directory"
  source_dir=$update_tmp_dir/source

  printf 'INFO: Fetching Shimmy management updates from %s\n' "$source_url" >&2
  if git clone "$source_url" "$source_dir" >/dev/null; then
    :
  else
    command_status=$?
    rm -rf "$update_tmp_dir"
    return "$command_status"
  fi

  if [ ! -x "$source_dir/shimmy" ]; then
    rm -rf "$update_tmp_dir"
    fail "fetched source does not contain an executable shimmy launcher"
  fi

  source_ref=$(git -C "$source_dir" rev-parse --short HEAD 2>/dev/null || printf unknown)
  printf 'INFO: Updating Shimmy management plane from %s\n' "$source_ref" >&2

  set -- "$source_dir/shimmy" update --install-dir "$install_dir"
  if [ "$SHIMMY_PROFILE_ACTIVATED" -eq 1 ]; then
    set -- "$@" --profile "$SHIMMY_PROFILE_NAME"
  fi
  if [ "$PULL_IMAGES" -eq 1 ]; then
    set -- "$@" --pull
  fi
  if [ "$BUILD_IMAGES" -eq 1 ]; then
    set -- "$@" --build
  fi
  if [ "$REPAIR_STARTUP" -eq 1 ]; then
    set -- "$@" --repair-startup
  fi
  if [ "$UPDATE_ALL" -eq 1 ]; then
    set -- "$@" --all
  fi
  if [ -n "$REQUESTED_SHIMS" ]; then
    for shim_name in $REQUESTED_SHIMS; do
      set -- "$@" --shim "$shim_name"
    done
  fi
  if [ -n "$REQUESTED_SHELL" ]; then
    set -- "$@" --shell "$REQUESTED_SHELL"
  fi
  if [ -n "$REQUESTED_STARTUP_FILES" ]; then
    while IFS= read -r startup_file; do
      [ -n "$startup_file" ] || continue
      set -- "$@" --startup-file "$startup_file"
    done <<EOF
$REQUESTED_STARTUP_FILES
EOF
  fi

  set +e
  if [ -n "$UPDATE_SOURCE_CHECKOUT" ]; then
    SHIMMY_UPSTREAM_CHECKOUT_DIR=$UPDATE_SOURCE_CHECKOUT "$@"
    command_status=$?
  else
    "$@"
    command_status=$?
  fi
  set -e

  if [ "$command_status" -eq 0 ]; then
    rm -rf "$update_tmp_dir"
    return 0
  fi

  rm -rf "$update_tmp_dir"
  return "$command_status"
}
