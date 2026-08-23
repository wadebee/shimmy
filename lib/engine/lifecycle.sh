#!/bin/sh
# Journal-first machine creation and removal primitives.

shimmy_engine_lifecycle_write() {
  shimmy_engine_lifecycle_write_path=$1
  shimmy_engine_lifecycle_write_root=$(dirname -- "$shimmy_engine_lifecycle_write_path")
  shift
  [ -d "$shimmy_engine_lifecycle_write_root" ] && [ ! -L "$shimmy_engine_lifecycle_write_root" ] || return 1
  shimmy_engine_lifecycle_write_stage=$shimmy_engine_lifecycle_write_root/.lifecycle.tmp.$$
  [ ! -e "$shimmy_engine_lifecycle_write_stage" ] &&
    [ ! -L "$shimmy_engine_lifecycle_write_stage" ] || return 1
  shimmy_engine_lifecycle_render "$@" > "$shimmy_engine_lifecycle_write_stage" || {
    rm -f "$shimmy_engine_lifecycle_write_stage"
    return 1
  }
  chmod 0644 "$shimmy_engine_lifecycle_write_stage" || {
    rm -f "$shimmy_engine_lifecycle_write_stage"
    return 1
  }
  shimmy_engine_lifecycle_read "$shimmy_engine_lifecycle_write_stage" || {
    rm -f "$shimmy_engine_lifecycle_write_stage"
    return 1
  }
  shimmy_engine_state_candidate_replace "$shimmy_engine_lifecycle_write_stage" \
    "$shimmy_engine_lifecycle_write_path" "$shimmy_engine_lifecycle_write_root"
}

shimmy_engine_lifecycle_transition_validate() {
  shimmy_engine_lifecycle_transition_operation=$1
  shimmy_engine_lifecycle_transition_prior=$2
  shimmy_engine_lifecycle_transition_next=$3
  [ "$shimmy_engine_lifecycle_transition_prior" = "$shimmy_engine_lifecycle_transition_next" ] && return 0
  case "$shimmy_engine_lifecycle_transition_operation|$shimmy_engine_lifecycle_transition_prior|$shimmy_engine_lifecycle_transition_next" in
    create\|planned\|initialized|create\|initialized\|recorded|create\|recorded\|starting|create\|starting\|started|create\|started\|guest-marking|create\|guest-marking\|guest-marked|create\|guest-marked\|committed|remove\|planned\|verification-starting|remove\|verification-starting\|verification-started|remove\|verification-started\|verified|remove\|verified\|stopping|remove\|stopping\|stopped|remove\|stopped\|removing|remove\|removing\|removed|remove\|removed\|committed) ;;
    *) return 1 ;;
  esac
}

shimmy_engine_lifecycle_transition() {
  shimmy_engine_lifecycle_transition_path=$1
  shimmy_engine_lifecycle_transition_next=$2
  shimmy_engine_lifecycle_read "$shimmy_engine_lifecycle_transition_path" || return 1
  shimmy_engine_lifecycle_transition_validate "$SHIMMY_ENGINE_LIFECYCLE_OPERATION" \
    "$SHIMMY_ENGINE_LIFECYCLE_PHASE" "$shimmy_engine_lifecycle_transition_next" || return 1
  shimmy_engine_lifecycle_write "$shimmy_engine_lifecycle_transition_path" \
    "$SHIMMY_ENGINE_LIFECYCLE_ID" "$SHIMMY_ENGINE_LIFECYCLE_OPERATION" \
    "$shimmy_engine_lifecycle_transition_next" "$SHIMMY_ENGINE_LIFECYCLE_NAME" \
    "$SHIMMY_ENGINE_LIFECYCLE_CONNECTION" \
    "$SHIMMY_ENGINE_LIFECYCLE_INITIAL_MACHINE_STATE" \
    "$SHIMMY_ENGINE_LIFECYCLE_OWNERSHIP_TOKEN" \
    "$SHIMMY_ENGINE_LIFECYCLE_CREATED_IDENTITY"
}

shimmy_engine_lifecycle_clear() {
  shimmy_engine_lifecycle_clear_path=$1
  shimmy_engine_lifecycle_read "$shimmy_engine_lifecycle_clear_path" || return 1
  [ "$SHIMMY_ENGINE_LIFECYCLE_PHASE" = committed ] || return 1
  rm -f "$shimmy_engine_lifecycle_clear_path"
}

