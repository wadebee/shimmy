#!/bin/sh
# Profile-bound Podman engine discovery and activation.

shimmy_profile_activation_expected_resolve() {
  command -v shimmy_engine_profile_binding_resolve >/dev/null 2>&1 || return 1
  [ -n "${SHIMMY_CONFIG_ROOT:-}" ] || return 1
  shimmy_engine_profile_binding_resolve "$SHIMMY_CONFIG_ROOT" \
    "${SHIMMY_PROFILE_NAME:-}"
}

shimmy_profile_activation_host_os_resolve() {
  if [ "${SHIMMY_TEST_PROFILE_OS+x}" = x ]; then
    host_os=$SHIMMY_TEST_PROFILE_OS
  else
    host_os=$(uname -s 2>/dev/null) || host_os=
  fi

  case "$host_os" in
    Darwin) SHIMMY_PROFILE_HOST_OS=darwin ;;
    Linux) SHIMMY_PROFILE_HOST_OS=linux ;;
    '') SHIMMY_PROFILE_HOST_OS=unknown ;;
    *) SHIMMY_PROFILE_HOST_OS=$(printf '%s' "$host_os" | tr '[:upper:]' '[:lower:]') ;;
  esac
}

shimmy_profile_activation_lock_acquire() {
  if [ "${SHIMMY_ACTIVATION_LOCK_EXTERNAL:-0}" -eq 1 ]; then
    command -v shimmy_lock_held >/dev/null 2>&1 &&
      shimmy_lock_held activation || {
        printf '%s\n' 'ERROR: profile activation requires the externally held installation activation lock' >&2
        return 1
      }
    SHIMMY_PROFILE_ACTIVATION_LOCK_HELD=external
    return 0
  fi
  SHIMMY_PROFILE_ACTIVATION_LOCK=$SHIMMY_CONFIG_ROOT/.profile-activation.lock
  [ -d "$SHIMMY_CONFIG_ROOT" ] && [ ! -L "$SHIMMY_CONFIG_ROOT" ] || {
    printf 'ERROR: invalid Shimmy configuration root for profile activation: %s\n' "$SHIMMY_CONFIG_ROOT" >&2
    return 1
  }
  if ! mkdir "$SHIMMY_PROFILE_ACTIVATION_LOCK" 2>/dev/null; then
    printf 'ERROR: another Shimmy profile activation holds %s; wait for it to finish and do not remove the lock automatically\n' "$SHIMMY_PROFILE_ACTIVATION_LOCK" >&2
    return 1
  fi
  SHIMMY_PROFILE_ACTIVATION_LOCK_HELD=1
}

shimmy_profile_activation_lock_check() {
  if [ "${SHIMMY_ACTIVATION_LOCK_EXTERNAL:-0}" -eq 1 ]; then
    command -v shimmy_lock_kind_resolve >/dev/null 2>&1 || return 1
    shimmy_lock_kind_resolve activation "$SHIMMY_CONFIG_ROOT" || return 1
    if [ -e "$SHIMMY_LOCK_PATH" ] || [ -L "$SHIMMY_LOCK_PATH" ]; then
      printf 'ERROR: another profile activation holds %s; dry-run made no changes\n' "$SHIMMY_LOCK_PATH" >&2
      return 1
    fi
    return 0
  fi
  SHIMMY_PROFILE_ACTIVATION_LOCK=$SHIMMY_CONFIG_ROOT/.profile-activation.lock
  if [ -e "$SHIMMY_PROFILE_ACTIVATION_LOCK" ] || [ -L "$SHIMMY_PROFILE_ACTIVATION_LOCK" ]; then
    printf 'ERROR: another Shimmy profile activation holds %s; dry-run made no changes\n' "$SHIMMY_PROFILE_ACTIVATION_LOCK" >&2
    return 1
  fi
}

shimmy_profile_activation_lock_release() {
  if [ "${SHIMMY_PROFILE_ACTIVATION_LOCK_HELD:-0}" = external ]; then
    SHIMMY_PROFILE_ACTIVATION_LOCK_HELD=0
    return 0
  fi
  [ "${SHIMMY_PROFILE_ACTIVATION_LOCK_HELD:-0}" -eq 1 ] || return 0
  case "${SHIMMY_PROFILE_ACTIVATION_LOCK:-}" in
    "$SHIMMY_CONFIG_ROOT"/.profile-activation.lock)
      rmdir "$SHIMMY_PROFILE_ACTIVATION_LOCK" 2>/dev/null || true
      ;;
  esac
  SHIMMY_PROFILE_ACTIVATION_LOCK_HELD=0
}

shimmy_profile_activation_override_read() {
  SHIMMY_PROFILE_CONNECTION_OVERRIDE=none
  if [ -n "${CONTAINER_CONNECTION:-}" ] && [ -n "${CONTAINER_HOST:-}" ]; then
    SHIMMY_PROFILE_CONNECTION_OVERRIDE=CONTAINER_CONNECTION,CONTAINER_HOST
  elif [ -n "${CONTAINER_CONNECTION:-}" ]; then
    SHIMMY_PROFILE_CONNECTION_OVERRIDE=CONTAINER_CONNECTION
  elif [ -n "${CONTAINER_HOST:-}" ]; then
    SHIMMY_PROFILE_CONNECTION_OVERRIDE=CONTAINER_HOST
  fi
}

shimmy_profile_activation_override_reject() {
  shimmy_profile_activation_override_read
  [ "$SHIMMY_PROFILE_CONNECTION_OVERRIDE" = none ] && return 0
  printf 'ERROR: %s overrides Podman profile activation; unset it and retry (its value was not displayed)\n' "$SHIMMY_PROFILE_CONNECTION_OVERRIDE" >&2
  return 1
}

