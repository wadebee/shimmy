#!/bin/sh
# Profile-local update helpers.

shimmy_update_profile_materialization_run() {
  selected_tools=$1
  [ -n "$selected_tools" ] || return 0

  set -- "$SHIMMY_PROFILE_ROOT/commands/install.sh"
  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    set -- "$@" --shim "$tool_name"
  done <<EOF
$selected_tools
EOF
  "$@"
}

shimmy_update_startup_repair_run() {
  [ "$REPAIR_STARTUP" -eq 1 ] || return 0

  startup_files=$(shimmy_read_manifest_values "$SHIMMY_PROFILE_MANIFEST_PATH" startup_file || true)
  if [ -z "$startup_files" ]; then
    printf '%s\n' 'INFO: profile has no managed startup files to repair' >&2
    return 0
  fi

  shell_init_block=$(shimmy_shell_init_source_block_render "$SHIMMY_PROFILE_ROOT/shell-init.sh") ||
    fail "unable to render shell init block for startup repair"
  while IFS= read -r startup_file; do
    [ -n "$startup_file" ] || continue
    shimmy_startup_file_update "$startup_file" "$shell_init_block" ||
      fail "unable to repair startup file: $startup_file"
    printf 'INFO: Repaired startup file: %s\n' "$startup_file" >&2
  done <<EOF
$startup_files
EOF
}

shimmy_update_profile_validate() {
  shimmy_profile_context_resolve "$ROOT_DIR" || fail "update must run from a canonical installed profile"
  shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME" || fail "incomplete or damaged Shimmy profile at $SHIMMY_PROFILE_ROOT"
  shimmy_catalog_profile_resolve "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_CONFIG_ROOT" || fail "$SHIMMY_CATALOG_ERROR"
  if [ "$SHIMMY_PROFILE_NAME" = upstream ]; then
    source_checkout=$(shimmy_read_manifest_value "$SHIMMY_PROFILE_MANIFEST_PATH" source_checkout || true)
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_checkout" || true)
    [ -z "$upstream_invalid_reason" ] || fail "invalid upstream source checkout ($upstream_invalid_reason): $source_checkout"
  fi
}