shimmy_engine_machine_create_prepare() {
  shimmy_engine_machine_create_id=$1
  shimmy_engine_machine_create_name=$2
  shimmy_engine_machine_create_connection=$3
  shimmy_engine_machine_create_journal=$4
  shimmy_engine_podman_machine_absence_validate "$shimmy_engine_machine_create_name" \
    "$shimmy_engine_machine_create_connection" || return 1
  [ ! -e "$shimmy_engine_machine_create_journal" ] &&
    [ ! -L "$shimmy_engine_machine_create_journal" ] || return 1
  shimmy_engine_lifecycle_write "$shimmy_engine_machine_create_journal" \
    "$shimmy_engine_machine_create_id" create planned \
    "$shimmy_engine_machine_create_name" "$shimmy_engine_machine_create_connection" \
    absent '' ''
}

shimmy_engine_machine_create_initialize() {
  shimmy_engine_machine_create_journal=$1
  shimmy_engine_lifecycle_read "$shimmy_engine_machine_create_journal" || return 1
  [ "$SHIMMY_ENGINE_LIFECYCLE_OPERATION|$SHIMMY_ENGINE_LIFECYCLE_PHASE" = create\|planned ] || return 1
  shimmy_engine_podman_machine_init "$SHIMMY_ENGINE_LIFECYCLE_NAME" \
    "$SHIMMY_ENGINE_LIFECYCLE_CONNECTION" || return 1
  shimmy_engine_machine_create_identity=$(shimmy_engine_podman_machine_identity_fingerprint_render \
    "$SHIMMY_ENGINE_LIFECYCLE_NAME" "$SHIMMY_ENGINE_LIFECYCLE_CONNECTION") || return 1
  shimmy_engine_machine_create_token=$(shimmy_engine_ownership_token_generate) || return 1
  shimmy_engine_lifecycle_write "$shimmy_engine_machine_create_journal" \
    "$SHIMMY_ENGINE_LIFECYCLE_ID" create initialized "$SHIMMY_ENGINE_LIFECYCLE_NAME" \
    "$SHIMMY_ENGINE_LIFECYCLE_CONNECTION" absent \
    "$shimmy_engine_machine_create_token" \
    "$shimmy_engine_machine_create_identity"
}

shimmy_engine_machine_create_record() {
  shimmy_engine_machine_create_journal=$1
  shimmy_engine_machine_create_record_path=$2
  shimmy_engine_machine_create_scope=$3
  shimmy_engine_lifecycle_read "$shimmy_engine_machine_create_journal" || return 1
  [ "$SHIMMY_ENGINE_LIFECYCLE_OPERATION|$SHIMMY_ENGINE_LIFECYCLE_PHASE" = create\|initialized ] || return 1
  shimmy_engine_podman_machine_state_read "$SHIMMY_ENGINE_LIFECYCLE_NAME" || return 1
  shimmy_engine_machine_create_provider=$SHIMMY_ENGINE_MACHINE_PROVIDER
  shimmy_engine_machine_create_root=$(dirname -- "$shimmy_engine_machine_create_record_path")
  shimmy_engine_machine_create_stage=$shimmy_engine_machine_create_root/.engine.tmp.$$
  [ ! -e "$shimmy_engine_machine_create_stage" ] && [ ! -L "$shimmy_engine_machine_create_stage" ] || return 1
  shimmy_engine_record_render "$SHIMMY_ENGINE_LIFECYCLE_ID" darwin-machine \
    "$shimmy_engine_machine_create_scope" "$SHIMMY_ENGINE_LIFECYCLE_NAME" \
    "$SHIMMY_ENGINE_LIFECYCLE_CONNECTION" "$shimmy_engine_machine_create_provider" \
    shimmy-created "$SHIMMY_ENGINE_LIFECYCLE_OWNERSHIP_TOKEN" \
    "$SHIMMY_ENGINE_LIFECYCLE_CREATED_IDENTITY" > "$shimmy_engine_machine_create_stage" || {
      rm -f "$shimmy_engine_machine_create_stage"
      return 1
    }
  chmod 0644 "$shimmy_engine_machine_create_stage" || {
    rm -f "$shimmy_engine_machine_create_stage"
    return 1
  }
  shimmy_engine_record_read "$shimmy_engine_machine_create_stage" || {
    rm -f "$shimmy_engine_machine_create_stage"
    return 1
  }
  if [ -e "$shimmy_engine_machine_create_record_path" ] ||
    [ -L "$shimmy_engine_machine_create_record_path" ]; then
    shimmy_engine_record_read "$shimmy_engine_machine_create_record_path" || {
      rm -f "$shimmy_engine_machine_create_stage"
      return 1
    }
    cmp -s "$shimmy_engine_machine_create_stage" \
      "$shimmy_engine_machine_create_record_path" || {
      rm -f "$shimmy_engine_machine_create_stage"
      return 1
    }
    rm -f "$shimmy_engine_machine_create_stage" || return 1
    shimmy_engine_lifecycle_transition "$shimmy_engine_machine_create_journal" recorded
    return
  fi
  shimmy_engine_state_candidate_replace "$shimmy_engine_machine_create_stage" \
    "$shimmy_engine_machine_create_record_path" "$shimmy_engine_machine_create_root" || return 1
  shimmy_engine_lifecycle_transition "$shimmy_engine_machine_create_journal" recorded
}

