#!/bin/sh
# Published engine registry, compatibility state, and explicit migration.

SHIMMY_ENGINE_REGISTRY_MIGRATION_ACTIVE=0
SHIMMY_ENGINE_REGISTRY_MIGRATION_LOCKS_HELD=0
SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE=0
SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE=0

shimmy_engine_registry_migration_locks_acquire() {
  shimmy_engine_registry_migration_locks_config=$1
  shimmy_engine_registry_migration_locks_profiles=$2
  shimmy_engine_registry_migration_locks_active=$3
  shimmy_lock_acquire activation "$shimmy_engine_registry_migration_locks_config" || return 1
  while IFS= read -r shimmy_engine_registry_migration_locks_profile; do
    [ -n "$shimmy_engine_registry_migration_locks_profile" ] || continue
    shimmy_lock_acquire profile "$shimmy_engine_registry_migration_locks_config" \
      "$shimmy_engine_registry_migration_locks_profile" || return 1
  done <<EOF
$shimmy_engine_registry_migration_locks_profiles
EOF
  shimmy_lock_acquire registry "$shimmy_engine_registry_migration_locks_config" \
    "$shimmy_engine_registry_migration_locks_active" || return 1
  SHIMMY_ENGINE_REGISTRY_MIGRATION_LOCKS_HELD=1
}

shimmy_engine_registry_migration_journal_read() {
  shimmy_engine_registry_migration_journal_config=$1
  SHIMMY_ENGINE_REGISTRY_MIGRATION_JOURNAL_PATH=$shimmy_engine_registry_migration_journal_config/.engine-migration.conf
  shimmy_engine_state_file_validate "$SHIMMY_ENGINE_REGISTRY_MIGRATION_JOURNAL_PATH" || return 1
  [ "$(sed -n '1p' "$SHIMMY_ENGINE_REGISTRY_MIGRATION_JOURNAL_PATH")" = \
    shimmy_engine_migration_version=1 ] || return 1
  SHIMMY_ENGINE_REGISTRY_MIGRATION_JOURNAL_HOST_OS=$(sed -n '2s/^host_os=//p' \
    "$SHIMMY_ENGINE_REGISTRY_MIGRATION_JOURNAL_PATH") || return 1
  case "$SHIMMY_ENGINE_REGISTRY_MIGRATION_JOURNAL_HOST_OS" in darwin|linux) ;; *) return 1 ;; esac
  [ -z "$(sed -n '/^profile=/!{1,2!p;}' "$SHIMMY_ENGINE_REGISTRY_MIGRATION_JOURNAL_PATH")" ] || return 1
  SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES=$(sed -n 's/^profile=//p' \
    "$SHIMMY_ENGINE_REGISTRY_MIGRATION_JOURNAL_PATH") || return 1
  [ -n "$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES" ] || return 1
  while IFS= read -r shimmy_engine_registry_migration_journal_profile; do
    shimmy_name_component_validate "$shimmy_engine_registry_migration_journal_profile" || return 1
  done <<EOF
$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES
EOF
  [ "$(printf '%s\n' "$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES" | LC_ALL=C sort -u)" = \
    "$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES" ]
}

shimmy_engine_registry_migration_journal_write() {
  shimmy_engine_registry_migration_journal_config=$1
  shimmy_engine_registry_migration_journal_profiles=$2
  case "${SHIMMY_ENGINE_REGISTRY_HOST_OS:-}" in darwin|linux) ;; *) return 1 ;; esac
  shimmy_engine_registry_migration_journal_path=$shimmy_engine_registry_migration_journal_config/.engine-migration.conf
  shimmy_engine_registry_migration_journal_stage=$shimmy_engine_registry_migration_journal_config/.engine-migration.tmp.$$
  [ ! -e "$shimmy_engine_registry_migration_journal_path" ] &&
    [ ! -L "$shimmy_engine_registry_migration_journal_path" ] &&
    [ ! -e "$shimmy_engine_registry_migration_journal_stage" ] &&
    [ ! -L "$shimmy_engine_registry_migration_journal_stage" ] || return 1
  {
    printf '%s\n' shimmy_engine_migration_version=1
    printf 'host_os=%s\n' "$SHIMMY_ENGINE_REGISTRY_HOST_OS"
    while IFS= read -r shimmy_engine_registry_migration_journal_profile; do
      [ -n "$shimmy_engine_registry_migration_journal_profile" ] || continue
      shimmy_name_component_validate "$shimmy_engine_registry_migration_journal_profile" || return 1
      printf 'profile=%s\n' "$shimmy_engine_registry_migration_journal_profile"
    done <<EOF
$shimmy_engine_registry_migration_journal_profiles
EOF
  } > "$shimmy_engine_registry_migration_journal_stage" || {
    rm -f "$shimmy_engine_registry_migration_journal_stage"
    return 1
  }
  chmod 0644 "$shimmy_engine_registry_migration_journal_stage" || {
    rm -f "$shimmy_engine_registry_migration_journal_stage"
    return 1
  }
  mv "$shimmy_engine_registry_migration_journal_stage" \
    "$shimmy_engine_registry_migration_journal_path"
}