shimmy_profile_activation_recommendation_resolve() {
  connection_override=${SHIMMY_PROFILE_CONNECTION_OVERRIDE:-none}
  registry_override=${SHIMMY_REGISTRIES_OVERRIDE:-none}
  activation_state=${SHIMMY_PROFILE_ACTIVATION_STATE:-unknown}
  expected_machine_state=${SHIMMY_PROFILE_EXPECTED_MACHINE_STATE:-unknown}

  SHIMMY_PROFILE_ACTIVATION_LABEL=$(printf '%s' "$activation_state" | tr '_' ' ')
  SHIMMY_PROFILE_RECOMMENDED_ACTION=investigate
  SHIMMY_PROFILE_RECOMMENDED_ACTION_LABEL=investigate
  SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND=

  if [ "$connection_override" != none ] || [ "$registry_override" != none ]; then
    masking_overrides=
    if [ "$connection_override" != none ]; then
      masking_overrides=$connection_override
    fi
    if [ "$registry_override" != none ]; then
      if [ -n "$masking_overrides" ]; then
        masking_overrides=$masking_overrides,$registry_override
      else
        masking_overrides=$registry_override
      fi
    fi
    SHIMMY_PROFILE_RECOMMENDED_ACTION=unset_override
    SHIMMY_PROFILE_RECOMMENDED_ACTION_LABEL='unset override'
    SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND="unset $(printf '%s' "$masking_overrides" | tr ',' ' ')"
    return 0
  fi

  case "$activation_state" in
    active)
      SHIMMY_PROFILE_RECOMMENDED_ACTION=none
      SHIMMY_PROFILE_RECOMMENDED_ACTION_LABEL=none
      ;;
    alternate_running|mismatched_default|ready|stopped)
      SHIMMY_PROFILE_RECOMMENDED_ACTION=profile_activate
      SHIMMY_PROFILE_RECOMMENDED_ACTION_LABEL='activate profile'
      SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND="'${SHIMMY_PROFILE_ROOT:-unknown}/bin/shimmy' profile activate ${SHIMMY_PROFILE_NAME:-unknown}"
      ;;
    registry_policy_stale)
      SHIMMY_PROFILE_RECOMMENDED_ACTION=profile_activate_restart
      SHIMMY_PROFILE_RECOMMENDED_ACTION_LABEL='restart profile engine'
      SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND="'${SHIMMY_PROFILE_ROOT:-unknown}/bin/shimmy' profile activate ${SHIMMY_PROFILE_NAME:-unknown} --restart"
      ;;
    overridden)
      SHIMMY_PROFILE_RECOMMENDED_ACTION=unset_override
      SHIMMY_PROFILE_RECOMMENDED_ACTION_LABEL='unset override'
      ;;
  esac
}

shimmy_profile_connection_is_rootless() {
  connection_target=$1
  connection_lines=$2
  connection_matches=0
  connection_rootless=0

  while IFS='|' read -r connection_name connection_uri connection_default connection_extra; do
    [ -n "$connection_name" ] || continue
    [ -z "$connection_extra" ] || return 1
    [ "$connection_name" = "$connection_target" ] || continue
    connection_matches=$((connection_matches + 1))
    case "$connection_uri" in
      ssh://root@*) ;;
      ssh://*/*/run/user/*/podman/podman.sock|ssh://*/run/user/*/podman/podman.sock)
        connection_rootless=1
        ;;
    esac
  done <<EOF
$connection_lines
EOF

  [ "$connection_matches" -eq 1 ] && [ "$connection_rootless" -eq 1 ]
}

shimmy_profile_podman_bin_require() {
  if [ -n "${SHIMMY_TEST_PROFILE_PODMAN_BIN:-}" ]; then
    SHIMMY_PROFILE_PODMAN_BIN=$SHIMMY_TEST_PROFILE_PODMAN_BIN
    [ -x "$SHIMMY_PROFILE_PODMAN_BIN" ] || return 1
    return 0
  fi
  if command -v podman >/dev/null 2>&1; then
    SHIMMY_PROFILE_PODMAN_BIN=$(command -v podman)
    return 0
  fi
  if [ -x /opt/podman/bin/podman ]; then
    SHIMMY_PROFILE_PODMAN_BIN=/opt/podman/bin/podman
    return 0
  fi
  SHIMMY_PROFILE_PODMAN_BIN=
  return 1
}

shimmy_profile_podman_run() {
  "$SHIMMY_PROFILE_PODMAN_BIN" "$@"
}

shimmy_profile_state_connections_read() {
  SHIMMY_PROFILE_CONNECTION_METADATA=unavailable
  SHIMMY_PROFILE_CONNECTION_LINES=
  SHIMMY_PROFILE_DEFAULT_CONNECTION=unknown
  SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE=missing

  connection_output=$(shimmy_profile_podman_run system connection list --format '{{.Name}}|{{.URI}}|{{.Default}}' 2>/dev/null) || return 0
  default_count=0
  expected_count=0
  connection_names=
  connection_invalid=0
  while IFS='|' read -r connection_name connection_uri connection_default connection_extra; do
    [ -n "$connection_name" ] || continue
    case "$connection_name" in *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-]*) connection_invalid=1 ;; esac
    [ -z "$connection_extra" ] || connection_invalid=1
    case "$connection_default" in true|false) ;; *) connection_invalid=1 ;; esac
    shimmy_contains_line_list "$connection_names" "$connection_name" && connection_invalid=1
    connection_names=$(shimmy_append_line_list "$connection_names" "$connection_name")
    [ "$connection_name" != "$SHIMMY_PROFILE_EXPECTED_CONNECTION" ] || expected_count=$((expected_count + 1))
    if [ "$connection_default" = true ]; then
      default_count=$((default_count + 1))
      SHIMMY_PROFILE_DEFAULT_CONNECTION=$connection_name
    fi
  done <<EOF