shimmy_engine_machine_create_start() {
  shimmy_engine_machine_create_journal=$1
  shimmy_engine_lifecycle_read "$shimmy_engine_machine_create_journal" || return 1
  [ "$SHIMMY_ENGINE_LIFECYCLE_OPERATION" = create ] || return 1
  case "$SHIMMY_ENGINE_LIFECYCLE_PHASE" in
    recorded)
      shimmy_engine_lifecycle_transition "$shimmy_engine_machine_create_journal" starting || return 1
      shimmy_engine_lifecycle_read "$shimmy_engine_machine_create_journal" || return 1
      ;;
    starting) ;;
    *) return 1 ;;
  esac
  shimmy_engine_podman_machine_state_read "$SHIMMY_ENGINE_LIFECYCLE_NAME" || return 1
  case "$SHIMMY_ENGINE_MACHINE_STATE" in
    stopped) shimmy_engine_podman_machine_start "$SHIMMY_ENGINE_LIFECYCLE_NAME" || return 1 ;;
    running) ;;
    *) return 1 ;;
  esac
  [ "$(shimmy_engine_podman_machine_identity_fingerprint_render \
    "$SHIMMY_ENGINE_LIFECYCLE_NAME" "$SHIMMY_ENGINE_LIFECYCLE_CONNECTION")" = \
    "$SHIMMY_ENGINE_LIFECYCLE_CREATED_IDENTITY" ] || return 1
  shimmy_engine_lifecycle_transition "$shimmy_engine_machine_create_journal" started
}

shimmy_engine_machine_create_guest_mark() {
  shimmy_engine_machine_create_journal=$1
  shimmy_engine_lifecycle_read "$shimmy_engine_machine_create_journal" || return 1
  [ "$SHIMMY_ENGINE_LIFECYCLE_OPERATION" = create ] || return 1
  case "$SHIMMY_ENGINE_LIFECYCLE_PHASE" in
    started)
      shimmy_engine_lifecycle_transition "$shimmy_engine_machine_create_journal" guest-marking || return 1
      shimmy_engine_lifecycle_read "$shimmy_engine_machine_create_journal" || return 1
      ;;
    guest-marking) ;;
    *) return 1 ;;
  esac
  shimmy_engine_podman_guest_marker_write "$SHIMMY_ENGINE_LIFECYCLE_NAME" \
    "$SHIMMY_ENGINE_LIFECYCLE_ID" "$SHIMMY_ENGINE_LIFECYCLE_OWNERSHIP_TOKEN" || return 1
  shimmy_engine_lifecycle_transition "$shimmy_engine_machine_create_journal" guest-marked
}

shimmy_engine_machine_create_commit() {
  shimmy_engine_machine_create_journal=$1
  shimmy_engine_lifecycle_transition "$shimmy_engine_machine_create_journal" committed || return 1
  shimmy_engine_lifecycle_clear "$shimmy_engine_machine_create_journal"
}