shimmy_engine_registry_migration_rollback() {
  [ "${SHIMMY_ENGINE_REGISTRY_MIGRATION_ACTIVE:-0}" -eq 1 ] || return 0
  shimmy_engine_registry_migration_rollback_complete=1
  if [ "${SHIMMY_ENGINE_REGISTRY_HOST_OS:-}" = darwin ] &&
    { [ "${SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE:-0}" -eq 1 ] ||
      [ -e "$SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG/engines/shared/lifecycle.conf" ]; }; then
    shimmy_engine_registry_shared_create_rollback \
      "$SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG" ||
      shimmy_engine_registry_migration_rollback_complete=0
  fi
  while IFS= read -r shimmy_engine_registry_migration_rollback_profile; do
    [ -n "$shimmy_engine_registry_migration_rollback_profile" ] || continue
    rm -f "$SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG/profiles/$shimmy_engine_registry_migration_rollback_profile/engine-binding.conf" ||
      shimmy_engine_registry_migration_rollback_complete=0
    rm -rf "$SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG/engines/profile-$shimmy_engine_registry_migration_rollback_profile" ||
      shimmy_engine_registry_migration_rollback_complete=0
  done <<EOF
${SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES:-}
EOF
  if [ "${SHIMMY_ENGINE_REGISTRY_HOST_OS:-}" = linux ]; then
    rm -rf "$SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG/engines/shared" ||
      shimmy_engine_registry_migration_rollback_complete=0
  fi
  if [ "$shimmy_engine_registry_migration_rollback_complete" -eq 1 ]; then
    rmdir "$SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG/engines/shared" 2>/dev/null || true
    rmdir "$SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG/engines" 2>/dev/null || true
    rm -f "$SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG/.engine-migration.conf" || return 1
    SHIMMY_ENGINE_REGISTRY_MIGRATION_ACTIVE=0
  fi
  [ "$shimmy_engine_registry_migration_rollback_complete" -eq 1 ]
}

shimmy_engine_registry_host_os_resolve() {
  if [ "${SHIMMY_TEST_PROFILE_OS+x}" = x ]; then
    shimmy_engine_registry_os=$SHIMMY_TEST_PROFILE_OS
  else
    shimmy_engine_registry_os=$(uname -s 2>/dev/null) || shimmy_engine_registry_os=
  fi
  case "$shimmy_engine_registry_os" in
    Darwin|darwin) SHIMMY_ENGINE_REGISTRY_HOST_OS=darwin ;;
    Linux|linux) SHIMMY_ENGINE_REGISTRY_HOST_OS=linux ;;
    *) SHIMMY_ENGINE_REGISTRY_HOST_OS=unsupported ;;
  esac
}

