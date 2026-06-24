#!/bin/sh
# Profile uninstall and install-root cleanup.

remove_path_if_present() {
  path_value=$1
  description=$2

  if [ ! -e "$path_value" ] && [ ! -L "$path_value" ]; then
    return 0
  fi

  shimmy_validate_remove_path_safe "$path_value" || fail "refusing to remove unsafe path: $path_value"
  log_debug "Removing $description path: $path_value"
  rm -rf "$path_value"
}

remove_empty_install_dirs() {
  if [ -d "$SHIMMY_INSTALL_DIR/profiles" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/profiles" 2>/dev/null || true
  fi
  if [ -d "$SHIMMY_INSTALL_DIR/bin" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/bin" 2>/dev/null || true
  fi
  if [ -d "$SHIMMY_INSTALL_DIR/core" ]; then
    rmdir "$SHIMMY_INSTALL_DIR/core" 2>/dev/null || true
  fi

  if [ -d "$SHIMMY_INSTALL_DIR" ]; then
    shimmy_validate_remove_path_safe "$SHIMMY_INSTALL_DIR" || fail "refusing to remove unsafe path: $SHIMMY_INSTALL_DIR"
    if rmdir "$SHIMMY_INSTALL_DIR" 2>/dev/null; then
      log_debug "Removed empty install directory: $SHIMMY_INSTALL_DIR"
    fi
  fi
}

is_shimmy_public_dispatcher() {
  dispatcher_path=$1

  [ -L "$dispatcher_path" ] || return 1
  command -v readlink >/dev/null 2>&1 || return 1

  dispatcher_target=$(readlink "$dispatcher_path" 2>/dev/null || true)
  [ "$dispatcher_target" = ../core/commands/dispatch-tool.sh ] && return 0
  [ "$dispatcher_target" = "$SHIMMY_CORE_DISPATCHER" ] && return 0

  return 1
}

remove_shimmy_public_dispatchers() {
  [ -d "$SHIMMY_BIN_DIR" ] || return 0

  for dispatcher_path in "$SHIMMY_BIN_DIR"/*; do
    [ -e "$dispatcher_path" ] || [ -L "$dispatcher_path" ] || continue
    [ "$(basename "$dispatcher_path")" != shimmy ] || continue
    if is_shimmy_public_dispatcher "$dispatcher_path"; then
      remove_path_if_present "$dispatcher_path" "public dispatcher"
    fi
  done
}

uninstall_skills_target_remove() {
  [ "$SKIP_SKILLS" -eq 0 ] || return 0
  [ -n "$REQUESTED_SKILLS_TARGET" ] || return 0

  if [ ! -x "$SKILLS_SCRIPT" ]; then
    fail "missing skills helper: $SKILLS_SCRIPT"
  fi

  "$SKILLS_SCRIPT" uninstall --target "$REQUESTED_SKILLS_TARGET"
}

uninstall_startup_file_list_resolve() {
  profile_manifest_file=$1
  startup_file_paths=

  if [ -f "$SHIMMY_ROOT_MANIFEST_FILE" ]; then
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      if ! shimmy_contains_line_list "$startup_file_paths" "$startup_file_path"; then
        startup_file_paths=$(shimmy_append_line_list "$startup_file_paths" "$startup_file_path")
      fi
    done <<EOF
$(shimmy_read_manifest_values "$SHIMMY_ROOT_MANIFEST_FILE" startup_file || true)
EOF
  fi

  if [ -f "$profile_manifest_file" ]; then
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      if ! shimmy_contains_line_list "$startup_file_paths" "$startup_file_path"; then
        startup_file_paths=$(shimmy_append_line_list "$startup_file_paths" "$startup_file_path")
      fi
    done <<EOF
$(shimmy_read_manifest_values "$profile_manifest_file" startup_file || true)
EOF
  fi

  printf '%s\n' "$startup_file_paths"
}

perform_uninstall_profile() {
  uninstall_manifest_file=$SHIMMY_PROFILE_MANIFEST_FILE
  if [ ! -f "$uninstall_manifest_file" ] && [ ! -d "$SHIMMY_PROFILE_DIR" ]; then
    log_info "No shimmy $SHIMMY_PROFILE_RESOLVED profile found at $SHIMMY_PROFILE_DIR; checking install root cleanup"
  fi

  log_info "Removing shimmy $SHIMMY_PROFILE_RESOLVED profile rooted at $SHIMMY_PROFILE_DIR"

  kinds_to_check=$(shimmy_read_manifest_kinds "$uninstall_manifest_file" || true)
  startup_files_to_remove=$(uninstall_startup_file_list_resolve "$uninstall_manifest_file")

  uninstall_skills_target_remove
  remove_path_if_present "$SHIMMY_PROFILE_DIR" "profile"

  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    if shimmy_contains_profile_kind_other "$SHIMMY_INSTALL_DIR" "$kind_name" "$uninstall_manifest_file"; then
      continue
    fi
    remove_path_if_present "$SHIMMY_BIN_DIR/$kind_name" "dispatcher"
  done <<EOF
$kinds_to_check
EOF

  if [ "$(shimmy_count_profile_manifests "$SHIMMY_INSTALL_DIR")" -eq 0 ]; then
    remove_shimmy_public_dispatchers
    if [ -n "$startup_files_to_remove" ]; then
      while IFS= read -r startup_file_to_remove; do
        [ -n "$startup_file_to_remove" ] || continue
        shimmy_startup_block_remove "$startup_file_to_remove" "$SHIMMY_STARTUP_BLOCK_START" "$SHIMMY_STARTUP_BLOCK_END"
        log_info "Removed managed Shimmy startup block from: $startup_file_to_remove"
      done <<EOF
$startup_files_to_remove
EOF
    fi
    remove_path_if_present "$SHIMMY_CONTROL_BIN" "management command"
    remove_path_if_present "$SHIMMY_CORE_DIR" "management support"
    remove_path_if_present "$SHIMMY_ACTIVATE_FILE" "activation"
    remove_path_if_present "$SHIMMY_ROOT_MANIFEST_FILE" "root manifest"
  else
    write_root_manifest_existing_profiles
  fi

  remove_empty_install_dirs

  log_info "Removed shimmy $SHIMMY_PROFILE_RESOLVED profile from $SHIMMY_INSTALL_DIR"
}
