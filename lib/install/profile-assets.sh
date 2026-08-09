#!/bin/sh
# Staging and commit helpers for profile-local assets.

profile_asset_directory_stage() {
  source_path=$1
  target_path=$2

  [ -d "$source_path" ] || fail "missing source directory: $source_path"
  cp -R "$source_path" "$target_path"
}

shim_name_kind_resolve() {
  shim_name=$1
  if shimmy_is_kind "$shim_name"; then
    printf '%s\n' "$shim_name"
  else
    shimmy_version_kind "$shim_name"
  fi
}

shim_name_version_label_resolve() {
  shim_name=$1
  shimmy_is_kind "$shim_name" && return 1
  shimmy_version_label "$shim_name"
}

shim_source_config_path_resolve() {
  shim_name=$1
  kind_name=$(shim_name_kind_resolve "$shim_name") || return 1
  if shimmy_is_kind "$shim_name"; then
    printf '%s/tools/%s/tool.conf\n' "$ROOT_DIR" "$kind_name"
  else
    version_label=$(shim_name_version_label_resolve "$shim_name") || return 1
    printf '%s/tools/%s/versions/%s/smoke.conf\n' "$ROOT_DIR" "$kind_name" "$version_label"
  fi
}

render_shim_exec_wrapper() {
  shim_name=$1
  source_root=$2
  kind_name=$(shim_name_kind_resolve "$shim_name") || fail "missing Shimmy tool metadata for $shim_name"
  quoted_kind_name=$(shimmy_quote_shell_word "$kind_name")
  quoted_source_root=$(shimmy_quote_shell_word "$source_root")

  if shimmy_is_kind "$shim_name"; then
    target_rel=commands/run-tool.sh
    target_args='$shimmy_tool_kind "$@"'
  else
    version_label=$(shim_name_version_label_resolve "$shim_name") || fail "missing version label for $shim_name"
    target_rel=tools/$kind_name/versions/$version_label/run.sh
    target_args='"$@"'
  fi

  cat <<EOF
#!/bin/sh
set -eu

shimmy_tool_kind=$quoted_kind_name
shimmy_source_root=$quoted_source_root
shimmy_runtime_target=\$shimmy_source_root/$target_rel

if [ ! -x "\$shimmy_runtime_target" ]; then
  printf 'ERROR: missing Shimmy tool runtime: %s\n' "\$shimmy_runtime_target" >&2
  exit 1
fi

exec "\$shimmy_runtime_target" $target_args
EOF
}

profile_shim_assets_stage() {
  shim_name=$1
  source_root=$SHIMMY_PROFILE_ROOT
  [ "$SHIMMY_PROFILE_RESOLVED" != upstream ] || source_root=$SHIMMY_PROFILE_SOURCE_CHECKOUT

  render_shim_exec_wrapper "$shim_name" "$source_root" > "$SHIMMY_STAGE_ROOT/implementations/$shim_name"
  chmod 755 "$SHIMMY_STAGE_ROOT/implementations/$shim_name"

  config_source=$(shim_source_config_path_resolve "$shim_name") || fail "missing Shimmy metadata for $shim_name"
  [ -f "$config_source" ] || fail "missing shim config source: $config_source"
  cp "$config_source" "$SHIMMY_STAGE_ROOT/config/shims/$shim_name.conf"
  chmod 644 "$SHIMMY_STAGE_ROOT/config/shims/$shim_name.conf"
}

profile_control_assets_stage() {
  mkdir -p "$SHIMMY_STAGE_ROOT"
  for asset_name in commands lib tools tests plugins agent; do
    profile_asset_directory_stage "$ROOT_DIR/$asset_name" "$SHIMMY_STAGE_ROOT/$asset_name"
  done
  mkdir -p "$SHIMMY_STAGE_ROOT/config/shims" "$SHIMMY_STAGE_ROOT/implementations" "$SHIMMY_STAGE_ROOT/bin"

  [ -f "$ROOT_DIR/lib/install/launcher-template.sh" ] || fail "missing launcher template"
  cp "$ROOT_DIR/lib/install/launcher-template.sh" "$SHIMMY_STAGE_ROOT/bin/shimmy"
  chmod 755 "$SHIMMY_STAGE_ROOT/bin/shimmy"
}

profile_dispatcher_stage() {
  kind_name=$1
  ln -s ../commands/dispatch-tool.sh "$SHIMMY_STAGE_ROOT/bin/$kind_name"
}

profile_dispatcher_collision_validate() {
  kind_name=$1
  dispatcher_path=$SHIMMY_BIN_DIR/$kind_name

  [ ! -e "$dispatcher_path" ] && [ ! -L "$dispatcher_path" ] && return 0
  shimmy_contains_line_list "$EXISTING_PROFILE_KINDS" "$kind_name" || fail "unmanaged dispatcher collision: $dispatcher_path"
}

profile_launcher_collision_validate() {
  launcher_path=$SHIMMY_BIN_DIR/shimmy

  [ ! -e "$launcher_path" ] && [ ! -L "$launcher_path" ] && return 0
  [ "$PROFILE_EXISTS" -eq 1 ] || fail "unmanaged launcher collision: $launcher_path"
  [ -f "$launcher_path" ] && [ ! -L "$launcher_path" ] || fail "installed launcher must be a regular non-symlink file: $launcher_path"
}