shimmy_engine_registry_profile_names_render() {
  shimmy_engine_registry_profiles=$1
  [ -d "$shimmy_engine_registry_profiles" ] &&
    [ ! -L "$shimmy_engine_registry_profiles" ] || return 1
  for shimmy_engine_registry_profile_root in "$shimmy_engine_registry_profiles"/*; do
    [ -e "$shimmy_engine_registry_profile_root" ] ||
      [ -L "$shimmy_engine_registry_profile_root" ] || continue
    shimmy_engine_registry_profile=$(basename -- "$shimmy_engine_registry_profile_root")
    shimmy_name_component_validate "$shimmy_engine_registry_profile" &&
      [ -d "$shimmy_engine_registry_profile_root" ] &&
      [ ! -L "$shimmy_engine_registry_profile_root" ] || return 1
    printf '%s\n' "$shimmy_engine_registry_profile"
  done | LC_ALL=C sort
}

shimmy_engine_registry_linux_shared_publish() {
  shimmy_engine_registry_linux_config=$1
  shimmy_engine_registry_linux_profile=$2
  shimmy_engine_paths_resolve "$shimmy_engine_registry_linux_config" shared || return 1
  mkdir -p "$SHIMMY_ENGINE_ROOT" || return 1
  [ -d "$SHIMMY_ENGINE_ROOT" ] && [ ! -L "$SHIMMY_ENGINE_ROOT" ] || return 1
  if [ ! -e "$SHIMMY_ENGINE_RECORD_PATH" ] && [ ! -L "$SHIMMY_ENGINE_RECORD_PATH" ]; then
    shimmy_engine_record_write "$SHIMMY_ENGINE_RECORD_PATH" shared linux-rootless \
      installation local local none host-local '' '' || return 1
  else
    shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
    [ "$SHIMMY_ENGINE_RECORD_ID|$SHIMMY_ENGINE_RECORD_KIND|$SHIMMY_ENGINE_RECORD_ORIGIN" = \
      'shared|linux-rootless|host-local' ] || return 1
  fi
  shimmy_engine_binding_write \
    "$shimmy_engine_registry_linux_config/profiles/$shimmy_engine_registry_linux_profile/engine-binding.conf" \
    "$shimmy_engine_registry_linux_profile" shared shared
}

shimmy_engine_registry_shared_create_prepare() {
  shimmy_engine_registry_shared_config=$1
  shimmy_engine_registry_shared_profile=$2
  shimmy_engine_registry_shared_name=$3
  shimmy_name_component_validate "$shimmy_engine_registry_shared_name" || return 1
  SHIMMY_ENGINE_REGISTRY_SHARED_CONFIG=$shimmy_engine_registry_shared_config
  SHIMMY_ENGINE_REGISTRY_SHARED_NAME=$shimmy_engine_registry_shared_name
  shimmy_engine_paths_resolve "$shimmy_engine_registry_shared_config" shared || return 1
  mkdir -p "$SHIMMY_ENGINE_ROOT" || return 1
  [ -d "$SHIMMY_ENGINE_ROOT" ] && [ ! -L "$SHIMMY_ENGINE_ROOT" ] || return 1
  shimmy_engine_podman_bin_require || return 1
  shimmy_engine_machine_create_prepare shared "$shimmy_engine_registry_shared_name" \
    "$shimmy_engine_registry_shared_name" "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE=1
  shimmy_engine_machine_create_initialize "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_machine_create_record "$SHIMMY_ENGINE_LIFECYCLE_PATH" \
    "$SHIMMY_ENGINE_RECORD_PATH" installation || return 1
  shimmy_engine_projection_prepare shared "$SHIMMY_ENGINE_ROOT" \
    "$shimmy_engine_registry_shared_profile" \
    "$shimmy_engine_registry_shared_config/profiles/$shimmy_engine_registry_shared_profile/registries.conf" \
    "$shimmy_engine_registry_shared_name" || return 1
  shimmy_engine_machine_create_start "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_podman_projection_dropin_install "$shimmy_engine_registry_shared_name" \
    "$SHIMMY_ENGINE_REGISTRIES_PATH" || return 1
  shimmy_engine_machine_create_guest_mark "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_projection_apply "$shimmy_engine_registry_shared_name" || return 1
  shimmy_engine_projection_commit || return 1
}

shimmy_engine_registry_shared_create_commit() {
  [ "${SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE:-0}" -eq 1 ] || return 1
  shimmy_engine_paths_resolve "$SHIMMY_ENGINE_REGISTRY_SHARED_CONFIG" shared || return 1
  if [ "${SHIMMY_ENGINE_PROJECTION_APPLIED:-0}" -eq 1 ]; then
    shimmy_engine_projection_commit || return 1
  fi
  shimmy_engine_machine_create_commit "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE=0
}

shimmy_engine_registry_shared_create_rollback() {
  shimmy_engine_registry_shared_rollback_config=$1
  shimmy_engine_paths_resolve "$shimmy_engine_registry_shared_rollback_config" shared || return 1
  shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_registry_shared_rollback_name=$SHIMMY_ENGINE_LIFECYCLE_NAME
  shimmy_engine_projection_rollback \
    "$shimmy_engine_registry_shared_rollback_name" >/dev/null 2>&1 || true
  shimmy_engine_podman_projection_dropin_remove \
    "$shimmy_engine_registry_shared_rollback_name" \
    "$SHIMMY_ENGINE_REGISTRIES_PATH" >/dev/null 2>&1 || true
  shimmy_engine_machine_create_rollback "$SHIMMY_ENGINE_RECORD_PATH" \
    "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  rm -f "$SHIMMY_ENGINE_REGISTRIES_PATH" "$SHIMMY_ENGINE_PROJECTION_PATH" || return 1
  rmdir "$SHIMMY_ENGINE_ROOT" 2>/dev/null || true
  rmdir "$SHIMMY_ENGINES_ROOT" 2>/dev/null || true
  SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE=0
}

shimmy_engine_registry_isolated_preflight() {
  shimmy_engine_registry_isolated_preflight_config=$1
  shimmy_engine_registry_isolated_preflight_profile=$2
  shimmy_name_component_validate "$shimmy_engine_registry_isolated_preflight_profile" || return 1
  shimmy_engine_registry_host_os_resolve
  [ "$SHIMMY_ENGINE_REGISTRY_HOST_OS" = darwin ] || {
    printf '%s\n' 'ERROR: isolated profiles require a managed macOS Podman machine' >&2
    return 1
  }
  shimmy_engine_registry_isolated_preflight_id=profile-$shimmy_engine_registry_isolated_preflight_profile
  shimmy_engine_registry_isolated_preflight_name=shimmy-$shimmy_engine_registry_isolated_preflight_profile
  shimmy_engine_paths_resolve "$shimmy_engine_registry_isolated_preflight_config" \
    "$shimmy_engine_registry_isolated_preflight_id" || return 1
  [ ! -e "$SHIMMY_ENGINE_ROOT" ] && [ ! -L "$SHIMMY_ENGINE_ROOT" ] || {
    printf 'ERROR: isolated engine state already exists: %s\n' "$SHIMMY_ENGINE_ROOT" >&2
    return 1
  }
  shimmy_engine_podman_bin_require || return 1
  shimmy_engine_podman_machine_absence_validate \
    "$shimmy_engine_registry_isolated_preflight_name" \
    "$shimmy_engine_registry_isolated_preflight_name" || {
    printf 'ERROR: Podman machine or connection name collision: %s; Shimmy will not adopt it\n' \
      "$shimmy_engine_registry_isolated_preflight_name" >&2
    return 1
  }
}

shimmy_engine_registry_isolated_create_prepare() {
  shimmy_engine_registry_isolated_config=$1
  shimmy_engine_registry_isolated_profile=$2
  shimmy_engine_registry_isolated_preflight \
    "$shimmy_engine_registry_isolated_config" \
    "$shimmy_engine_registry_isolated_profile" || return 1
  SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG=$shimmy_engine_registry_isolated_config
  SHIMMY_ENGINE_REGISTRY_ISOLATED_PROFILE=$shimmy_engine_registry_isolated_profile
  SHIMMY_ENGINE_REGISTRY_ISOLATED_ID=profile-$shimmy_engine_registry_isolated_profile
  SHIMMY_ENGINE_REGISTRY_ISOLATED_NAME=shimmy-$shimmy_engine_registry_isolated_profile
  shimmy_engine_paths_resolve "$SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_ID" || return 1
  mkdir -p "$SHIMMY_ENGINE_ROOT" || return 1
  [ -d "$SHIMMY_ENGINE_ROOT" ] && [ ! -L "$SHIMMY_ENGINE_ROOT" ] || return 1
  if ! shimmy_engine_machine_create_prepare "$SHIMMY_ENGINE_REGISTRY_ISOLATED_ID" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_NAME" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_NAME" \
    "$SHIMMY_ENGINE_LIFECYCLE_PATH"; then
    rmdir "$SHIMMY_ENGINE_ROOT" 2>/dev/null || true
    return 1
  fi
  SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE=1
  shimmy_engine_machine_create_initialize "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_machine_create_record "$SHIMMY_ENGINE_LIFECYCLE_PATH" \
    "$SHIMMY_ENGINE_RECORD_PATH" profile || return 1
  shimmy_engine_projection_prepare "$SHIMMY_ENGINE_REGISTRY_ISOLATED_ID" \
    "$SHIMMY_ENGINE_ROOT" "$SHIMMY_ENGINE_REGISTRY_ISOLATED_PROFILE" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG/profiles/$SHIMMY_ENGINE_REGISTRY_ISOLATED_PROFILE/registries.conf" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_NAME"
}

shimmy_engine_registry_isolated_create_commit() {
  [ "${SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE:-0}" -eq 1 ] || return 1
  shimmy_engine_paths_resolve "$SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_ID" || return 1
  if [ "${SHIMMY_ENGINE_PROJECTION_APPLIED:-0}" -eq 1 ]; then
    shimmy_engine_projection_commit || return 1
  fi
  shimmy_engine_machine_create_commit "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE=0
}

shimmy_engine_registry_isolated_create_rollback() {
  shimmy_engine_registry_isolated_rollback_config=$1
  shimmy_engine_registry_isolated_rollback_profile=$2
  shimmy_engine_registry_isolated_rollback_id=profile-$shimmy_engine_registry_isolated_rollback_profile
  shimmy_engine_registry_isolated_rollback_name=shimmy-$shimmy_engine_registry_isolated_rollback_profile
  shimmy_engine_paths_resolve "$shimmy_engine_registry_isolated_rollback_config" \
    "$shimmy_engine_registry_isolated_rollback_id" || return 1
  shimmy_engine_projection_rollback \
    "$shimmy_engine_registry_isolated_rollback_name" >/dev/null 2>&1 || true
  shimmy_engine_podman_projection_dropin_remove \
    "$shimmy_engine_registry_isolated_rollback_name" \
    "$SHIMMY_ENGINE_REGISTRIES_PATH" >/dev/null 2>&1 || true
  shimmy_engine_machine_create_rollback "$SHIMMY_ENGINE_RECORD_PATH" \
    "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  rm -f "$SHIMMY_ENGINE_REGISTRIES_PATH" "$SHIMMY_ENGINE_PROJECTION_PATH" || return 1
  rmdir "$SHIMMY_ENGINE_ROOT" 2>/dev/null || true
  SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE=0
}

shimmy_engine_registry_legacy_record_publish() {
  shimmy_engine_registry_legacy_config=$1
  shimmy_engine_registry_legacy_profile=$2
  shimmy_engine_registry_legacy_machine=shimmy-$shimmy_engine_registry_legacy_profile
  shimmy_engine_podman_machine_state_read "$shimmy_engine_registry_legacy_machine" || return 1
  case "$SHIMMY_ENGINE_MACHINE_STATE" in running|stopped) ;; *) return 1 ;; esac
  shimmy_engine_registry_legacy_provider=$SHIMMY_ENGINE_MACHINE_PROVIDER
  shimmy_engine_podman_connection_state_read "$shimmy_engine_registry_legacy_machine" || return 1
  [ "$SHIMMY_ENGINE_CONNECTION_STATE" = rootless ] || return 1
  shimmy_engine_registry_legacy_identity=$(shimmy_engine_podman_machine_identity_fingerprint_render \
    "$shimmy_engine_registry_legacy_machine" "$shimmy_engine_registry_legacy_machine") || return 1
  shimmy_engine_paths_resolve "$shimmy_engine_registry_legacy_config" \
    "profile-$shimmy_engine_registry_legacy_profile" || return 1
  mkdir -p "$SHIMMY_ENGINE_ROOT" || return 1
  shimmy_engine_record_write "$SHIMMY_ENGINE_RECORD_PATH" \
    "profile-$shimmy_engine_registry_legacy_profile" darwin-machine profile \
    "$shimmy_engine_registry_legacy_machine" "$shimmy_engine_registry_legacy_machine" \
    "$shimmy_engine_registry_legacy_provider" legacy-external '' \
    "$shimmy_engine_registry_legacy_identity"
}

shimmy_engine_registry_migration_preflight() {
  shimmy_engine_registry_migration_config=$1
  shimmy_profile_installation_context_resolve "$shimmy_engine_registry_migration_config" || return 1
  shimmy_engine_installation_schema_state_read "$shimmy_engine_registry_migration_config" || return 1
  [ "$SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE" = unmigrated ] || {
    printf '%s\n' 'ERROR: Shimmy engine state is already migrated' >&2
    return 1
  }
  SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES=$(shimmy_engine_registry_profile_names_render \
    "$shimmy_engine_registry_migration_config/profiles") || return 1
  [ -w "$shimmy_engine_registry_migration_config" ] || return 1
  while IFS= read -r shimmy_engine_registry_migration_write_profile; do
    [ -n "$shimmy_engine_registry_migration_write_profile" ] || continue
    shimmy_engine_registry_migration_write_root=$shimmy_engine_registry_migration_config/profiles/$shimmy_engine_registry_migration_write_profile
    [ -w "$shimmy_engine_registry_migration_write_root" ] || return 1
    [ ! -e "$shimmy_engine_registry_migration_write_root/engine-binding.conf" ] &&
      [ ! -L "$shimmy_engine_registry_migration_write_root/engine-binding.conf" ] || return 1
  done <<EOF
$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES
EOF
  shimmy_engine_registry_host_os_resolve
  case "$SHIMMY_ENGINE_REGISTRY_HOST_OS" in
    linux)
      shimmy_profile_linux_engine_validate || return 1
      ;;
    darwin)
      shimmy_engine_podman_bin_require || return 1
      shimmy_engine_registry_shared_name=shimmy
      shimmy_engine_podman_machine_absence_validate \
        "$shimmy_engine_registry_shared_name" "$shimmy_engine_registry_shared_name" || {
        printf 'ERROR: Podman machine or connection name collision: %s\n' \
          "$shimmy_engine_registry_shared_name" >&2
        return 1
      }
      while IFS= read -r shimmy_engine_registry_migration_profile; do
        [ -n "$shimmy_engine_registry_migration_profile" ] || continue
        shimmy_engine_registry_migration_machine=shimmy-$shimmy_engine_registry_migration_profile
        shimmy_engine_podman_machine_state_read "$shimmy_engine_registry_migration_machine" || return 1
        case "$SHIMMY_ENGINE_MACHINE_STATE" in running|stopped) ;; *) return 1 ;; esac
        shimmy_engine_podman_connection_state_read "$shimmy_engine_registry_migration_machine" || return 1
        [ "$SHIMMY_ENGINE_CONNECTION_STATE" = rootless ] || return 1
        shimmy_engine_podman_machine_identity_fingerprint_render \
          "$shimmy_engine_registry_migration_machine" \
          "$shimmy_engine_registry_migration_machine" >/dev/null || return 1
      done <<EOF
$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES
EOF
      ;;
    *) return 1 ;;
  esac
}

shimmy_engine_registry_migrate() {
  shimmy_engine_registry_migrate_config=$1
  shimmy_engine_registry_migrate_dry=${2:-0}
  case "$shimmy_engine_registry_migrate_dry" in 0|1) ;; *) return 1 ;; esac
  if [ -e "$shimmy_engine_registry_migrate_config/.engine-migration.conf" ] ||
    [ -L "$shimmy_engine_registry_migrate_config/.engine-migration.conf" ]; then
    shimmy_profile_installation_context_resolve "$shimmy_engine_registry_migrate_config" || return 1
    if [ "$shimmy_engine_registry_migrate_dry" -eq 1 ]; then
      shimmy_engine_registry_migration_journal_read "$shimmy_engine_registry_migrate_config" || return 1
      printf '%s\n' 'dry_run=yes' 'engine_schema_before=ambiguous' \
        'recovery_required=yes' 'would_restore_legacy_authority=yes'
      return 1
    fi
    if shimmy_engine_installation_schema_state_read "$shimmy_engine_registry_migrate_config" &&
      [ "$SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE" = migrated ]; then
      rm -f "$shimmy_engine_registry_migrate_config/.engine-migration.conf" || return 1
    else
      shimmy_engine_registry_migration_journal_read "$shimmy_engine_registry_migrate_config" || return 1
      [ "$(shimmy_engine_registry_profile_names_render \
        "$shimmy_engine_registry_migrate_config/profiles")" = \
        "$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES" ] || return 1
      shimmy_engine_registry_migration_recovery_active=$SHIMMY_PROFILE_ACTIVE_NAME
      shimmy_engine_registry_migration_locks_acquire "$shimmy_engine_registry_migrate_config" \
        "$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES" \
        "$shimmy_engine_registry_migration_recovery_active" || return 1
      shimmy_profile_installation_context_resolve "$shimmy_engine_registry_migrate_config" || return 1
      [ "$SHIMMY_PROFILE_ACTIVE_NAME" = \
        "$shimmy_engine_registry_migration_recovery_active" ] || return 1
      shimmy_engine_registry_migration_journal_read "$shimmy_engine_registry_migrate_config" || return 1
      [ "$(shimmy_engine_registry_profile_names_render \
        "$shimmy_engine_registry_migrate_config/profiles")" = \
        "$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES" ] || return 1
      SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG=$shimmy_engine_registry_migrate_config
      SHIMMY_ENGINE_REGISTRY_MIGRATION_ACTIVE=1
      shimmy_engine_registry_host_os_resolve
      [ "$SHIMMY_ENGINE_REGISTRY_HOST_OS" = \
        "$SHIMMY_ENGINE_REGISTRY_MIGRATION_JOURNAL_HOST_OS" ] || return 1
      if [ "$SHIMMY_ENGINE_REGISTRY_HOST_OS" = darwin ]; then
        shimmy_engine_podman_bin_require || return 1
      fi
      shimmy_engine_registry_migration_rollback || return 1
    fi
  fi
  shimmy_engine_registry_migration_preflight "$shimmy_engine_registry_migrate_config" || return 1
  shimmy_engine_registry_migrate_profiles=$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES
  shimmy_engine_registry_migrate_active=$SHIMMY_PROFILE_ACTIVE_NAME
  printf 'dry_run=%s\nengine_schema_before=unmigrated\n' \
    "$(if [ "$shimmy_engine_registry_migrate_dry" -eq 1 ]; then printf yes; else printf no; fi)"
  while IFS= read -r shimmy_engine_registry_migrate_profile; do
    [ -n "$shimmy_engine_registry_migrate_profile" ] || continue
    if [ "$SHIMMY_ENGINE_REGISTRY_HOST_OS" = darwin ]; then
      printf 'profile_binding=%s|legacy-isolated|profile-%s|shimmy-%s\n' \
        "$shimmy_engine_registry_migrate_profile" "$shimmy_engine_registry_migrate_profile" \
        "$shimmy_engine_registry_migrate_profile"
    else
      printf 'profile_binding=%s|shared|shared|local\n' \
        "$shimmy_engine_registry_migrate_profile"
    fi
  done <<EOF
$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES
EOF
  if [ "$SHIMMY_ENGINE_REGISTRY_HOST_OS" = darwin ]; then
    printf '%s\n' 'shared_engine=shared|shimmy|would-create'
  else
    printf '%s\n' 'shared_engine=shared|local|host-local'
  fi
  [ "$shimmy_engine_registry_migrate_dry" -eq 0 ] || return 0

  if [ "$SHIMMY_ENGINE_REGISTRY_MIGRATION_LOCKS_HELD" -eq 0 ]; then
    shimmy_engine_registry_migration_locks_acquire "$shimmy_engine_registry_migrate_config" \
      "$shimmy_engine_registry_migrate_profiles" \
      "$shimmy_engine_registry_migrate_active" || return 1
  fi
  shimmy_engine_registry_migration_preflight "$shimmy_engine_registry_migrate_config" || return 1
  [ "$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES" = \
    "$shimmy_engine_registry_migrate_profiles" ] &&
    [ "$SHIMMY_PROFILE_ACTIVE_NAME" = "$shimmy_engine_registry_migrate_active" ] || return 1

  SHIMMY_ENGINE_REGISTRY_MIGRATION_CONFIG=$shimmy_engine_registry_migrate_config
  SHIMMY_ENGINE_REGISTRY_MIGRATION_ACTIVE=1
  shimmy_engine_registry_migration_journal_write "$shimmy_engine_registry_migrate_config" \
    "$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES" || return 1
  mkdir "$shimmy_engine_registry_migrate_config/engines" || return 1
  shimmy_engine_registry_migrate_status=0
  if [ "$SHIMMY_ENGINE_REGISTRY_HOST_OS" = darwin ]; then
    while IFS= read -r shimmy_engine_registry_migrate_profile; do
      [ -n "$shimmy_engine_registry_migrate_profile" ] || continue
      shimmy_engine_registry_legacy_record_publish "$shimmy_engine_registry_migrate_config" \
        "$shimmy_engine_registry_migrate_profile" || shimmy_engine_registry_migrate_status=1
      [ "$shimmy_engine_registry_migrate_status" -eq 0 ] || break
    done <<EOF
$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES
EOF
    if [ "$shimmy_engine_registry_migrate_status" -eq 0 ]; then
      shimmy_engine_registry_shared_create_prepare "$shimmy_engine_registry_migrate_config" \
        "$SHIMMY_PROFILE_ACTIVE_NAME" shimmy || shimmy_engine_registry_migrate_status=1
    fi
  else
    shimmy_engine_paths_resolve "$shimmy_engine_registry_migrate_config" shared || return 1
    mkdir -p "$SHIMMY_ENGINE_ROOT" || return 1
    shimmy_engine_record_write "$SHIMMY_ENGINE_RECORD_PATH" shared linux-rootless \
      installation local local none host-local '' '' || shimmy_engine_registry_migrate_status=1
  fi
  if [ "$shimmy_engine_registry_migrate_status" -eq 0 ]; then
    while IFS= read -r shimmy_engine_registry_migrate_profile; do
      [ -n "$shimmy_engine_registry_migrate_profile" ] || continue
      if [ "$SHIMMY_ENGINE_REGISTRY_HOST_OS" = darwin ]; then
        shimmy_engine_binding_write \
          "$shimmy_engine_registry_migrate_config/profiles/$shimmy_engine_registry_migrate_profile/engine-binding.conf" \
          "$shimmy_engine_registry_migrate_profile" legacy-isolated \
          "profile-$shimmy_engine_registry_migrate_profile" || shimmy_engine_registry_migrate_status=1
      else
        shimmy_engine_binding_write \
          "$shimmy_engine_registry_migrate_config/profiles/$shimmy_engine_registry_migrate_profile/engine-binding.conf" \
          "$shimmy_engine_registry_migrate_profile" shared shared || shimmy_engine_registry_migrate_status=1
      fi
      [ "$shimmy_engine_registry_migrate_status" -eq 0 ] || break
  done <<EOF
$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES
EOF
  fi
  if [ "$shimmy_engine_registry_migrate_status" -eq 0 ]; then
    if ! shimmy_engine_installation_schema_state_read "$shimmy_engine_registry_migrate_config"; then
      printf '%s\n' 'ERROR: prepared engine registry failed compatibility validation' >&2
      shimmy_engine_registry_migrate_status=1
    elif [ "$SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE" != migrated ]; then
      printf 'ERROR: prepared engine registry remained in schema state %s\n' \
        "$SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE" >&2
      shimmy_engine_registry_migrate_status=1
    fi
  fi
  if [ "$shimmy_engine_registry_migrate_status" -eq 0 ] &&
    [ "$SHIMMY_ENGINE_REGISTRY_HOST_OS" = darwin ]; then
    shimmy_engine_registry_shared_create_commit || shimmy_engine_registry_migrate_status=1
  fi
  if [ "$shimmy_engine_registry_migrate_status" -ne 0 ]; then
    shimmy_engine_registry_migration_rollback || true
    return 1
  fi
  rm -f "$shimmy_engine_registry_migrate_config/.engine-migration.conf" || return 1
  SHIMMY_ENGINE_REGISTRY_MIGRATION_ACTIVE=0
  shimmy_locks_release_all || return 1
  SHIMMY_ENGINE_REGISTRY_MIGRATION_LOCKS_HELD=0
  printf '%s\n' 'engine_schema_after=migrated'
}

shimmy_engine_registry_status_render() {
  shimmy_engine_registry_status_config=$1
  shimmy_engine_registry_status_format=${2:-human}
  case "$shimmy_engine_registry_status_format" in human|manifest) ;; *) return 1 ;; esac
  shimmy_profile_installation_context_resolve "$shimmy_engine_registry_status_config" || return 1
  if ! shimmy_engine_installation_schema_state_read "$shimmy_engine_registry_status_config"; then
    SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE=ambiguous
  fi
  shimmy_engine_registry_host_os_resolve
  if [ "$shimmy_engine_registry_status_format" = manifest ]; then
    printf 'shimmy_engine_schema=%s\nshimmy_engine_host_os=%s\n' \
      "$SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE" "$SHIMMY_ENGINE_REGISTRY_HOST_OS"
  else
    printf 'Engine schema: %s\nHost OS: %s\n' \
      "$SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE" "$SHIMMY_ENGINE_REGISTRY_HOST_OS"
  fi
  shimmy_engine_registry_status_profiles=$(shimmy_engine_registry_profile_names_render \
    "$shimmy_engine_registry_status_config/profiles") || return 1
  while IFS= read -r shimmy_engine_registry_status_profile; do
    [ -n "$shimmy_engine_registry_status_profile" ] || continue
    if ! shimmy_engine_profile_binding_resolve "$shimmy_engine_registry_status_config" \
      "$shimmy_engine_registry_status_profile"; then
      if [ "$shimmy_engine_registry_status_format" = manifest ]; then
        printf 'shimmy_engine_profile=%s|ambiguous|ambiguous|-|-|ambiguous|ambiguous|stale\n' \
          "$shimmy_engine_registry_status_profile"
      else
        printf 'Profile %s: mode=ambiguous engine=- name=- origin=ambiguous ownership=ambiguous projection=stale\n' \
          "$shimmy_engine_registry_status_profile"
      fi
      continue
    fi
    shimmy_engine_registry_status_ownership=external
    shimmy_engine_registry_status_projection=not-applicable
    if [ "$SHIMMY_PROFILE_ENGINE_MIGRATION_STATE" = migrated ]; then
      if [ "$SHIMMY_PROFILE_ENGINE_ORIGIN" = shimmy-created ]; then
        shimmy_engine_ownership_state_read "$SHIMMY_PROFILE_ENGINE_RECORD_PATH"
        shimmy_engine_registry_status_ownership=$SHIMMY_ENGINE_OWNERSHIP_STATE
      elif [ "$SHIMMY_PROFILE_ENGINE_ORIGIN" = host-local ]; then
        shimmy_engine_registry_status_ownership=host-local
      fi
      if [ "$SHIMMY_PROFILE_ENGINE_ORIGIN" = shimmy-created ]; then
        shimmy_engine_paths_resolve "$shimmy_engine_registry_status_config" \
          "$SHIMMY_PROFILE_ENGINE_ID" || return 1
        if [ -e "$SHIMMY_ENGINE_PROJECTION_PATH" ] || [ -L "$SHIMMY_ENGINE_PROJECTION_PATH" ]; then
          if shimmy_engine_projection_read "$SHIMMY_ENGINE_PROJECTION_PATH" &&
            [ "$SHIMMY_ENGINE_PROJECTION_SOURCE_PROFILE" = "$shimmy_engine_registry_status_profile" ] &&
            [ "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" = \
              "$SHIMMY_ENGINE_PROJECTION_LOADED_FINGERPRINT" ]; then
            shimmy_engine_registry_status_projection=current
          else
            shimmy_engine_registry_status_projection=stale
          fi
        else
          shimmy_engine_registry_status_projection=stale
        fi
      fi
    fi
    if [ "$shimmy_engine_registry_status_format" = manifest ]; then
      printf 'shimmy_engine_profile=%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$shimmy_engine_registry_status_profile" "$SHIMMY_PROFILE_ENGINE_MIGRATION_STATE" \
        "$SHIMMY_PROFILE_ENGINE_BINDING_MODE" "$SHIMMY_PROFILE_ENGINE_ID" \
        "$SHIMMY_PROFILE_EXPECTED_MACHINE" "$SHIMMY_PROFILE_ENGINE_ORIGIN" \
        "$shimmy_engine_registry_status_ownership" \
        "$shimmy_engine_registry_status_projection"
    else
      printf 'Profile %s: mode=%s engine=%s name=%s origin=%s ownership=%s projection=%s\n' \
        "$shimmy_engine_registry_status_profile" "$SHIMMY_PROFILE_ENGINE_BINDING_MODE" \
        "$SHIMMY_PROFILE_ENGINE_ID" "$SHIMMY_PROFILE_EXPECTED_MACHINE" \
        "$SHIMMY_PROFILE_ENGINE_ORIGIN" \
        "$shimmy_engine_registry_status_ownership" "$shimmy_engine_registry_status_projection"
    fi
  done <<EOF
$shimmy_engine_registry_status_profiles
EOF
}

shimmy_engine_registry_projection_state_read() {
  shimmy_engine_registry_projection_config=$1
  shimmy_engine_registry_projection_profile=$2
  shimmy_engine_registry_projection_id=$3
  SHIMMY_ENGINE_REGISTRY_PROJECTION_STATE=stale
  shimmy_engine_paths_resolve "$shimmy_engine_registry_projection_config" \
    "$shimmy_engine_registry_projection_id" || return 1
  [ -f "$SHIMMY_ENGINE_REGISTRIES_PATH" ] &&
    [ ! -L "$SHIMMY_ENGINE_REGISTRIES_PATH" ] || return 0
  shimmy_engine_projection_read "$SHIMMY_ENGINE_PROJECTION_PATH" || return 0
  [ "$SHIMMY_ENGINE_PROJECTION_ID" = "$shimmy_engine_registry_projection_id" ] || return 0
  [ "$SHIMMY_ENGINE_PROJECTION_SOURCE_PROFILE" = \
    "$shimmy_engine_registry_projection_profile" ] || return 0
  shimmy_engine_registry_projection_source=$shimmy_engine_registry_projection_config/profiles/$shimmy_engine_registry_projection_profile/registries.conf
  [ "$SHIMMY_ENGINE_PROJECTION_SOURCE_PATH" = \
    "$shimmy_engine_registry_projection_source" ] || return 0
  shimmy_registries_config_validate "$shimmy_engine_registry_projection_source" \
    "$shimmy_engine_registry_projection_profile" || return 0
  [ "$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_engine_registry_projection_source")" = \
    "$SHIMMY_ENGINE_PROJECTION_SOURCE_FINGERPRINT" ] || return 0
  shimmy_engine_registry_projection_entries=$(shimmy_registries_config_entries_read \
    "$shimmy_engine_registry_projection_source" \
    "$shimmy_engine_registry_projection_profile") || return 0
  [ "$(shimmy_engine_projection_effective_fingerprint_render \
    "$shimmy_engine_registry_projection_entries")" = \
    "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" ] || return 0
  [ "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" = \
    "$SHIMMY_ENGINE_PROJECTION_LOADED_FINGERPRINT" ] || return 0
  SHIMMY_ENGINE_REGISTRY_PROJECTION_STATE=current
}

shimmy_engine_registry_projection_action_plan() {
  shimmy_engine_registry_plan_config=$1
  shimmy_engine_registry_plan_profile=$2
  shimmy_engine_registry_plan_id=$3
  shimmy_engine_paths_resolve "$shimmy_engine_registry_plan_config" \
    "$shimmy_engine_registry_plan_id" || return 1
  shimmy_engine_registry_plan_source=$shimmy_engine_registry_plan_config/profiles/$shimmy_engine_registry_plan_profile/registries.conf
  shimmy_registries_config_validate "$shimmy_engine_registry_plan_source" \
    "$shimmy_engine_registry_plan_profile" || return 1
  shimmy_engine_registry_plan_entries=$(shimmy_registries_config_entries_read \
    "$shimmy_engine_registry_plan_source" "$shimmy_engine_registry_plan_profile") || return 1
  SHIMMY_ENGINE_REGISTRY_PLANNED_FINGERPRINT=$(shimmy_engine_projection_effective_fingerprint_render \
    "$shimmy_engine_registry_plan_entries") || return 1
  SHIMMY_ENGINE_REGISTRY_PLANNED_SERVICE_ACTION=recycle-podman-service
  if [ -f "$SHIMMY_ENGINE_PROJECTION_PATH" ] &&
    [ ! -L "$SHIMMY_ENGINE_PROJECTION_PATH" ] &&
    shimmy_engine_projection_read "$SHIMMY_ENGINE_PROJECTION_PATH" &&
    [ "$SHIMMY_ENGINE_PROJECTION_LOADED_FINGERPRINT" = \
      "$SHIMMY_ENGINE_REGISTRY_PLANNED_FINGERPRINT" ]; then
    SHIMMY_ENGINE_REGISTRY_PLANNED_SERVICE_ACTION=none
  fi
}
