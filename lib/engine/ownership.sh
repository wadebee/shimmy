#!/bin/sh
# Redundant ownership proof for Shimmy-created Podman machines.

shimmy_engine_ownership_token_generate() {
  shimmy_engine_ownership_token=$(od -An -N32 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n') || return 1
  shimmy_engine_token_validate "$shimmy_engine_ownership_token" || return 1
  printf '%s\n' "$shimmy_engine_ownership_token"
}

shimmy_engine_ownership_host_state_read() {
  shimmy_engine_ownership_record=$1
  SHIMMY_ENGINE_OWNERSHIP_STATE=ambiguous
  SHIMMY_ENGINE_OWNERSHIP_REASON=invalid-host-record
  shimmy_engine_record_read "$shimmy_engine_ownership_record" || return 0
  [ "$SHIMMY_ENGINE_RECORD_KIND" = darwin-machine ] || {
    SHIMMY_ENGINE_OWNERSHIP_REASON=not-darwin-machine
    return 0
  }
  [ "$SHIMMY_ENGINE_RECORD_ORIGIN" = shimmy-created ] || {
    SHIMMY_ENGINE_OWNERSHIP_STATE=external
    SHIMMY_ENGINE_OWNERSHIP_REASON=external-origin
    return 0
  }
  shimmy_engine_podman_bin_require || {
    SHIMMY_ENGINE_OWNERSHIP_REASON=podman-unavailable
    return 0
  }
  shimmy_engine_podman_machine_state_read "$SHIMMY_ENGINE_RECORD_NAME" || {
    SHIMMY_ENGINE_OWNERSHIP_REASON=machine-metadata-unavailable
    return 0
  }
  case "$SHIMMY_ENGINE_MACHINE_STATE" in
    running|stopped) ;;
    absent)
      SHIMMY_ENGINE_OWNERSHIP_STATE=missing
      SHIMMY_ENGINE_OWNERSHIP_REASON=machine-absent
      return 0
      ;;
    *)
      SHIMMY_ENGINE_OWNERSHIP_REASON=machine-metadata-invalid
      return 0
      ;;
  esac
  [ "$SHIMMY_ENGINE_MACHINE_PROVIDER" = "$SHIMMY_ENGINE_RECORD_PROVIDER" ] || {
    SHIMMY_ENGINE_OWNERSHIP_REASON=provider-mismatch
    return 0
  }
  shimmy_engine_podman_connection_state_read "$SHIMMY_ENGINE_RECORD_CONNECTION" || {
    SHIMMY_ENGINE_OWNERSHIP_REASON=connection-metadata-unavailable
    return 0
  }
  [ "$SHIMMY_ENGINE_CONNECTION_STATE" = rootless ] || {
    SHIMMY_ENGINE_OWNERSHIP_REASON=connection-mismatch
    return 0
  }
  shimmy_engine_ownership_current_identity=$(shimmy_engine_podman_machine_identity_fingerprint_render \
    "$SHIMMY_ENGINE_RECORD_NAME" "$SHIMMY_ENGINE_RECORD_CONNECTION") || {
    SHIMMY_ENGINE_OWNERSHIP_REASON=inspect-mismatch
    return 0
  }
  [ "$shimmy_engine_ownership_current_identity" = \
    "$SHIMMY_ENGINE_RECORD_CREATED_IDENTITY" ] || {
    SHIMMY_ENGINE_OWNERSHIP_REASON=inspect-mismatch
    return 0
  }
  SHIMMY_ENGINE_OWNERSHIP_STATE=owned
  SHIMMY_ENGINE_OWNERSHIP_REASON=host-matched
}

shimmy_engine_ownership_state_read() {
  shimmy_engine_ownership_record=$1
  shimmy_engine_ownership_host_state_read "$shimmy_engine_ownership_record"
  [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] || return 0
  shimmy_engine_podman_guest_marker_verify "$SHIMMY_ENGINE_RECORD_NAME" \
    "$SHIMMY_ENGINE_RECORD_ID" "$SHIMMY_ENGINE_RECORD_OWNERSHIP_TOKEN" || {
    SHIMMY_ENGINE_OWNERSHIP_STATE=ambiguous
    SHIMMY_ENGINE_OWNERSHIP_REASON=guest-marker-mismatch
    return 0
  }
  SHIMMY_ENGINE_OWNERSHIP_REASON=matched
}

shimmy_engine_ownership_destructive_validate() {
  shimmy_engine_ownership_state_read "$1"
  [ "$SHIMMY_ENGINE_OWNERSHIP_STATE" = owned ] && return 0
  printf 'ERROR: preserving Podman machine because Shimmy ownership is not proved: %s\n' \
    "$SHIMMY_ENGINE_OWNERSHIP_REASON" >&2
  return 1
}
