#!/bin/sh
# Remove only manifest- or registry-owned Shimmy assets.

perform_uninstall_global() {
  global_config_root=$SHIMMY_CONFIG_ROOT
  global_profiles_root=$SHIMMY_PROFILES_ROOT

  shimmy_catalog_owned_state_validate "$global_config_root" 0 || fail "$SHIMMY_CATALOG_ERROR"
  for global_profile_name in default upstream; do
    shimmy_profile_paths_resolve "$global_profile_name" || fail "unable to resolve canonical $global_profile_name profile"
    if [ -e "$SHIMMY_PROFILE_ROOT" ] || [ -L "$SHIMMY_PROFILE_ROOT" ]; then
      [ -f "$SHIMMY_PROFILE_MANIFEST_PATH" ] && [ ! -L "$SHIMMY_PROFILE_MANIFEST_PATH" ] ||
        fail "refusing global uninstall with unmanaged or incomplete profile state: $SHIMMY_PROFILE_ROOT"
      shimmy_profile_manifest_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$global_profile_name" || exit 1
      if [ -e "$SHIMMY_PROFILE_REGISTRIES_PATH" ] || [ -L "$SHIMMY_PROFILE_REGISTRIES_PATH" ]; then
        shimmy_registries_config_validate "$SHIMMY_PROFILE_REGISTRIES_PATH" "$global_profile_name" ||
          fail "refusing global uninstall with invalid registry configuration: $SHIMMY_PROFILE_REGISTRIES_PATH"
      fi
      [ ! -e "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH" ] && [ ! -L "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH" ] ||
        fail "refusing global uninstall while a registry transaction is active or damaged: $SHIMMY_PROFILE_REGISTRIES_LOCK_PATH"
      shimmy_registries_active_link_state_read
      [ "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" != invalid ] ||
        fail "refusing global uninstall with invalid or foreign registry activation state: $SHIMMY_REGISTRIES_ACTIVE_LINK"
    fi
  done

  for global_profile_name in default upstream; do
    shimmy_profile_paths_resolve "$global_profile_name" || fail "unable to resolve canonical $global_profile_name profile"
    [ -f "$SHIMMY_PROFILE_MANIFEST_PATH" ] || continue
    SHIMMY_PROFILE_RESOLVED=$global_profile_name
    SHIMMY_BIN_DIR=$SHIMMY_PROFILE_BIN_DIR
    SHIMMY_CONTROL_BIN=$SHIMMY_BIN_DIR/shimmy
    SHIMMY_SHELL_INIT_FILE=$SHIMMY_PROFILE_ROOT/shell-init.sh
    INSTALL_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_PATH
    perform_uninstall_profile
  done

  SHIMMY_CONFIG_ROOT=$global_config_root
  SHIMMY_PROFILES_ROOT=$global_profiles_root
  shimmy_catalog_owned_state_remove "$SHIMMY_CONFIG_ROOT" || fail "$SHIMMY_CATALOG_ERROR"
  rmdir "$SHIMMY_PROFILES_ROOT" 2>/dev/null || true
  rmdir "$SHIMMY_CONFIG_ROOT" 2>/dev/null || true
  log_info "Removed all manifest-owned Shimmy profiles and shared catalogs from $SHIMMY_CONFIG_ROOT"
}

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
  if [ -e "$SHIMMY_PROFILE_REGISTRIES_PATH" ] || [ -L "$SHIMMY_PROFILE_REGISTRIES_PATH" ]; then
    shimmy_registries_config_validate "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_RESOLVED" ||
      fail "refusing to remove invalid or unmanaged registry configuration: $SHIMMY_PROFILE_REGISTRIES_PATH"
  fi
  shimmy_registries_lock_acquire || fail "unable to lock registry configuration for profile uninstall"
  shimmy_registries_active_link_state_read
  case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in
    current) shimmy_registries_active_link_detach || fail "unable to detach active Linux registry policy" ;;
    invalid) fail "refusing to remove profile with invalid or foreign registry activation state: $SHIMMY_REGISTRIES_ACTIVE_LINK" ;;
  esac

  installed_tools=$(shimmy_manifest_tool_list_read "$INSTALL_MANIFEST_FILE" || true)
  startup_files=
  if [ "$SHIMMY_PROFILE_RESOLVED" = default ]; then
    startup_files=$(shimmy_read_manifest_values "$INSTALL_MANIFEST_FILE" startup_file || true)
  fi

  for asset_name in agent commands config implementations lib plugins tests tools; do
    profile_owned_path_remove "$SHIMMY_PROFILE_ROOT/$asset_name"
  done
  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    profile_owned_path_remove "$SHIMMY_BIN_DIR/$tool_name"
  done <<EOF
$installed_tools
EOF
  profile_owned_path_remove "$SHIMMY_CONTROL_BIN"
  profile_owned_path_remove "$SHIMMY_SHELL_INIT_FILE"
  profile_owned_path_remove "$SHIMMY_PROFILE_REGISTRIES_PATH"
  profile_owned_path_remove "$INSTALL_MANIFEST_FILE"

  while IFS= read -r startup_file; do
    [ -n "$startup_file" ] || continue
    shimmy_startup_block_remove "$startup_file" "$SHIMMY_STARTUP_BLOCK_START" "$SHIMMY_STARTUP_BLOCK_END"
    log_info "Removed managed Shimmy startup block from: $startup_file"
  done <<EOF
$startup_files
EOF

  shimmy_registries_lock_release
  rmdir "$SHIMMY_BIN_DIR" 2>/dev/null || true
  rmdir "$SHIMMY_PROFILE_ROOT" 2>/dev/null || true
  rmdir "$SHIMMY_PROFILES_ROOT" 2>/dev/null || true
  rmdir "$SHIMMY_CONFIG_ROOT" 2>/dev/null || true
  log_info "Removed Shimmy $SHIMMY_PROFILE_RESOLVED profile from $SHIMMY_PROFILE_ROOT"
}
