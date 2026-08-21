#!/bin/sh
# Private target profile synchronization and startup repair lifecycle.

SHIMMY_TARGET_PROFILE_SYNC_BACKUP=
SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT=
SHIMMY_TARGET_PROFILE_SYNC_ERROR=

shimmy_target_profile_control_fetch() {
  shimmy_target_profile_control_fetch_config=$1
  shimmy_target_profile_control_fetch_url=$2
  shimmy_scalar_value_validate "$shimmy_target_profile_control_fetch_url" || return 1
  command -v git >/dev/null 2>&1 || return 1
  SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT=$shimmy_target_profile_control_fetch_config/.control-sync.$$
  [ ! -e "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" ] && [ ! -L "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" ] || return 1
  mkdir "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" || return 1
  git -C "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" init -q || return 1
  git -C "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" fetch --no-tags --force -- \
    "$shimmy_target_profile_control_fetch_url" refs/heads/main >/dev/null 2>&1 || return 1
  SHIMMY_TARGET_PROFILE_SYNC_SOURCE_REF=$(git -C "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" \
    rev-parse --verify 'FETCH_HEAD^{commit}' 2>/dev/null) || return 1
  shimmy_git_commit_validate "$SHIMMY_TARGET_PROFILE_SYNC_SOURCE_REF" || return 1
  git -C "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" update-ref refs/heads/main \
    "$SHIMMY_TARGET_PROFILE_SYNC_SOURCE_REF" || return 1
}

shimmy_target_profile_control_ref_revalidate() {
  shimmy_target_profile_control_ref_url=$1
  shimmy_target_profile_control_ref_expected=$2
  shimmy_target_profile_control_ref_line=$(git ls-remote --exit-code --refs -- \
    "$shimmy_target_profile_control_ref_url" refs/heads/main 2>/dev/null) || return 1
  SHIMMY_TARGET_PROFILE_SYNC_REMOTE_REF=${shimmy_target_profile_control_ref_line%%[[:space:]]*}
  [ "$SHIMMY_TARGET_PROFILE_SYNC_REMOTE_REF" = "$shimmy_target_profile_control_ref_expected" ]
}

shimmy_target_profile_startup_repair_run() {
  shimmy_target_profile_startup_repair_config=$1
  shimmy_target_profile_startup_repair_name=$2
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_startup_repair_config" \
    "$shimmy_target_profile_startup_repair_name" || return 1
  shimmy_target_profile_startup_repair_manifest=$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/install-manifest.txt
  shimmy_target_profile_startup_repair_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_target_profile_startup_repair_manifest") || return 1
  shimmy_target_profile_startup_repair_files=$SHIMMY_TARGET_PROFILE_CANDIDATE_STARTUP_FILES
  shimmy_target_profile_startup_repair_shell_init=$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/shell-init.sh
  if [ -z "$shimmy_target_profile_startup_repair_files" ]; then
    printf '%s\n' 'INFO: profile has no managed startup files to repair' >&2
    return 0
  fi
  shimmy_target_lock_acquire profile "$shimmy_target_profile_startup_repair_config" \
    "$shimmy_target_profile_startup_repair_name" || return 1
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_startup_repair_config" \
    "$shimmy_target_profile_startup_repair_name" || return 1
  [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/install-manifest.txt")" = \
    "$shimmy_target_profile_startup_repair_fingerprint" ] || return 1
  shimmy_target_external_transaction_begin || return 1
  if ! shimmy_target_startup_apply "$shimmy_target_profile_startup_repair_config" \
    "$shimmy_target_profile_startup_repair_files" "$shimmy_target_profile_startup_repair_shell_init"; then
    shimmy_target_external_transaction_rollback 'target startup repair failed' || true
    return 1
  fi
  shimmy_target_external_transaction_commit || return 1
  shimmy_target_profile_startup_backup_cleanup || return 1
  shimmy_target_locks_release_all || return 1
  while IFS= read -r shimmy_target_profile_startup_repair_file; do
    [ -n "$shimmy_target_profile_startup_repair_file" ] || continue
    printf 'Repaired startup file: %s\n' "$shimmy_target_profile_startup_repair_file"
  done <<EOF
$shimmy_target_profile_startup_repair_files
EOF
}

