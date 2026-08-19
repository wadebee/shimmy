#!/bin/sh
# Staging and commit helpers for profile-local assets.

profile_asset_directory_stage() {
  source_path=$1
  target_path=$2

  [ -d "$source_path" ] || fail "missing source directory: $source_path"
  cp -R "$source_path" "$target_path"
}

profile_tool_config_stage() {
  tool_name=$1
  config_source=$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/tool.conf
  [ -f "$config_source" ] || fail "missing shim config source: $config_source"
  cp "$config_source" "$SHIMMY_STAGE_ROOT/config/shims/$tool_name.conf"
  chmod 644 "$SHIMMY_STAGE_ROOT/config/shims/$tool_name.conf"
}

profile_tool_version_config_stage() {
  tool_name=$1
  version_label=$2
  version_name=$3
  config_source=$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/versions/$version_label/smoke.conf
  [ -f "$config_source" ] || fail "missing shim config source: $config_source"
  cp "$config_source" "$SHIMMY_STAGE_ROOT/config/shims/$version_name.conf"
  chmod 644 "$SHIMMY_STAGE_ROOT/config/shims/$version_name.conf"
}

profile_control_assets_stage() {
  mkdir -p "$SHIMMY_STAGE_ROOT"
  for asset_name in commands lib tests; do
    profile_asset_directory_stage "$ROOT_DIR/$asset_name" "$SHIMMY_STAGE_ROOT/$asset_name"
  done
  mkdir -p "$SHIMMY_STAGE_ROOT/config/shims" "$SHIMMY_STAGE_ROOT/bin" "$SHIMMY_STAGE_ROOT/tools"

  [ -f "$ROOT_DIR/lib/install/launcher-template.sh" ] || fail "missing launcher template"
  cp "$ROOT_DIR/lib/install/launcher-template.sh" "$SHIMMY_STAGE_ROOT/bin/shimmy"
  chmod 755 "$SHIMMY_STAGE_ROOT/bin/shimmy"
}

