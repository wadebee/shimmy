#!/bin/sh
# Remove only manifest-, registry-, or catalog-owned Shimmy assets.

perform_uninstall_global() {
  global_config_root=$SHIMMY_CONFIG_ROOT
  global_profiles_root=$SHIMMY_PROFILES_ROOT
  global_profile_names='default
upstream'

  shimmy_catalog_owned_state_validate "$global_config_root" 0 || fail "$SHIMMY_CATALOG_ERROR"
  shimmy_profile_activation_lock_check || fail "unable to preflight the profile activation lock for global uninstall"
  shimmy_uninstall_plan_build "$global_profile_names" 0 1 || exit 1
  shimmy_uninstall_locks_acquire "$SHIMMY_UNINSTALL_PRESENT_PROFILES" || exit 1
  shimmy_catalog_lock_acquire "$global_config_root" || fail "$SHIMMY_CATALOG_ERROR"
  shimmy_catalog_owned_state_validate "$global_config_root" 1 || fail "$SHIMMY_CATALOG_ERROR"
  shimmy_uninstall_plan_build "$global_profile_names" 1 0 || exit 1

  shimmy_uninstall_projection_cleanup || exit 1
  shimmy_uninstall_linux_links_detach || exit 1

  for global_profile_name in $SHIMMY_UNINSTALL_PRESENT_PROFILES; do
    shimmy_uninstall_profile_assets_remove "$global_profile_name"
  done
  shimmy_uninstall_registry_locks_release
  for global_profile_name in $SHIMMY_UNINSTALL_PRESENT_PROFILES; do
    shimmy_uninstall_profile_context_resolve "$global_profile_name" || exit 1
    rmdir "$SHIMMY_PROFILE_BIN_DIR" 2>/dev/null || true
    rmdir "$SHIMMY_PROFILE_ROOT" 2>/dev/null || true
  done
  shimmy_catalog_owned_state_remove "$global_config_root" 1 || fail "$SHIMMY_CATALOG_ERROR"
  shimmy_catalog_lock_release
  shimmy_profile_activation_lock_release
  rmdir "$global_profiles_root" 2>/dev/null || true
  rmdir "$global_config_root/catalogs" 2>/dev/null || true
  rmdir "$global_config_root" 2>/dev/null || true
  log_info "Removed all manifest-owned Shimmy profiles and shared catalogs from $global_config_root"
}