shimmy_target_profile_sync_assets_restore() {
  [ -n "$SHIMMY_TARGET_PROFILE_SYNC_BACKUP" ] || return 0
  for shimmy_target_profile_sync_restore_entry in ai-skills bin commands config lib tests tools shell-init.sh install-manifest.txt; do
    shimmy_target_profile_sync_restore_target=$SHIMMY_TARGET_PROFILE_SYNC_PROFILE_ROOT/$shimmy_target_profile_sync_restore_entry
    shimmy_target_profile_sync_restore_backup=$SHIMMY_TARGET_PROFILE_SYNC_BACKUP/$shimmy_target_profile_sync_restore_entry
    if [ -e "$shimmy_target_profile_sync_restore_target" ] || [ -L "$shimmy_target_profile_sync_restore_target" ]; then
      if [ -d "$shimmy_target_profile_sync_restore_target" ] && [ ! -L "$shimmy_target_profile_sync_restore_target" ]; then
        rm -rf "$shimmy_target_profile_sync_restore_target"
      else
        rm -f "$shimmy_target_profile_sync_restore_target"
      fi
    fi
    if [ -e "$shimmy_target_profile_sync_restore_backup" ] || [ -L "$shimmy_target_profile_sync_restore_backup" ]; then
      mv "$shimmy_target_profile_sync_restore_backup" "$shimmy_target_profile_sync_restore_target" || return 1
    fi
  done
  rm -rf "$SHIMMY_TARGET_PROFILE_SYNC_BACKUP"
  SHIMMY_TARGET_PROFILE_SYNC_BACKUP=
}

shimmy_target_profile_sync_candidate_commit() {
  shimmy_target_profile_sync_candidate=$1
  SHIMMY_TARGET_PROFILE_SYNC_BACKUP=$SHIMMY_TARGET_PROFILE_SYNC_PROFILE_ROOT/.sync-backup.$$
  [ ! -e "$SHIMMY_TARGET_PROFILE_SYNC_BACKUP" ] && [ ! -L "$SHIMMY_TARGET_PROFILE_SYNC_BACKUP" ] || return 1
  mkdir "$SHIMMY_TARGET_PROFILE_SYNC_BACKUP" || return 1
  for shimmy_target_profile_sync_commit_entry in ai-skills bin commands config lib tests tools shell-init.sh install-manifest.txt; do
    shimmy_target_profile_sync_commit_current=$SHIMMY_TARGET_PROFILE_SYNC_PROFILE_ROOT/$shimmy_target_profile_sync_commit_entry
    shimmy_target_profile_sync_commit_backup=$SHIMMY_TARGET_PROFILE_SYNC_BACKUP/$shimmy_target_profile_sync_commit_entry
    mv "$shimmy_target_profile_sync_commit_current" "$shimmy_target_profile_sync_commit_backup" || {
      shimmy_target_profile_sync_assets_restore
      return 1
    }
  done
  for shimmy_target_profile_sync_commit_entry in ai-skills bin commands config lib tests tools shell-init.sh; do
    mv "$shimmy_target_profile_sync_candidate/$shimmy_target_profile_sync_commit_entry" \
      "$SHIMMY_TARGET_PROFILE_SYNC_PROFILE_ROOT/$shimmy_target_profile_sync_commit_entry" || {
      shimmy_target_profile_sync_assets_restore
      return 1
    }
  done
  mv "$shimmy_target_profile_sync_candidate/install-manifest.txt" \
    "$SHIMMY_TARGET_PROFILE_SYNC_PROFILE_ROOT/install-manifest.txt" || {
    shimmy_target_profile_sync_assets_restore
    return 1
  }
}