profile_materialization_assets_stage() {
  materialized_versions=

  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    tool_source=$SHIMMY_CATALOG_TOOLS_DIR/$tool_name
    tool_target=$SHIMMY_STAGE_ROOT/tools/$tool_name
    [ -d "$tool_source" ] && [ ! -L "$tool_source" ] || fail "missing catalog tool source: $tool_source"
    mkdir -p "$tool_target/versions"
    cp "$tool_source/tool.conf" "$tool_target/tool.conf"
    chmod 644 "$tool_target/tool.conf"
  done <<EOF
$PROFILE_MANIFEST_TOOLS
EOF

  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    tool_name=${tool_version_entry%%|*}
    version_remainder=${tool_version_entry#*|}
    version_label=${version_remainder%%|*}
    [ "$version_label" != default ] || continue
    materialized_version=$tool_name\|$version_label
    shimmy_contains_line_list "$materialized_versions" "$materialized_version" && continue
    materialized_versions=$(shimmy_append_line_list "$materialized_versions" "$materialized_version")
    version_source=$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/versions/$version_label
    version_target=$SHIMMY_STAGE_ROOT/tools/$tool_name/versions/$version_label
    profile_asset_directory_stage "$version_source" "$version_target"
  done <<EOF
$PROFILE_MANIFEST_TOOL_VERSIONS
EOF
}

profile_materialization_catalog_snapshot_record() {
  SHIMMY_MATERIALIZATION_CATALOG_NAME=$SHIMMY_CATALOG_NAME
  SHIMMY_MATERIALIZATION_CATALOG_SOURCE_TYPE=$SHIMMY_CATALOG_SOURCE_TYPE
  SHIMMY_MATERIALIZATION_CATALOG_SOURCE_PATH=$SHIMMY_CATALOG_SOURCE_PATH
  SHIMMY_MATERIALIZATION_CATALOG_GENERATION=$SHIMMY_CATALOG_GENERATION
  SHIMMY_MATERIALIZATION_CATALOG_SCHEMA=$SHIMMY_CATALOG_SCHEMA
  SHIMMY_MATERIALIZATION_CATALOG_FINGERPRINT=$SHIMMY_CATALOG_CONTENT_FINGERPRINT
}

profile_materialization_catalog_snapshot_validate() {
  shimmy_catalog_registry_resolve "$SHIMMY_CONFIG_ROOT" "$SHIMMY_PROFILE_CATALOG_NAME" || fail "$SHIMMY_CATALOG_ERROR"
  [ "$SHIMMY_CATALOG_NAME" = "$SHIMMY_MATERIALIZATION_CATALOG_NAME" ] &&
    [ "$SHIMMY_CATALOG_SOURCE_TYPE" = "$SHIMMY_MATERIALIZATION_CATALOG_SOURCE_TYPE" ] &&
    [ "$SHIMMY_CATALOG_SOURCE_PATH" = "$SHIMMY_MATERIALIZATION_CATALOG_SOURCE_PATH" ] &&
    [ "$SHIMMY_CATALOG_GENERATION" = "$SHIMMY_MATERIALIZATION_CATALOG_GENERATION" ] &&
    [ "$SHIMMY_CATALOG_SCHEMA" = "$SHIMMY_MATERIALIZATION_CATALOG_SCHEMA" ] &&
    [ "$SHIMMY_CATALOG_CONTENT_FINGERPRINT" = "$SHIMMY_MATERIALIZATION_CATALOG_FINGERPRINT" ] ||
    fail "catalog $SHIMMY_PROFILE_CATALOG_NAME changed during profile materialization; no profile changes were committed"

  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    cmp -s "$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/tool.conf" "$SHIMMY_STAGE_ROOT/tools/$tool_name/tool.conf" ||
      fail "catalog tool changed during profile materialization: $tool_name"
  done <<EOF
$PROFILE_MANIFEST_TOOLS
EOF

  materialized_versions=
  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    tool_name=${tool_version_entry%%|*}
    version_remainder=${tool_version_entry#*|}
    version_label=${version_remainder%%|*}
    [ "$version_label" != default ] || continue
    materialized_version=$tool_name\|$version_label
    shimmy_contains_line_list "$materialized_versions" "$materialized_version" && continue
    materialized_versions=$(shimmy_append_line_list "$materialized_versions" "$materialized_version")
    diff -r "$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/versions/$version_label" "$SHIMMY_STAGE_ROOT/tools/$tool_name/versions/$version_label" >/dev/null ||
      fail "catalog version changed during profile materialization: $tool_name@$version_label"
  done <<EOF
$PROFILE_MANIFEST_TOOL_VERSIONS
EOF
}

profile_commit_temporary_files_cleanup() {
  for temporary_path in "$SHIMMY_MANIFEST_COMMIT_TMP" "$SHIMMY_MACHINE_PROJECTION_COMMIT_TMP" "$SHIMMY_REGISTRIES_COMMIT_TMP" "$SHIMMY_SHELL_INIT_COMMIT_TMP"; do
    [ -n "$temporary_path" ] || continue
    case "$temporary_path" in
      "$SHIMMY_PROFILE_ROOT"/.install-manifest.txt.tmp.*|"$SHIMMY_PROFILE_ROOT"/.machine-projection.txt.tmp.*|"$SHIMMY_PROFILE_ROOT"/.registries.tmp.*|"$SHIMMY_PROFILE_ROOT"/.shell-init.sh.tmp.*) ;;
      *) continue ;;
    esac
    [ ! -f "$temporary_path" ] && [ ! -L "$temporary_path" ] || rm -f "$temporary_path"
  done
  SHIMMY_MANIFEST_COMMIT_TMP=
  SHIMMY_MACHINE_PROJECTION_COMMIT_TMP=
  SHIMMY_REGISTRIES_COMMIT_TMP=
  SHIMMY_SHELL_INIT_COMMIT_TMP=
}

profile_commit_backup_cleanup() {
  for relative_path in shell-init.sh registries.conf machine-projection.txt install-manifest.txt bin/shimmy; do
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/$relative_path
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || rm -f "$backup_path"
  done
  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/bin/$tool_name
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || rm -f "$backup_path"
  done <<EOF
$PROFILE_MANIFEST_TOOLS
EOF
  rmdir "$SHIMMY_PROFILE_BACKUP_ROOT/bin" 2>/dev/null || true
  rmdir "$SHIMMY_PROFILE_BACKUP_ROOT" 2>/dev/null || true
}

