#!/bin/sh
# Fetch a source checkout and refresh only the invoking profile.

shimmy_update_management_run() {
  manifest_file=$1
  source_url=$(shimmy_read_manifest_value "$manifest_file" shimmy_source_url || true)
  [ -n "$source_url" ] || fail "no shimmy_source_url found in $manifest_file"
  command -v git >/dev/null 2>&1 || fail "git is required for Shimmy self-update"

  update_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/shimmy-self-update.XXXXXX") || fail "unable to create update directory"
  source_dir=$update_tmp_dir/source
  set +e
  git clone "$source_url" "$source_dir" >/dev/null
  update_status=$?
  set -e
  if [ "$update_status" -ne 0 ]; then
    rm -rf "$update_tmp_dir"
    return "$update_status"
  fi

  upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_dir" || true)
  if [ -n "$upstream_invalid_reason" ]; then
    rm -rf "$update_tmp_dir"
    fail "fetched source does not satisfy the Shimmy bootstrap contract ($upstream_invalid_reason)"
  fi

  set -- "$source_dir/install.sh" --profile "$SHIMMY_PROFILE_NAME" --no-skills
  if [ "$REPAIR_STARTUP" -eq 0 ]; then
    set -- "$@" --no-startup
  else
    startup_shell=$REQUESTED_SHELL
    startup_files=$REQUESTED_STARTUP_FILES
    [ -n "$startup_shell" ] || startup_shell=$(shimmy_read_manifest_value "$manifest_file" startup_shell || true)
    [ -n "$startup_files" ] || startup_files=$(shimmy_read_manifest_values "$manifest_file" startup_file || true)
    [ -z "$startup_shell" ] || set -- "$@" --shell "$startup_shell"
    while IFS= read -r startup_file; do
      [ -n "$startup_file" ] || continue
      set -- "$@" --startup-file "$startup_file"
    done <<EOF
$startup_files
EOF
  fi

  previous_source_ref=$(shimmy_read_manifest_value "$manifest_file" shimmy_source_ref || true)
  set +e
  if [ "$SHIMMY_PROFILE_NAME" = upstream ]; then
    source_checkout=$(shimmy_read_manifest_value "$manifest_file" source_checkout)
    SHIMMY_UPSTREAM_CHECKOUT_DIR=$source_checkout SHIMMY_PREVIOUS_SOURCE_REF=$previous_source_ref "$@"
  else
    SHIMMY_PREVIOUS_SOURCE_REF=$previous_source_ref "$@"
  fi
  update_status=$?
  set -e
  rm -rf "$update_tmp_dir"
  return "$update_status"
}
