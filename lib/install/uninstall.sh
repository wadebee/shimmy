#!/bin/sh
# Canonical inactive-profile deletion and installation-wide uninstall.

SHIMMY_UNINSTALL_ERROR=
SHIMMY_UNINSTALL_JOURNAL_PATH=

shimmy_uninstall_csv_validate() {
  shimmy_uninstall_csv_value=$1
  [ "$shimmy_uninstall_csv_value" != none ] || return 0
  [ -n "$shimmy_uninstall_csv_value" ] || return 1
  shimmy_uninstall_csv_seen=
  shimmy_uninstall_csv_rest=$shimmy_uninstall_csv_value
  while :; do
    shimmy_uninstall_csv_item=${shimmy_uninstall_csv_rest%%,*}
    shimmy_engine_id_validate "$shimmy_uninstall_csv_item" || return 1
    shimmy_contains_line_list "$shimmy_uninstall_csv_seen" \
      "$shimmy_uninstall_csv_item" && return 1
    shimmy_uninstall_csv_seen=$(shimmy_append_line_list \
      "$shimmy_uninstall_csv_seen" "$shimmy_uninstall_csv_item")
    [ "$shimmy_uninstall_csv_rest" != "$shimmy_uninstall_csv_item" ] || break
    shimmy_uninstall_csv_rest=${shimmy_uninstall_csv_rest#*,}
    [ -n "$shimmy_uninstall_csv_rest" ] || return 1
  done
}

shimmy_uninstall_csv_contains() {
  shimmy_uninstall_csv_haystack=$1
  shimmy_uninstall_csv_needle=$2
  [ "$shimmy_uninstall_csv_haystack" != none ] || return 1
  case ",$shimmy_uninstall_csv_haystack," in
    *,"$shimmy_uninstall_csv_needle",*) return 0 ;;
    *) return 1 ;;
  esac
}

shimmy_uninstall_csv_append() {
  shimmy_uninstall_csv_append_value=$1
  shimmy_uninstall_csv_append_item=$2
  shimmy_engine_id_validate "$shimmy_uninstall_csv_append_item" || return 1
  if [ "$shimmy_uninstall_csv_append_value" = none ]; then
    printf '%s\n' "$shimmy_uninstall_csv_append_item"
  else
    shimmy_uninstall_csv_contains "$shimmy_uninstall_csv_append_value" \
      "$shimmy_uninstall_csv_append_item" && return 1
    printf '%s,%s\n' "$shimmy_uninstall_csv_append_value" \
      "$shimmy_uninstall_csv_append_item"
  fi
}

shimmy_uninstall_csv_remove() {
  shimmy_uninstall_csv_remove_value=$1
  shimmy_uninstall_csv_remove_item=$2
  shimmy_uninstall_csv_validate "$shimmy_uninstall_csv_remove_value" || return 1
  shimmy_engine_id_validate "$shimmy_uninstall_csv_remove_item" || return 1
  [ "$shimmy_uninstall_csv_remove_value" != none ] || return 1
  shimmy_uninstall_csv_remove_result=none
  shimmy_uninstall_csv_remove_found=0
  shimmy_uninstall_csv_remove_rest=$shimmy_uninstall_csv_remove_value
  while :; do
    shimmy_uninstall_csv_remove_current=${shimmy_uninstall_csv_remove_rest%%,*}
    if [ "$shimmy_uninstall_csv_remove_current" = \
      "$shimmy_uninstall_csv_remove_item" ]; then
      shimmy_uninstall_csv_remove_found=1
    else
      shimmy_uninstall_csv_remove_result=$(shimmy_uninstall_csv_append \
        "$shimmy_uninstall_csv_remove_result" \
        "$shimmy_uninstall_csv_remove_current") || return 1
    fi
    [ "$shimmy_uninstall_csv_remove_rest" != \
      "$shimmy_uninstall_csv_remove_current" ] || break
    shimmy_uninstall_csv_remove_rest=${shimmy_uninstall_csv_remove_rest#*,}
  done
  [ "$shimmy_uninstall_csv_remove_found" -eq 1 ] || return 1
  printf '%s\n' "$shimmy_uninstall_csv_remove_result"
}

shimmy_uninstall_preserved_validate() {
  shimmy_uninstall_preserved_value=$1
  [ "$shimmy_uninstall_preserved_value" != none ] || return 0
  [ -n "$shimmy_uninstall_preserved_value" ] || return 1
  shimmy_uninstall_preserved_seen=
  shimmy_uninstall_preserved_rest=$shimmy_uninstall_preserved_value
  while :; do
    shimmy_uninstall_preserved_item=${shimmy_uninstall_preserved_rest%%,*}
    shimmy_uninstall_preserved_id=${shimmy_uninstall_preserved_item%%:*}
    shimmy_uninstall_preserved_reason=${shimmy_uninstall_preserved_item#*:}
    [ "$shimmy_uninstall_preserved_reason" != "$shimmy_uninstall_preserved_item" ] || return 1
    shimmy_engine_id_validate "$shimmy_uninstall_preserved_id" || return 1
    shimmy_version_token_validate "$shimmy_uninstall_preserved_reason" || return 1
    shimmy_contains_line_list "$shimmy_uninstall_preserved_seen" \
      "$shimmy_uninstall_preserved_id" && return 1
    shimmy_uninstall_preserved_seen=$(shimmy_append_line_list \
      "$shimmy_uninstall_preserved_seen" "$shimmy_uninstall_preserved_id")
    [ "$shimmy_uninstall_preserved_rest" != "$shimmy_uninstall_preserved_item" ] || break
    shimmy_uninstall_preserved_rest=${shimmy_uninstall_preserved_rest#*,}
    [ -n "$shimmy_uninstall_preserved_rest" ] || return 1
  done
}

shimmy_uninstall_preserved_append() {
  shimmy_uninstall_preserved_append_value=$1
  shimmy_uninstall_preserved_append_id=$2
  shimmy_uninstall_preserved_append_reason=$3
  shimmy_engine_id_validate "$shimmy_uninstall_preserved_append_id" || return 1
  shimmy_version_token_validate "$shimmy_uninstall_preserved_append_reason" || return 1
  case ",$shimmy_uninstall_preserved_append_value," in
    *,"$shimmy_uninstall_preserved_append_id":*) return 1 ;;
  esac
  if [ "$shimmy_uninstall_preserved_append_value" = none ]; then
    printf '%s:%s\n' "$shimmy_uninstall_preserved_append_id" \
      "$shimmy_uninstall_preserved_append_reason"
  else
    printf '%s,%s:%s\n' "$shimmy_uninstall_preserved_append_value" \
      "$shimmy_uninstall_preserved_append_id" \
      "$shimmy_uninstall_preserved_append_reason"
  fi
}

shimmy_uninstall_preserved_contains() {
  shimmy_uninstall_preserved_haystack=$1
  shimmy_uninstall_preserved_needle=$2
  [ "$shimmy_uninstall_preserved_haystack" != none ] || return 1
  case ",$shimmy_uninstall_preserved_haystack," in
    *,"$shimmy_uninstall_preserved_needle":*) return 0 ;;
    *) return 1 ;;
  esac
}