profile_commit_restore() {
  profile_owned_files_restore
  profile_owned_directories_restore
  profile_commit_backup_cleanup
  SHIMMY_PROFILE_BACKUP_ROOT=
}

profile_dispatcher_stage() {
  tool_name=$1
  ln -s ../commands/dispatch-tool.sh "$SHIMMY_STAGE_ROOT/bin/$tool_name"
}

profile_dispatcher_collision_validate() {
  tool_name=$1
  dispatcher_path=$SHIMMY_BIN_DIR/$tool_name

  [ ! -e "$dispatcher_path" ] && [ ! -L "$dispatcher_path" ] && return 0
  shimmy_contains_line_list "$EXISTING_PROFILE_TOOLS" "$tool_name" || fail "unmanaged dispatcher collision: $dispatcher_path"
}

profile_launcher_collision_validate() {
  launcher_path=$SHIMMY_BIN_DIR/shimmy

  [ ! -e "$launcher_path" ] && [ ! -L "$launcher_path" ] && return 0
  [ "$PROFILE_EXISTS" -eq 1 ] || fail "unmanaged launcher collision: $launcher_path"
  [ -f "$launcher_path" ] && [ ! -L "$launcher_path" ] || fail "installed launcher must be a regular non-symlink file: $launcher_path"
}

profile_shell_init_collision_validate() {
  shell_init_path=$SHIMMY_SHELL_INIT_FILE

  [ ! -e "$shell_init_path" ] && [ ! -L "$shell_init_path" ] && return 0
  [ "$PROFILE_EXISTS" -eq 1 ] || fail "unmanaged shell init collision: $shell_init_path"
  [ -f "$shell_init_path" ] && [ ! -L "$shell_init_path" ] || fail "installed shell init must be a regular non-symlink file: $shell_init_path"
}

