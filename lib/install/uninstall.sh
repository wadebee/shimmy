#!/bin/sh
# Private target inactive-profile deletion and installation-wide uninstall.

SHIMMY_TARGET_UNINSTALL_ERROR=
SHIMMY_TARGET_UNINSTALL_PROJECTION_BACKUP=

shimmy_target_profile_active_link_restore() {
  shimmy_target_profile_active_link_restore_path=$1
  shimmy_target_profile_active_link_restore_prior=$2
  shimmy_target_profile_active_link_restore_committed=$3
  [ "$shimmy_target_profile_active_link_restore_committed" = absent ] || return 1
  [ ! -e "$shimmy_target_profile_active_link_restore_path" ] &&
    [ ! -L "$shimmy_target_profile_active_link_restore_path" ] || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_target_profile_active_link_restore_prior" || return 1
  shimmy_target_profile_active_link_restore_stage=$(dirname -- "$shimmy_target_profile_active_link_restore_path")/.shimmy-active-profile.uninstall-rollback.$$
  [ ! -e "$shimmy_target_profile_active_link_restore_stage" ] &&
    [ ! -L "$shimmy_target_profile_active_link_restore_stage" ] || return 1
  ln -s "$shimmy_target_profile_active_link_restore_prior" \
    "$shimmy_target_profile_active_link_restore_stage" || return 1
  mv "$shimmy_target_profile_active_link_restore_stage" "$shimmy_target_profile_active_link_restore_path"
}

shimmy_target_profile_delete_run() {
  shimmy_target_profile_delete_config=$1
  shimmy_target_profile_delete_name=$2
  shimmy_target_profile_delete_stop=$3
  shimmy_name_component_validate "$shimmy_target_profile_delete_name" || return 1
  case "$shimmy_target_profile_delete_stop" in 0|1) ;; *) return 1 ;; esac
  [ "$shimmy_target_profile_delete_name" != default ] || {
    SHIMMY_TARGET_UNINSTALL_ERROR='the default Shimmy profile cannot be deleted'
    return 1
  }
  shimmy_target_profile_installation_context_resolve "$shimmy_target_profile_delete_config" || return 1
  [ "$SHIMMY_TARGET_PROFILE_ACTIVE_NAME" != "$shimmy_target_profile_delete_name" ] || {
    SHIMMY_TARGET_UNINSTALL_ERROR="the active Shimmy profile cannot be deleted: $shimmy_target_profile_delete_name"
    return 1
  }
  shimmy_target_profile_owned_root_validate "$shimmy_target_profile_delete_config" \
    "$shimmy_target_profile_delete_name" 0 || return 1
  shimmy_target_lock_acquire activation "$shimmy_target_profile_delete_config" || return 1
  shimmy_target_lock_acquire profile "$shimmy_target_profile_delete_config" \
    "$shimmy_target_profile_delete_name" || return 1
  shimmy_target_lock_acquire registry "$shimmy_target_profile_delete_config" \
    "$shimmy_target_profile_delete_name" || return 1
  shimmy_target_profile_installation_context_resolve "$shimmy_target_profile_delete_config" || return 1
  [ "$SHIMMY_TARGET_PROFILE_ACTIVE_NAME" != "$shimmy_target_profile_delete_name" ] || return 1
  shimmy_target_profile_owned_root_validate "$shimmy_target_profile_delete_config" \
    "$shimmy_target_profile_delete_name" 1 || return 1
  shimmy_target_profile_projection_cleanup "$shimmy_target_profile_delete_config" \
    "$shimmy_target_profile_delete_name" "$shimmy_target_profile_delete_stop" || return 1
  shimmy_target_profile_owned_assets_remove "$shimmy_target_profile_delete_config" \
    "$shimmy_target_profile_delete_name" || return 1
  shimmy_target_locks_release_all || return 1
  shimmy_target_profile_paths_resolve "$shimmy_target_profile_delete_config" \
    "$shimmy_target_profile_delete_name" || return 1
  rmdir "$SHIMMY_TARGET_PROFILE_ROOT" || return 1
  printf 'Deleted inactive Shimmy profile %s.\n' "$shimmy_target_profile_delete_name"
}