shimmy_uninstall_journal_render() {
  shimmy_uninstall_journal_phase=$1
  shimmy_uninstall_journal_host=$2
  shimmy_uninstall_journal_active=$3
  shimmy_uninstall_journal_acknowledged=$4
  shimmy_uninstall_journal_planned=$5
  shimmy_uninstall_journal_completed=$6
  shimmy_uninstall_journal_pending=$7
  shimmy_uninstall_journal_skipped=$8
  shimmy_uninstall_journal_preserved=$9
  case "$shimmy_uninstall_journal_phase" in
    planned|removing-engines|configuration) ;;
    *) return 1 ;;
  esac
  case "$shimmy_uninstall_journal_host" in darwin|linux) ;; *) return 1 ;; esac
  case "$shimmy_uninstall_journal_acknowledged" in yes|no) ;; *) return 1 ;; esac
  shimmy_engine_id_validate "$shimmy_uninstall_journal_active" || return 1
  for shimmy_uninstall_journal_list in "$shimmy_uninstall_journal_planned" \
    "$shimmy_uninstall_journal_completed" "$shimmy_uninstall_journal_pending" \
    "$shimmy_uninstall_journal_skipped"; do
    shimmy_uninstall_csv_validate "$shimmy_uninstall_journal_list" || return 1
  done
  shimmy_uninstall_preserved_validate "$shimmy_uninstall_journal_preserved" || return 1
  for shimmy_uninstall_journal_id in $(printf '%s\n' \
    "$shimmy_uninstall_journal_completed,$shimmy_uninstall_journal_pending,$shimmy_uninstall_journal_skipped" | \
    tr ',' ' '); do
    [ "$shimmy_uninstall_journal_id" = none ] && continue
    shimmy_uninstall_csv_contains "$shimmy_uninstall_journal_planned" \
      "$shimmy_uninstall_journal_id" || return 1
  done
  if [ "$shimmy_uninstall_journal_planned" = none ]; then
    [ "$shimmy_uninstall_journal_completed|$shimmy_uninstall_journal_pending|$shimmy_uninstall_journal_skipped" = \
      'none|none|none' ] || return 1
  else
    shimmy_uninstall_journal_partition_rest=$shimmy_uninstall_journal_planned
    while :; do
      shimmy_uninstall_journal_partition_id=${shimmy_uninstall_journal_partition_rest%%,*}
      shimmy_uninstall_journal_partition_count=0
      for shimmy_uninstall_journal_partition_list in \
        "$shimmy_uninstall_journal_completed" \
        "$shimmy_uninstall_journal_pending" \
        "$shimmy_uninstall_journal_skipped"; do
        if shimmy_uninstall_csv_contains \
          "$shimmy_uninstall_journal_partition_list" \
          "$shimmy_uninstall_journal_partition_id"; then
          shimmy_uninstall_journal_partition_count=$((shimmy_uninstall_journal_partition_count + 1))
        fi
      done
      [ "$shimmy_uninstall_journal_partition_count" -eq 1 ] || return 1
      [ "$shimmy_uninstall_journal_partition_rest" != \
        "$shimmy_uninstall_journal_partition_id" ] || break
      shimmy_uninstall_journal_partition_rest=${shimmy_uninstall_journal_partition_rest#*,}
    done
  fi
  if [ "$shimmy_uninstall_journal_skipped" != none ]; then
    shimmy_uninstall_journal_skipped_rest=$shimmy_uninstall_journal_skipped
    while :; do
      shimmy_uninstall_journal_skipped_id=${shimmy_uninstall_journal_skipped_rest%%,*}
      shimmy_uninstall_preserved_contains "$shimmy_uninstall_journal_preserved" \
        "$shimmy_uninstall_journal_skipped_id" || return 1
      [ "$shimmy_uninstall_journal_skipped_rest" != \
        "$shimmy_uninstall_journal_skipped_id" ] || break
      shimmy_uninstall_journal_skipped_rest=${shimmy_uninstall_journal_skipped_rest#*,}
    done
  fi
  printf '%s\n' 'shimmy_uninstall_version=1'
  printf 'phase=%s\n' "$shimmy_uninstall_journal_phase"
  printf 'host_os=%s\n' "$shimmy_uninstall_journal_host"
  printf 'active_engine=%s\n' "$shimmy_uninstall_journal_active"
  printf 'workloads_acknowledged=%s\n' "$shimmy_uninstall_journal_acknowledged"
  printf 'planned_engines=%s\n' "$shimmy_uninstall_journal_planned"
  printf 'completed_engines=%s\n' "$shimmy_uninstall_journal_completed"
  printf 'pending_engines=%s\n' "$shimmy_uninstall_journal_pending"
  printf 'skipped_engines=%s\n' "$shimmy_uninstall_journal_skipped"
  printf 'preserved_engines=%s\n' "$shimmy_uninstall_journal_preserved"
}

shimmy_uninstall_journal_read() {
  shimmy_uninstall_journal_read_path=$1
  shimmy_engine_state_file_validate "$shimmy_uninstall_journal_read_path" || return 1
  SHIMMY_UNINSTALL_JOURNAL_PHASE=$(sed -n '2s/^phase=//p' "$shimmy_uninstall_journal_read_path")
  SHIMMY_UNINSTALL_JOURNAL_HOST_OS=$(sed -n '3s/^host_os=//p' "$shimmy_uninstall_journal_read_path")
  SHIMMY_UNINSTALL_JOURNAL_ACTIVE_ENGINE=$(sed -n '4s/^active_engine=//p' "$shimmy_uninstall_journal_read_path")
  SHIMMY_UNINSTALL_JOURNAL_WORKLOADS_ACKNOWLEDGED=$(sed -n '5s/^workloads_acknowledged=//p' "$shimmy_uninstall_journal_read_path")
  SHIMMY_UNINSTALL_JOURNAL_PLANNED=$(sed -n '6s/^planned_engines=//p' "$shimmy_uninstall_journal_read_path")
  SHIMMY_UNINSTALL_JOURNAL_COMPLETED=$(sed -n '7s/^completed_engines=//p' "$shimmy_uninstall_journal_read_path")
  SHIMMY_UNINSTALL_JOURNAL_PENDING=$(sed -n '8s/^pending_engines=//p' "$shimmy_uninstall_journal_read_path")
  SHIMMY_UNINSTALL_JOURNAL_SKIPPED=$(sed -n '9s/^skipped_engines=//p' "$shimmy_uninstall_journal_read_path")
  SHIMMY_UNINSTALL_JOURNAL_PRESERVED=$(sed -n '10s/^preserved_engines=//p' "$shimmy_uninstall_journal_read_path")
  [ "$(shimmy_uninstall_journal_render "$SHIMMY_UNINSTALL_JOURNAL_PHASE" \
    "$SHIMMY_UNINSTALL_JOURNAL_HOST_OS" "$SHIMMY_UNINSTALL_JOURNAL_ACTIVE_ENGINE" \
    "$SHIMMY_UNINSTALL_JOURNAL_WORKLOADS_ACKNOWLEDGED" \
    "$SHIMMY_UNINSTALL_JOURNAL_PLANNED" "$SHIMMY_UNINSTALL_JOURNAL_COMPLETED" \
    "$SHIMMY_UNINSTALL_JOURNAL_PENDING" "$SHIMMY_UNINSTALL_JOURNAL_SKIPPED" \
    "$SHIMMY_UNINSTALL_JOURNAL_PRESERVED")" = \
    "$(cat "$shimmy_uninstall_journal_read_path")" ]
}

shimmy_uninstall_journal_write() {
  shimmy_uninstall_journal_write_config=$1
  shift
  SHIMMY_UNINSTALL_JOURNAL_PATH=$shimmy_uninstall_journal_write_config/.uninstall.conf
  shimmy_uninstall_journal_write_stage=$shimmy_uninstall_journal_write_config/.uninstall.tmp.$$
  [ -d "$shimmy_uninstall_journal_write_config" ] &&
    [ ! -L "$shimmy_uninstall_journal_write_config" ] || return 1
  [ ! -e "$shimmy_uninstall_journal_write_stage" ] &&
    [ ! -L "$shimmy_uninstall_journal_write_stage" ] || return 1
  shimmy_uninstall_journal_render "$@" > "$shimmy_uninstall_journal_write_stage" || {
    rm -f "$shimmy_uninstall_journal_write_stage"
    return 1
  }
  chmod 0644 "$shimmy_uninstall_journal_write_stage" || {
    rm -f "$shimmy_uninstall_journal_write_stage"
    return 1
  }
  shimmy_uninstall_journal_read "$shimmy_uninstall_journal_write_stage" || {
    rm -f "$shimmy_uninstall_journal_write_stage"
    return 1
  }
  mv "$shimmy_uninstall_journal_write_stage" "$SHIMMY_UNINSTALL_JOURNAL_PATH"
}

shimmy_profile_active_link_restore() {
  shimmy_profile_active_link_restore_path=$1
  shimmy_profile_active_link_restore_prior=$2
  shimmy_profile_active_link_restore_committed=$3
  [ "$shimmy_profile_active_link_restore_committed" = absent ] || return 1
  [ ! -e "$shimmy_profile_active_link_restore_path" ] &&
    [ ! -L "$shimmy_profile_active_link_restore_path" ] || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_profile_active_link_restore_prior" || return 1
  shimmy_profile_active_link_restore_stage=$(dirname -- "$shimmy_profile_active_link_restore_path")/.shimmy-active-profile.uninstall-rollback.$$
  [ ! -e "$shimmy_profile_active_link_restore_stage" ] &&
    [ ! -L "$shimmy_profile_active_link_restore_stage" ] || return 1
  ln -s "$shimmy_profile_active_link_restore_prior" \
    "$shimmy_profile_active_link_restore_stage" || return 1
  mv "$shimmy_profile_active_link_restore_stage" "$shimmy_profile_active_link_restore_path"
}

shimmy_profile_engine_state_remove() {
  shimmy_profile_engine_state_remove_config=$1
  shimmy_profile_engine_state_remove_id=$2
  shimmy_engine_paths_resolve "$shimmy_profile_engine_state_remove_config" \
    "$shimmy_profile_engine_state_remove_id" || return 1
  for shimmy_profile_engine_state_remove_path in \
    "$SHIMMY_ENGINE_REGISTRIES_PATH" "$SHIMMY_ENGINE_PROJECTION_PATH" \
    "$SHIMMY_ENGINE_RECORD_PATH"; do
    if [ -e "$shimmy_profile_engine_state_remove_path" ] ||
      [ -L "$shimmy_profile_engine_state_remove_path" ]; then
      [ -f "$shimmy_profile_engine_state_remove_path" ] &&
        [ ! -L "$shimmy_profile_engine_state_remove_path" ] || return 1
      rm -f "$shimmy_profile_engine_state_remove_path" || return 1
    fi
  done
}

shimmy_profile_delete_removed_resume() {
  shimmy_profile_delete_resume_config=$1
  shimmy_profile_delete_resume_name=$2
  shimmy_profile_delete_resume_dry=$3
  shimmy_profile_state_paths_resolve "$shimmy_profile_delete_resume_config" \
    "$shimmy_profile_delete_resume_name" || return 1
  if [ -d "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ]; then
    shimmy_profile_delete_resume_root_state=present
  elif [ ! -e "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ]; then
    shimmy_profile_delete_resume_root_state=absent
  else
    return 2
  fi
  shimmy_profile_delete_resume_id=profile-$shimmy_profile_delete_resume_name
  shimmy_engine_paths_resolve "$shimmy_profile_delete_resume_config" \
    "$shimmy_profile_delete_resume_id" || return 1
  [ -f "$SHIMMY_ENGINE_RECORD_PATH" ] && [ ! -L "$SHIMMY_ENGINE_RECORD_PATH" ] &&
    [ -f "$SHIMMY_ENGINE_LIFECYCLE_PATH" ] && [ ! -L "$SHIMMY_ENGINE_LIFECYCLE_PATH" ] || return 2
  shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
  shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  [ "$SHIMMY_ENGINE_RECORD_ID|$SHIMMY_ENGINE_LIFECYCLE_ID|$SHIMMY_ENGINE_LIFECYCLE_OPERATION" = \
    "$shimmy_profile_delete_resume_id|$shimmy_profile_delete_resume_id|remove" ] || return 1
  [ "$SHIMMY_ENGINE_LIFECYCLE_PHASE" = removed ] || return 2
  [ "$SHIMMY_ENGINE_RECORD_KIND|$SHIMMY_ENGINE_RECORD_ORIGIN" = \
    'darwin-machine|shimmy-created' ] || return 1
  if [ "$shimmy_profile_delete_resume_dry" -eq 1 ]; then
    printf 'dry_run=yes\nprofile=%s\nbinding_mode=isolated\nengine_id=%s\n' \
      "$shimmy_profile_delete_resume_name" "$shimmy_profile_delete_resume_id"
    printf '%s\n' 'engine_origin=shimmy-created' 'ownership=owned' \
      'deletion_action=resume-cleanup' \
      'irreversible_vm_data=containers,images,volumes,build-cache,all-vm-local-data'
    return 0
  fi
  shimmy_lock_acquire activation "$shimmy_profile_delete_resume_config" || return 1
  if [ "$shimmy_profile_delete_resume_root_state" = present ]; then
    shimmy_lock_acquire profile "$shimmy_profile_delete_resume_config" \
      "$shimmy_profile_delete_resume_name" || return 1
    shimmy_lock_acquire registry "$shimmy_profile_delete_resume_config" \
      "$shimmy_profile_delete_resume_name" || return 1
  fi
  shimmy_profile_installation_context_resolve "$shimmy_profile_delete_resume_config" || return 1
  [ "$SHIMMY_PROFILE_ACTIVE_NAME" != "$shimmy_profile_delete_resume_name" ] || return 1
  shimmy_profile_state_paths_resolve "$shimmy_profile_delete_resume_config" \
    "$shimmy_profile_delete_resume_name" || return 1
  if [ "$shimmy_profile_delete_resume_root_state" = present ]; then
    [ -d "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ] || return 1
    shimmy_profile_owned_assets_remove "$shimmy_profile_delete_resume_config" \
      "$shimmy_profile_delete_resume_name" || return 1
    shimmy_lock_release || return 1
    shimmy_lock_release || return 1
    rmdir "$SHIMMY_PROFILE_ROOT" || return 1
  else
    [ ! -e "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ] || return 1
  fi
  shimmy_engine_paths_resolve "$shimmy_profile_delete_resume_config" \
    "$shimmy_profile_delete_resume_id" || return 1
  shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
  shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  [ "$SHIMMY_ENGINE_RECORD_ID|$SHIMMY_ENGINE_LIFECYCLE_ID|$SHIMMY_ENGINE_LIFECYCLE_OPERATION|$SHIMMY_ENGINE_LIFECYCLE_PHASE" = \
    "$shimmy_profile_delete_resume_id|$shimmy_profile_delete_resume_id|remove|removed" ] || return 1
  shimmy_profile_engine_state_remove "$shimmy_profile_delete_resume_config" \
    "$shimmy_profile_delete_resume_id" || return 1
  shimmy_engine_paths_resolve "$shimmy_profile_delete_resume_config" \
    "$shimmy_profile_delete_resume_id" || return 1
  shimmy_engine_machine_remove_commit "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  rmdir "$SHIMMY_ENGINE_ROOT" || return 1
  shimmy_locks_release_all || return 1
  printf 'Completed interrupted deletion of isolated Shimmy profile %s.\n' \
    "$shimmy_profile_delete_resume_name"
}

shimmy_profile_delete_run() {
  shimmy_profile_delete_config=$1
  shimmy_profile_delete_name=$2
  shimmy_profile_delete_stop=$3
  shimmy_profile_delete_dry=${4:-0}
  shimmy_name_component_validate "$shimmy_profile_delete_name" || return 1
  case "$shimmy_profile_delete_stop:$shimmy_profile_delete_dry" in
    [01]:[01]) ;; *) return 1 ;;
  esac
  [ "$shimmy_profile_delete_name" != default ] || {
    SHIMMY_UNINSTALL_ERROR='the default Shimmy profile cannot be deleted'
    return 1
  }
  shimmy_profile_installation_context_resolve "$shimmy_profile_delete_config" || return 1
  [ "$SHIMMY_PROFILE_ACTIVE_NAME" != "$shimmy_profile_delete_name" ] || {
    SHIMMY_UNINSTALL_ERROR="the active Shimmy profile cannot be deleted: $shimmy_profile_delete_name"
    return 1
  }
  if shimmy_profile_delete_removed_resume "$shimmy_profile_delete_config" \
    "$shimmy_profile_delete_name" "$shimmy_profile_delete_dry"; then
    return 0
  else
    [ "$?" -eq 2 ] || return 1
  fi
  shimmy_profile_owned_root_validate "$shimmy_profile_delete_config" \
    "$shimmy_profile_delete_name" 0 || return 1
  shimmy_profile_engine_context_resolve "$shimmy_profile_delete_config" \
    "$shimmy_profile_delete_name" || return 1
  shimmy_profile_delete_mode=$SHIMMY_PROFILE_ENGINE_BINDING_MODE
  shimmy_profile_delete_engine_id=$SHIMMY_PROFILE_ENGINE_ID
  shimmy_profile_delete_origin=$SHIMMY_PROFILE_ENGINE_ORIGIN
  shimmy_profile_delete_engine_record=$SHIMMY_PROFILE_ENGINE_RECORD_PATH
  shimmy_profile_activation_host_os_resolve
  shimmy_profile_delete_host_os=$SHIMMY_PROFILE_HOST_OS
  shimmy_profile_delete_engine_action=preserve
  shimmy_profile_delete_ownership=not-applicable
  if [ "$shimmy_profile_delete_host_os" = darwin ] &&
    [ "$shimmy_profile_delete_mode" = isolated ] &&
    [ "$shimmy_profile_delete_origin" = shimmy-created ]; then
    shimmy_engine_podman_bin_require || return 1
    shimmy_engine_paths_resolve "$shimmy_profile_delete_config" \
      "$shimmy_profile_delete_engine_id" || return 1
    if [ -e "$SHIMMY_ENGINE_LIFECYCLE_PATH" ] || [ -L "$SHIMMY_ENGINE_LIFECYCLE_PATH" ]; then
      shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
      [ "$SHIMMY_ENGINE_LIFECYCLE_ID|$SHIMMY_ENGINE_LIFECYCLE_OPERATION" = \
        "$shimmy_profile_delete_engine_id|remove" ] || return 1
      shimmy_profile_delete_ownership=owned
      shimmy_profile_delete_engine_action=resume-remove
      if [ "$SHIMMY_ENGINE_LIFECYCLE_INITIAL_MACHINE_STATE" = running ] &&
        [ "$shimmy_profile_delete_stop" -eq 0 ]; then
        SHIMMY_UNINSTALL_ERROR='interrupted isolated deletion stopped a running machine; retry with --stop-running acknowledgement'
        return 1
      fi
    else
      shimmy_engine_ownership_host_state_read "$shimmy_profile_delete_engine_record"
      shimmy_profile_delete_ownership=$SHIMMY_ENGINE_OWNERSHIP_STATE
      if [ "$shimmy_profile_delete_ownership" = owned ]; then
        shimmy_profile_delete_engine_action=remove
        if [ "$SHIMMY_ENGINE_MACHINE_STATE" = running ]; then
          shimmy_engine_ownership_state_read "$shimmy_profile_delete_engine_record"
          shimmy_profile_delete_ownership=$SHIMMY_ENGINE_OWNERSHIP_STATE
          if [ "$shimmy_profile_delete_ownership" != owned ]; then
            shimmy_profile_delete_engine_action=preserve
          fi
        fi
        if [ "$shimmy_profile_delete_engine_action" = remove ] &&
          [ "$SHIMMY_ENGINE_MACHINE_STATE" = running ]; then
          shimmy_engine_podman_workloads_read "$SHIMMY_ENGINE_RECORD_CONNECTION" || return 1
          if [ -n "$SHIMMY_ENGINE_RUNNING_WORKLOADS" ]; then
            printf 'Running containers on %s:\n%s\n' "$SHIMMY_ENGINE_RECORD_NAME" \
              "$SHIMMY_ENGINE_RUNNING_WORKLOADS"
          fi
          if [ "$SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT" -gt 0 ] &&
            [ "$shimmy_profile_delete_stop" -eq 0 ]; then
            SHIMMY_UNINSTALL_ERROR='running containers block isolated profile deletion; retry with explicit --stop-running acknowledgement'
            return 1
          fi
        elif [ "$shimmy_profile_delete_stop" -eq 1 ]; then
          SHIMMY_UNINSTALL_ERROR='--stop-running is valid only when isolated profile deletion must stop a running machine'
          return 1
        fi
      elif [ "$shimmy_profile_delete_stop" -eq 1 ]; then
        SHIMMY_UNINSTALL_ERROR='--stop-running cannot authorize deletion of an external or ambiguous machine'
        return 1
      fi
    fi
  fi
  if [ "$shimmy_profile_delete_dry" -eq 1 ]; then
    printf 'dry_run=yes\nprofile=%s\nbinding_mode=%s\nengine_id=%s\n' \
      "$shimmy_profile_delete_name" "$shimmy_profile_delete_mode" \
      "$shimmy_profile_delete_engine_id"
    printf 'engine_origin=%s\nownership=%s\ndeletion_action=%s\n' \
      "$shimmy_profile_delete_origin" "$shimmy_profile_delete_ownership" \
      "$shimmy_profile_delete_engine_action"
    if [ "$shimmy_profile_delete_engine_action" = remove ] ||
      [ "$shimmy_profile_delete_engine_action" = resume-remove ]; then
      printf '%s\n' 'irreversible_vm_data=containers,images,volumes,build-cache,all-vm-local-data'
    fi
    return 0
  fi
  shimmy_lock_acquire activation "$shimmy_profile_delete_config" || return 1
  shimmy_lock_acquire profile "$shimmy_profile_delete_config" \
    "$shimmy_profile_delete_name" || return 1
  shimmy_lock_acquire registry "$shimmy_profile_delete_config" \
    "$shimmy_profile_delete_name" || return 1
  shimmy_profile_installation_context_resolve "$shimmy_profile_delete_config" || return 1
  [ "$SHIMMY_PROFILE_ACTIVE_NAME" != "$shimmy_profile_delete_name" ] || return 1
  shimmy_profile_owned_root_validate "$shimmy_profile_delete_config" \
    "$shimmy_profile_delete_name" 1 || return 1
  shimmy_profile_engine_context_resolve "$shimmy_profile_delete_config" \
    "$shimmy_profile_delete_name" || return 1
  [ "$SHIMMY_PROFILE_ENGINE_BINDING_MODE|$SHIMMY_PROFILE_ENGINE_ID|$SHIMMY_PROFILE_ENGINE_ORIGIN" = \
    "$shimmy_profile_delete_mode|$shimmy_profile_delete_engine_id|$shimmy_profile_delete_origin" ] || {
    SHIMMY_UNINSTALL_ERROR='profile engine binding changed while deletion was waiting for locks'
    return 1
  }
  if [ "$shimmy_profile_delete_engine_action" = remove ] ||
    [ "$shimmy_profile_delete_engine_action" = resume-remove ]; then
    shimmy_engine_paths_resolve "$shimmy_profile_delete_config" \
      "$shimmy_profile_delete_engine_id" || return 1
    if [ "$shimmy_profile_delete_engine_action" = remove ]; then
      shimmy_engine_ownership_host_state_read "$SHIMMY_ENGINE_RECORD_PATH"
      [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || {
        SHIMMY_UNINSTALL_ERROR='isolated engine ownership changed while deletion was waiting for locks; machine preserved'
        return 1
      }
      if [ "$SHIMMY_ENGINE_MACHINE_STATE" = running ]; then
        shimmy_engine_ownership_state_read "$SHIMMY_ENGINE_RECORD_PATH"
        [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || {
          SHIMMY_UNINSTALL_ERROR='isolated engine guest ownership changed while deletion was waiting for locks; machine preserved'
          return 1
        }
        shimmy_engine_podman_workloads_read "$SHIMMY_ENGINE_RECORD_CONNECTION" || return 1
        if [ "$SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT" -gt 0 ] &&
          [ "$shimmy_profile_delete_stop" -eq 0 ]; then
          SHIMMY_UNINSTALL_ERROR='running containers appeared while deletion was waiting for locks; retry with explicit --stop-running acknowledgement'
          return 1
        fi
      fi
    else
      shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
      shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
      [ "$SHIMMY_ENGINE_LIFECYCLE_ID|$SHIMMY_ENGINE_LIFECYCLE_OPERATION" = \
        "$shimmy_profile_delete_engine_id|remove" ] || return 1
    fi
    printf 'WARNING: deleting owned isolated Podman machine %s permanently destroys its containers, images, volumes, build cache, and all other VM-local data.\n' \
      "$SHIMMY_ENGINE_RECORD_NAME" >&2
    if [ "$shimmy_profile_delete_engine_action" = remove ]; then
      shimmy_engine_machine_remove_prepare "$SHIMMY_ENGINE_RECORD_PATH" \
        "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
    fi
    shimmy_engine_machine_remove_apply "$SHIMMY_ENGINE_RECORD_PATH" \
      "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
    if [ "${SHIMMY_TEST_PROFILE_DELETE_FAILURE:-}" = after-machine-remove ]; then
      SHIMMY_UNINSTALL_ERROR='injected failure after isolated machine removal; retry the same profile delete command'
      return 1
    fi
  else
    shimmy_profile_projection_cleanup "$shimmy_profile_delete_config" \
      "$shimmy_profile_delete_name" "$shimmy_profile_delete_stop" || return 1
  fi
  shimmy_profile_owned_assets_remove "$shimmy_profile_delete_config" \
    "$shimmy_profile_delete_name" || return 1
  shimmy_locks_release_all || return 1
  shimmy_profile_state_paths_resolve "$shimmy_profile_delete_config" \
    "$shimmy_profile_delete_name" || return 1
  rmdir "$SHIMMY_PROFILE_ROOT" || return 1
  if [ "$shimmy_profile_delete_mode" != shared ] &&
    [ "$shimmy_profile_delete_host_os" = darwin ]; then
    shimmy_profile_engine_state_remove "$shimmy_profile_delete_config" \
      "$shimmy_profile_delete_engine_id" || return 1
    shimmy_engine_paths_resolve "$shimmy_profile_delete_config" \
      "$shimmy_profile_delete_engine_id" || return 1
    if [ "$shimmy_profile_delete_engine_action" = remove ] ||
      [ "$shimmy_profile_delete_engine_action" = resume-remove ]; then
      shimmy_engine_machine_remove_commit "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
    fi
    rmdir "$SHIMMY_ENGINE_ROOT" || return 1
  fi
  if [ "$shimmy_profile_delete_engine_action" = preserve ] &&
    [ "$shimmy_profile_delete_host_os" = darwin ] &&
    [ "$shimmy_profile_delete_mode" != shared ]; then
    printf 'Preserved external or ambiguous Podman machine for profile %s.\n' \
      "$shimmy_profile_delete_name"
  fi
  printf 'Deleted inactive Shimmy profile %s.\n' "$shimmy_profile_delete_name"
}

shimmy_profile_owned_assets_remove() {
  shimmy_profile_owned_remove_config=$1
  shimmy_profile_owned_remove_name=$2
  shimmy_profile_state_paths_resolve "$shimmy_profile_owned_remove_config" \
    "$shimmy_profile_owned_remove_name" || return 1
  for shimmy_profile_owned_remove_entry in ai-skills bin commands config lib tools \
    engine-binding.conf install-manifest.txt registries.conf shell-init.sh; do
    shimmy_profile_owned_remove_path=$SHIMMY_PROFILE_ROOT/$shimmy_profile_owned_remove_entry
    if [ -d "$shimmy_profile_owned_remove_path" ] && [ ! -L "$shimmy_profile_owned_remove_path" ]; then
      rm -rf "$shimmy_profile_owned_remove_path" || return 1
    elif [ -e "$shimmy_profile_owned_remove_path" ] || [ -L "$shimmy_profile_owned_remove_path" ]; then
      rm -f "$shimmy_profile_owned_remove_path" || return 1
    fi
  done
}

shimmy_profile_owned_root_validate() {
  shimmy_profile_owned_config=$1
  shimmy_profile_owned_name=$2
  shimmy_profile_owned_locks=${3:-0}
  shimmy_profile_candidate_resolve "$shimmy_profile_owned_config" \
    "$shimmy_profile_owned_name" || return 1
  shimmy_profile_owned_root=$SHIMMY_PROFILE_CANDIDATE_ROOT
  for shimmy_profile_owned_entry in "$shimmy_profile_owned_root"/* \
    "$shimmy_profile_owned_root"/.[!.]* "$shimmy_profile_owned_root"/..?*; do
    [ -e "$shimmy_profile_owned_entry" ] || [ -L "$shimmy_profile_owned_entry" ] || continue
    shimmy_profile_owned_base=$(basename -- "$shimmy_profile_owned_entry")
    case "$shimmy_profile_owned_base" in
      ai-skills|bin|commands|config|lib|tools)
        [ -d "$shimmy_profile_owned_entry" ] && [ ! -L "$shimmy_profile_owned_entry" ] || return 1
        ;;
      engine-binding.conf|install-manifest.txt|registries.conf|shell-init.sh)
        [ -f "$shimmy_profile_owned_entry" ] && [ ! -L "$shimmy_profile_owned_entry" ] || return 1
        ;;
      .profile.lock|.registries.lock)
        [ "$shimmy_profile_owned_locks" -eq 1 ] &&
          [ -f "$shimmy_profile_owned_entry" ] && [ ! -L "$shimmy_profile_owned_entry" ] || return 1
        ;;
      *)
        SHIMMY_UNINSTALL_ERROR="unrecognized profile state blocks deletion: $shimmy_profile_owned_entry"
        return 1
        ;;
    esac
  done
}

shimmy_profile_projection_cleanup() {
  shimmy_profile_projection_config=$1
  shimmy_profile_projection_name=$2
  shimmy_profile_projection_stop=$3
  shimmy_profile_projection_strict_stop=${4:-1}
  shimmy_profile_projection_dry=${5:-0}
  case "$shimmy_profile_projection_stop:$shimmy_profile_projection_strict_stop:$shimmy_profile_projection_dry" in
    [01]:[01]:[01]) ;;
    *) return 1 ;;
  esac
  shimmy_profile_engine_context_resolve "$shimmy_profile_projection_config" \
    "$shimmy_profile_projection_name" || return 1
  shimmy_profile_activation_expected_resolve || return 1
  [ "$shimmy_profile_projection_stop" -eq 0 ] ||
    [ "$shimmy_profile_projection_strict_stop" -eq 0 ] || {
      SHIMMY_UNINSTALL_ERROR='--stop-running cannot authorize changes to a preserved engine'
      return 1
    }
  if [ "$shimmy_profile_projection_dry" -eq 1 ]; then
    printf 'projection_cleanup=%s|none|engine-state-preserved\n' \
      "$shimmy_profile_projection_name"
  fi
}

shimmy_startup_remove_apply() {
  shimmy_startup_remove_config=$1
  shimmy_startup_remove_files=${2:-}
  [ -n "$shimmy_startup_remove_files" ] || return 0
  shimmy_startup_remove_sequence=0
  SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP=$shimmy_startup_remove_config/.startup-backup.$$
  mkdir "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" || return 1
  while IFS= read -r shimmy_startup_remove_file; do
    [ -n "$shimmy_startup_remove_file" ] || continue
    [ -f "$shimmy_startup_remove_file" ] && [ ! -L "$shimmy_startup_remove_file" ] || return 1
    shimmy_startup_remove_sequence=$((shimmy_startup_remove_sequence + 1))
    shimmy_startup_remove_backup=$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP/$shimmy_startup_remove_sequence
    cp "$shimmy_startup_remove_file" "$shimmy_startup_remove_backup" || return 1
    shimmy_external_rollback_register "$shimmy_startup_remove_file" \
      shimmy_startup_restore "$shimmy_startup_remove_backup" present \
      'restore startup file removed during uninstall' || return 1
    shimmy_startup_block_remove "$shimmy_startup_remove_file" \
      "$SHIMMY_STARTUP_BLOCK_START" "$SHIMMY_STARTUP_BLOCK_END" || return 1
  done <<EOF
$shimmy_startup_remove_files
EOF
}

shimmy_uninstall_config_validate() {
  shimmy_uninstall_config=$1
  shimmy_uninstall_locks=${2:-0}
  shimmy_profile_installation_context_resolve "$shimmy_uninstall_config" || return 1
  SHIMMY_UNINSTALL_ACTIVE=$SHIMMY_PROFILE_ACTIVE_NAME
  SHIMMY_UNINSTALL_USER_ROOT=$SHIMMY_PROFILE_USER_SKILL_ROOT
  SHIMMY_UNINSTALL_PROFILES=
  for shimmy_uninstall_profile_path in "$SHIMMY_PROFILES_ROOT"/*; do
    [ -e "$shimmy_uninstall_profile_path" ] || [ -L "$shimmy_uninstall_profile_path" ] || continue
    shimmy_uninstall_profile_name=$(basename -- "$shimmy_uninstall_profile_path")
    shimmy_name_component_validate "$shimmy_uninstall_profile_name" || return 1
    shimmy_profile_owned_root_validate "$shimmy_uninstall_config" \
      "$shimmy_uninstall_profile_name" "$shimmy_uninstall_locks" || return 1
    SHIMMY_UNINSTALL_PROFILES=$(shimmy_append_line_list "$SHIMMY_UNINSTALL_PROFILES" \
      "$shimmy_uninstall_profile_name")
  done
  SHIMMY_UNINSTALL_PROFILES=$(printf '%s\n' "$SHIMMY_UNINSTALL_PROFILES" | sed '/^$/d' | LC_ALL=C sort)
  shimmy_contains_line_list "$SHIMMY_UNINSTALL_PROFILES" default || return 1
  for shimmy_uninstall_entry in "$shimmy_uninstall_config"/* \
    "$shimmy_uninstall_config"/.[!.]* "$shimmy_uninstall_config"/..?*; do
    [ -e "$shimmy_uninstall_entry" ] || [ -L "$shimmy_uninstall_entry" ] || continue
    shimmy_uninstall_base=$(basename -- "$shimmy_uninstall_entry")
    case "$shimmy_uninstall_base" in
      active-profile.conf) [ -f "$shimmy_uninstall_entry" ] && [ ! -L "$shimmy_uninstall_entry" ] || return 1 ;;
      catalogs|engines|profiles) [ -d "$shimmy_uninstall_entry" ] && [ ! -L "$shimmy_uninstall_entry" ] || return 1 ;;
      .uninstall.conf) shimmy_uninstall_journal_read "$shimmy_uninstall_entry" || return 1 ;;
      .catalog.lock|.activation.lock)
        [ "$shimmy_uninstall_locks" -eq 1 ] && [ -f "$shimmy_uninstall_entry" ] &&
          [ ! -L "$shimmy_uninstall_entry" ] || return 1
        ;;
      *) SHIMMY_UNINSTALL_ERROR="unrecognized installation-owned state blocks uninstall: $shimmy_uninstall_entry"; return 1 ;;
    esac
  done
}

shimmy_uninstall_links_apply() {
  shimmy_uninstall_links_user=$1
  shimmy_uninstall_links_profiles=$2
  for shimmy_uninstall_links_entry in "$shimmy_uninstall_links_user"/*; do
    [ -e "$shimmy_uninstall_links_entry" ] || [ -L "$shimmy_uninstall_links_entry" ] || continue
    [ -L "$shimmy_uninstall_links_entry" ] || continue
    shimmy_uninstall_links_target=$(readlink "$shimmy_uninstall_links_entry") || return 1
    case "$shimmy_uninstall_links_target" in
      "$shimmy_uninstall_links_profiles"/*)
        shimmy_ai_skill_link_recognized_read "$shimmy_uninstall_links_entry" \
          "$shimmy_uninstall_links_user" "$shimmy_uninstall_links_profiles" || return 1
        shimmy_ai_skill_link_remove_recognized "$shimmy_uninstall_links_user" \
          "$shimmy_uninstall_links_profiles" "$(basename -- "$shimmy_uninstall_links_entry")" || return 1
        ;;
    esac
  done
}

shimmy_uninstall_links_validate() {
  shimmy_uninstall_links_validate_user=$1
  shimmy_uninstall_links_validate_profiles=$2
  for shimmy_uninstall_links_validate_entry in \
    "$shimmy_uninstall_links_validate_user"/*; do
    [ -e "$shimmy_uninstall_links_validate_entry" ] ||
      [ -L "$shimmy_uninstall_links_validate_entry" ] || continue
    [ -L "$shimmy_uninstall_links_validate_entry" ] || continue
    shimmy_uninstall_links_validate_target=$(readlink \
      "$shimmy_uninstall_links_validate_entry") || return 1
    case "$shimmy_uninstall_links_validate_target" in
      "$shimmy_uninstall_links_validate_profiles"/*)
        shimmy_ai_skill_link_recognized_read \
          "$shimmy_uninstall_links_validate_entry" \
          "$shimmy_uninstall_links_validate_user" \
          "$shimmy_uninstall_links_validate_profiles" || return 1
        ;;
    esac
  done
}

shimmy_uninstall_startup_validate() {
  shimmy_uninstall_startup_files=${1:-}
  while IFS= read -r shimmy_uninstall_startup_file; do
    [ -n "$shimmy_uninstall_startup_file" ] || continue
    shimmy_path_absolute_normalized_validate "$shimmy_uninstall_startup_file" || return 1
    [ -f "$shimmy_uninstall_startup_file" ] &&
      [ ! -L "$shimmy_uninstall_startup_file" ] || return 1
  done <<EOF
$shimmy_uninstall_startup_files
EOF
}

shimmy_uninstall_engine_roots_validate() {
  shimmy_uninstall_engine_config=$1
  SHIMMY_UNINSTALL_ENGINE_IDS=
  if [ ! -e "$shimmy_uninstall_engine_config/engines" ] &&
    [ ! -L "$shimmy_uninstall_engine_config/engines" ]; then
    return 0
  fi
  [ -d "$shimmy_uninstall_engine_config/engines" ] &&
    [ ! -L "$shimmy_uninstall_engine_config/engines" ] || return 1
  for shimmy_uninstall_engine_root in "$shimmy_uninstall_engine_config"/engines/*; do
    [ -e "$shimmy_uninstall_engine_root" ] ||
      [ -L "$shimmy_uninstall_engine_root" ] || continue
    shimmy_uninstall_engine_id=$(basename -- "$shimmy_uninstall_engine_root")
    shimmy_engine_id_validate "$shimmy_uninstall_engine_id" &&
      [ -d "$shimmy_uninstall_engine_root" ] &&
      [ ! -L "$shimmy_uninstall_engine_root" ] || return 1
    shimmy_engine_paths_resolve "$shimmy_uninstall_engine_config" \
      "$shimmy_uninstall_engine_id" || return 1
    [ -f "$SHIMMY_ENGINE_RECORD_PATH" ] &&
      [ ! -L "$SHIMMY_ENGINE_RECORD_PATH" ] || return 1
    shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
    [ "$SHIMMY_ENGINE_RECORD_ID" = "$shimmy_uninstall_engine_id" ] || return 1
    for shimmy_uninstall_engine_entry in "$shimmy_uninstall_engine_root"/* \
      "$shimmy_uninstall_engine_root"/.[!.]* \
      "$shimmy_uninstall_engine_root"/..?*; do
      [ -e "$shimmy_uninstall_engine_entry" ] ||
        [ -L "$shimmy_uninstall_engine_entry" ] || continue
      shimmy_uninstall_engine_base=$(basename -- "$shimmy_uninstall_engine_entry")
      case "$shimmy_uninstall_engine_base" in
        engine.conf) ;;
        registries.conf)
          [ -f "$shimmy_uninstall_engine_entry" ] &&
            [ ! -L "$shimmy_uninstall_engine_entry" ] || return 1
          ;;
        projection.conf)
          shimmy_engine_projection_read "$shimmy_uninstall_engine_entry" || return 1
          [ "$SHIMMY_ENGINE_PROJECTION_ID" = "$shimmy_uninstall_engine_id" ] || return 1
          ;;
        lifecycle.conf)
          shimmy_engine_lifecycle_read "$shimmy_uninstall_engine_entry" || return 1
          [ "$SHIMMY_ENGINE_LIFECYCLE_ID" = "$shimmy_uninstall_engine_id" ] || return 1
          ;;
        *)
          SHIMMY_UNINSTALL_ERROR="unrecognized engine state blocks uninstall: $shimmy_uninstall_engine_entry"
          return 1
          ;;
      esac
    done
    SHIMMY_UNINSTALL_ENGINE_IDS=$(shimmy_append_line_list \
      "$SHIMMY_UNINSTALL_ENGINE_IDS" "$shimmy_uninstall_engine_id")
  done
  SHIMMY_UNINSTALL_ENGINE_IDS=$(printf '%s\n' "$SHIMMY_UNINSTALL_ENGINE_IDS" |
    sed '/^$/d' | LC_ALL=C sort)
  [ -n "$SHIMMY_UNINSTALL_ENGINE_IDS" ]
}

shimmy_uninstall_engine_preserved_reason_append() {
  shimmy_uninstall_engine_preserved_id=$1
  shimmy_uninstall_engine_preserved_reason=$2
  SHIMMY_UNINSTALL_ENGINE_PRESERVED=$(shimmy_uninstall_preserved_append \
    "$SHIMMY_UNINSTALL_ENGINE_PRESERVED" \
    "$shimmy_uninstall_engine_preserved_id" \
    "$shimmy_uninstall_engine_preserved_reason") || return 1
}

shimmy_uninstall_engine_target_append() {
  shimmy_uninstall_engine_target_id=$1
  shimmy_uninstall_engine_target_scope=$2
  if [ "$shimmy_uninstall_engine_target_id" = "$SHIMMY_UNINSTALL_ACTIVE_ENGINE" ]; then
    SHIMMY_UNINSTALL_ENGINE_ACTIVE_TARGET=$shimmy_uninstall_engine_target_id
  elif [ "$shimmy_uninstall_engine_target_scope" = profile ]; then
    SHIMMY_UNINSTALL_ENGINE_INACTIVE_ISOLATED=$(shimmy_append_line_list \
      "$SHIMMY_UNINSTALL_ENGINE_INACTIVE_ISOLATED" \
      "$shimmy_uninstall_engine_target_id")
  else
    SHIMMY_UNINSTALL_ENGINE_INACTIVE_SHARED=$shimmy_uninstall_engine_target_id
  fi
}

shimmy_uninstall_engine_plan_read() {
  shimmy_uninstall_engine_plan_config=$1
  shimmy_uninstall_engine_plan_stop=$2
  shimmy_profile_engine_context_resolve "$shimmy_uninstall_engine_plan_config" \
    "$SHIMMY_UNINSTALL_ACTIVE" || return 1
  shimmy_engine_profile_binding_resolve "$shimmy_uninstall_engine_plan_config" \
    "$SHIMMY_UNINSTALL_ACTIVE" || return 1
  SHIMMY_UNINSTALL_ACTIVE_ENGINE=$SHIMMY_PROFILE_ENGINE_ID
  shimmy_profile_activation_host_os_resolve
  SHIMMY_UNINSTALL_HOST_OS=$SHIMMY_PROFILE_HOST_OS
  shimmy_uninstall_engine_roots_validate "$shimmy_uninstall_engine_plan_config" || return 1
  SHIMMY_UNINSTALL_ENGINE_INACTIVE_ISOLATED=
  SHIMMY_UNINSTALL_ENGINE_INACTIVE_SHARED=
  SHIMMY_UNINSTALL_ENGINE_ACTIVE_TARGET=
  SHIMMY_UNINSTALL_ENGINE_PRESERVED=none
  SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP=0
  case "$SHIMMY_UNINSTALL_HOST_OS" in
    linux)
      [ "$shimmy_uninstall_engine_plan_stop" -eq 0 ] || {
        SHIMMY_UNINSTALL_ERROR='--stop-running is not supported for local Linux uninstall'
        return 1
      }
      ;;
    darwin) shimmy_engine_podman_bin_require || return 1 ;;
    *) return 1 ;;
  esac

  while IFS= read -r shimmy_uninstall_engine_plan_id; do
    [ -n "$shimmy_uninstall_engine_plan_id" ] || continue
    shimmy_engine_paths_resolve "$shimmy_uninstall_engine_plan_config" \
      "$shimmy_uninstall_engine_plan_id" || return 1
    shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
    shimmy_uninstall_engine_plan_kind=$SHIMMY_ENGINE_RECORD_KIND
    shimmy_uninstall_engine_plan_scope=$SHIMMY_ENGINE_RECORD_SCOPE
    shimmy_uninstall_engine_plan_origin=$SHIMMY_ENGINE_RECORD_ORIGIN
    shimmy_uninstall_engine_plan_name=$SHIMMY_ENGINE_RECORD_NAME
    shimmy_uninstall_engine_plan_connection=$SHIMMY_ENGINE_RECORD_CONNECTION
    shimmy_uninstall_engine_plan_action=preserve
    shimmy_uninstall_engine_plan_ownership=not-applicable
    shimmy_uninstall_engine_plan_reason=host-local
    shimmy_uninstall_engine_plan_state=not-applicable
    shimmy_uninstall_engine_plan_service=none
    shimmy_uninstall_engine_plan_workloads=0
    if [ "$SHIMMY_UNINSTALL_HOST_OS" = darwin ] &&
      [ "$shimmy_uninstall_engine_plan_kind" = darwin-machine ]; then
      if [ "$shimmy_uninstall_engine_plan_origin" != shimmy-created ]; then
        shimmy_uninstall_engine_plan_ownership=external
        shimmy_uninstall_engine_plan_reason=external-origin
        if shimmy_engine_podman_machine_state_read \
          "$shimmy_uninstall_engine_plan_name"; then
          shimmy_uninstall_engine_plan_state=$SHIMMY_ENGINE_MACHINE_STATE
        else
          shimmy_uninstall_engine_plan_state=unknown
          shimmy_uninstall_engine_plan_reason=machine-metadata-unavailable
        fi
      elif [ -e "$SHIMMY_ENGINE_LIFECYCLE_PATH" ] ||
        [ -L "$SHIMMY_ENGINE_LIFECYCLE_PATH" ]; then
        shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
        if [ "$SHIMMY_ENGINE_LIFECYCLE_OPERATION" != remove ]; then
          shimmy_uninstall_engine_plan_ownership=ambiguous
          shimmy_uninstall_engine_plan_reason=incomplete-create-lifecycle
          shimmy_uninstall_engine_plan_state=unknown
        else
          shimmy_engine_podman_machine_state_read \
            "$shimmy_uninstall_engine_plan_name" || return 1
          shimmy_uninstall_engine_plan_state=$SHIMMY_ENGINE_MACHINE_STATE
          if [ "$SHIMMY_ENGINE_LIFECYCLE_PHASE" = removed ]; then
            shimmy_engine_podman_connection_state_read \
              "$shimmy_uninstall_engine_plan_connection" || return 1
            [ "$SHIMMY_ENGINE_MACHINE_STATE|$SHIMMY_ENGINE_CONNECTION_STATE" = \
              'absent|absent' ] || {
              SHIMMY_UNINSTALL_ERROR="engine name reappeared after recorded removal: $shimmy_uninstall_engine_plan_id"
              return 1
            }
            shimmy_uninstall_engine_plan_ownership=owned
            shimmy_uninstall_engine_plan_action=resume-complete
          else
            shimmy_engine_ownership_host_state_read "$SHIMMY_ENGINE_RECORD_PATH"
            shimmy_uninstall_engine_plan_ownership=$SHIMMY_ENGINE_OWNERSHIP_STATE
            shimmy_uninstall_engine_plan_reason=$SHIMMY_ENGINE_OWNERSHIP_REASON
            shimmy_uninstall_engine_plan_state=$SHIMMY_ENGINE_MACHINE_STATE
            if [ "$shimmy_uninstall_engine_plan_ownership" = owned ]; then
              shimmy_uninstall_engine_plan_action=resume-remove
            fi
          fi
          if [ "$SHIMMY_ENGINE_LIFECYCLE_INITIAL_MACHINE_STATE" = running ]; then
            SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP=1
          fi
        fi
      else
        shimmy_engine_ownership_host_state_read "$SHIMMY_ENGINE_RECORD_PATH"
        shimmy_uninstall_engine_plan_ownership=$SHIMMY_ENGINE_OWNERSHIP_STATE
        shimmy_uninstall_engine_plan_reason=$SHIMMY_ENGINE_OWNERSHIP_REASON
        shimmy_uninstall_engine_plan_state=$SHIMMY_ENGINE_MACHINE_STATE
        if [ "$shimmy_uninstall_engine_plan_ownership" = owned ]; then
          shimmy_uninstall_engine_plan_action=remove
        fi
      fi
      if [ "$shimmy_uninstall_engine_plan_action" = remove ] ||
        [ "$shimmy_uninstall_engine_plan_action" = resume-remove ]; then
        case "$shimmy_uninstall_engine_plan_state" in
          running)
            shimmy_engine_ownership_state_read "$SHIMMY_ENGINE_RECORD_PATH"
            shimmy_uninstall_engine_plan_ownership=$SHIMMY_ENGINE_OWNERSHIP_STATE
            shimmy_uninstall_engine_plan_reason=$SHIMMY_ENGINE_OWNERSHIP_REASON
            if [ "$shimmy_uninstall_engine_plan_ownership" = owned ]; then
              shimmy_engine_podman_workloads_read \
                "$shimmy_uninstall_engine_plan_connection" || return 1
              shimmy_uninstall_engine_plan_workloads=$SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT
              while IFS='|' read -r shimmy_uninstall_engine_workload_id \
                shimmy_uninstall_engine_workload_name shimmy_uninstall_engine_workload_extra; do
                [ -n "$shimmy_uninstall_engine_workload_id" ] || continue
                [ -z "$shimmy_uninstall_engine_workload_extra" ] || return 1
                printf 'running_container=%s|%s|%s\n' \
                  "$shimmy_uninstall_engine_plan_id" \
                  "$shimmy_uninstall_engine_workload_id" \
                  "$shimmy_uninstall_engine_workload_name"
              done <<EOF
$SHIMMY_ENGINE_RUNNING_WORKLOADS
EOF
              shimmy_uninstall_engine_plan_service=stop
              if [ "$SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT" -gt 0 ]; then
                SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP=1
              fi
            else
              shimmy_uninstall_engine_plan_action=preserve
            fi
            ;;
          stopped) shimmy_uninstall_engine_plan_service=start-verify-stop ;;
          *) ;;
        esac
      fi
    fi
    if [ "$shimmy_uninstall_engine_plan_action" = remove ] ||
      [ "$shimmy_uninstall_engine_plan_action" = resume-remove ] ||
      [ "$shimmy_uninstall_engine_plan_action" = resume-complete ]; then
      shimmy_uninstall_engine_target_append "$shimmy_uninstall_engine_plan_id" \
        "$shimmy_uninstall_engine_plan_scope" || return 1
    else
      shimmy_uninstall_engine_preserved_reason_append \
        "$shimmy_uninstall_engine_plan_id" \
        "$shimmy_uninstall_engine_plan_reason" || return 1
    fi
    printf 'engine_id=%s|machine=%s|origin=%s|ownership=%s|machine_state=%s|service_action=%s|deletion_action=%s|running_workloads=%s' \
      "$shimmy_uninstall_engine_plan_id" "$shimmy_uninstall_engine_plan_name" \
      "$shimmy_uninstall_engine_plan_origin" "$shimmy_uninstall_engine_plan_ownership" \
      "$shimmy_uninstall_engine_plan_state" "$shimmy_uninstall_engine_plan_service" \
      "$shimmy_uninstall_engine_plan_action" "$shimmy_uninstall_engine_plan_workloads"
    if [ "$shimmy_uninstall_engine_plan_action" = preserve ]; then
      printf '|preservation_reason=%s' "$shimmy_uninstall_engine_plan_reason"
    fi
    printf '\n'
  done <<EOF
$SHIMMY_UNINSTALL_ENGINE_IDS
EOF
  SHIMMY_UNINSTALL_ENGINE_PLANNED=none
  while IFS= read -r shimmy_uninstall_engine_ordered; do
    [ -n "$shimmy_uninstall_engine_ordered" ] || continue
    SHIMMY_UNINSTALL_ENGINE_PLANNED=$(shimmy_uninstall_csv_append \
      "$SHIMMY_UNINSTALL_ENGINE_PLANNED" "$shimmy_uninstall_engine_ordered") || return 1
  done <<EOF
$SHIMMY_UNINSTALL_ENGINE_INACTIVE_ISOLATED
$SHIMMY_UNINSTALL_ENGINE_INACTIVE_SHARED
$SHIMMY_UNINSTALL_ENGINE_ACTIVE_TARGET
EOF
}

shimmy_uninstall_plan_render() {
  shimmy_uninstall_plan_dry=$1
  printf 'dry_run=%s\n' "$(if [ "$shimmy_uninstall_plan_dry" -eq 1 ]; then printf yes; else printf no; fi)"
  printf '%s\n' \
    'WARNING: uninstall permanently destroys containers, images, volumes, build caches, and all other VM-local data in every provably Shimmy-owned Podman machine.' \
    'irreversible_vm_data=containers,images,volumes,build-caches,all-other-vm-local-data'
  printf 'planned_engines=%s\npreserved_engines=%s\n' \
    "$SHIMMY_UNINSTALL_ENGINE_PLANNED" "$SHIMMY_UNINSTALL_ENGINE_PRESERVED"
}

shimmy_uninstall_projection_preflight() {
  shimmy_uninstall_projection_config=$1
  shimmy_uninstall_projection_profiles=$2
  shimmy_uninstall_projection_planned=$3
  shimmy_uninstall_projection_stop=$4
  while IFS= read -r shimmy_uninstall_projection_profile; do
    [ -n "$shimmy_uninstall_projection_profile" ] || continue
    shimmy_profile_engine_context_resolve "$shimmy_uninstall_projection_config" \
      "$shimmy_uninstall_projection_profile" || return 1
    if shimmy_uninstall_csv_contains "$shimmy_uninstall_projection_planned" \
      "$SHIMMY_PROFILE_ENGINE_ID"; then
      continue
    fi
    shimmy_profile_projection_cleanup "$shimmy_uninstall_projection_config" \
      "$shimmy_uninstall_projection_profile" "$shimmy_uninstall_projection_stop" \
      0 1 || return 1
  done <<EOF
$shimmy_uninstall_projection_profiles
EOF
}

shimmy_uninstall_failure_report() {
  shimmy_uninstall_failure_config=$1
  shimmy_uninstall_failure_reason=$2
  shimmy_uninstall_journal_read "$shimmy_uninstall_failure_config/.uninstall.conf" || return 1
  printf 'Uninstall stopped after its durable removal journal was created.\n' >&2
  printf 'Completed engines: %s\nPending engines: %s\nPreserved engines: %s\n' \
    "$SHIMMY_UNINSTALL_JOURNAL_COMPLETED" \
    "$SHIMMY_UNINSTALL_JOURNAL_PENDING" \
    "$SHIMMY_UNINSTALL_JOURNAL_PRESERVED" >&2
  printf 'Retry exactly: shimmy admin uninstall%s\n' \
    "$(if [ "$SHIMMY_UNINSTALL_JOURNAL_WORKLOADS_ACKNOWLEDGED" = yes ] || [ "$SHIMMY_UNINSTALL_STOP_RUNNING" -eq 1 ] || [ "$SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP" -eq 1 ]; then printf ' --stop-running'; fi)" >&2
  SHIMMY_UNINSTALL_ERROR=$shimmy_uninstall_failure_reason
  return 1
}

shimmy_uninstall_journal_transition() {
  shimmy_uninstall_journal_transition_config=$1
  shimmy_uninstall_journal_transition_phase=$2
  shimmy_uninstall_journal_read \
    "$shimmy_uninstall_journal_transition_config/.uninstall.conf" || return 1
  shimmy_uninstall_journal_write "$shimmy_uninstall_journal_transition_config" \
    "$shimmy_uninstall_journal_transition_phase" \
    "$SHIMMY_UNINSTALL_JOURNAL_HOST_OS" \
    "$SHIMMY_UNINSTALL_JOURNAL_ACTIVE_ENGINE" \
    "$SHIMMY_UNINSTALL_JOURNAL_WORKLOADS_ACKNOWLEDGED" \
    "$SHIMMY_UNINSTALL_JOURNAL_PLANNED" \
    "$SHIMMY_UNINSTALL_JOURNAL_COMPLETED" \
    "$SHIMMY_UNINSTALL_JOURNAL_PENDING" \
    "$SHIMMY_UNINSTALL_JOURNAL_SKIPPED" \
    "$SHIMMY_UNINSTALL_JOURNAL_PRESERVED"
}

shimmy_uninstall_journal_pending_advance() {
  shimmy_uninstall_journal_advance_config=$1
  shimmy_uninstall_journal_advance_disposition=$2
  shimmy_uninstall_journal_advance_reason=${3:-}
  shimmy_uninstall_journal_read \
    "$shimmy_uninstall_journal_advance_config/.uninstall.conf" || return 1
  [ "$SHIMMY_UNINSTALL_JOURNAL_PENDING" != none ] || return 1
  shimmy_uninstall_journal_advance_id=${SHIMMY_UNINSTALL_JOURNAL_PENDING%%,*}
  if [ "$SHIMMY_UNINSTALL_JOURNAL_PENDING" = \
    "$shimmy_uninstall_journal_advance_id" ]; then
    shimmy_uninstall_journal_advance_pending=none
  else
    shimmy_uninstall_journal_advance_pending=${SHIMMY_UNINSTALL_JOURNAL_PENDING#*,}
  fi
  shimmy_uninstall_journal_advance_completed=$SHIMMY_UNINSTALL_JOURNAL_COMPLETED
  shimmy_uninstall_journal_advance_skipped=$SHIMMY_UNINSTALL_JOURNAL_SKIPPED
  shimmy_uninstall_journal_advance_preserved=$SHIMMY_UNINSTALL_JOURNAL_PRESERVED
  case "$shimmy_uninstall_journal_advance_disposition" in
    completed)
      shimmy_uninstall_journal_advance_completed=$(shimmy_uninstall_csv_append \
        "$shimmy_uninstall_journal_advance_completed" \
        "$shimmy_uninstall_journal_advance_id") || return 1
      ;;
    preserved)
      shimmy_uninstall_journal_advance_skipped=$(shimmy_uninstall_csv_append \
        "$shimmy_uninstall_journal_advance_skipped" \
        "$shimmy_uninstall_journal_advance_id") || return 1
      shimmy_uninstall_journal_advance_preserved=$(shimmy_uninstall_preserved_append \
        "$shimmy_uninstall_journal_advance_preserved" \
        "$shimmy_uninstall_journal_advance_id" \
        "$shimmy_uninstall_journal_advance_reason") || return 1
      ;;
    *) return 1 ;;
  esac
  shimmy_uninstall_journal_write "$shimmy_uninstall_journal_advance_config" \
    removing-engines "$SHIMMY_UNINSTALL_JOURNAL_HOST_OS" \
    "$SHIMMY_UNINSTALL_JOURNAL_ACTIVE_ENGINE" \
    "$SHIMMY_UNINSTALL_JOURNAL_WORKLOADS_ACKNOWLEDGED" \
    "$SHIMMY_UNINSTALL_JOURNAL_PLANNED" \
    "$shimmy_uninstall_journal_advance_completed" \
    "$shimmy_uninstall_journal_advance_pending" \
    "$shimmy_uninstall_journal_advance_skipped" \
    "$shimmy_uninstall_journal_advance_preserved"
}

shimmy_uninstall_journal_pending_preserve() {
  shimmy_uninstall_journal_preserve_config=$1
  shimmy_uninstall_journal_preserve_id=$2
  shimmy_uninstall_journal_preserve_reason=$3
  shimmy_uninstall_journal_read \
    "$shimmy_uninstall_journal_preserve_config/.uninstall.conf" || return 1
  shimmy_uninstall_journal_preserve_pending=$(shimmy_uninstall_csv_remove \
    "$SHIMMY_UNINSTALL_JOURNAL_PENDING" \
    "$shimmy_uninstall_journal_preserve_id") || return 1
  shimmy_uninstall_journal_preserve_skipped=$(shimmy_uninstall_csv_append \
    "$SHIMMY_UNINSTALL_JOURNAL_SKIPPED" \
    "$shimmy_uninstall_journal_preserve_id") || return 1
  shimmy_uninstall_journal_preserve_preserved=$(shimmy_uninstall_preserved_append \
    "$SHIMMY_UNINSTALL_JOURNAL_PRESERVED" \
    "$shimmy_uninstall_journal_preserve_id" \
    "$shimmy_uninstall_journal_preserve_reason") || return 1
  shimmy_uninstall_journal_write "$shimmy_uninstall_journal_preserve_config" \
    removing-engines "$SHIMMY_UNINSTALL_JOURNAL_HOST_OS" \
    "$SHIMMY_UNINSTALL_JOURNAL_ACTIVE_ENGINE" \
    "$SHIMMY_UNINSTALL_JOURNAL_WORKLOADS_ACKNOWLEDGED" \
    "$SHIMMY_UNINSTALL_JOURNAL_PLANNED" \
    "$SHIMMY_UNINSTALL_JOURNAL_COMPLETED" \
    "$shimmy_uninstall_journal_preserve_pending" \
    "$shimmy_uninstall_journal_preserve_skipped" \
    "$shimmy_uninstall_journal_preserve_preserved"
}

shimmy_uninstall_completed_absence_validate() {
  shimmy_uninstall_completed_config=$1
  shimmy_uninstall_completed_csv=$2
  [ "$shimmy_uninstall_completed_csv" != none ] || return 0
  printf '%s\n' "$shimmy_uninstall_completed_csv" | tr ',' '\n' |
    while IFS= read -r shimmy_uninstall_completed_id; do
      shimmy_engine_paths_resolve "$shimmy_uninstall_completed_config" \
        "$shimmy_uninstall_completed_id" || exit 1
      shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || exit 1
      shimmy_engine_podman_machine_state_read "$SHIMMY_ENGINE_RECORD_NAME" || exit 1
      shimmy_engine_podman_connection_state_read \
        "$SHIMMY_ENGINE_RECORD_CONNECTION" || exit 1
      [ "$SHIMMY_ENGINE_MACHINE_STATE|$SHIMMY_ENGINE_CONNECTION_STATE" = \
        'absent|absent' ] || {
        printf 'ERROR: completed engine name reappeared and is a collision: %s\n' \
          "$shimmy_uninstall_completed_id" >&2
        exit 1
      }
    done
}

shimmy_uninstall_pending_prepare() {
  shimmy_uninstall_pending_config=$1
  shimmy_uninstall_pending_csv=$2
  [ "$shimmy_uninstall_pending_csv" != none ] || return 0
  printf '%s\n' "$shimmy_uninstall_pending_csv" | tr ',' '\n' |
    while IFS= read -r shimmy_uninstall_pending_id; do
      shimmy_engine_paths_resolve "$shimmy_uninstall_pending_config" \
        "$shimmy_uninstall_pending_id" || exit 1
      shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || exit 1
      if [ -e "$SHIMMY_ENGINE_LIFECYCLE_PATH" ] ||
        [ -L "$SHIMMY_ENGINE_LIFECYCLE_PATH" ]; then
        shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || exit 1
        [ "$SHIMMY_ENGINE_LIFECYCLE_ID|$SHIMMY_ENGINE_LIFECYCLE_OPERATION" = \
          "$shimmy_uninstall_pending_id|remove" ] || exit 1
      else
        shimmy_engine_machine_remove_prepare "$SHIMMY_ENGINE_RECORD_PATH" \
          "$SHIMMY_ENGINE_LIFECYCLE_PATH" || exit 1
      fi
    done
}

shimmy_uninstall_engine_preflight_one() {
  shimmy_uninstall_preflight_config=$1
  shimmy_uninstall_preflight_id=$2
  shimmy_engine_paths_resolve "$shimmy_uninstall_preflight_config" \
    "$shimmy_uninstall_preflight_id" || return 1
  shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
  while :; do
    shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
    case "$SHIMMY_ENGINE_LIFECYCLE_PHASE" in
      planned)
        shimmy_engine_lifecycle_transition "$SHIMMY_ENGINE_LIFECYCLE_PATH" \
          verification-starting || return 1
        ;;
      verification-starting)
        shimmy_engine_ownership_host_state_read "$SHIMMY_ENGINE_RECORD_PATH"
        if [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" != owned ]; then
          SHIMMY_UNINSTALL_PREFLIGHT_PRESERVE_REASON=$SHIMMY_ENGINE_OWNERSHIP_REASON
          return 2
        fi
        if [ "$SHIMMY_ENGINE_MACHINE_STATE" = stopped ]; then
          shimmy_engine_podman_machine_start \
            "$SHIMMY_ENGINE_RECORD_NAME" || return 1
        else
          [ "$SHIMMY_ENGINE_MACHINE_STATE" = running ] || return 1
        fi
        shimmy_engine_lifecycle_transition "$SHIMMY_ENGINE_LIFECYCLE_PATH" \
          verification-started || return 1
        ;;
      verification-started)
        shimmy_engine_ownership_state_read "$SHIMMY_ENGINE_RECORD_PATH"
        if [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" != owned ]; then
          SHIMMY_UNINSTALL_PREFLIGHT_PRESERVE_REASON=$SHIMMY_ENGINE_OWNERSHIP_REASON
          return 2
        fi
        shimmy_engine_podman_workloads_read \
          "$SHIMMY_ENGINE_RECORD_CONNECTION" || return 1
        if [ "$SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT" -gt 0 ] &&
          [ "$SHIMMY_UNINSTALL_STOP_RUNNING" -eq 0 ]; then
          SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP=1
          SHIMMY_UNINSTALL_ERROR="running containers appeared on $shimmy_uninstall_preflight_id; retry with explicit --stop-running acknowledgement"
          return 1
        fi
        shimmy_engine_lifecycle_transition "$SHIMMY_ENGINE_LIFECYCLE_PATH" \
          verified || return 1
        ;;
      verified)
        shimmy_engine_lifecycle_transition "$SHIMMY_ENGINE_LIFECYCLE_PATH" \
          stopping || return 1
        ;;
      stopping)
        shimmy_engine_ownership_state_read "$SHIMMY_ENGINE_RECORD_PATH"
        if [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" != owned ]; then
          SHIMMY_UNINSTALL_PREFLIGHT_PRESERVE_REASON=$SHIMMY_ENGINE_OWNERSHIP_REASON
          return 2
        fi
        shimmy_engine_podman_workloads_read \
          "$SHIMMY_ENGINE_RECORD_CONNECTION" || return 1
        if [ "$SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT" -gt 0 ] &&
          [ "$SHIMMY_UNINSTALL_STOP_RUNNING" -eq 0 ]; then
          SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP=1
          SHIMMY_UNINSTALL_ERROR="running containers appeared on $shimmy_uninstall_preflight_id; retry with explicit --stop-running acknowledgement"
          return 1
        fi
        shimmy_engine_ownership_state_read "$SHIMMY_ENGINE_RECORD_PATH"
        if [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" != owned ]; then
          SHIMMY_UNINSTALL_PREFLIGHT_PRESERVE_REASON=$SHIMMY_ENGINE_OWNERSHIP_REASON
          return 2
        fi
        shimmy_engine_podman_machine_stop \
          "$SHIMMY_ENGINE_RECORD_NAME" || return 1
        shimmy_engine_lifecycle_transition "$SHIMMY_ENGINE_LIFECYCLE_PATH" \
          stopped || return 1
        ;;
      stopped)
        shimmy_engine_ownership_host_state_read "$SHIMMY_ENGINE_RECORD_PATH"
        if [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" != owned ]; then
          SHIMMY_UNINSTALL_PREFLIGHT_PRESERVE_REASON=$SHIMMY_ENGINE_OWNERSHIP_REASON
          return 2
        fi
        return 0
        ;;
      removing)
        return 0
        ;;
      removed)
        shimmy_engine_podman_machine_state_read \
          "$SHIMMY_ENGINE_RECORD_NAME" || return 1
        shimmy_engine_podman_connection_state_read \
          "$SHIMMY_ENGINE_RECORD_CONNECTION" || return 1
        [ "$SHIMMY_ENGINE_MACHINE_STATE|$SHIMMY_ENGINE_CONNECTION_STATE" = \
          'absent|absent' ] || {
          SHIMMY_UNINSTALL_ERROR="engine name reappeared after recorded removal: $shimmy_uninstall_preflight_id"
          return 1
        }
        return 0
        ;;
      *) return 1 ;;
    esac
  done
}

shimmy_uninstall_pending_preflight() {
  shimmy_uninstall_preflight_config=$1
  shimmy_uninstall_preflight_pending=$2
  [ "$shimmy_uninstall_preflight_pending" != none ] || return 0
  shimmy_uninstall_preflight_rest=$shimmy_uninstall_preflight_pending
  while :; do
    shimmy_uninstall_preflight_id=${shimmy_uninstall_preflight_rest%%,*}
    SHIMMY_UNINSTALL_PREFLIGHT_PRESERVE_REASON=
    if shimmy_uninstall_engine_preflight_one \
      "$shimmy_uninstall_preflight_config" \
      "$shimmy_uninstall_preflight_id"; then
      shimmy_uninstall_preflight_status=0
    else
      shimmy_uninstall_preflight_status=$?
    fi
    case "$shimmy_uninstall_preflight_status" in
      0) ;;
      2)
        printf 'Preserved engine %s during complete preflight: %s.\n' \
          "$shimmy_uninstall_preflight_id" \
          "$SHIMMY_UNINSTALL_PREFLIGHT_PRESERVE_REASON" >&2
        shimmy_uninstall_journal_pending_preserve \
          "$shimmy_uninstall_preflight_config" \
          "$shimmy_uninstall_preflight_id" \
          "$SHIMMY_UNINSTALL_PREFLIGHT_PRESERVE_REASON" || return 1
        ;;
      *) return 1 ;;
    esac
    [ "$shimmy_uninstall_preflight_rest" != \
      "$shimmy_uninstall_preflight_id" ] || break
    shimmy_uninstall_preflight_rest=${shimmy_uninstall_preflight_rest#*,}
  done
}

shimmy_uninstall_engines_apply() {
  shimmy_uninstall_engines_config=$1
  shimmy_uninstall_journal_read "$shimmy_uninstall_engines_config/.uninstall.conf" || return 1
  shimmy_uninstall_completed_absence_validate "$shimmy_uninstall_engines_config" \
    "$SHIMMY_UNINSTALL_JOURNAL_COMPLETED" || return 1
  shimmy_uninstall_pending_prepare "$shimmy_uninstall_engines_config" \
    "$SHIMMY_UNINSTALL_JOURNAL_PENDING" || return 1
  shimmy_uninstall_pending_preflight "$shimmy_uninstall_engines_config" \
    "$SHIMMY_UNINSTALL_JOURNAL_PENDING" || return 1
  while :; do
    shimmy_uninstall_journal_read "$shimmy_uninstall_engines_config/.uninstall.conf" || return 1
    [ "$SHIMMY_UNINSTALL_JOURNAL_PENDING" != none ] || return 0
    shimmy_uninstall_engines_id=${SHIMMY_UNINSTALL_JOURNAL_PENDING%%,*}
    shimmy_engine_paths_resolve "$shimmy_uninstall_engines_config" \
      "$shimmy_uninstall_engines_id" || return 1
    shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
    shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
    if [ "$SHIMMY_ENGINE_LIFECYCLE_PHASE" = removed ]; then
      shimmy_engine_podman_machine_state_read "$SHIMMY_ENGINE_RECORD_NAME" || return 1
      shimmy_engine_podman_connection_state_read \
        "$SHIMMY_ENGINE_RECORD_CONNECTION" || return 1
      [ "$SHIMMY_ENGINE_MACHINE_STATE|$SHIMMY_ENGINE_CONNECTION_STATE" = \
        'absent|absent' ] || {
        SHIMMY_UNINSTALL_ERROR="engine name reappeared after removal: $shimmy_uninstall_engines_id"
        return 1
      }
    else
      shimmy_engine_ownership_host_state_read "$SHIMMY_ENGINE_RECORD_PATH"
      if [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" != owned ]; then
        shimmy_uninstall_engines_reason=$SHIMMY_ENGINE_OWNERSHIP_REASON
        printf 'Preserved engine %s because ownership changed: %s.\n' \
          "$shimmy_uninstall_engines_id" "$shimmy_uninstall_engines_reason" >&2
        shimmy_uninstall_journal_pending_advance \
          "$shimmy_uninstall_engines_config" preserved \
          "$shimmy_uninstall_engines_reason" || return 1
        continue
      fi
      if [ "$SHIMMY_ENGINE_MACHINE_STATE" = running ]; then
        shimmy_engine_ownership_state_read "$SHIMMY_ENGINE_RECORD_PATH"
        [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || {
          shimmy_uninstall_engines_reason=$SHIMMY_ENGINE_OWNERSHIP_REASON
          shimmy_uninstall_journal_pending_advance \
            "$shimmy_uninstall_engines_config" preserved \
            "$shimmy_uninstall_engines_reason" || return 1
          continue
        }
        shimmy_engine_podman_workloads_read \
          "$SHIMMY_ENGINE_RECORD_CONNECTION" || return 1
        if [ "$SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT" -gt 0 ] &&
          [ "$SHIMMY_UNINSTALL_STOP_RUNNING" -eq 0 ]; then
          SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP=1
          SHIMMY_UNINSTALL_ERROR="running containers appeared on $shimmy_uninstall_engines_id; retry with explicit --stop-running acknowledgement"
          return 1
        fi
      fi
      if ! shimmy_engine_machine_remove_apply "$SHIMMY_ENGINE_RECORD_PATH" \
        "$SHIMMY_ENGINE_LIFECYCLE_PATH"; then
        shimmy_engine_ownership_host_state_read "$SHIMMY_ENGINE_RECORD_PATH"
        if [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = ambiguous ] ||
          [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = external ]; then
          shimmy_uninstall_engines_reason=$SHIMMY_ENGINE_OWNERSHIP_REASON
          printf 'Preserved engine %s because ownership changed: %s.\n' \
            "$shimmy_uninstall_engines_id" "$shimmy_uninstall_engines_reason" >&2
          shimmy_uninstall_journal_pending_advance \
            "$shimmy_uninstall_engines_config" preserved \
            "$shimmy_uninstall_engines_reason" || return 1
          continue
        fi
        return 1
      fi
    fi
    if [ "${SHIMMY_TEST_UNINSTALL_FAILURE:-}" = \
      "after-$shimmy_uninstall_engines_id-remove" ]; then
      return 1
    fi
    shimmy_uninstall_journal_pending_advance \
      "$shimmy_uninstall_engines_config" completed || return 1
  done
}

shimmy_uninstall_run() {
  shimmy_uninstall_config=$1
  shimmy_uninstall_stop=$2
  shimmy_uninstall_dry=${3:-0}
  case "$shimmy_uninstall_stop:$shimmy_uninstall_dry" in
    [01]:[01]) ;;
    *) return 1 ;;
  esac
  SHIMMY_UNINSTALL_STOP_RUNNING=$shimmy_uninstall_stop
  shimmy_uninstall_config_validate "$shimmy_uninstall_config" 0 || return 1
  shimmy_uninstall_initial_active=$SHIMMY_UNINSTALL_ACTIVE
  shimmy_uninstall_user_root=$SHIMMY_UNINSTALL_USER_ROOT
  shimmy_uninstall_profiles=$SHIMMY_UNINSTALL_PROFILES
  shimmy_profile_candidate_resolve "$shimmy_uninstall_config" default || return 1
  shimmy_uninstall_startup_files=$SHIMMY_PROFILE_CANDIDATE_STARTUP_FILES
  shimmy_uninstall_links_validate "$shimmy_uninstall_user_root" \
    "$SHIMMY_PROFILES_ROOT" || return 1
  shimmy_uninstall_startup_validate "$shimmy_uninstall_startup_files" || return 1
  if [ -e "$shimmy_uninstall_config/.uninstall.conf" ] ||
    [ -L "$shimmy_uninstall_config/.uninstall.conf" ]; then
    shimmy_uninstall_journal_read "$shimmy_uninstall_config/.uninstall.conf" || return 1
    SHIMMY_UNINSTALL_HOST_OS=$SHIMMY_UNINSTALL_JOURNAL_HOST_OS
    SHIMMY_UNINSTALL_ACTIVE_ENGINE=$SHIMMY_UNINSTALL_JOURNAL_ACTIVE_ENGINE
    SHIMMY_UNINSTALL_ENGINE_PLANNED=$SHIMMY_UNINSTALL_JOURNAL_PLANNED
    SHIMMY_UNINSTALL_ENGINE_PRESERVED=$SHIMMY_UNINSTALL_JOURNAL_PRESERVED
    SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP=0
    [ "$SHIMMY_UNINSTALL_JOURNAL_WORKLOADS_ACKNOWLEDGED" != yes ] ||
      SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP=1
    [ "$SHIMMY_UNINSTALL_HOST_OS" != darwin ] ||
      shimmy_engine_podman_bin_require || return 1
    shimmy_uninstall_engine_roots_validate "$shimmy_uninstall_config" || return 1
  else
    shimmy_uninstall_engine_plan_read "$shimmy_uninstall_config" \
      "$shimmy_uninstall_stop" || return 1
  fi
  shimmy_uninstall_projection_preflight "$shimmy_uninstall_config" \
    "$shimmy_uninstall_profiles" "$SHIMMY_UNINSTALL_ENGINE_PLANNED" \
    "$shimmy_uninstall_stop" || return 1
  shimmy_uninstall_plan_render "$shimmy_uninstall_dry" >&2
  [ "$shimmy_uninstall_dry" -eq 0 ] || return 0
  if [ "$SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP" -eq 1 ] &&
    [ "$shimmy_uninstall_stop" -eq 0 ]; then
    SHIMMY_UNINSTALL_ERROR='running containers block owned-machine uninstall; retry with explicit --stop-running acknowledgement'
    return 1
  fi

  shimmy_lock_acquire catalog "$shimmy_uninstall_config" || return 1
  shimmy_lock_acquire activation "$shimmy_uninstall_config" || return 1
  while IFS= read -r shimmy_uninstall_profile; do
    shimmy_lock_acquire profile "$shimmy_uninstall_config" \
      "$shimmy_uninstall_profile" || return 1
  done <<EOF
$shimmy_uninstall_profiles
EOF
  shimmy_uninstall_config_validate "$shimmy_uninstall_config" 1 || return 1
  [ "$SHIMMY_UNINSTALL_ACTIVE" = "$shimmy_uninstall_initial_active" ] &&
    [ "$SHIMMY_UNINSTALL_USER_ROOT" = "$shimmy_uninstall_user_root" ] &&
    [ "$SHIMMY_UNINSTALL_PROFILES" = "$shimmy_uninstall_profiles" ] || return 1
  shimmy_uninstall_links_validate "$shimmy_uninstall_user_root" \
    "$SHIMMY_PROFILES_ROOT" || return 1
  shimmy_uninstall_startup_validate "$shimmy_uninstall_startup_files" || return 1

  if [ -e "$shimmy_uninstall_config/.uninstall.conf" ] ||
    [ -L "$shimmy_uninstall_config/.uninstall.conf" ]; then
    shimmy_uninstall_journal_read "$shimmy_uninstall_config/.uninstall.conf" || return 1
    [ "$SHIMMY_UNINSTALL_JOURNAL_ACTIVE_ENGINE" = \
      "$SHIMMY_UNINSTALL_ACTIVE_ENGINE" ] || return 1
  else
    shimmy_uninstall_engine_plan_read "$shimmy_uninstall_config" \
      "$shimmy_uninstall_stop" >/dev/null || return 1
    shimmy_uninstall_journal_write "$shimmy_uninstall_config" planned \
      "$SHIMMY_UNINSTALL_HOST_OS" "$SHIMMY_UNINSTALL_ACTIVE_ENGINE" \
      "$(if [ "$SHIMMY_UNINSTALL_RUNNING_REQUIRES_STOP" -eq 1 ]; then printf yes; else printf no; fi)" \
      "$SHIMMY_UNINSTALL_ENGINE_PLANNED" none \
      "$SHIMMY_UNINSTALL_ENGINE_PLANNED" none \
      "$SHIMMY_UNINSTALL_ENGINE_PRESERVED" || return 1
  fi
  shimmy_uninstall_projection_preflight "$shimmy_uninstall_config" \
    "$shimmy_uninstall_profiles" "$SHIMMY_UNINSTALL_ENGINE_PLANNED" \
    "$shimmy_uninstall_stop" >/dev/null || return 1
  shimmy_uninstall_journal_transition "$shimmy_uninstall_config" \
    removing-engines || return 1
  if [ "$SHIMMY_UNINSTALL_HOST_OS" = darwin ]; then
    if ! shimmy_uninstall_engines_apply "$shimmy_uninstall_config"; then
      shimmy_uninstall_engine_failure=${SHIMMY_UNINSTALL_ERROR:-owned-machine removal did not complete; installation state was retained for exact retry}
      shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
        "$shimmy_uninstall_engine_failure"
      return 1
    fi
  fi
  shimmy_uninstall_journal_transition "$shimmy_uninstall_config" \
    configuration || {
      shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
        'machine removal completed but configuration cleanup could not begin'
      return 1
    }
  shimmy_uninstall_journal_read "$shimmy_uninstall_config/.uninstall.conf" || {
    SHIMMY_UNINSTALL_ERROR='machine removal completed but the uninstall journal became unreadable'
    return 1
  }
  shimmy_uninstall_removed_engines=$SHIMMY_UNINSTALL_JOURNAL_COMPLETED

  if [ "$SHIMMY_UNINSTALL_HOST_OS" = darwin ]; then
    while IFS= read -r shimmy_uninstall_profile; do
      shimmy_profile_engine_context_resolve "$shimmy_uninstall_config" \
        "$shimmy_uninstall_profile" || {
          shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
            'machine removal completed but profile projection cleanup preflight failed'
          return 1
        }
      if shimmy_uninstall_csv_contains "$shimmy_uninstall_removed_engines" \
        "$SHIMMY_PROFILE_ENGINE_ID"; then
        continue
      fi
      shimmy_lock_acquire registry "$shimmy_uninstall_config" \
        "$shimmy_uninstall_profile" || {
          shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
            'machine removal completed but a registry cleanup lock was unavailable'
          return 1
        }
      shimmy_profile_projection_cleanup "$shimmy_uninstall_config" \
        "$shimmy_uninstall_profile" "$shimmy_uninstall_stop" 0 || {
          shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
            'machine removal completed but a preserved-engine projection could not be cleaned'
          return 1
        }
      shimmy_lock_release || {
        shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
          'machine removal completed but a registry cleanup lock could not be released'
        return 1
      }
    done <<EOF
$shimmy_uninstall_profiles
EOF
  fi

  shimmy_external_transaction_begin || {
    shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
      'machine removal completed but configuration cleanup transaction setup failed'
    return 1
  }
  shimmy_profile_engine_context_resolve "$shimmy_uninstall_config" \
    "$shimmy_uninstall_initial_active" || {
      shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
        'machine removal completed but active-profile cleanup validation failed'
      return 1
    }
  if [ "$SHIMMY_UNINSTALL_HOST_OS" = linux ]; then
    shimmy_registries_active_link_state_read
    [ "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" = current ] || {
      shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
        'configuration cleanup found an invalid Linux active registry link'
      return 1
    }
    shimmy_uninstall_active_link_prior=$(readlink "$SHIMMY_REGISTRIES_ACTIVE_LINK") || {
      shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
        'configuration cleanup could not read the Linux active registry link'
      return 1
    }
    shimmy_external_rollback_register "$SHIMMY_REGISTRIES_ACTIVE_LINK" \
      shimmy_profile_active_link_restore "$shimmy_uninstall_active_link_prior" absent \
      'restore Linux active registry link' || {
        shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
          'configuration cleanup could not journal the Linux registry link'
        return 1
      }
    shimmy_registries_active_link_detach || {
      shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
        'configuration cleanup could not detach the Linux active registry link'
      return 1
    }
  fi
  shimmy_uninstall_links_apply "$shimmy_uninstall_user_root" \
    "$SHIMMY_PROFILES_ROOT" || {
      shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
        'machine removal completed but owned AI-skill link cleanup failed'
      return 1
    }
  shimmy_startup_remove_apply "$shimmy_uninstall_config" \
    "$shimmy_uninstall_startup_files" || {
      shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
        'machine removal completed but startup cleanup failed'
      return 1
    }

  shimmy_uninstall_parent=$(dirname -- "$shimmy_uninstall_config")
  shimmy_uninstall_backup=$shimmy_uninstall_parent/.shimmy-uninstall.$$
  [ ! -e "$shimmy_uninstall_backup" ] && [ ! -L "$shimmy_uninstall_backup" ] || return 1
  shimmy_locks_release_all || return 1
  mv "$shimmy_uninstall_config" "$shimmy_uninstall_backup" || {
    shimmy_external_transaction_rollback 'unable to remove installation root' || true
    shimmy_uninstall_failure_report "$shimmy_uninstall_config" \
      'machine removal completed but the installation root could not be removed'
    return 1
  }
  shimmy_external_transaction_commit || return 1
  SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP=
  rm -rf "$shimmy_uninstall_backup" || return 1
  printf 'Uninstalled all Shimmy-owned profiles and default catalog from %s.\n' \
    "$shimmy_uninstall_config"
  if [ "$SHIMMY_UNINSTALL_JOURNAL_COMPLETED" != none ]; then
    printf 'Removed owned Podman engines: %s.\n' \
      "$SHIMMY_UNINSTALL_JOURNAL_COMPLETED"
  fi
  if [ "$SHIMMY_UNINSTALL_JOURNAL_PRESERVED" != none ]; then
    printf 'Preserved external or ambiguous engines: %s.\n' \
      "$SHIMMY_UNINSTALL_JOURNAL_PRESERVED"
  fi
}
