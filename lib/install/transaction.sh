#!/bin/sh
# Same-filesystem regular-file candidate transactions.

SHIMMY_FILESYSTEM_TRANSACTION_ACTIVE=0
SHIMMY_FILESYSTEM_TRANSACTION_SEQUENCE=0

shimmy_file_mode_render() {
  shimmy_file_mode_path=$1
  if stat -f '%Lp' "$shimmy_file_mode_path" >/dev/null 2>&1; then
    stat -f '%Lp' "$shimmy_file_mode_path"
  else
    stat -c '%a' "$shimmy_file_mode_path"
  fi
}

shimmy_filesystem_transaction_target_snapshot() {
  shimmy_filesystem_snapshot_path=$1
  if [ -L "$shimmy_filesystem_snapshot_path" ]; then return 1; fi
  if [ -e "$shimmy_filesystem_snapshot_path" ]; then
    [ -f "$shimmy_filesystem_snapshot_path" ] || return 1
    SHIMMY_FILESYSTEM_SNAPSHOT_STATE=present
    SHIMMY_FILESYSTEM_SNAPSHOT_FINGERPRINT=$(shimmy_sha256_fingerprint_file_render "$shimmy_filesystem_snapshot_path") || return 1
    SHIMMY_FILESYSTEM_SNAPSHOT_MODE=$(shimmy_file_mode_render "$shimmy_filesystem_snapshot_path") || return 1
  else
    SHIMMY_FILESYSTEM_SNAPSHOT_STATE=absent
    SHIMMY_FILESYSTEM_SNAPSHOT_FINGERPRINT=-
    SHIMMY_FILESYSTEM_SNAPSHOT_MODE=-
  fi
}

shimmy_filesystem_transaction_prepare() {
  shimmy_filesystem_target=$1
  [ "$SHIMMY_FILESYSTEM_TRANSACTION_ACTIVE" -eq 0 ] || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_filesystem_target" || return 1
  shimmy_filesystem_parent=$(dirname -- "$shimmy_filesystem_target")
  shimmy_filesystem_base=$(basename -- "$shimmy_filesystem_target")
  [ -d "$shimmy_filesystem_parent" ] && [ ! -L "$shimmy_filesystem_parent" ] &&
    shimmy_path_parent_chain_validate "$shimmy_filesystem_parent" || return 1
  shimmy_filesystem_transaction_target_snapshot "$shimmy_filesystem_target" || return 1

  SHIMMY_FILESYSTEM_TARGET_PATH=$shimmy_filesystem_target
  SHIMMY_FILESYSTEM_TARGET_PRIOR_STATE=$SHIMMY_FILESYSTEM_SNAPSHOT_STATE
  SHIMMY_FILESYSTEM_TARGET_PRIOR_FINGERPRINT=$SHIMMY_FILESYSTEM_SNAPSHOT_FINGERPRINT
  SHIMMY_FILESYSTEM_TARGET_PRIOR_MODE=$SHIMMY_FILESYSTEM_SNAPSHOT_MODE
  SHIMMY_FILESYSTEM_TRANSACTION_SEQUENCE=$((SHIMMY_FILESYSTEM_TRANSACTION_SEQUENCE + 1))
  SHIMMY_FILESYSTEM_TRANSACTION_ROOT=$shimmy_filesystem_parent/.$shimmy_filesystem_base.shimmy-transaction.$$.$SHIMMY_FILESYSTEM_TRANSACTION_SEQUENCE
  SHIMMY_FILESYSTEM_CANDIDATE_PATH=$SHIMMY_FILESYSTEM_TRANSACTION_ROOT/candidate
  SHIMMY_FILESYSTEM_ROLLBACK_PATH=$SHIMMY_FILESYSTEM_TRANSACTION_ROOT/rollback
  [ ! -e "$SHIMMY_FILESYSTEM_TRANSACTION_ROOT" ] && [ ! -L "$SHIMMY_FILESYSTEM_TRANSACTION_ROOT" ] || return 1
  mkdir "$SHIMMY_FILESYSTEM_TRANSACTION_ROOT" || return 1
  chmod 0700 "$SHIMMY_FILESYSTEM_TRANSACTION_ROOT" || {
    rmdir "$SHIMMY_FILESYSTEM_TRANSACTION_ROOT" 2>/dev/null || true
    return 1
  }
  SHIMMY_FILESYSTEM_CANDIDATE_VALIDATED=0
  SHIMMY_FILESYSTEM_COMMITTED=0
  SHIMMY_FILESYSTEM_ROLLBACK_RESULT=not-needed
  SHIMMY_FILESYSTEM_TRANSACTION_ACTIVE=1
}