shimmy_target_profile_owned_assets_remove() {
  shimmy_target_profile_owned_remove_config=$1
  shimmy_target_profile_owned_remove_name=$2
  shimmy_target_profile_paths_resolve "$shimmy_target_profile_owned_remove_config" \
    "$shimmy_target_profile_owned_remove_name" || return 1
  for shimmy_target_profile_owned_remove_entry in ai-skills bin commands config lib tools \
    install-manifest.txt machine-projection.txt registries.conf shell-init.sh; do
    shimmy_target_profile_owned_remove_path=$SHIMMY_TARGET_PROFILE_ROOT/$shimmy_target_profile_owned_remove_entry
    if [ -d "$shimmy_target_profile_owned_remove_path" ] && [ ! -L "$shimmy_target_profile_owned_remove_path" ]; then
      rm -rf "$shimmy_target_profile_owned_remove_path" || return 1
    elif [ -e "$shimmy_target_profile_owned_remove_path" ] || [ -L "$shimmy_target_profile_owned_remove_path" ]; then
      rm -f "$shimmy_target_profile_owned_remove_path" || return 1
    fi
  done
}

shimmy_target_profile_owned_root_validate() {
  shimmy_target_profile_owned_config=$1
  shimmy_target_profile_owned_name=$2
  shimmy_target_profile_owned_locks=${3:-0}
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_owned_config" \
    "$shimmy_target_profile_owned_name" || return 1
  shimmy_target_profile_owned_root=$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT
  for shimmy_target_profile_owned_entry in "$shimmy_target_profile_owned_root"/* \
    "$shimmy_target_profile_owned_root"/.[!.]* "$shimmy_target_profile_owned_root"/..?*; do
    [ -e "$shimmy_target_profile_owned_entry" ] || [ -L "$shimmy_target_profile_owned_entry" ] || continue
    shimmy_target_profile_owned_base=$(basename -- "$shimmy_target_profile_owned_entry")
    case "$shimmy_target_profile_owned_base" in
      ai-skills|bin|commands|config|lib|tools)
        [ -d "$shimmy_target_profile_owned_entry" ] && [ ! -L "$shimmy_target_profile_owned_entry" ] || return 1
        ;;
      install-manifest.txt|machine-projection.txt|registries.conf|shell-init.sh)
        [ -f "$shimmy_target_profile_owned_entry" ] && [ ! -L "$shimmy_target_profile_owned_entry" ] || return 1
        ;;
      .profile.lock|.registries.lock)
        [ "$shimmy_target_profile_owned_locks" -eq 1 ] &&
          [ -f "$shimmy_target_profile_owned_entry" ] && [ ! -L "$shimmy_target_profile_owned_entry" ] || return 1
        ;;
      *)
        SHIMMY_TARGET_UNINSTALL_ERROR="unrecognized target profile state blocks deletion: $shimmy_target_profile_owned_entry"
        return 1
        ;;
    esac
  done
}

shimmy_target_profile_projection_cleanup() {
  shimmy_target_profile_projection_config=$1
  shimmy_target_profile_projection_name=$2
  shimmy_target_profile_projection_stop=$3
  shimmy_target_profile_projection_strict_stop=${4:-1}
  shimmy_target_profile_engine_context_resolve "$shimmy_target_profile_projection_config" \
    "$shimmy_target_profile_projection_name" || return 1
  shimmy_profile_activation_expected_resolve || return 1
  shimmy_profile_activation_host_os_resolve
  case "$SHIMMY_PROFILE_HOST_OS" in
    linux)
      [ "$shimmy_target_profile_projection_stop" -eq 0 ] ||
        [ "$shimmy_target_profile_projection_strict_stop" -eq 0 ] || {
        SHIMMY_TARGET_UNINSTALL_ERROR='--stop-running is not supported for local Linux profile deletion'
        return 1
      }
      shimmy_registries_active_link_state_read
      case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in absent|sibling) return 0 ;; *) return 1 ;; esac
      ;;
    darwin) ;;
    *) SHIMMY_TARGET_UNINSTALL_ERROR="unsupported host operating system for profile deletion: $SHIMMY_PROFILE_HOST_OS"; return 1 ;;
  esac
  shimmy_registries_machine_projection_record_read
  case "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE" in
    absent)
      [ "$shimmy_target_profile_projection_stop" -eq 0 ] ||
        [ "$shimmy_target_profile_projection_strict_stop" -eq 0 ] || return 1
      return 0
      ;;
    valid) ;;
    *) return 1 ;;
  esac
  shimmy_profile_state_darwin_read
  case "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" in
    missing)
      [ "$shimmy_target_profile_projection_stop" -eq 0 ] ||
        [ "$shimmy_target_profile_projection_strict_stop" -eq 0 ] || return 1
      shimmy_registries_machine_projection_detach_prepare || return 1
      SHIMMY_TARGET_UNINSTALL_PROJECTION_BACKUP=$SHIMMY_PROFILE_ROOT/.machine-projection.detach.$$
      shimmy_registries_machine_projection_detach_record_remove \
        "$SHIMMY_TARGET_UNINSTALL_PROJECTION_BACKUP" || return 1
      shimmy_registries_machine_projection_detach_finalize \
        "$SHIMMY_TARGET_UNINSTALL_PROJECTION_BACKUP" || return 1
      SHIMMY_TARGET_UNINSTALL_PROJECTION_BACKUP=
      return 0
      ;;
    running|stopped) ;;
    *) return 1 ;;
  esac
  [ "$SHIMMY_PROFILE_CONNECTION_METADATA" = valid ] &&
    [ "$SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE" = rootless ] || return 1
  shimmy_target_profile_projection_stop_planned=0
  [ "$SHIMMY_PROFILE_RUNNING_MACHINE" = none ] ||
    shimmy_target_profile_projection_stop_planned=1
  if [ "$shimmy_target_profile_projection_stop_planned" -eq 1 ]; then
    [ "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT" != unknown ] || return 1
    shimmy_profile_workloads_print
    if [ "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT" -gt 0 ] &&
      [ "$shimmy_target_profile_projection_stop" -eq 0 ]; then
      SHIMMY_TARGET_UNINSTALL_ERROR='running containers block profile deletion; retry with explicit --stop-running acknowledgement'
      return 1
    fi
  elif [ "$shimmy_target_profile_projection_stop" -eq 1 ] &&
    [ "$shimmy_target_profile_projection_strict_stop" -eq 1 ]; then
    SHIMMY_TARGET_UNINSTALL_ERROR='--stop-running is valid only when profile deletion must stop a running machine'
    return 1
  fi
  shimmy_registries_machine_projection_detach_prepare || return 1
  shimmy_profile_cleanup_transaction_begin "$SHIMMY_PROFILE_RUNNING_MACHINE" \
    "$SHIMMY_PROFILE_DEFAULT_CONNECTION" || return 1
  shimmy_target_profile_projection_was_running=0
  [ "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" != running ] ||
    shimmy_target_profile_projection_was_running=1
  shimmy_profile_cleanup_machine_switch "$SHIMMY_PROFILE_EXPECTED_MACHINE" || return 1
  shimmy_profile_cleanup_engine_validate "$SHIMMY_PROFILE_EXPECTED_CONNECTION" || return 1
  shimmy_registries_machine_projection_detach_remote || return 1
  if [ "$shimmy_target_profile_projection_was_running" -eq 1 ]; then
    shimmy_profile_cleanup_machine_restart "$SHIMMY_PROFILE_EXPECTED_MACHINE" || return 1
  fi
  shimmy_profile_cleanup_restore || return 1
  SHIMMY_TARGET_UNINSTALL_PROJECTION_BACKUP=$SHIMMY_PROFILE_ROOT/.machine-projection.detach.$$
  shimmy_registries_machine_projection_detach_record_remove \
    "$SHIMMY_TARGET_UNINSTALL_PROJECTION_BACKUP" || return 1
  shimmy_registries_machine_projection_detach_finalize \
    "$SHIMMY_TARGET_UNINSTALL_PROJECTION_BACKUP" || return 1
  SHIMMY_TARGET_UNINSTALL_PROJECTION_BACKUP=
  if [ "$shimmy_target_profile_projection_stop" -eq 1 ] &&
    [ "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT" -gt 0 ]; then
    printf '%s\n' 'WARNING: acknowledged workloads were interrupted; verify that they resumed as intended.' >&2
  fi
}

shimmy_target_startup_remove_apply() {
  shimmy_target_startup_remove_config=$1
  shimmy_target_startup_remove_files=${2:-}
  [ -n "$shimmy_target_startup_remove_files" ] || return 0
  shimmy_target_startup_remove_sequence=0
  SHIMMY_TARGET_PROFILE_LIFECYCLE_STARTUP_BACKUP=$shimmy_target_startup_remove_config/.startup-backup.$$
  mkdir "$SHIMMY_TARGET_PROFILE_LIFECYCLE_STARTUP_BACKUP" || return 1
  while IFS= read -r shimmy_target_startup_remove_file; do
    [ -n "$shimmy_target_startup_remove_file" ] || continue
    [ -f "$shimmy_target_startup_remove_file" ] && [ ! -L "$shimmy_target_startup_remove_file" ] || return 1
    shimmy_target_startup_remove_sequence=$((shimmy_target_startup_remove_sequence + 1))
    shimmy_target_startup_remove_backup=$SHIMMY_TARGET_PROFILE_LIFECYCLE_STARTUP_BACKUP/$shimmy_target_startup_remove_sequence
    cp "$shimmy_target_startup_remove_file" "$shimmy_target_startup_remove_backup" || return 1
    shimmy_target_external_rollback_register "$shimmy_target_startup_remove_file" \
      shimmy_target_startup_restore "$shimmy_target_startup_remove_backup" present \
      'restore startup file removed during uninstall' || return 1
    shimmy_startup_block_remove "$shimmy_target_startup_remove_file" \
      "$SHIMMY_STARTUP_BLOCK_START" "$SHIMMY_STARTUP_BLOCK_END" || return 1
  done <<EOF
$shimmy_target_startup_remove_files
EOF
}

shimmy_target_uninstall_config_validate() {
  shimmy_target_uninstall_config=$1
  shimmy_target_uninstall_locks=${2:-0}
  shimmy_target_profile_installation_context_resolve "$shimmy_target_uninstall_config" || return 1
  SHIMMY_TARGET_UNINSTALL_ACTIVE=$SHIMMY_TARGET_PROFILE_ACTIVE_NAME
  SHIMMY_TARGET_UNINSTALL_USER_ROOT=$SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT
  SHIMMY_TARGET_UNINSTALL_PROFILES=
  for shimmy_target_uninstall_profile_path in "$SHIMMY_TARGET_PROFILES_ROOT"/*; do
    [ -e "$shimmy_target_uninstall_profile_path" ] || [ -L "$shimmy_target_uninstall_profile_path" ] || continue
    shimmy_target_uninstall_profile_name=$(basename -- "$shimmy_target_uninstall_profile_path")
    shimmy_name_component_validate "$shimmy_target_uninstall_profile_name" || return 1
    shimmy_target_profile_owned_root_validate "$shimmy_target_uninstall_config" \
      "$shimmy_target_uninstall_profile_name" "$shimmy_target_uninstall_locks" || return 1
    SHIMMY_TARGET_UNINSTALL_PROFILES=$(shimmy_append_line_list "$SHIMMY_TARGET_UNINSTALL_PROFILES" \
      "$shimmy_target_uninstall_profile_name")
  done
  SHIMMY_TARGET_UNINSTALL_PROFILES=$(printf '%s\n' "$SHIMMY_TARGET_UNINSTALL_PROFILES" | sed '/^$/d' | LC_ALL=C sort)
  shimmy_contains_line_list "$SHIMMY_TARGET_UNINSTALL_PROFILES" default || return 1
  for shimmy_target_uninstall_entry in "$shimmy_target_uninstall_config"/* \
    "$shimmy_target_uninstall_config"/.[!.]* "$shimmy_target_uninstall_config"/..?*; do
    [ -e "$shimmy_target_uninstall_entry" ] || [ -L "$shimmy_target_uninstall_entry" ] || continue
    shimmy_target_uninstall_base=$(basename -- "$shimmy_target_uninstall_entry")
    case "$shimmy_target_uninstall_base" in
      active-profile.conf) [ -f "$shimmy_target_uninstall_entry" ] && [ ! -L "$shimmy_target_uninstall_entry" ] || return 1 ;;
      catalogs|profiles) [ -d "$shimmy_target_uninstall_entry" ] && [ ! -L "$shimmy_target_uninstall_entry" ] || return 1 ;;
      .catalog.lock|.activation.lock)
        [ "$shimmy_target_uninstall_locks" -eq 1 ] && [ -f "$shimmy_target_uninstall_entry" ] &&
          [ ! -L "$shimmy_target_uninstall_entry" ] || return 1
        ;;
      *) SHIMMY_TARGET_UNINSTALL_ERROR="unrecognized installation-owned state blocks uninstall: $shimmy_target_uninstall_entry"; return 1 ;;
    esac
  done
}

shimmy_target_uninstall_links_apply() {
  shimmy_target_uninstall_links_user=$1
  shimmy_target_uninstall_links_profiles=$2
  for shimmy_target_uninstall_links_entry in "$shimmy_target_uninstall_links_user"/*; do
    [ -e "$shimmy_target_uninstall_links_entry" ] || [ -L "$shimmy_target_uninstall_links_entry" ] || continue
    [ -L "$shimmy_target_uninstall_links_entry" ] || continue
    shimmy_target_uninstall_links_target=$(readlink "$shimmy_target_uninstall_links_entry") || return 1
    case "$shimmy_target_uninstall_links_target" in
      "$shimmy_target_uninstall_links_profiles"/*)
        shimmy_target_ai_skill_link_recognized_read "$shimmy_target_uninstall_links_entry" \
          "$shimmy_target_uninstall_links_user" "$shimmy_target_uninstall_links_profiles" || return 1
        shimmy_target_ai_skill_link_remove_recognized "$shimmy_target_uninstall_links_user" \
          "$shimmy_target_uninstall_links_profiles" "$(basename -- "$shimmy_target_uninstall_links_entry")" || return 1
        ;;
    esac
  done
}

shimmy_target_uninstall_run() {
  shimmy_target_uninstall_config=$1
  shimmy_target_uninstall_stop=$2
  case "$shimmy_target_uninstall_stop" in 0|1) ;; *) return 1 ;; esac
  shimmy_target_uninstall_config_validate "$shimmy_target_uninstall_config" 0 || return 1
  shimmy_target_uninstall_initial_active=$SHIMMY_TARGET_UNINSTALL_ACTIVE
  shimmy_target_uninstall_user_root=$SHIMMY_TARGET_UNINSTALL_USER_ROOT
  shimmy_target_uninstall_profiles=$SHIMMY_TARGET_UNINSTALL_PROFILES
  shimmy_target_profile_candidate_resolve "$shimmy_target_uninstall_config" default || return 1
  shimmy_target_uninstall_startup_files=$SHIMMY_TARGET_PROFILE_CANDIDATE_STARTUP_FILES
  shimmy_target_lock_acquire catalog "$shimmy_target_uninstall_config" || return 1
  shimmy_target_lock_acquire activation "$shimmy_target_uninstall_config" || return 1
  while IFS= read -r shimmy_target_uninstall_profile; do
    shimmy_target_lock_acquire profile "$shimmy_target_uninstall_config" \
      "$shimmy_target_uninstall_profile" || return 1
  done <<EOF
$shimmy_target_uninstall_profiles
EOF
  shimmy_target_uninstall_config_validate "$shimmy_target_uninstall_config" 1 || return 1
  [ "$SHIMMY_TARGET_UNINSTALL_ACTIVE" = "$shimmy_target_uninstall_initial_active" ] &&
    [ "$SHIMMY_TARGET_UNINSTALL_USER_ROOT" = "$shimmy_target_uninstall_user_root" ] &&
    [ "$SHIMMY_TARGET_UNINSTALL_PROFILES" = "$shimmy_target_uninstall_profiles" ] || return 1

  shimmy_target_profile_engine_context_resolve "$shimmy_target_uninstall_config" \
    "$shimmy_target_uninstall_initial_active" || return 1
  shimmy_profile_activation_host_os_resolve
  shimmy_target_uninstall_host_os=$SHIMMY_PROFILE_HOST_OS
  if [ "$shimmy_target_uninstall_host_os" = linux ] && [ "$shimmy_target_uninstall_stop" -eq 1 ]; then
    SHIMMY_TARGET_UNINSTALL_ERROR='--stop-running is not supported for local Linux uninstall'
    return 1
  fi
  if [ "$shimmy_target_uninstall_host_os" = darwin ]; then
    while IFS= read -r shimmy_target_uninstall_profile; do
      shimmy_target_lock_acquire registry "$shimmy_target_uninstall_config" \
        "$shimmy_target_uninstall_profile" || return 1
      shimmy_target_profile_projection_cleanup "$shimmy_target_uninstall_config" \
        "$shimmy_target_uninstall_profile" "$shimmy_target_uninstall_stop" 0 || return 1
      shimmy_target_lock_release || return 1
    done <<EOF
$shimmy_target_uninstall_profiles
EOF
  fi

  shimmy_target_external_transaction_begin || return 1
  shimmy_target_profile_engine_context_resolve "$shimmy_target_uninstall_config" \
    "$shimmy_target_uninstall_initial_active" || return 1
  if [ "$shimmy_target_uninstall_host_os" = linux ]; then
    shimmy_registries_active_link_state_read
    [ "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" = current ] || return 1
    shimmy_target_uninstall_active_link_prior=$(readlink "$SHIMMY_REGISTRIES_ACTIVE_LINK") || return 1
    shimmy_target_external_rollback_register "$SHIMMY_REGISTRIES_ACTIVE_LINK" \
      shimmy_target_profile_active_link_restore "$shimmy_target_uninstall_active_link_prior" absent \
      'restore Linux active registry link' || return 1
    shimmy_registries_active_link_detach || return 1
  fi
  shimmy_target_uninstall_links_apply "$shimmy_target_uninstall_user_root" \
    "$SHIMMY_TARGET_PROFILES_ROOT" || return 1
  shimmy_target_startup_remove_apply "$shimmy_target_uninstall_config" \
    "$shimmy_target_uninstall_startup_files" || return 1

  shimmy_target_uninstall_parent=$(dirname -- "$shimmy_target_uninstall_config")
  shimmy_target_uninstall_backup=$shimmy_target_uninstall_parent/.shimmy-uninstall.$$
  [ ! -e "$shimmy_target_uninstall_backup" ] && [ ! -L "$shimmy_target_uninstall_backup" ] || return 1
  shimmy_target_locks_release_all || return 1
  mv "$shimmy_target_uninstall_config" "$shimmy_target_uninstall_backup" || {
    shimmy_target_external_transaction_rollback 'unable to remove target installation root' || true
    return 1
  }
  shimmy_target_external_transaction_commit || return 1
  SHIMMY_TARGET_PROFILE_LIFECYCLE_STARTUP_BACKUP=
  rm -rf "$shimmy_target_uninstall_backup" || return 1
  printf 'Uninstalled all Shimmy-owned profiles and default catalog from %s.\n' \
    "$shimmy_target_uninstall_config"
}