perform_uninstall_profile() {
  uninstall_profile_name=$SHIMMY_PROFILE_RESOLVED
  shimmy_profile_activation_lock_check || fail "unable to preflight the profile activation lock for profile uninstall"
  shimmy_uninstall_plan_build "$uninstall_profile_name" 0 1 || exit 1
  shimmy_uninstall_locks_acquire "$SHIMMY_UNINSTALL_PRESENT_PROFILES" || exit 1
  shimmy_uninstall_plan_build "$uninstall_profile_name" 1 0 || exit 1

  shimmy_uninstall_projection_cleanup || exit 1
  shimmy_uninstall_linux_links_detach || exit 1
  shimmy_uninstall_profile_assets_remove "$uninstall_profile_name"
  shimmy_uninstall_registry_locks_release
  shimmy_profile_activation_lock_release
  shimmy_uninstall_empty_roots_remove
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

shimmy_uninstall_darwin_profile_plan() {
  uninstall_plan_profile=$1
  shimmy_profile_activation_override_reject || return 1
  shimmy_registries_override_reject || return 1
  shimmy_profile_activation_expected_resolve || return 1
  shimmy_profile_state_darwin_read

  [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE" = valid ] || {
    printf 'ERROR: invalid Darwin machine projection record: %s\n' "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" >&2
    return 1
  }
  [ "$SHIMMY_PROFILE_MACHINE_METADATA" = valid ] || {
    printf 'ERROR: Podman machine metadata is %s; refusing uninstall cleanup for profile %s\n' \
      "$SHIMMY_PROFILE_MACHINE_METADATA" "$uninstall_plan_profile" >&2
    return 1
  }

  SHIMMY_UNINSTALL_PROJECTED_PROFILES=$(shimmy_append_line_list \
    "$SHIMMY_UNINSTALL_PROJECTED_PROFILES" "$uninstall_plan_profile")
  if [ "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" = missing ]; then
    SHIMMY_UNINSTALL_MISSING_PROFILES=$(shimmy_append_line_list \
      "$SHIMMY_UNINSTALL_MISSING_PROFILES" "$uninstall_plan_profile")
    return 0
  fi

  [ "$SHIMMY_PROFILE_CONNECTION_METADATA" = valid ] &&
    [ "$SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE" = rootless ] || {
      printf 'ERROR: required same-name rootless Podman connection is missing or invalid: %s\n' \
        "$SHIMMY_PROFILE_EXPECTED_CONNECTION" >&2
      return 1
    }
  case "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" in
    running)
      [ "$SHIMMY_PROFILE_ENGINE_REACHABLE" = true ] || {
        printf 'ERROR: expected machine %s is unreachable; refusing uninstall cleanup\n' \
          "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
        return 1
      }
      [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE" = current ] || {
        printf 'ERROR: refusing uninstall with foreign, absent, or invalid Darwin machine projection: %s\n' \
          "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK" >&2
        return 1
      }
      SHIMMY_UNINSTALL_RUNNING_PROFILES=$(shimmy_append_line_list \
        "$SHIMMY_UNINSTALL_RUNNING_PROFILES" "$uninstall_plan_profile")
      ;;
    stopped)
      SHIMMY_UNINSTALL_STOPPED_PROFILES=$(shimmy_append_line_list \
        "$SHIMMY_UNINSTALL_STOPPED_PROFILES" "$uninstall_plan_profile")
      ;;
    *)
      printf 'ERROR: unable to prove Darwin machine state for uninstall cleanup: %s\n' \
        "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
      return 1
      ;;
  esac

  SHIMMY_UNINSTALL_NONMISSING_PROFILES=$(shimmy_append_line_list \
    "$SHIMMY_UNINSTALL_NONMISSING_PROFILES" "$uninstall_plan_profile")
  if [ "$SHIMMY_UNINSTALL_SNAPSHOT_SET" -eq 0 ]; then
    SHIMMY_UNINSTALL_INITIAL_RUNNING_MACHINE=$SHIMMY_PROFILE_RUNNING_MACHINE
    SHIMMY_UNINSTALL_INITIAL_DEFAULT_CONNECTION=$SHIMMY_PROFILE_DEFAULT_CONNECTION
    SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINER_COUNT=$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT
    SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINERS=$SHIMMY_PROFILE_RUNNING_CONTAINERS
    SHIMMY_UNINSTALL_SNAPSHOT_SET=1
  elif [ "$SHIMMY_UNINSTALL_INITIAL_RUNNING_MACHINE" != "$SHIMMY_PROFILE_RUNNING_MACHINE" ] ||
    [ "$SHIMMY_UNINSTALL_INITIAL_DEFAULT_CONNECTION" != "$SHIMMY_PROFILE_DEFAULT_CONNECTION" ] ||
    [ "$SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINER_COUNT" != "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT" ]; then
    printf '%s\n' 'ERROR: Podman machine or connection state changed while building the uninstall plan' >&2
    return 1
  fi
}

shimmy_uninstall_empty_roots_remove() {
  rmdir "$SHIMMY_PROFILE_ROOT/bin" 2>/dev/null || true
  rmdir "$SHIMMY_PROFILE_ROOT" 2>/dev/null || true
  rmdir "$SHIMMY_PROFILES_ROOT" 2>/dev/null || true
  rmdir "$SHIMMY_CONFIG_ROOT" 2>/dev/null || true
}