$connection_output
EOF
  [ "$connection_invalid" -eq 0 ] && [ "$default_count" -eq 1 ] || {
    SHIMMY_PROFILE_CONNECTION_METADATA=invalid
    return 0
  }
  SHIMMY_PROFILE_CONNECTION_LINES=$connection_output
  SHIMMY_PROFILE_CONNECTION_METADATA=valid
  if [ "$expected_count" -eq 1 ]; then
    if shimmy_profile_connection_is_rootless "$SHIMMY_PROFILE_EXPECTED_CONNECTION" "$connection_output"; then
      SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE=rootless
    else
      SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE=invalid
    fi
  elif [ "$expected_count" -gt 1 ]; then
    SHIMMY_PROFILE_CONNECTION_METADATA=invalid
    SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE=invalid
  fi
}

shimmy_profile_state_darwin_read() {
  SHIMMY_PROFILE_MACHINE_METADATA=unavailable
  SHIMMY_PROFILE_EXPECTED_MACHINE_STATE=unknown
  SHIMMY_PROFILE_ALTERNATE_RUNNING_MACHINE=none
  SHIMMY_PROFILE_RUNNING_MACHINE=none
  SHIMMY_PROFILE_RUNNING_MACHINE_COUNT=0
  SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT=unknown
  SHIMMY_PROFILE_RUNNING_CONTAINERS=
  SHIMMY_PROFILE_ENGINE_REACHABLE=unknown
  shimmy_profile_activation_override_read
  if command -v shimmy_registries_override_read >/dev/null 2>&1; then
    shimmy_registries_override_read
  else
    SHIMMY_REGISTRIES_OVERRIDE=none
  fi
  if [ "$SHIMMY_PROFILE_CONNECTION_OVERRIDE" != none ] || [ "$SHIMMY_REGISTRIES_OVERRIDE" != none ]; then
    SHIMMY_PROFILE_CONNECTION_METADATA=unknown
    SHIMMY_PROFILE_DEFAULT_CONNECTION=unknown
    SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE=unknown
    SHIMMY_PROFILE_ACTIVATION_STATE=overridden
    return 0
  fi

  if ! shimmy_profile_podman_bin_require; then
    SHIMMY_PROFILE_ACTIVATION_STATE=unavailable
    SHIMMY_PROFILE_CONNECTION_METADATA=unavailable
    SHIMMY_PROFILE_DEFAULT_CONNECTION=unknown
    SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE=unknown
    return 0
  fi

  machine_output=$(shimmy_profile_podman_run machine list --format '{{.Name}}|{{.Running}}' 2>/dev/null) || {
    SHIMMY_PROFILE_ACTIVATION_STATE=unreachable
    shimmy_profile_state_connections_read
    return 0
  }
  machine_names=
  machine_expected_count=0
  machine_invalid=0
  while IFS='|' read -r machine_name machine_running machine_extra; do
    [ -n "$machine_name" ] || continue
    case "$machine_name" in *\*) machine_name=${machine_name%\*} ;; esac
    case "$machine_name" in ''|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-]*) machine_invalid=1 ;; esac
    [ -z "$machine_extra" ] || machine_invalid=1
    case "$machine_running" in true|false) ;; *) machine_invalid=1 ;; esac
    shimmy_contains_line_list "$machine_names" "$machine_name" && machine_invalid=1
    machine_names=$(shimmy_append_line_list "$machine_names" "$machine_name")
    if [ "$machine_name" = "$SHIMMY_PROFILE_EXPECTED_MACHINE" ]; then
      machine_expected_count=$((machine_expected_count + 1))
      if [ "$machine_running" = true ]; then
        SHIMMY_PROFILE_EXPECTED_MACHINE_STATE=running
      else
        SHIMMY_PROFILE_EXPECTED_MACHINE_STATE=stopped
      fi
    fi
    if [ "$machine_running" = true ]; then
      SHIMMY_PROFILE_RUNNING_MACHINE_COUNT=$((SHIMMY_PROFILE_RUNNING_MACHINE_COUNT + 1))
      SHIMMY_PROFILE_RUNNING_MACHINE=$machine_name
      if [ "$machine_name" != "$SHIMMY_PROFILE_EXPECTED_MACHINE" ]; then
        SHIMMY_PROFILE_ALTERNATE_RUNNING_MACHINE=$machine_name
      fi
    fi
  done <<EOF
$machine_output
EOF
  if [ "$machine_expected_count" -eq 0 ]; then
    SHIMMY_PROFILE_EXPECTED_MACHINE_STATE=missing
  elif [ "$machine_expected_count" -gt 1 ]; then
    machine_invalid=1
  fi
  if [ "$machine_invalid" -ne 0 ] || [ "$SHIMMY_PROFILE_RUNNING_MACHINE_COUNT" -gt 1 ]; then
    SHIMMY_PROFILE_MACHINE_METADATA=invalid
  else
    SHIMMY_PROFILE_MACHINE_METADATA=valid
  fi

  shimmy_profile_state_connections_read
  if [ "$SHIMMY_PROFILE_RUNNING_MACHINE_COUNT" -eq 1 ] &&
    [ "$SHIMMY_PROFILE_CONNECTION_METADATA" = valid ] &&
    shimmy_profile_connection_is_rootless "$SHIMMY_PROFILE_RUNNING_MACHINE" "$SHIMMY_PROFILE_CONNECTION_LINES"; then
    if workload_output=$(shimmy_profile_podman_run --connection "$SHIMMY_PROFILE_RUNNING_MACHINE" ps --format '{{.ID}}|{{.Names}}' 2>/dev/null); then
      SHIMMY_PROFILE_RUNNING_CONTAINERS=$workload_output
      workload_count=0
      while IFS= read -r workload_line; do
        [ -n "$workload_line" ] || continue
        workload_count=$((workload_count + 1))
      done <<EOF
