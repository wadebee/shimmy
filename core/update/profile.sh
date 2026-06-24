#!/bin/sh
# Profile discovery and refresh orchestration for update requests.

shimmy_update_installed_profile_list() {
  root_manifest_file=$1
  profile_names=

  if [ -f "$root_manifest_file" ]; then
    profile_names=$(shimmy_read_manifest_values "$root_manifest_file" profile || true)
  fi

  for profile_manifest_file in "$install_dir"/profiles/*/install-manifest.txt; do
    [ -f "$profile_manifest_file" ] || continue
    profile_name=$(basename "$(dirname "$profile_manifest_file")")
    if ! shimmy_contains_line_list "$profile_names" "$profile_name"; then
      profile_names=$(shimmy_append_line_list "$profile_names" "$profile_name")
    fi
  done

  printf '%s\n' "$profile_names"
}

shimmy_update_profile_refresh_run() {
  profile_name=$1
  profile_manifest_file=$2
  request_list=$3
  version_list=$4

  [ -n "$request_list" ] || fail "no installed shim kinds selected for profile $profile_name"

  PREVIOUS_SOURCE_REF=$(shimmy_read_manifest_value "$profile_manifest_file" shimmy_source_ref || true)
  UPDATE_SOURCE_CHECKOUT=
  manifest_source_checkout=$(shimmy_read_manifest_value "$profile_manifest_file" source_checkout || true)
  if [ "$profile_name" = upstream ] && [ -n "$manifest_source_checkout" ]; then
    UPDATE_SOURCE_CHECKOUT=$manifest_source_checkout
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$UPDATE_SOURCE_CHECKOUT" || true)
    if [ -n "$upstream_invalid_reason" ]; then
      fail "invalid upstream Shimmy checkout ($upstream_invalid_reason): $UPDATE_SOURCE_CHECKOUT; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
  fi

  set -- "$SCRIPT_DIR/install.sh" --install-dir "$install_dir" --profile "$profile_name" --refresh-shims --no-skills
  if [ "$REPAIR_STARTUP" -eq 0 ]; then
    set -- "$@" --no-startup
  else
    startup_shell=$REQUESTED_SHELL
    startup_files=$REQUESTED_STARTUP_FILES

    if [ -z "$startup_shell" ]; then
      startup_shell=$(shimmy_read_manifest_value "$root_manifest_file" startup_shell || true)
    fi
    if [ -z "$startup_files" ]; then
      startup_files=$(shimmy_read_manifest_values "$root_manifest_file" startup_file || true)
    fi

    if [ -n "$startup_shell" ]; then
      set -- "$@" --shell "$startup_shell"
    fi
    if [ -n "$startup_files" ]; then
      while IFS= read -r startup_file; do
        [ -n "$startup_file" ] || continue
        set -- "$@" --startup-file "$startup_file"
      done <<EOF
$startup_files
EOF
    fi
  fi

  for requested_shim in $request_list; do
    set -- "$@" --shim "$requested_shim"
  done

  if [ -n "$PREVIOUS_SOURCE_REF" ]; then
    if [ -n "$UPDATE_SOURCE_CHECKOUT" ]; then
      SHIMMY_UPSTREAM_CHECKOUT_DIR=$UPDATE_SOURCE_CHECKOUT SHIMMY_PREVIOUS_SOURCE_REF=$PREVIOUS_SOURCE_REF "$@"
    else
      SHIMMY_PREVIOUS_SOURCE_REF=$PREVIOUS_SOURCE_REF "$@"
    fi
  else
    if [ -n "$UPDATE_SOURCE_CHECKOUT" ]; then
      SHIMMY_UPSTREAM_CHECKOUT_DIR=$UPDATE_SOURCE_CHECKOUT "$@"
    else
      "$@"
    fi
  fi

  shimmy_update_profile_paths_resolve "$install_dir"
  if [ "$PULL_IMAGES" -eq 1 ]; then
    shimmy_update_refresh_hooks_run pull "$profile_name" "$version_list"
  fi

  if [ "$BUILD_IMAGES" -eq 1 ]; then
    shimmy_update_refresh_hooks_run build "$profile_name" "$version_list"
  fi
}