shimmy_uninstall_linux_links_detach() {
  [ "$SHIMMY_UNINSTALL_HOST_OS" = linux ] || return 0
  for uninstall_link_profile in $SHIMMY_UNINSTALL_PRESENT_PROFILES; do
    shimmy_uninstall_profile_context_resolve "$uninstall_link_profile" || return 1
    shimmy_registries_active_link_state_read
    case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in
      current) shimmy_registries_active_link_detach || return 1 ;;
      absent|sibling) ;;
      *)
        printf 'ERROR: refusing to remove profile with invalid or foreign registry activation state: %s\n' \
          "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
        return 1
        ;;
    esac
  done
}

shimmy_uninstall_locks_acquire() {
  uninstall_lock_profiles=$1
  shimmy_profile_activation_lock_acquire || return 1
  for uninstall_lock_profile in $uninstall_lock_profiles; do
    shimmy_uninstall_profile_context_resolve "$uninstall_lock_profile" || return 1
    shimmy_registries_lock_acquire || return 1
    SHIMMY_UNINSTALL_REGISTRY_LOCK_PROFILES=$(shimmy_append_line_list \
      "$SHIMMY_UNINSTALL_REGISTRY_LOCK_PROFILES" "$uninstall_lock_profile")
    SHIMMY_REGISTRIES_LOCK_HELD=0
  done
}