$workload_output
EOF
      SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT=$workload_count
    fi
  fi

  if [ "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" = running ] &&
    [ "$SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE" = rootless ]; then
    if target_info=$(shimmy_profile_podman_run --connection "$SHIMMY_PROFILE_EXPECTED_CONNECTION" info --format '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}' 2>/dev/null) &&
      [ "$target_info" = 'true|true' ]; then
      SHIMMY_PROFILE_ENGINE_REACHABLE=true
    else
      SHIMMY_PROFILE_ENGINE_REACHABLE=false
    fi
  fi

  if [ "$SHIMMY_PROFILE_MACHINE_METADATA" = invalid ] || [ "$SHIMMY_PROFILE_CONNECTION_METADATA" = invalid ] ||
    [ "$SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE" = invalid ]; then
    SHIMMY_PROFILE_ACTIVATION_STATE=invalid_metadata
  elif [ "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" = missing ]; then
    SHIMMY_PROFILE_ACTIVATION_STATE=unavailable
  elif [ "$SHIMMY_PROFILE_CONNECTION_METADATA" = unavailable ]; then
    SHIMMY_PROFILE_ACTIVATION_STATE=unreachable
  elif [ "$SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE" = missing ]; then
    SHIMMY_PROFILE_ACTIVATION_STATE=invalid_metadata
  elif [ "$SHIMMY_PROFILE_ALTERNATE_RUNNING_MACHINE" != none ]; then
    SHIMMY_PROFILE_ACTIVATION_STATE=alternate_running
  elif [ "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" = stopped ]; then
    SHIMMY_PROFILE_ACTIVATION_STATE=stopped
  elif [ "$SHIMMY_PROFILE_DEFAULT_CONNECTION" != "$SHIMMY_PROFILE_EXPECTED_CONNECTION" ]; then
    SHIMMY_PROFILE_ACTIVATION_STATE=mismatched_default
  elif [ "$SHIMMY_PROFILE_ENGINE_REACHABLE" != true ]; then
    SHIMMY_PROFILE_ACTIVATION_STATE=unreachable
  else
    SHIMMY_PROFILE_ACTIVATION_STATE=active
  fi
  if [ "${SHIMMY_PROFILE_ENGINE_ORIGIN:-unknown}" = shimmy-created ]; then
    shimmy_engine_registry_projection_state_read "$SHIMMY_CONFIG_ROOT" \
      "$SHIMMY_PROFILE_NAME" "$SHIMMY_PROFILE_ENGINE_ID" || return 1
    if [ "$SHIMMY_PROFILE_ACTIVATION_STATE" = active ] &&
      [ "$SHIMMY_ENGINE_REGISTRY_PROJECTION_STATE" != current ]; then
      SHIMMY_PROFILE_ACTIVATION_STATE=registry_policy_stale
    fi
  fi
}

shimmy_profile_state_linux_read() {
  SHIMMY_PROFILE_EXPECTED_MACHINE=local
  SHIMMY_PROFILE_EXPECTED_CONNECTION=not_applicable
  SHIMMY_PROFILE_EXPECTED_MACHINE_STATE=not_applicable
  SHIMMY_PROFILE_ALTERNATE_RUNNING_MACHINE=none
  SHIMMY_PROFILE_RUNNING_MACHINE=local
  SHIMMY_PROFILE_RUNNING_MACHINE_COUNT=0
  SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT=unknown
  SHIMMY_PROFILE_DEFAULT_CONNECTION=not_applicable
  SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE=not_applicable
  SHIMMY_PROFILE_CONNECTION_METADATA=not_applicable
  SHIMMY_PROFILE_MACHINE_METADATA=not_applicable
  shimmy_profile_activation_override_read
  if command -v shimmy_registries_override_read >/dev/null 2>&1; then
    shimmy_registries_override_read
  else
    SHIMMY_REGISTRIES_OVERRIDE=none
  fi
  if [ "$SHIMMY_PROFILE_CONNECTION_OVERRIDE" != none ]; then
    SHIMMY_PROFILE_ENGINE_REACHABLE=unknown
    SHIMMY_PROFILE_ACTIVATION_STATE=overridden
    return 0
  fi
  if [ "$SHIMMY_REGISTRIES_OVERRIDE" != none ]; then
    SHIMMY_PROFILE_ENGINE_REACHABLE=unknown
    SHIMMY_PROFILE_ACTIVATION_STATE=overridden
    return 0
  fi
  if ! shimmy_profile_podman_bin_require; then
    SHIMMY_PROFILE_ENGINE_REACHABLE=false
    SHIMMY_PROFILE_ACTIVATION_STATE=unavailable
    return 0
  fi
  if linux_info=$(shimmy_profile_podman_run info --format '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}' 2>/dev/null); then
    case "$linux_info" in
      'true|false')
        SHIMMY_PROFILE_ENGINE_REACHABLE=true
        SHIMMY_PROFILE_ACTIVATION_STATE=ready
        if command -v shimmy_registries_active_link_state_read >/dev/null 2>&1; then
          shimmy_registries_active_link_state_read
          case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in
            current) SHIMMY_PROFILE_ACTIVATION_STATE=active ;;
            absent|sibling) ;;
            *) SHIMMY_PROFILE_ACTIVATION_STATE=invalid_registry ;;
          esac
        fi
        ;;
      *) SHIMMY_PROFILE_ENGINE_REACHABLE=false; SHIMMY_PROFILE_ACTIVATION_STATE=unsupported_engine ;;
    esac
  else
    SHIMMY_PROFILE_ENGINE_REACHABLE=false
    SHIMMY_PROFILE_ACTIVATION_STATE=unreachable
  fi
}

