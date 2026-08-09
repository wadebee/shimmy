#!/bin/sh
# Remove only schema-owned assets from the invoking profile.

profile_owned_path_remove() {
  path_value=$1
  [ -e "$path_value" ] || [ -L "$path_value" ] || return 0
  case "$path_value" in
    "$SHIMMY_PROFILE_ROOT"/*) ;;
    *) fail "refusing to remove path outside profile root: $path_value" ;;
  esac

  if [ -L "$path_value" ] || [ -f "$path_value" ]; then
    rm -f "$path_value"
  else
    rm -rf "$path_value"
  fi
}

perform_uninstall_profile() {
  [ -f "$INSTALL_MANIFEST_FILE" ] || fail "no Shimmy profile manifest found at $INSTALL_MANIFEST_FILE"
  shimmy_profile_manifest_validate "$INSTALL_MANIFEST_FILE" "$SHIMMY_PROFILE_RESOLVED" || exit 1

  installed_kinds=$(shimmy_read_manifest_kinds "$INSTALL_MANIFEST_FILE" || true)
  startup_files=
  if [ "$SHIMMY_PROFILE_RESOLVED" = default ]; then
    startup_files=$(shimmy_read_manifest_values "$INSTALL_MANIFEST_FILE" startup_file || true)
  fi

  for asset_name in agent commands config implementations lib plugins tests tools; do
    profile_owned_path_remove "$SHIMMY_PROFILE_ROOT/$asset_name"
  done
  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    profile_owned_path_remove "$SHIMMY_BIN_DIR/$kind_name"
  done <<EOF
$installed_kinds
EOF
  profile_owned_path_remove "$SHIMMY_CONTROL_BIN"
  profile_owned_path_remove "$SHIMMY_SHELL_INIT_FILE"
  profile_owned_path_remove "$INSTALL_MANIFEST_FILE"

  while IFS= read -r startup_file; do
    [ -n "$startup_file" ] || continue
    shimmy_startup_block_remove "$startup_file" "$SHIMMY_STARTUP_BLOCK_START" "$SHIMMY_STARTUP_BLOCK_END"
    log_info "Removed managed Shimmy startup block from: $startup_file"
  done <<EOF
$startup_files
EOF

  rmdir "$SHIMMY_BIN_DIR" 2>/dev/null || true
  rmdir "$SHIMMY_PROFILE_ROOT" 2>/dev/null || true
  rmdir "$SHIMMY_PROFILES_ROOT" 2>/dev/null || true
  rmdir "$SHIMMY_CONFIG_ROOT" 2>/dev/null || true
  log_info "Removed Shimmy $SHIMMY_PROFILE_RESOLVED profile from $SHIMMY_PROFILE_ROOT"
}