shimmy_uninstall_plan_build() {
  uninstall_plan_profiles=$1
  uninstall_plan_under_lock=$2
  uninstall_plan_report_workloads=$3
  shimmy_uninstall_plan_reset
  shimmy_profile_activation_host_os_resolve
  SHIMMY_UNINSTALL_HOST_OS=$SHIMMY_PROFILE_HOST_OS

  for uninstall_plan_profile in $uninstall_plan_profiles; do
    shimmy_uninstall_profile_context_resolve "$uninstall_plan_profile" || return 1
    if [ ! -e "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ]; then
      [ "$uninstall_plan_profiles" != "$uninstall_plan_profile" ] || {
        printf 'ERROR: no Shimmy profile manifest found at %s\n' "$SHIMMY_PROFILE_MANIFEST_PATH" >&2
        return 1
      }
      continue
    fi
    [ -f "$SHIMMY_PROFILE_MANIFEST_PATH" ] && [ ! -L "$SHIMMY_PROFILE_MANIFEST_PATH" ] || {
      printf 'ERROR: refusing uninstall with unmanaged or incomplete profile state: %s\n' "$SHIMMY_PROFILE_ROOT" >&2
      return 1
    }
    shimmy_profile_manifest_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$uninstall_plan_profile" || return 1
    if [ -e "$SHIMMY_PROFILE_REGISTRIES_PATH" ] || [ -L "$SHIMMY_PROFILE_REGISTRIES_PATH" ]; then
      shimmy_registries_config_validate "$SHIMMY_PROFILE_REGISTRIES_PATH" "$uninstall_plan_profile" || {
        printf 'ERROR: refusing to remove invalid or unmanaged registry configuration: %s\n' \
          "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
        return 1
      }
    fi
    if [ "$uninstall_plan_under_lock" -eq 1 ]; then
      [ -d "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH" ] && [ ! -L "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH" ] || {
        printf 'ERROR: registry transaction lock changed during uninstall: %s\n' \
          "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH" >&2
        return 1
      }
    elif [ -e "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH" ] || [ -L "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH" ]; then
      printf 'ERROR: refusing uninstall while a registry transaction is active or damaged: %s\n' \
        "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH" >&2
      return 1
    fi

    SHIMMY_UNINSTALL_PRESENT_PROFILES=$(shimmy_append_line_list \
      "$SHIMMY_UNINSTALL_PRESENT_PROFILES" "$uninstall_plan_profile")
    shimmy_registries_active_link_state_read
    [ "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" != invalid ] || {
      printf 'ERROR: refusing uninstall with invalid or foreign registry activation state: %s\n' \
        "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
      return 1
    }

    if [ -e "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ] ||
      [ -L "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ]; then
      [ -f "$SHIMMY_PROFILE_REGISTRIES_PATH" ] && [ ! -L "$SHIMMY_PROFILE_REGISTRIES_PATH" ] || {
        printf 'ERROR: refusing uninstall with a Darwin projection record but no valid registry configuration: %s\n' \
          "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
        return 1
      }
      shimmy_registries_machine_projection_record_validate \
        "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" "$uninstall_plan_profile" || {
          printf 'ERROR: refusing uninstall with invalid Darwin machine projection record: %s\n' \
            "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" >&2
          return 1
        }
      [ "$SHIMMY_UNINSTALL_HOST_OS" = darwin ] || {
        printf 'ERROR: retained Darwin projection for profile %s can be cleaned only from macOS\n' \
          "$uninstall_plan_profile" >&2
        return 1
      }
      shimmy_uninstall_darwin_profile_plan "$uninstall_plan_profile" || return 1
    fi
  done

  [ -z "$SHIMMY_UNINSTALL_NONMISSING_PROFILES" ] || SHIMMY_UNINSTALL_MACHINE_OPERATIONS=1
  uninstall_stop_planned=0
  if [ "$SHIMMY_UNINSTALL_MACHINE_OPERATIONS" -eq 1 ] &&
    [ "$SHIMMY_UNINSTALL_INITIAL_RUNNING_MACHINE" != none ]; then
    uninstall_stop_planned=1
    [ "$SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINER_COUNT" != unknown ] || {
      printf 'ERROR: unable to inspect running workloads on %s; no machine was stopped\n' \
        "$SHIMMY_UNINSTALL_INITIAL_RUNNING_MACHINE" >&2
      return 1
    }
    if [ "$uninstall_plan_report_workloads" -eq 1 ] &&
      [ -n "$SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINERS" ]; then
      printf 'Running containers on %s:\n' "$SHIMMY_UNINSTALL_INITIAL_RUNNING_MACHINE"
      printf '%s\n' "$SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINERS"
    fi
    if [ "$SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINER_COUNT" -gt 0 ] && [ "$STOP_RUNNING" -eq 0 ]; then
      if [ "$uninstall_plan_report_workloads" -eq 0 ] &&
        [ -n "$SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINERS" ]; then
        printf 'Running containers on %s:\n' "$SHIMMY_UNINSTALL_INITIAL_RUNNING_MACHINE"
        printf '%s\n' "$SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINERS"
      fi
      printf '%s\n' 'ERROR: running containers block uninstall cleanup; review the workloads and retry with explicit --stop-running acknowledgement' >&2
      return 1
    fi
  fi
  if [ "$STOP_RUNNING" -eq 1 ] && [ "$uninstall_stop_planned" -eq 0 ]; then
    printf '%s\n' 'ERROR: --stop-running is valid only when uninstall cleanup will stop an already running machine' >&2
    return 1
  fi
}

shimmy_uninstall_plan_reset() {
  SHIMMY_UNINSTALL_HOST_OS=unsupported
  SHIMMY_UNINSTALL_INITIAL_DEFAULT_CONNECTION=unknown
  SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINER_COUNT=unknown
  SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINERS=
  SHIMMY_UNINSTALL_INITIAL_RUNNING_MACHINE=none
  SHIMMY_UNINSTALL_MACHINE_OPERATIONS=0
  SHIMMY_UNINSTALL_MISSING_PROFILES=
  SHIMMY_UNINSTALL_NONMISSING_PROFILES=
  SHIMMY_UNINSTALL_PREPARED_PROFILES=
  SHIMMY_UNINSTALL_PRESENT_PROFILES=
  SHIMMY_UNINSTALL_PROJECTED_PROFILES=
  SHIMMY_UNINSTALL_RUNNING_PROFILES=
  SHIMMY_UNINSTALL_SNAPSHOT_SET=0
  SHIMMY_UNINSTALL_STOPPED_PROFILES=
}

shimmy_uninstall_profile_assets_remove() {
  uninstall_remove_profile=$1
  shimmy_uninstall_profile_context_resolve "$uninstall_remove_profile" || return 1
  installed_tools=$(shimmy_manifest_tool_list_read "$SHIMMY_PROFILE_MANIFEST_PATH" || true)
  startup_files=
  if [ "$uninstall_remove_profile" = default ]; then
    startup_files=$(shimmy_read_manifest_values "$SHIMMY_PROFILE_MANIFEST_PATH" startup_file || true)
  fi

  for asset_name in agent commands config implementations lib plugins tests tools; do
    profile_owned_path_remove "$SHIMMY_PROFILE_ROOT/$asset_name"
  done
  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    profile_owned_path_remove "$SHIMMY_PROFILE_BIN_DIR/$tool_name"
  done <<EOF
$installed_tools
EOF
  profile_owned_path_remove "$SHIMMY_PROFILE_BIN_DIR/shimmy"
  profile_owned_path_remove "$SHIMMY_PROFILE_ROOT/shell-init.sh"
  profile_owned_path_remove "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
  profile_owned_path_remove "$SHIMMY_PROFILE_REGISTRIES_PATH"
  profile_owned_path_remove "$SHIMMY_PROFILE_MANIFEST_PATH"

  while IFS= read -r startup_file; do
    [ -n "$startup_file" ] || continue
    shimmy_startup_block_remove "$startup_file" "$SHIMMY_STARTUP_BLOCK_START" "$SHIMMY_STARTUP_BLOCK_END"
    log_info "Removed managed Shimmy startup block from: $startup_file"
  done <<EOF
$startup_files
EOF
  log_info "Removed Shimmy $uninstall_remove_profile profile from $SHIMMY_PROFILE_ROOT"
}

shimmy_uninstall_profile_context_resolve() {
  uninstall_context_profile=$1
  shimmy_profile_paths_resolve "$uninstall_context_profile" || {
    printf 'ERROR: unable to resolve canonical %s profile\n' "$uninstall_context_profile" >&2
    return 1
  }
  SHIMMY_PROFILE_RESOLVED=$uninstall_context_profile
  SHIMMY_BIN_DIR=$SHIMMY_PROFILE_BIN_DIR
  SHIMMY_CONTROL_BIN=$SHIMMY_BIN_DIR/shimmy
  SHIMMY_SHELL_INIT_FILE=$SHIMMY_PROFILE_ROOT/shell-init.sh
  INSTALL_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_PATH
}

shimmy_uninstall_projection_cleanup() {
  [ "$SHIMMY_UNINSTALL_HOST_OS" = darwin ] || return 0
  [ -n "$SHIMMY_UNINSTALL_PROJECTED_PROFILES" ] || return 0

  SHIMMY_UNINSTALL_DETACHED_PROFILES=
  SHIMMY_UNINSTALL_PREPARED_PROFILES=
  SHIMMY_UNINSTALL_RECORD_REMOVED_PROFILES=
  SHIMMY_UNINSTALL_TRANSACTION_ACTIVE=1
  if [ "$SHIMMY_UNINSTALL_MACHINE_OPERATIONS" -eq 1 ]; then
    shimmy_profile_cleanup_transaction_begin \
      "$SHIMMY_UNINSTALL_INITIAL_RUNNING_MACHINE" "$SHIMMY_UNINSTALL_INITIAL_DEFAULT_CONNECTION"
  fi

  for uninstall_projection_profile in $SHIMMY_UNINSTALL_PROJECTED_PROFILES; do
    shimmy_uninstall_profile_context_resolve "$uninstall_projection_profile" || {
      shimmy_uninstall_transaction_fail "unable to resolve profile $uninstall_projection_profile during cleanup"
      return 1
    }
    shimmy_profile_activation_expected_resolve || {
      shimmy_uninstall_transaction_fail "unable to resolve engine identity for $uninstall_projection_profile"
      return 1
    }
    shimmy_registries_machine_projection_detach_prepare || {
      shimmy_uninstall_transaction_fail "unable to prepare projection cleanup for $uninstall_projection_profile"
      return 1
    }
    SHIMMY_UNINSTALL_PREPARED_PROFILES=$(shimmy_append_line_list \
      "$SHIMMY_UNINSTALL_PREPARED_PROFILES" "$uninstall_projection_profile")
    if shimmy_contains_line_list "$SHIMMY_UNINSTALL_MISSING_PROFILES" "$uninstall_projection_profile"; then
      printf 'Removing projection record for proven-missing machine: %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE"
      continue
    fi
    if ! shimmy_profile_cleanup_machine_switch "$SHIMMY_PROFILE_EXPECTED_MACHINE" ||
      ! shimmy_profile_cleanup_engine_validate "$SHIMMY_PROFILE_EXPECTED_CONNECTION" ||
      ! shimmy_registries_machine_projection_detach_remote; then
      shimmy_uninstall_transaction_fail "unable to detach registry policy for $uninstall_projection_profile"
      return 1
    fi
    SHIMMY_UNINSTALL_DETACHED_PROFILES=$(shimmy_append_line_list \
      "$SHIMMY_UNINSTALL_DETACHED_PROFILES" "$uninstall_projection_profile")
    printf 'Detached Darwin registry projection for profile %s from %s\n' \
      "$uninstall_projection_profile" "$SHIMMY_PROFILE_EXPECTED_MACHINE"
    if shimmy_contains_line_list "$SHIMMY_UNINSTALL_RUNNING_PROFILES" "$uninstall_projection_profile"; then
      if ! shimmy_profile_cleanup_machine_restart "$SHIMMY_PROFILE_EXPECTED_MACHINE"; then
        shimmy_uninstall_transaction_fail "unable to restart $SHIMMY_PROFILE_EXPECTED_MACHINE after detach"
        return 1
      fi
    fi
  done

  if [ "$SHIMMY_UNINSTALL_MACHINE_OPERATIONS" -eq 1 ] && ! shimmy_profile_cleanup_restore; then
    shimmy_uninstall_transaction_fail 'unable to restore the initial Podman machine and default connection state'
    return 1
  fi
  for uninstall_projection_profile in $SHIMMY_UNINSTALL_PREPARED_PROFILES; do
    shimmy_uninstall_profile_context_resolve "$uninstall_projection_profile" || {
      shimmy_uninstall_transaction_fail "unable to resolve profile $uninstall_projection_profile before record removal"
      return 1
    }
    projection_backup=$SHIMMY_PROFILE_ROOT/.machine-projection.detach.$$
    if ! shimmy_registries_machine_projection_detach_record_remove "$projection_backup"; then
      shimmy_uninstall_transaction_fail "unable to remove projection record for $uninstall_projection_profile"
      return 1
    fi
    SHIMMY_UNINSTALL_RECORD_REMOVED_PROFILES=$(shimmy_append_line_list \
      "$SHIMMY_UNINSTALL_RECORD_REMOVED_PROFILES" "$uninstall_projection_profile")
  done
  for uninstall_projection_profile in $SHIMMY_UNINSTALL_PREPARED_PROFILES; do
    shimmy_uninstall_profile_context_resolve "$uninstall_projection_profile" || return 1
    shimmy_registries_machine_projection_detach_finalize \
      "$SHIMMY_PROFILE_ROOT/.machine-projection.detach.$$" || return 1
  done
  SHIMMY_UNINSTALL_TRANSACTION_ACTIVE=0
  if [ "$STOP_RUNNING" -eq 1 ] &&
    [ "$SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINER_COUNT" -gt 0 ]; then
    printf '%s\n' 'WARNING: acknowledged workloads were interrupted; verify that they resumed as intended.' >&2
  fi
}

shimmy_uninstall_registry_locks_release() {
  for uninstall_lock_profile in $SHIMMY_UNINSTALL_REGISTRY_LOCK_PROFILES; do
    uninstall_lock_path=$SHIMMY_PROFILES_ROOT/$uninstall_lock_profile/.registries.lock
    case "$uninstall_lock_path" in
      "$SHIMMY_PROFILES_ROOT"/default/.registries.lock|"$SHIMMY_PROFILES_ROOT"/upstream/.registries.lock)
        rmdir "$uninstall_lock_path" 2>/dev/null || true
        ;;
    esac
  done
  SHIMMY_UNINSTALL_REGISTRY_LOCK_PROFILES=
}

shimmy_uninstall_transaction_abort() {
  [ "${SHIMMY_UNINSTALL_TRANSACTION_ACTIVE:-0}" -eq 1 ] || return 0
  shimmy_uninstall_transaction_rollback 'uninstall interrupted before commit'
}

shimmy_uninstall_transaction_fail() {
  uninstall_failure_reason=$1
  printf 'ERROR: uninstall cleanup failed: %s\n' "$uninstall_failure_reason" >&2
  shimmy_uninstall_transaction_rollback "$uninstall_failure_reason"
}

shimmy_uninstall_transaction_rollback() {
  uninstall_rollback_reason=$1
  uninstall_rollback_complete=1

  for uninstall_rollback_profile in $SHIMMY_UNINSTALL_PREPARED_PROFILES; do
    shimmy_uninstall_profile_context_resolve "$uninstall_rollback_profile" || {
      uninstall_rollback_complete=0
      continue
    }
    projection_backup=$SHIMMY_PROFILE_ROOT/.machine-projection.detach.$$
    if shimmy_registries_machine_projection_detach_record_rollback "$projection_backup"; then
      printf 'Rollback: projection record retained for %s\n' "$uninstall_rollback_profile" >&2
    else
      printf 'Rollback: projection record restoration failed for %s\n' "$uninstall_rollback_profile" >&2
      uninstall_rollback_complete=0
    fi
  done

  for uninstall_rollback_profile in $SHIMMY_UNINSTALL_DETACHED_PROFILES; do
    shimmy_uninstall_profile_context_resolve "$uninstall_rollback_profile" || {
      uninstall_rollback_complete=0
      continue
    }
    shimmy_profile_activation_expected_resolve || {
      uninstall_rollback_complete=0
      continue
    }
    if shimmy_profile_cleanup_machine_switch "$SHIMMY_PROFILE_EXPECTED_MACHINE" &&
      shimmy_profile_cleanup_engine_validate "$SHIMMY_PROFILE_EXPECTED_CONNECTION" &&
      shimmy_registries_machine_projection_detach_remote_rollback &&
      shimmy_profile_cleanup_machine_restart "$SHIMMY_PROFILE_EXPECTED_MACHINE"; then
      printf 'Rollback: registry projection restored for %s\n' "$uninstall_rollback_profile" >&2
    else
      printf 'Rollback: registry projection restoration failed for %s\n' "$uninstall_rollback_profile" >&2
      uninstall_rollback_complete=0
    fi
  done
  if [ "$SHIMMY_UNINSTALL_MACHINE_OPERATIONS" -eq 1 ] && ! shimmy_profile_cleanup_restore; then
    uninstall_rollback_complete=0
  fi
  if [ "$STOP_RUNNING" -eq 1 ] &&
    [ "$SHIMMY_UNINSTALL_INITIAL_RUNNING_CONTAINER_COUNT" -gt 0 ]; then
    printf '%s\n' 'Rollback warning: acknowledged running workloads may not have resumed; inspect them manually.' >&2
    uninstall_rollback_complete=0
  fi
  for uninstall_rollback_profile in $SHIMMY_UNINSTALL_PREPARED_PROFILES; do
    shimmy_uninstall_profile_context_resolve "$uninstall_rollback_profile" || continue
    projection_backup=$SHIMMY_PROFILE_ROOT/.machine-projection.detach.$$
    if shimmy_registries_machine_projection_record_validate \
      "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" "$uninstall_rollback_profile"; then
      shimmy_registries_machine_projection_detach_finalize "$projection_backup" || true
    fi
  done
  SHIMMY_UNINSTALL_TRANSACTION_ACTIVE=0
  if [ "$uninstall_rollback_complete" -eq 1 ]; then
    printf 'Rollback result: prior projections and engine selection restored after %s.\n' \
      "$uninstall_rollback_reason" >&2
  else
    printf '%s\n' 'Rollback result: incomplete; profiles and catalogs were retained for recovery.' >&2
  fi
  return 1
}