shimmy_profile_linux_engine_validate() {
  shimmy_profile_podman_bin_require || {
    printf '%s\n' 'ERROR: Podman is required for Linux registry activation.' >&2
    return 1
  }
  linux_info=$(shimmy_profile_podman_run info --format '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}' 2>/dev/null) || {
    printf '%s\n' 'ERROR: local Linux Podman engine is unreachable' >&2
    return 1
  }
  [ "$linux_info" = 'true|false' ] || {
    printf '%s\n' 'ERROR: Linux activation requires the current user local rootless Podman engine; remote and rootful engines are unsupported' >&2
    return 1
  }
}

shimmy_profile_state_read() {
  shimmy_profile_activation_expected_resolve || return 1
  shimmy_profile_activation_host_os_resolve
  case "$SHIMMY_PROFILE_HOST_OS" in
    darwin) SHIMMY_PROFILE_ENGINE_TYPE=podman_machine; shimmy_profile_state_darwin_read ;;
    linux) SHIMMY_PROFILE_ENGINE_TYPE=local_rootless; shimmy_profile_state_linux_read ;;
    *)
      SHIMMY_PROFILE_ENGINE_TYPE=unsupported
      SHIMMY_PROFILE_ACTIVATION_STATE=unsupported_host
      SHIMMY_PROFILE_ENGINE_REACHABLE=unknown
      SHIMMY_PROFILE_EXPECTED_MACHINE_STATE=unknown
      SHIMMY_PROFILE_ALTERNATE_RUNNING_MACHINE=none
      SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT=unknown
      SHIMMY_PROFILE_DEFAULT_CONNECTION=unknown
      shimmy_profile_activation_override_read
      if command -v shimmy_registries_override_read >/dev/null 2>&1; then
        shimmy_registries_override_read
      else
        SHIMMY_REGISTRIES_OVERRIDE=none
      fi
      SHIMMY_PROFILE_CONNECTION_METADATA=unknown
      SHIMMY_PROFILE_MACHINE_METADATA=unknown
      SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE=unknown
      ;;
  esac
}

shimmy_profile_status_print() {
  output_format=$1
  shimmy_profile_state_read
  case "$output_format" in
    manifest)
      printf 'profile=%s\n' "$SHIMMY_PROFILE_NAME"
      printf 'host_os=%s\n' "$SHIMMY_PROFILE_HOST_OS"
      printf 'engine_type=%s\n' "$SHIMMY_PROFILE_ENGINE_TYPE"
      printf 'expected_engine=%s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE"
      printf 'expected_connection=%s\n' "$SHIMMY_PROFILE_EXPECTED_CONNECTION"
      printf 'default_connection=%s\n' "$SHIMMY_PROFILE_DEFAULT_CONNECTION"
      printf 'machine_state=%s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE"
      printf 'alternate_running_machine=%s\n' "$SHIMMY_PROFILE_ALTERNATE_RUNNING_MACHINE"
      printf 'running_container_count=%s\n' "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT"
      printf 'connection_override=%s\n' "$SHIMMY_PROFILE_CONNECTION_OVERRIDE"
      printf 'machine_metadata=%s\n' "$SHIMMY_PROFILE_MACHINE_METADATA"
      printf 'connection_metadata=%s\n' "$SHIMMY_PROFILE_CONNECTION_METADATA"
      printf 'engine_reachable=%s\n' "$SHIMMY_PROFILE_ENGINE_REACHABLE"
      printf 'activation=%s\n' "$SHIMMY_PROFILE_ACTIVATION_STATE"
      ;;
    human)
      printf 'Profile: %s\n' "$SHIMMY_PROFILE_NAME"
      printf 'Host OS: %s\n' "$SHIMMY_PROFILE_HOST_OS"
      printf 'Expected engine: %s (%s)\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" "$SHIMMY_PROFILE_ENGINE_TYPE"
      printf 'Expected connection: %s\n' "$SHIMMY_PROFILE_EXPECTED_CONNECTION"
      printf 'Default connection: %s\n' "$SHIMMY_PROFILE_DEFAULT_CONNECTION"
      printf 'Machine state: %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE"
      printf 'Alternate running machine: %s\n' "$SHIMMY_PROFILE_ALTERNATE_RUNNING_MACHINE"
      printf 'Running containers: %s\n' "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT"
      printf 'Connection override: %s\n' "$SHIMMY_PROFILE_CONNECTION_OVERRIDE"
      printf 'Activation: %s\n' "$SHIMMY_PROFILE_ACTIVATION_STATE"
      ;;
  esac
}

shimmy_profile_workloads_print() {
  [ -n "${SHIMMY_PROFILE_RUNNING_CONTAINERS:-}" ] || return 0
  printf 'Running containers on %s:\n' "$SHIMMY_PROFILE_RUNNING_MACHINE"
  printf '%s\n' "$SHIMMY_PROFILE_RUNNING_CONTAINERS"
}