profile_owned_directories_restore() {
  for asset_name in commands config implementations lib tools tests plugins agent; do
    target_path=$SHIMMY_PROFILE_ROOT/$asset_name
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/$asset_name
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
      if [ -L "$target_path" ]; then rm -f "$target_path"; else rm -rf "$target_path"; fi
    fi
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || mv "$backup_path" "$target_path"
  done
}

profile_owned_files_backup() {
  mkdir -p "$SHIMMY_PROFILE_BACKUP_ROOT/bin"
  for relative_path in activate.sh install-manifest.txt bin/shimmy; do
    source_path=$SHIMMY_PROFILE_ROOT/$relative_path
    target_path=$SHIMMY_PROFILE_BACKUP_ROOT/$relative_path
    [ ! -e "$source_path" ] && [ ! -L "$source_path" ] || cp -R "$source_path" "$target_path"
  done
  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    source_path=$SHIMMY_BIN_DIR/$kind_name
    [ ! -e "$source_path" ] && [ ! -L "$source_path" ] || cp -R "$source_path" "$SHIMMY_PROFILE_BACKUP_ROOT/bin/$kind_name"
  done <<EOF
$EXISTING_PROFILE_KINDS
EOF
}

profile_owned_files_restore() {
  for relative_path in activate.sh install-manifest.txt bin/shimmy; do
    target_path=$SHIMMY_PROFILE_ROOT/$relative_path
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/$relative_path
    [ ! -e "$target_path" ] && [ ! -L "$target_path" ] || rm -f "$target_path"
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || mv "$backup_path" "$target_path"
  done
  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    target_path=$SHIMMY_BIN_DIR/$kind_name
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/bin/$kind_name
    [ ! -e "$target_path" ] && [ ! -L "$target_path" ] || rm -f "$target_path"
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || mv "$backup_path" "$target_path"
  done <<EOF
$PROFILE_MANIFEST_KINDS
EOF
}

profile_replace_owned_directories() {
  SHIMMY_PROFILE_BACKUP_ROOT=$SHIMMY_PROFILES_ROOT/."$SHIMMY_PROFILE_RESOLVED".backup.$$
  mkdir -p "$SHIMMY_PROFILE_BACKUP_ROOT"
  for asset_name in commands config implementations lib tools tests plugins agent; do
    target_path=$SHIMMY_PROFILE_ROOT/$asset_name
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/$asset_name
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
      mv "$target_path" "$backup_path" || { profile_owned_directories_restore; return 1; }
    fi
    mv "$SHIMMY_STAGE_ROOT/$asset_name" "$target_path" || { profile_owned_directories_restore; return 1; }
  done
}

profile_merge_bin_commit() {
  mkdir -p "$SHIMMY_BIN_DIR"
  launcher_tmp=$SHIMMY_BIN_DIR/.shimmy.tmp.$$
  cp "$SHIMMY_STAGE_ROOT/bin/shimmy" "$launcher_tmp"
  chmod 755 "$launcher_tmp"
  mv "$launcher_tmp" "$SHIMMY_CONTROL_BIN"

  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    dispatcher_tmp=$SHIMMY_BIN_DIR/."$kind_name".tmp.$$
    rm -f "$dispatcher_tmp"
    ln -s ../commands/dispatch-tool.sh "$dispatcher_tmp"
    mv "$dispatcher_tmp" "$SHIMMY_BIN_DIR/$kind_name"
  done <<EOF
$PROFILE_MANIFEST_KINDS
EOF
}

profile_assets_commit() {
  mkdir -p "$SHIMMY_CONFIG_ROOT" "$SHIMMY_PROFILES_ROOT" "$SHIMMY_PROFILE_ROOT"
  profile_replace_owned_directories || fail "unable to replace profile assets; prior profile restored"
  profile_owned_files_backup || { profile_owned_directories_restore; fail "unable to back up owned profile files"; }
  if ! profile_merge_bin_commit; then
    profile_owned_files_restore
    profile_owned_directories_restore
    fail "unable to replace profile bin assets; prior profile directories restored"
  fi

  activate_tmp=$SHIMMY_PROFILE_ROOT/.activate.sh.tmp.$$
  cp "$SHIMMY_STAGE_ROOT/activate.sh" "$activate_tmp"
  chmod 644 "$activate_tmp"
  mv "$activate_tmp" "$SHIMMY_ACTIVATE_FILE"

  manifest_tmp=$SHIMMY_PROFILE_ROOT/.install-manifest.txt.tmp.$$
  cp "$SHIMMY_STAGE_ROOT/install-manifest.txt" "$manifest_tmp"
  chmod 644 "$manifest_tmp"
  mv "$manifest_tmp" "$INSTALL_MANIFEST_FILE"
  rm -rf "$SHIMMY_PROFILE_BACKUP_ROOT"
  SHIMMY_PROFILE_BACKUP_ROOT=
}