shimmy_engine_machine_remove_prepare() {
  shimmy_engine_machine_remove_record=$1
  shimmy_engine_machine_remove_journal=$2
  shimmy_engine_ownership_host_state_read "$shimmy_engine_machine_remove_record"
  [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || return 1
  shimmy_engine_machine_remove_initial_state=$SHIMMY_ENGINE_MACHINE_STATE
  if [ "$shimmy_engine_machine_remove_initial_state" = running ]; then
    shimmy_engine_ownership_destructive_validate "$shimmy_engine_machine_remove_record" || return 1
  fi
  [ ! -e "$shimmy_engine_machine_remove_journal" ] &&
    [ ! -L "$shimmy_engine_machine_remove_journal" ] || return 1
  shimmy_engine_lifecycle_write "$shimmy_engine_machine_remove_journal" \
    "$SHIMMY_ENGINE_RECORD_ID" remove planned "$SHIMMY_ENGINE_RECORD_NAME" \
    "$SHIMMY_ENGINE_RECORD_CONNECTION" "$shimmy_engine_machine_remove_initial_state" \
    "$SHIMMY_ENGINE_RECORD_OWNERSHIP_TOKEN" \
    "$SHIMMY_ENGINE_RECORD_CREATED_IDENTITY"
}

shimmy_engine_machine_remove_apply() {
  shimmy_engine_machine_remove_record=$1
  shimmy_engine_machine_remove_journal=$2
  shimmy_engine_lifecycle_read "$shimmy_engine_machine_remove_journal" || return 1
  [ "$SHIMMY_ENGINE_LIFECYCLE_OPERATION" = remove ] || return 1
  while :; do
    shimmy_engine_lifecycle_read "$shimmy_engine_machine_remove_journal" || return 1
    case "$SHIMMY_ENGINE_LIFECYCLE_PHASE" in
      planned)
        shimmy_engine_lifecycle_transition "$shimmy_engine_machine_remove_journal" \
          verification-starting || return 1
        ;;
      verification-starting)
        shimmy_engine_ownership_host_state_read "$shimmy_engine_machine_remove_record"
        [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || return 1
        if [ "$SHIMMY_ENGINE_MACHINE_STATE" = stopped ]; then
          shimmy_engine_podman_machine_start "$SHIMMY_ENGINE_LIFECYCLE_NAME" || return 1
        else
          [ "$SHIMMY_ENGINE_MACHINE_STATE" = running ] || return 1
        fi
        shimmy_engine_lifecycle_transition "$shimmy_engine_machine_remove_journal" \
          verification-started || return 1
        ;;
      verification-started)
        shimmy_engine_ownership_destructive_validate "$shimmy_engine_machine_remove_record" || return 1
        shimmy_engine_lifecycle_transition "$shimmy_engine_machine_remove_journal" verified || return 1
        ;;
      verified)
        shimmy_engine_lifecycle_transition "$shimmy_engine_machine_remove_journal" stopping || return 1
        ;;
      stopping)
        shimmy_engine_ownership_host_state_read "$shimmy_engine_machine_remove_record"
        [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || return 1
        if [ "$SHIMMY_ENGINE_MACHINE_STATE" = running ]; then
          shimmy_engine_podman_machine_stop "$SHIMMY_ENGINE_LIFECYCLE_NAME" || return 1
        else
          [ "$SHIMMY_ENGINE_MACHINE_STATE" = stopped ] || return 1
        fi
        shimmy_engine_lifecycle_transition "$shimmy_engine_machine_remove_journal" stopped || return 1
        ;;
      stopped)
        shimmy_engine_ownership_host_state_read "$shimmy_engine_machine_remove_record"
        [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] &&
          [ "$SHIMMY_ENGINE_MACHINE_STATE" = stopped ] || return 1
        shimmy_engine_lifecycle_transition "$shimmy_engine_machine_remove_journal" removing || return 1
        ;;
      removing)
        shimmy_engine_podman_machine_state_read "$SHIMMY_ENGINE_LIFECYCLE_NAME" || return 1
        if [ "$SHIMMY_ENGINE_MACHINE_STATE" != absent ]; then
          [ "$SHIMMY_ENGINE_MACHINE_STATE" = stopped ] || return 1
          shimmy_engine_ownership_host_state_read "$shimmy_engine_machine_remove_record"
          [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || return 1
          shimmy_engine_podman_machine_remove "$SHIMMY_ENGINE_LIFECYCLE_NAME" || return 1
          shimmy_engine_podman_machine_state_read "$SHIMMY_ENGINE_LIFECYCLE_NAME" || return 1
          [ "$SHIMMY_ENGINE_MACHINE_STATE" = absent ] || return 1
        fi
        shimmy_engine_lifecycle_transition "$shimmy_engine_machine_remove_journal" removed || return 1
        ;;
      removed) return 0 ;;
      *) return 1 ;;
    esac
  done
}

shimmy_engine_machine_remove_commit() {
  shimmy_engine_machine_remove_journal=$1
  shimmy_engine_lifecycle_transition "$shimmy_engine_machine_remove_journal" committed || return 1
  shimmy_engine_lifecycle_clear "$shimmy_engine_machine_remove_journal"
}