shimmy_profile_activation_rollback() {
  rollback_reason=$1
  rollback_complete=1
  printf 'ERROR: profile activation failed: %s\n' "$rollback_reason" >&2

  if [ "${SHIMMY_ENGINE_PROJECTION_APPLIED:-0}" -eq 1 ]; then
    if shimmy_engine_projection_rollback "$SHIMMY_PROFILE_EXPECTED_MACHINE"; then
      printf 'Rollback: engine registry projection restored for %s\n' \
        "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
    else
      rollback_complete=0
    fi
  fi

  if [ "${SHIMMY_REGISTRIES_ACTIVE_LINK_CHANGED:-0}" -eq 1 ]; then
    if shimmy_registries_active_link_rollback; then
      printf 'Rollback: Linux active registry link restored for %s\n' "$SHIMMY_PROFILE_NAME" >&2
    else
      rollback_complete=0
    fi
  fi

  if [ "${SHIMMY_PROFILE_TARGET_START_ATTEMPTED:-0}" -eq 1 ]; then
    if shimmy_profile_podman_run machine stop "$SHIMMY_PROFILE_EXPECTED_MACHINE" </dev/null >/dev/null 2>&1; then
      printf 'Rollback: target cleanup succeeded for %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
    else
      printf 'Rollback: target cleanup failed for %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
      rollback_complete=0
    fi
  fi
  if [ "${SHIMMY_PROFILE_PRIOR_STOP_ATTEMPTED:-0}" -eq 1 ] && [ -n "${SHIMMY_PROFILE_PRIOR_RUNNING_MACHINE:-}" ]; then
    if shimmy_profile_podman_run machine start "$SHIMMY_PROFILE_PRIOR_RUNNING_MACHINE" </dev/null >/dev/null 2>&1; then
      printf 'Rollback: previous machine restart succeeded for %s\n' "$SHIMMY_PROFILE_PRIOR_RUNNING_MACHINE" >&2
    else
      printf 'Rollback: previous machine restart failed for %s\n' "$SHIMMY_PROFILE_PRIOR_RUNNING_MACHINE" >&2
      rollback_complete=0
    fi
  fi
  if [ -n "${SHIMMY_PROFILE_PRIOR_DEFAULT_CONNECTION:-}" ]; then
    if shimmy_profile_podman_run system connection default "$SHIMMY_PROFILE_PRIOR_DEFAULT_CONNECTION" >/dev/null 2>&1; then
      printf 'Rollback: previous default connection restored to %s\n' "$SHIMMY_PROFILE_PRIOR_DEFAULT_CONNECTION" >&2
    else
      printf 'Rollback: previous default connection restoration failed for %s\n' "$SHIMMY_PROFILE_PRIOR_DEFAULT_CONNECTION" >&2
      rollback_complete=0
    fi
  fi
  if [ "${SHIMMY_PROFILE_WORKLOAD_INTERRUPTED:-0}" -eq 1 ]; then
    printf '%s\n' 'Rollback warning: acknowledged running workloads may not have resumed; inspect them manually.' >&2
    rollback_complete=0
  fi
  if [ "$rollback_complete" -eq 1 ]; then
    printf '%s\n' 'Rollback result: prior engine selection restored.' >&2
  else
    printf '%s\n' 'Rollback result: incomplete; inspect Podman machine, workload, and connection state.' >&2
  fi
  return 1
}