shimmy_target_profile_sync_cleanup() {
  if [ "${SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE:-0}" -eq 1 ]; then
    shimmy_target_external_transaction_rollback 'target profile sync interruption' 2>/dev/null || true
  fi
  shimmy_target_profile_sync_assets_restore 2>/dev/null || true
  shimmy_target_profile_candidate_stage_cleanup 2>/dev/null || true
  if [ -n "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" ]; then
    case "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" in
      "$SHIMMY_TARGET_CONFIG_ROOT"/.control-sync.*)
        [ ! -e "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" ] || rm -rf "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT"
        ;;
    esac
    SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT=
  fi
  shimmy_target_profile_startup_backup_cleanup 2>/dev/null || true
  shimmy_target_locks_release_all 2>/dev/null || true
}

shimmy_target_profile_sync_records_resolve() {
  shimmy_target_profile_sync_records_catalog=$1
  shimmy_target_profile_sync_records_shims=$2
  shimmy_target_profile_sync_records_versions=$3
  SHIMMY_TARGET_PROFILE_SYNC_SHIMS=$(shimmy_target_shim_sorted "$shimmy_target_profile_sync_records_shims") || return 1
  SHIMMY_TARGET_PROFILE_SYNC_VERSIONS=$shimmy_target_profile_sync_records_versions
  while IFS= read -r shimmy_target_profile_sync_records_shim; do
    [ -n "$shimmy_target_profile_sync_records_shim" ] || continue
    shimmy_target_shim_record_validate "$shimmy_target_profile_sync_records_shim" || return 1
    shimmy_target_profile_sync_records_tool=$shimmy_target_shim_record_tool
    shimmy_target_profile_sync_records_mode=$shimmy_target_shim_record_mode
    SHIMMY_TARGET_SHIM_VERSION_RECORDS=$SHIMMY_TARGET_PROFILE_SYNC_VERSIONS
    shimmy_target_profile_sync_records_old_default=$(shimmy_target_shim_default_read \
      "$shimmy_target_profile_sync_records_tool") || return 1
    if [ "$shimmy_target_profile_sync_records_mode" = tracking ]; then
      shimmy_target_profile_sync_records_tool_file=$shimmy_target_profile_sync_records_catalog/tools/$shimmy_target_profile_sync_records_tool/tool.conf
      shimmy_target_profile_sync_records_new_default=$(shimmy__catalog_config_value_read \
        "$shimmy_target_profile_sync_records_tool_file" tool_default_version) || return 1
      SHIMMY_TARGET_PROFILE_SYNC_VERSIONS=$(shimmy_target_shim_record_without_version \
        "$SHIMMY_TARGET_PROFILE_SYNC_VERSIONS" "$shimmy_target_profile_sync_records_tool" \
        "$shimmy_target_profile_sync_records_old_default")
      SHIMMY_TARGET_PROFILE_SYNC_VERSIONS=$(shimmy_target_shim_record_without_version \
        "$SHIMMY_TARGET_PROFILE_SYNC_VERSIONS" "$shimmy_target_profile_sync_records_tool" \
        "$shimmy_target_profile_sync_records_new_default")
      SHIMMY_TARGET_PROFILE_SYNC_VERSIONS=$(shimmy_append_line_list \
        "$SHIMMY_TARGET_PROFILE_SYNC_VERSIONS" \
        "$shimmy_target_profile_sync_records_tool|$shimmy_target_profile_sync_records_new_default|default")
    fi
  done <<EOF
$SHIMMY_TARGET_PROFILE_SYNC_SHIMS
EOF
  SHIMMY_TARGET_PROFILE_SYNC_VERSIONS=$(shimmy_target_shim_sorted "$SHIMMY_TARGET_PROFILE_SYNC_VERSIONS")
  shimmy_target_shim_records_validate "$SHIMMY_TARGET_PROFILE_SYNC_SHIMS" \
    "$SHIMMY_TARGET_PROFILE_SYNC_VERSIONS" || return 1
  SHIMMY_TARGET_PROFILE_SYNC_PAIRS=
  while IFS= read -r shimmy_target_profile_sync_records_version; do
    [ -n "$shimmy_target_profile_sync_records_version" ] || continue
    shimmy_target_shim_version_record_validate "$shimmy_target_profile_sync_records_version" || return 1
    shimmy_target_shim_catalog_version_validate "$shimmy_target_shim_version_tool" \
      "$shimmy_target_shim_version_name" || return 1
    SHIMMY_TARGET_PROFILE_SYNC_PAIRS=$(shimmy_append_line_list "$SHIMMY_TARGET_PROFILE_SYNC_PAIRS" \
      "$shimmy_target_shim_version_tool|$shimmy_target_shim_version_name")
  done <<EOF
$SHIMMY_TARGET_PROFILE_SYNC_VERSIONS
EOF
  SHIMMY_TARGET_PROFILE_SYNC_PAIRS=$(shimmy_target_shim_sorted "$SHIMMY_TARGET_PROFILE_SYNC_PAIRS")
}