profile_owned_directories_restore() {
  for asset_name in agent commands config lib tools tests; do
    target_path=$SHIMMY_PROFILE_ROOT/$asset_name
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/$asset_name
    if shimmy_contains_line_list "$SHIMMY_PROFILE_DIRECTORIES_REPLACED" "$asset_name" &&
      { [ -e "$target_path" ] || [ -L "$target_path" ]; }; then
      if [ -L "$target_path" ]; then rm -f "$target_path"; else rm -rf "$target_path"; fi
    fi
    [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || mv "$backup_path" "$target_path"
  done
  SHIMMY_PROFILE_DIRECTORIES_REPLACED=
}

profile_owned_files_backup() {
  mkdir -p "$SHIMMY_PROFILE_BACKUP_ROOT/bin"
  for relative_path in shell-init.sh registries.conf machine-projection.txt install-manifest.txt bin/shimmy; do
    source_path=$SHIMMY_PROFILE_ROOT/$relative_path
    target_path=$SHIMMY_PROFILE_BACKUP_ROOT/$relative_path
    [ ! -e "$source_path" ] && [ ! -L "$source_path" ] || cp -R "$source_path" "$target_path"
  done
  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    source_path=$SHIMMY_BIN_DIR/$tool_name
    [ ! -e "$source_path" ] && [ ! -L "$source_path" ] || cp -R "$source_path" "$SHIMMY_PROFILE_BACKUP_ROOT/bin/$tool_name"
  done <<EOF
$EXISTING_PROFILE_TOOLS
EOF
}

profile_owned_files_restore() {
  for relative_path in shell-init.sh registries.conf machine-projection.txt install-manifest.txt bin/shimmy; do
    target_path=$SHIMMY_PROFILE_ROOT/$relative_path
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/$relative_path
    if shimmy_contains_line_list "$SHIMMY_PROFILE_FILES_REPLACED" "$relative_path"; then
      [ ! -e "$target_path" ] && [ ! -L "$target_path" ] || rm -f "$target_path"
      [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || mv "$backup_path" "$target_path"
    fi
  done
  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    relative_path=bin/$tool_name
    target_path=$SHIMMY_PROFILE_ROOT/$relative_path
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/bin/$tool_name
    if shimmy_contains_line_list "$SHIMMY_PROFILE_FILES_REPLACED" "$relative_path"; then
      [ ! -e "$target_path" ] && [ ! -L "$target_path" ] || rm -f "$target_path"
      [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ] || mv "$backup_path" "$target_path"
    fi
  done <<EOF
$PROFILE_MANIFEST_TOOLS
EOF
  SHIMMY_PROFILE_FILES_REPLACED=
}

profile_replace_owned_directories() {
  SHIMMY_PROFILE_BACKUP_ROOT=$SHIMMY_PROFILES_ROOT/."$SHIMMY_PROFILE_RESOLVED".backup.$$
  SHIMMY_PROFILE_DIRECTORIES_REPLACED=
  mkdir -p "$SHIMMY_PROFILE_BACKUP_ROOT"
  for asset_name in agent commands config lib tools tests; do
    target_path=$SHIMMY_PROFILE_ROOT/$asset_name
    backup_path=$SHIMMY_PROFILE_BACKUP_ROOT/$asset_name
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
      mv "$target_path" "$backup_path" || { profile_owned_directories_restore; return 1; }
      SHIMMY_PROFILE_DIRECTORIES_REPLACED=$(shimmy_append_line_list "$SHIMMY_PROFILE_DIRECTORIES_REPLACED" "$asset_name")
    fi
  done

  for asset_name in commands config lib tools tests; do
    target_path=$SHIMMY_PROFILE_ROOT/$asset_name
    mv "$SHIMMY_STAGE_ROOT/$asset_name" "$target_path" || { profile_owned_directories_restore; return 1; }
    if ! shimmy_contains_line_list "$SHIMMY_PROFILE_DIRECTORIES_REPLACED" "$asset_name"; then
      SHIMMY_PROFILE_DIRECTORIES_REPLACED=$(shimmy_append_line_list "$SHIMMY_PROFILE_DIRECTORIES_REPLACED" "$asset_name")
    fi
  done
}

profile_merge_bin_commit() {
  mkdir -p "$SHIMMY_BIN_DIR"
  launcher_tmp=$SHIMMY_BIN_DIR/.shimmy.tmp.$$
  cp "$SHIMMY_STAGE_ROOT/bin/shimmy" "$launcher_tmp"
  chmod 755 "$launcher_tmp"
  mv "$launcher_tmp" "$SHIMMY_CONTROL_BIN"
  SHIMMY_PROFILE_FILES_REPLACED=$(shimmy_append_line_list "$SHIMMY_PROFILE_FILES_REPLACED" bin/shimmy)

  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    dispatcher_tmp=$SHIMMY_BIN_DIR/."$tool_name".tmp.$$
    rm -f "$dispatcher_tmp"
    ln -s ../commands/dispatch-tool.sh "$dispatcher_tmp"
    mv "$dispatcher_tmp" "$SHIMMY_BIN_DIR/$tool_name"
    SHIMMY_PROFILE_FILES_REPLACED=$(shimmy_append_line_list "$SHIMMY_PROFILE_FILES_REPLACED" "bin/$tool_name")
  done <<EOF
$PROFILE_MANIFEST_TOOLS
EOF
}

profile_assets_commit() {
  mkdir -p "$SHIMMY_CONFIG_ROOT" "$SHIMMY_PROFILES_ROOT" "$SHIMMY_PROFILE_ROOT"
  profile_replace_owned_directories || fail "unable to replace profile assets; prior profile restored"
  profile_owned_files_backup || { profile_commit_restore; fail "unable to back up owned profile files"; }
  if ! profile_merge_bin_commit; then
    profile_commit_restore
    fail "unable to replace profile bin assets; prior profile directories restored"
  fi

  SHIMMY_SHELL_INIT_COMMIT_TMP=$SHIMMY_PROFILE_ROOT/.shell-init.sh.tmp.$$
  [ ! -e "$SHIMMY_SHELL_INIT_COMMIT_TMP" ] && [ ! -L "$SHIMMY_SHELL_INIT_COMMIT_TMP" ] || fail "shell init temporary path collision: $SHIMMY_SHELL_INIT_COMMIT_TMP"
  cp "$SHIMMY_STAGE_ROOT/shell-init.sh" "$SHIMMY_SHELL_INIT_COMMIT_TMP"
  chmod 644 "$SHIMMY_SHELL_INIT_COMMIT_TMP"
  mv "$SHIMMY_SHELL_INIT_COMMIT_TMP" "$SHIMMY_SHELL_INIT_FILE"
  SHIMMY_PROFILE_FILES_REPLACED=$(shimmy_append_line_list "$SHIMMY_PROFILE_FILES_REPLACED" shell-init.sh)
  SHIMMY_SHELL_INIT_COMMIT_TMP=

  SHIMMY_REGISTRIES_COMMIT_TMP=$SHIMMY_PROFILE_ROOT/.registries.tmp.$$
  [ ! -e "$SHIMMY_REGISTRIES_COMMIT_TMP" ] && [ ! -L "$SHIMMY_REGISTRIES_COMMIT_TMP" ] || fail "registries temporary path collision: $SHIMMY_REGISTRIES_COMMIT_TMP"
  cp "$SHIMMY_STAGE_ROOT/registries.conf" "$SHIMMY_REGISTRIES_COMMIT_TMP"
  chmod 644 "$SHIMMY_REGISTRIES_COMMIT_TMP"
  mv "$SHIMMY_REGISTRIES_COMMIT_TMP" "$SHIMMY_PROFILE_REGISTRIES_PATH"
  SHIMMY_PROFILE_FILES_REPLACED=$(shimmy_append_line_list "$SHIMMY_PROFILE_FILES_REPLACED" registries.conf)
  SHIMMY_REGISTRIES_COMMIT_TMP=

  if [ -f "$SHIMMY_STAGE_ROOT/machine-projection.txt" ] && [ ! -L "$SHIMMY_STAGE_ROOT/machine-projection.txt" ]; then
    SHIMMY_MACHINE_PROJECTION_COMMIT_TMP=$SHIMMY_PROFILE_ROOT/.machine-projection.txt.tmp.$$
    [ ! -e "$SHIMMY_MACHINE_PROJECTION_COMMIT_TMP" ] && [ ! -L "$SHIMMY_MACHINE_PROJECTION_COMMIT_TMP" ] || fail "machine projection temporary path collision: $SHIMMY_MACHINE_PROJECTION_COMMIT_TMP"
    cp "$SHIMMY_STAGE_ROOT/machine-projection.txt" "$SHIMMY_MACHINE_PROJECTION_COMMIT_TMP"
    chmod 644 "$SHIMMY_MACHINE_PROJECTION_COMMIT_TMP"
    mv "$SHIMMY_MACHINE_PROJECTION_COMMIT_TMP" "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
    SHIMMY_PROFILE_FILES_REPLACED=$(shimmy_append_line_list "$SHIMMY_PROFILE_FILES_REPLACED" machine-projection.txt)
    SHIMMY_MACHINE_PROJECTION_COMMIT_TMP=
  fi

  SHIMMY_MANIFEST_COMMIT_TMP=$SHIMMY_PROFILE_ROOT/.install-manifest.txt.tmp.$$
  [ ! -e "$SHIMMY_MANIFEST_COMMIT_TMP" ] && [ ! -L "$SHIMMY_MANIFEST_COMMIT_TMP" ] || fail "manifest temporary path collision: $SHIMMY_MANIFEST_COMMIT_TMP"
  cp "$SHIMMY_STAGE_ROOT/install-manifest.txt" "$SHIMMY_MANIFEST_COMMIT_TMP"
  chmod 644 "$SHIMMY_MANIFEST_COMMIT_TMP"
  mv "$SHIMMY_MANIFEST_COMMIT_TMP" "$INSTALL_MANIFEST_FILE"
  SHIMMY_PROFILE_FILES_REPLACED=$(shimmy_append_line_list "$SHIMMY_PROFILE_FILES_REPLACED" install-manifest.txt)
  SHIMMY_MANIFEST_COMMIT_TMP=
  rm -rf "$SHIMMY_PROFILE_BACKUP_ROOT"
  SHIMMY_PROFILE_BACKUP_ROOT=
  SHIMMY_PROFILE_DIRECTORIES_REPLACED=
  SHIMMY_PROFILE_FILES_REPLACED=
}