shimmy_profile_activate_darwin_managed() {
  restart_requested=$1
  stop_running_requested=$2
  dry_run_requested=$3
  shimmy_profile_activation_override_reject || return 1
  shimmy_registries_override_reject || return 1
  shimmy_profile_podman_bin_require || {
    printf '%s\n' 'ERROR: Podman is required for managed profile activation.' >&2
    return 1
  }
  shimmy_engine_podman_bin_require || return 1
  if [ "$dry_run_requested" -eq 1 ]; then
    shimmy_profile_activation_lock_check || return 1
    shimmy_registries_lock_check || return 1
  else
    shimmy_profile_activation_lock_acquire || return 1
    shimmy_registries_lock_acquire || return 1
  fi
  shimmy_registries_config_validate "$SHIMMY_PROFILE_REGISTRIES_PATH" \
    "$SHIMMY_PROFILE_NAME" || return 1
  shimmy_engine_record_read "$SHIMMY_PROFILE_ENGINE_RECORD_PATH" || return 1
  [ "$SHIMMY_ENGINE_RECORD_ID" = "$SHIMMY_PROFILE_ENGINE_ID" ] &&
    [ "$SHIMMY_ENGINE_RECORD_KIND|$SHIMMY_ENGINE_RECORD_ORIGIN" = \
      'darwin-machine|shimmy-created' ] || return 1
  SHIMMY_PROFILE_MANAGED_CREATE_PENDING=0
  if [ "${SHIMMY_PROFILE_ENGINE_CREATE_PENDING:-0}" -eq 1 ]; then
    [ -f "$SHIMMY_ENGINE_LIFECYCLE_PATH" ] &&
      [ ! -L "$SHIMMY_ENGINE_LIFECYCLE_PATH" ] || return 1
    shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
    [ "$SHIMMY_ENGINE_LIFECYCLE_ID|$SHIMMY_ENGINE_LIFECYCLE_OPERATION|$SHIMMY_ENGINE_LIFECYCLE_PHASE" = \
      "$SHIMMY_PROFILE_ENGINE_ID|create|recorded" ] || return 1
    SHIMMY_PROFILE_MANAGED_CREATE_PENDING=1
  fi
  shimmy_engine_ownership_host_state_read "$SHIMMY_PROFILE_ENGINE_RECORD_PATH"
  [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || {
    printf 'ERROR: managed engine ownership is %s: %s\n' \
      "$SHIMMY_ENGINE_OWNERSHIP_STATE" "$SHIMMY_ENGINE_OWNERSHIP_REASON" >&2
    return 1
  }
  shimmy_profile_state_darwin_read
  [ "$SHIMMY_PROFILE_MACHINE_METADATA" = valid ] &&
    [ "$SHIMMY_PROFILE_CONNECTION_METADATA" = valid ] &&
    [ "$SHIMMY_PROFILE_EXPECTED_CONNECTION_STATE" = rootless ] || return 1
  case "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" in running|stopped) ;; *) return 1 ;; esac
  shimmy_profile_managed_stop_planned=0
  if [ "$SHIMMY_PROFILE_RUNNING_MACHINE_COUNT" -eq 1 ] &&
    { [ "$SHIMMY_PROFILE_RUNNING_MACHINE" != "$SHIMMY_PROFILE_EXPECTED_MACHINE" ] ||
      [ "$restart_requested" -eq 1 ]; }; then
    shimmy_profile_managed_stop_planned=1
  fi
  if [ "$stop_running_requested" -eq 1 ] &&
    [ "$shimmy_profile_managed_stop_planned" -eq 0 ]; then
    printf '%s\n' 'ERROR: --stop-running is valid only when activation will stop a running machine' >&2
    return 1
  fi
  if [ "$shimmy_profile_managed_stop_planned" -eq 1 ]; then
    [ "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT" != unknown ] || return 1
    shimmy_profile_workloads_print
    if [ "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT" -gt 0 ] &&
      [ "$stop_running_requested" -eq 0 ]; then
      printf '%s\n' 'ERROR: running containers block the engine transition; retry with --stop-running only after reviewing them' >&2
      return 1
    fi
  fi
  shimmy_engine_registry_projection_action_plan "$SHIMMY_CONFIG_ROOT" \
    "$SHIMMY_PROFILE_NAME" "$SHIMMY_PROFILE_ENGINE_ID" || return 1
  if [ "$dry_run_requested" -eq 1 ]; then
    printf 'dry_run=yes\nprofile=%s\nengine_id=%s\nengine_name=%s\n' \
      "$SHIMMY_PROFILE_NAME" "$SHIMMY_PROFILE_ENGINE_ID" \
      "$SHIMMY_PROFILE_EXPECTED_MACHINE"
    printf 'would_recycle_podman_service=%s\n' \
      "$(if [ "$SHIMMY_ENGINE_REGISTRY_PLANNED_SERVICE_ACTION" = recycle-podman-service ]; then printf yes; else printf no; fi)"
    if [ "$shimmy_profile_managed_stop_planned" -eq 1 ]; then
      printf 'would_stop=%s\n' "$SHIMMY_PROFILE_RUNNING_MACHINE"
    fi
    if [ "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" = stopped ] ||
      [ "$restart_requested" -eq 1 ]; then
      printf 'would_start=%s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE"
    fi
    printf 'would_restart_vm=%s\nwould_stop_running=%s\n' \
      "$restart_requested" "$stop_running_requested"
    return 0
  fi

  SHIMMY_PROFILE_PRIOR_DEFAULT_CONNECTION=$SHIMMY_PROFILE_DEFAULT_CONNECTION
  SHIMMY_PROFILE_PRIOR_RUNNING_MACHINE=
  SHIMMY_PROFILE_PRIOR_STOP_ATTEMPTED=0
  SHIMMY_PROFILE_TARGET_START_ATTEMPTED=0
  SHIMMY_PROFILE_WORKLOAD_INTERRUPTED=0
  shimmy_engine_paths_resolve "$SHIMMY_CONFIG_ROOT" "$SHIMMY_PROFILE_ENGINE_ID" || return 1
  shimmy_engine_projection_prepare "$SHIMMY_PROFILE_ENGINE_ID" "$SHIMMY_ENGINE_ROOT" \
    "$SHIMMY_PROFILE_NAME" "$SHIMMY_PROFILE_REGISTRIES_PATH" \
    "$SHIMMY_PROFILE_EXPECTED_CONNECTION" || return 1
  if [ "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" = running ] &&
    [ "$SHIMMY_PROFILE_MANAGED_CREATE_PENDING" -eq 0 ]; then
    shimmy_engine_podman_projection_dropin_verify "$SHIMMY_PROFILE_EXPECTED_MACHINE" \
      "$SHIMMY_ENGINE_REGISTRIES_PATH" || {
        printf '%s\n' 'ERROR: managed engine registry drop-in is missing or foreign' >&2
        return 1
      }
    shimmy_engine_ownership_state_read "$SHIMMY_PROFILE_ENGINE_RECORD_PATH"
    [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || return 1
  fi
  if [ "$shimmy_profile_managed_stop_planned" -eq 1 ]; then
    SHIMMY_PROFILE_PRIOR_RUNNING_MACHINE=$SHIMMY_PROFILE_RUNNING_MACHINE
    SHIMMY_PROFILE_PRIOR_STOP_ATTEMPTED=1
    [ "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT" -eq 0 ] || SHIMMY_PROFILE_WORKLOAD_INTERRUPTED=1
    shimmy_profile_podman_run machine stop "$SHIMMY_PROFILE_RUNNING_MACHINE" </dev/null || {
      shimmy_profile_activation_rollback 'unable to stop the prior managed engine' || true
      return 1
    }
  fi
  if [ "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" = stopped ] ||
    [ "$restart_requested" -eq 1 ]; then
    SHIMMY_PROFILE_TARGET_START_ATTEMPTED=1
    if [ "$SHIMMY_PROFILE_MANAGED_CREATE_PENDING" -eq 1 ]; then
      shimmy_engine_machine_create_start "$SHIMMY_ENGINE_LIFECYCLE_PATH" || {
        shimmy_profile_activation_rollback 'unable to start the new isolated engine' || true
        return 1
      }
    else
      shimmy_profile_podman_run machine start "$SHIMMY_PROFILE_EXPECTED_MACHINE" </dev/null || {
        shimmy_profile_activation_rollback 'unable to start the managed engine' || true
        return 1
      }
    fi
  fi
  if [ "$SHIMMY_PROFILE_MANAGED_CREATE_PENDING" -eq 1 ]; then
    shimmy_engine_podman_projection_dropin_install "$SHIMMY_PROFILE_EXPECTED_MACHINE" \
      "$SHIMMY_ENGINE_REGISTRIES_PATH" || {
        shimmy_profile_activation_rollback 'unable to install isolated engine registry authority' || true
        return 1
      }
    shimmy_engine_machine_create_guest_mark "$SHIMMY_ENGINE_LIFECYCLE_PATH" || {
      shimmy_profile_activation_rollback 'unable to record isolated engine guest ownership' || true
      return 1
    }
  else
    shimmy_engine_podman_projection_dropin_verify "$SHIMMY_PROFILE_EXPECTED_MACHINE" \
      "$SHIMMY_ENGINE_REGISTRIES_PATH" || {
        shimmy_profile_activation_rollback 'managed engine registry drop-in is missing or foreign' || true
        return 1
      }
  fi
  shimmy_engine_ownership_state_read "$SHIMMY_PROFILE_ENGINE_RECORD_PATH"
  [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || {
    shimmy_profile_activation_rollback 'managed engine ownership could not be verified after start' || true
    return 1
  }
  shimmy_engine_projection_apply "$SHIMMY_PROFILE_EXPECTED_MACHINE" || {
    shimmy_profile_activation_rollback 'unable to apply managed engine registry projection' || true
    return 1
  }
  if [ "$SHIMMY_PROFILE_DEFAULT_CONNECTION" != "$SHIMMY_PROFILE_EXPECTED_CONNECTION" ]; then
    shimmy_profile_podman_run system connection default \
      "$SHIMMY_PROFILE_EXPECTED_CONNECTION" || {
        shimmy_profile_activation_rollback 'unable to select shared engine connection' || true
        return 1
      }
  fi
  if [ "${SHIMMY_PROFILE_ACTIVATION_DEFER_COMMIT:-0}" -ne 1 ]; then
    shimmy_engine_projection_commit || return 1
  fi
  if [ "${SHIMMY_PROFILE_ACTIVATION_QUIET_SUCCESS:-0}" -ne 1 ]; then
    printf 'Activated Shimmy profile %s on managed Podman machine %s.\n' \
      "$SHIMMY_PROFILE_NAME" "$SHIMMY_PROFILE_EXPECTED_MACHINE"
  fi
}

shimmy_profile_activate_darwin() {
  restart_requested=$1
  stop_running_requested=$2
  dry_run_requested=$3

  shimmy_profile_activate_darwin_managed "$restart_requested" \
    "$stop_running_requested" "$dry_run_requested"
}

shimmy_profile_activate_linux() {
  restart_requested=$1
  stop_running_requested=$2
  dry_run_requested=$3
  [ "$restart_requested" -eq 0 ] || { printf '%s\n' 'ERROR: --restart is not supported for local Linux profile activation' >&2; return 1; }
  [ "$stop_running_requested" -eq 0 ] || { printf '%s\n' 'ERROR: --stop-running is not supported for local Linux profile activation' >&2; return 1; }
  shimmy_profile_activation_override_reject || return 1
  shimmy_registries_override_reject || return 1
  shimmy_profile_podman_bin_require || { printf '%s\n' 'ERROR: Podman is required for profile activation.' >&2; return 1; }
  if [ "$dry_run_requested" -eq 1 ]; then
    shimmy_profile_activation_lock_check || return 1
    shimmy_registries_lock_check || return 1
  else
    shimmy_profile_activation_lock_acquire || return 1
    shimmy_registries_lock_acquire || return 1
  fi
  shimmy_registries_config_validate "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME" || {
    printf 'ERROR: invalid managed registry redirect configuration: %s\n' "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
    shimmy_registries_lock_release
    return 1
  }
  shimmy_registries_active_link_state_read
  case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in
    absent|current|sibling) ;;
    *)
      printf 'ERROR: refusing Linux activation with invalid or foreign registry path: %s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
      shimmy_registries_lock_release
      return 1
      ;;
  esac
  if ! shimmy_profile_linux_engine_validate; then
    shimmy_registries_lock_release
    return 1
  fi
  if [ "$dry_run_requested" -eq 1 ]; then
    printf 'dry_run=yes\nprofile=%s\n' "$SHIMMY_PROFILE_NAME"
    if [ "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" = current ]; then
      printf '%s\n' 'would_change=nothing'
    else
      printf 'would_link=%s\nwould_target=%s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK" "$SHIMMY_PROFILE_REGISTRIES_PATH"
    fi
    return 0
  fi
  if ! shimmy_registries_active_link_apply; then
    shimmy_registries_lock_release
    return 1
  fi
  if ! shimmy_profile_linux_engine_validate; then
    if shimmy_registries_active_link_rollback; then
      printf '%s\n' 'ERROR: Linux registry activation validation failed; prior active profile restored' >&2
    else
      printf '%s\n' 'ERROR: Linux registry activation validation failed and active-profile rollback was incomplete' >&2
    fi
    shimmy_registries_lock_release
    return 1
  fi
  if [ "${SHIMMY_PROFILE_ACTIVATION_DEFER_COMMIT:-0}" -ne 1 ]; then
    shimmy_registries_active_link_commit
  fi
  shimmy_registries_lock_release
  if [ "${SHIMMY_PROFILE_ACTIVATION_QUIET_SUCCESS:-0}" -ne 1 ]; then
    printf 'Activated Shimmy profile %s registry policy with the local rootless Podman engine.\n' "$SHIMMY_PROFILE_NAME"
    printf "Select this profile in the current shell with: . '%s/shell-init.sh'\n" "$SHIMMY_PROFILE_ROOT"
  fi
}

shimmy_profile_activation_commit() {
  case "${SHIMMY_PROFILE_HOST_OS:-unknown}" in
    darwin)
      shimmy_engine_projection_commit
      ;;
    linux) shimmy_registries_active_link_commit ;;
    *) return 1 ;;
  esac
}

shimmy_profile_activate() {
  restart_requested=$1
  stop_running_requested=$2
  dry_run_requested=$3
  shimmy_profile_activation_expected_resolve || return 1
  shimmy_profile_activation_host_os_resolve
  case "$SHIMMY_PROFILE_HOST_OS" in
    darwin) shimmy_profile_activate_darwin "$restart_requested" "$stop_running_requested" "$dry_run_requested" ;;
    linux) shimmy_profile_activate_linux "$restart_requested" "$stop_running_requested" "$dry_run_requested" ;;
    *) printf 'ERROR: unsupported host operating system for profile activation: %s\n' "$SHIMMY_PROFILE_HOST_OS" >&2; return 1 ;;
  esac
}