shimmy_filesystem_transaction_candidate_validate() {
  shimmy_filesystem_validator=$1
  [ "$SHIMMY_FILESYSTEM_TRANSACTION_ACTIVE" -eq 1 ] || return 1
  shimmy_shell_function_name_validate "$shimmy_filesystem_validator" || return 1
  [ -f "$SHIMMY_FILESYSTEM_CANDIDATE_PATH" ] && [ ! -L "$SHIMMY_FILESYSTEM_CANDIDATE_PATH" ] || return 1
  "$shimmy_filesystem_validator" "$SHIMMY_FILESYSTEM_CANDIDATE_PATH" || return 1
  SHIMMY_FILESYSTEM_CANDIDATE_FINGERPRINT=$(shimmy_sha256_fingerprint_file_render "$SHIMMY_FILESYSTEM_CANDIDATE_PATH") || return 1
  SHIMMY_FILESYSTEM_CANDIDATE_MODE=$(shimmy_file_mode_render "$SHIMMY_FILESYSTEM_CANDIDATE_PATH") || return 1
  SHIMMY_FILESYSTEM_CANDIDATE_VALIDATOR=$shimmy_filesystem_validator
  SHIMMY_FILESYSTEM_CANDIDATE_VALIDATED=1
}

shimmy_filesystem_transaction_snapshot_matches() {
  shimmy_filesystem_transaction_target_snapshot "$SHIMMY_FILESYSTEM_TARGET_PATH" || return 1
  [ "$SHIMMY_FILESYSTEM_SNAPSHOT_STATE" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_STATE" ] &&
    [ "$SHIMMY_FILESYSTEM_SNAPSHOT_FINGERPRINT" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_FINGERPRINT" ] &&
    [ "$SHIMMY_FILESYSTEM_SNAPSHOT_MODE" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_MODE" ]
}

shimmy_filesystem_transaction_candidate_matches() {
  [ -f "$SHIMMY_FILESYSTEM_CANDIDATE_PATH" ] && [ ! -L "$SHIMMY_FILESYSTEM_CANDIDATE_PATH" ] || return 1
  [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_FILESYSTEM_CANDIDATE_PATH")" = "$SHIMMY_FILESYSTEM_CANDIDATE_FINGERPRINT" ] &&
    [ "$(shimmy_file_mode_render "$SHIMMY_FILESYSTEM_CANDIDATE_PATH")" = "$SHIMMY_FILESYSTEM_CANDIDATE_MODE" ] &&
    "$SHIMMY_FILESYSTEM_CANDIDATE_VALIDATOR" "$SHIMMY_FILESYSTEM_CANDIDATE_PATH"
}

shimmy_filesystem_transaction_rollback() {
  [ "$SHIMMY_FILESYSTEM_COMMITTED" -eq 1 ] || {
    SHIMMY_FILESYSTEM_ROLLBACK_RESULT=complete
    return 0
  }
  shimmy_filesystem_rollback_complete=1
  if [ "$SHIMMY_FILESYSTEM_TARGET_PRIOR_STATE" = present ]; then
    [ -f "$SHIMMY_FILESYSTEM_ROLLBACK_PATH" ] && [ ! -L "$SHIMMY_FILESYSTEM_ROLLBACK_PATH" ] &&
      [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_FILESYSTEM_ROLLBACK_PATH")" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_FINGERPRINT" ] &&
      [ "$(shimmy_file_mode_render "$SHIMMY_FILESYSTEM_ROLLBACK_PATH")" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_MODE" ] &&
      mv "$SHIMMY_FILESYSTEM_ROLLBACK_PATH" "$SHIMMY_FILESYSTEM_TARGET_PATH" || shimmy_filesystem_rollback_complete=0
  else
    if [ -f "$SHIMMY_FILESYSTEM_TARGET_PATH" ] && [ ! -L "$SHIMMY_FILESYSTEM_TARGET_PATH" ] &&
      [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_FILESYSTEM_TARGET_PATH")" = "$SHIMMY_FILESYSTEM_CANDIDATE_FINGERPRINT" ]; then
      rm -f "$SHIMMY_FILESYSTEM_TARGET_PATH" || shimmy_filesystem_rollback_complete=0
    elif [ -e "$SHIMMY_FILESYSTEM_TARGET_PATH" ] || [ -L "$SHIMMY_FILESYSTEM_TARGET_PATH" ]; then
      shimmy_filesystem_rollback_complete=0
    fi
  fi
  if [ "$shimmy_filesystem_rollback_complete" -eq 1 ]; then
    shimmy_filesystem_transaction_target_snapshot "$SHIMMY_FILESYSTEM_TARGET_PATH" || shimmy_filesystem_rollback_complete=0
    [ "$SHIMMY_FILESYSTEM_SNAPSHOT_STATE" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_STATE" ] &&
      [ "$SHIMMY_FILESYSTEM_SNAPSHOT_FINGERPRINT" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_FINGERPRINT" ] &&
      [ "$SHIMMY_FILESYSTEM_SNAPSHOT_MODE" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_MODE" ] || shimmy_filesystem_rollback_complete=0
  fi
  if [ "$shimmy_filesystem_rollback_complete" -eq 1 ]; then
    SHIMMY_FILESYSTEM_ROLLBACK_RESULT=complete
    SHIMMY_FILESYSTEM_COMMITTED=0
    return 0
  fi
  SHIMMY_FILESYSTEM_ROLLBACK_RESULT=incomplete
  return 1
}

shimmy_filesystem_transaction_commit() {
  shimmy_filesystem_authority_revalidate=$1
  shimmy_filesystem_required_lock_kind=$2
  shimmy_filesystem_required_lock_profile=${3:--}
  [ "$SHIMMY_FILESYSTEM_TRANSACTION_ACTIVE" -eq 1 ] &&
    [ "$SHIMMY_FILESYSTEM_CANDIDATE_VALIDATED" -eq 1 ] || return 1
  shimmy_lock_held "$shimmy_filesystem_required_lock_kind" "$shimmy_filesystem_required_lock_profile" || return 1
  shimmy_shell_function_name_validate "$shimmy_filesystem_authority_revalidate" || return 1
  shimmy_filesystem_transaction_snapshot_matches || return 1
  shimmy_filesystem_transaction_candidate_matches || return 1
  "$shimmy_filesystem_authority_revalidate" "$SHIMMY_FILESYSTEM_TARGET_PATH" "$SHIMMY_FILESYSTEM_CANDIDATE_PATH" || return 1

  if [ "$SHIMMY_FILESYSTEM_TARGET_PRIOR_STATE" = present ]; then
    cp -p "$SHIMMY_FILESYSTEM_TARGET_PATH" "$SHIMMY_FILESYSTEM_ROLLBACK_PATH" || return 1
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_FILESYSTEM_ROLLBACK_PATH")" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_FINGERPRINT" ] &&
      [ "$(shimmy_file_mode_render "$SHIMMY_FILESYSTEM_ROLLBACK_PATH")" = "$SHIMMY_FILESYSTEM_TARGET_PRIOR_MODE" ] || return 1
  fi

  if [ "${SHIMMY_TEST_MODE:-0}" -eq 1 ] &&
    [ "${SHIMMY_TEST_FILESYSTEM_FAILURE:-}" = before-commit ]; then
    return 1
  fi
  mv "$SHIMMY_FILESYSTEM_CANDIDATE_PATH" "$SHIMMY_FILESYSTEM_TARGET_PATH" || return 1
  SHIMMY_FILESYSTEM_COMMITTED=1
  if { [ "${SHIMMY_TEST_MODE:-0}" -eq 1 ] &&
      [ "${SHIMMY_TEST_FILESYSTEM_FAILURE:-}" = after-commit ]; } ||
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_FILESYSTEM_TARGET_PATH")" != "$SHIMMY_FILESYSTEM_CANDIDATE_FINGERPRINT" ] ||
    [ "$(shimmy_file_mode_render "$SHIMMY_FILESYSTEM_TARGET_PATH")" != "$SHIMMY_FILESYSTEM_CANDIDATE_MODE" ] ||
    ! "$SHIMMY_FILESYSTEM_CANDIDATE_VALIDATOR" "$SHIMMY_FILESYSTEM_TARGET_PATH"; then
    shimmy_filesystem_transaction_rollback || true
    return 1
  fi
  SHIMMY_FILESYSTEM_ROLLBACK_RESULT=not-needed
}

shimmy_filesystem_transaction_cleanup() {
  [ "$SHIMMY_FILESYSTEM_TRANSACTION_ACTIVE" -eq 1 ] || return 0
  rm -f "$SHIMMY_FILESYSTEM_CANDIDATE_PATH" "$SHIMMY_FILESYSTEM_ROLLBACK_PATH" || return 1
  rmdir "$SHIMMY_FILESYSTEM_TRANSACTION_ROOT" || return 1
  SHIMMY_FILESYSTEM_TRANSACTION_ACTIVE=0
  SHIMMY_FILESYSTEM_CANDIDATE_VALIDATED=0
  SHIMMY_FILESYSTEM_COMMITTED=0
}