shimmy_target_profile_sync_run() {
  shimmy_target_profile_sync_config=$1
  shimmy_target_profile_sync_name=$2
  SHIMMY_TARGET_PROFILE_SYNC_ERROR=
  shimmy_target_profile_installation_context_resolve "$shimmy_target_profile_sync_config" || return 1
  [ "$SHIMMY_TARGET_PROFILE_ACTIVE_NAME" = "$shimmy_target_profile_sync_name" ] || {
    SHIMMY_TARGET_PROFILE_SYNC_ERROR="profile sync requires the active invoking profile: $shimmy_target_profile_sync_name"
    return 1
  }
  shimmy_target_profile_active_engine_validate "$shimmy_target_profile_sync_config" \
    "$shimmy_target_profile_sync_name" || return 1
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_sync_config" \
    "$shimmy_target_profile_sync_name" || return 1
  SHIMMY_TARGET_PROFILE_SYNC_PROFILE_ROOT=$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT
  shimmy_target_profile_sync_source_url=$SHIMMY_TARGET_PROFILE_CANDIDATE_SOURCE_URL
  shimmy_target_profile_sync_prior_source_ref=$SHIMMY_TARGET_PROFILE_CANDIDATE_SOURCE_REF
  shimmy_target_profile_sync_prior_manifest_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$SHIMMY_TARGET_PROFILE_SYNC_PROFILE_ROOT/install-manifest.txt") || return 1
  shimmy_target_profile_sync_shims=$SHIMMY_TARGET_PROFILE_CANDIDATE_SHIMS
  shimmy_target_profile_sync_versions=$SHIMMY_TARGET_PROFILE_CANDIDATE_VERSIONS
  shimmy_target_profile_sync_startup_shell=$SHIMMY_TARGET_PROFILE_CANDIDATE_STARTUP_SHELL
  shimmy_target_profile_sync_startup_files=$SHIMMY_TARGET_PROFILE_CANDIDATE_STARTUP_FILES
  shimmy_target_profile_sync_registry_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH") || return 1
  shimmy_target_profile_sync_registry_config_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$SHIMMY_TARGET_PROFILE_SYNC_PROFILE_ROOT/registries.conf") || return 1
  shimmy_target_profile_sync_generation=$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT
  shimmy_target_profile_sync_catalog_commit=$SHIMMY_TARGET_CATALOG_SOURCE_COMMIT
  shimmy_target_profile_sync_catalog_fingerprint=$SHIMMY_TARGET_CATALOG_CONTENT_FINGERPRINT
  shimmy_target_profile_sync_catalog_root=$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$shimmy_target_profile_sync_generation
  shimmy_target_profile_sync_catalog_record=default\|$shimmy_target_profile_sync_generation\|$shimmy_target_profile_sync_catalog_commit\|$shimmy_target_profile_sync_catalog_fingerprint
  shimmy_target_profile_control_fetch "$shimmy_target_profile_sync_config" \
    "$shimmy_target_profile_sync_source_url" || return 1
  shimmy_target_profile_sync_source_ref=$SHIMMY_TARGET_PROFILE_SYNC_SOURCE_REF
  SHIMMY_TARGET_SHIM_CATALOG_ROOT=$shimmy_target_profile_sync_catalog_root
  shimmy_target_profile_sync_records_resolve "$shimmy_target_profile_sync_catalog_root" \
    "$shimmy_target_profile_sync_shims" "$shimmy_target_profile_sync_versions" || return 1
  shimmy_target_profile_materialization_prepare "$shimmy_target_profile_sync_config" \
    "$shimmy_target_profile_sync_name" git "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT" \
    "$shimmy_target_profile_sync_source_url" "$shimmy_target_profile_sync_source_ref" \
    "$shimmy_target_profile_sync_catalog_record" "$SHIMMY_TARGET_PROFILE_SYNC_SHIMS" \
    "$SHIMMY_TARGET_PROFILE_SYNC_VERSIONS" "$shimmy_target_profile_sync_startup_shell" \
    "$shimmy_target_profile_sync_startup_files" \
    "$SHIMMY_TARGET_PROFILE_SYNC_PROFILE_ROOT/registries.conf" || return 1
  shimmy_target_profile_images_prepare "$SHIMMY_TARGET_PROFILE_CANDIDATE_STAGE" \
    "$SHIMMY_TARGET_PROFILE_SYNC_PAIRS" || return 1
  shimmy_target_profile_control_ref_revalidate "$shimmy_target_profile_sync_source_url" \
    "$shimmy_target_profile_sync_source_ref" || {
    SHIMMY_TARGET_PROFILE_SYNC_ERROR='refs/heads/main changed during target profile staging'
    return 1
  }

  shimmy_target_lock_acquire catalog "$shimmy_target_profile_sync_config" || return 1
  shimmy_target_lock_acquire activation "$shimmy_target_profile_sync_config" || return 1
  shimmy_target_lock_acquire profile "$shimmy_target_profile_sync_config" \
    "$shimmy_target_profile_sync_name" || return 1
  shimmy_target_lock_acquire registry "$shimmy_target_profile_sync_config" \
    "$shimmy_target_profile_sync_name" || return 1
  shimmy_target_profile_installation_context_resolve "$shimmy_target_profile_sync_config" || return 1
  [ "$SHIMMY_TARGET_PROFILE_ACTIVE_NAME" = "$shimmy_target_profile_sync_name" ] || return 1
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_sync_config" \
    "$shimmy_target_profile_sync_name" || return 1
  [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/install-manifest.txt")" = \
    "$shimmy_target_profile_sync_prior_manifest_fingerprint" ] &&
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH")" = \
      "$shimmy_target_profile_sync_registry_fingerprint" ] &&
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/registries.conf")" = \
      "$shimmy_target_profile_sync_registry_config_fingerprint" ] &&
    [ "$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT" = "$shimmy_target_profile_sync_generation" ] || return 1
  shimmy_target_profile_sync_candidate_commit "$SHIMMY_TARGET_PROFILE_CANDIDATE_STAGE" || return 1
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_sync_config" \
    "$shimmy_target_profile_sync_name" || {
    shimmy_target_profile_sync_assets_restore
    return 1
  }
  shimmy_target_profile_ai_skill_prepare "$shimmy_target_profile_sync_config" \
    "$shimmy_target_profile_sync_name" "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT" \
    "$SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION_ROOT" || {
    shimmy_target_profile_sync_assets_restore
    return 1
  }
  shimmy_target_external_transaction_begin || {
    shimmy_target_profile_sync_assets_restore
    return 1
  }
  if ! shimmy_target_ai_skill_reconcile_apply; then
    shimmy_target_external_transaction_rollback 'target profile sync link reconciliation failed' || true
    shimmy_target_profile_sync_assets_restore
    return 1
  fi
  shimmy_target_external_transaction_commit || return 1
  rm -rf "$SHIMMY_TARGET_PROFILE_SYNC_BACKUP"
  SHIMMY_TARGET_PROFILE_SYNC_BACKUP=
  shimmy_target_profile_candidate_stage_cleanup || return 1
  rm -rf "$SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT"
  SHIMMY_TARGET_PROFILE_SYNC_CHECKOUT=
  shimmy_target_locks_release_all || return 1
  printf 'Synchronized active Shimmy profile %s from %s to %s and catalog %s.\n' \
    "$shimmy_target_profile_sync_name" "$shimmy_target_profile_sync_prior_source_ref" \
    "$shimmy_target_profile_sync_source_ref" "$shimmy_target_profile_sync_generation"
}
