#!/bin/sh
# Private target compensating rollback journal for external state.

SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE=0
SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS=
SHIMMY_TARGET_EXTERNAL_ROLLBACK_RESULT=not-needed

shimmy_target_external_transaction_begin() {
  [ "$SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE" -eq 0 ] || return 1
  SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE=1
  SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS=
  SHIMMY_TARGET_EXTERNAL_ROLLBACK_RESULT=not-needed
}

shimmy_target_external_rollback_register() {
  shimmy_target_external_resource=$1
  shimmy_target_external_callback=$2
  shimmy_target_external_prior_state=${3-}
  shimmy_target_external_committed_state=${4-}
  shimmy_target_external_description=$5
  [ "$SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE" -eq 1 ] || return 1
  shimmy_shell_function_name_validate "$shimmy_target_external_callback" || return 1
  command -v "$shimmy_target_external_callback" >/dev/null 2>&1 || return 1
  shimmy_target_external_resource_encoded=$(shimmy_manifest_value_encode "$shimmy_target_external_resource") || return 1
  shimmy_target_external_prior_encoded=$(shimmy_manifest_value_encode "$shimmy_target_external_prior_state") || return 1
  shimmy_target_external_committed_encoded=$(shimmy_manifest_value_encode "$shimmy_target_external_committed_state") || return 1
  shimmy_target_external_description_encoded=$(shimmy_manifest_value_encode "$shimmy_target_external_description") || return 1
  shimmy_target_external_record=restore\|$shimmy_target_external_resource_encoded\|$shimmy_target_external_callback\|$shimmy_target_external_prior_encoded\|$shimmy_target_external_committed_encoded\|$shimmy_target_external_description_encoded
  SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS=$(shimmy_append_line_list "$SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS" "$shimmy_target_external_record")
}

shimmy_target_external_irrecoverable_register() {
  shimmy_target_external_resource=$1
  shimmy_target_external_description=$2
  [ "$SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE" -eq 1 ] || return 1
  shimmy_target_external_resource_encoded=$(shimmy_manifest_value_encode "$shimmy_target_external_resource") || return 1
  shimmy_target_external_description_encoded=$(shimmy_manifest_value_encode "$shimmy_target_external_description") || return 1
  shimmy_target_external_record=irrecoverable\|$shimmy_target_external_resource_encoded\|-\|\|\|$shimmy_target_external_description_encoded
  SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS=$(shimmy_append_line_list "$SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS" "$shimmy_target_external_record")
}

shimmy_target_external_transaction_commit() {
  [ "$SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE" -eq 1 ] || return 1
  SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE=0
  SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS=
  SHIMMY_TARGET_EXTERNAL_ROLLBACK_RESULT=not-needed
}

shimmy_target_external_transaction_rollback() {
  shimmy_target_external_reason=$1
  [ "$SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE" -eq 1 ] || return 1
  shimmy_target_external_rollback_complete=1
  shimmy_target_external_reverse_records=$(printf '%s\n' "$SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS" | awk '{ records[NR] = $0 } END { for (line_number = NR; line_number > 0; line_number--) print records[line_number] }') || return 1
  while IFS='|' read -r shimmy_target_external_kind shimmy_target_external_resource_encoded shimmy_target_external_callback shimmy_target_external_prior_encoded shimmy_target_external_committed_encoded shimmy_target_external_description_encoded shimmy_target_external_extra; do
    [ -n "$shimmy_target_external_kind" ] || continue
    [ -z "$shimmy_target_external_extra" ] || {
      shimmy_target_external_rollback_complete=0
      continue
    }
    shimmy_target_external_resource=$(shimmy_manifest_value_decode "$shimmy_target_external_resource_encoded") || {
      shimmy_target_external_rollback_complete=0
      continue
    }
    shimmy_target_external_description=$(shimmy_manifest_value_decode "$shimmy_target_external_description_encoded") || {
      shimmy_target_external_rollback_complete=0
      continue
    }
    case "$shimmy_target_external_kind" in
      restore)
        shimmy_target_external_prior_state=$(shimmy_manifest_value_decode "$shimmy_target_external_prior_encoded") || {
          shimmy_target_external_rollback_complete=0
          continue
        }
        shimmy_target_external_committed_state=$(shimmy_manifest_value_decode "$shimmy_target_external_committed_encoded") || {
          shimmy_target_external_rollback_complete=0
          continue
        }
        if "$shimmy_target_external_callback" "$shimmy_target_external_resource" "$shimmy_target_external_prior_state" "$shimmy_target_external_committed_state"; then
          printf 'Rollback: restored Shimmy state for %s: %s\n' "$shimmy_target_external_resource" "$shimmy_target_external_description" >&2
        else
          printf 'Rollback: failed to restore Shimmy state for %s: %s\n' "$shimmy_target_external_resource" "$shimmy_target_external_description" >&2
          shimmy_target_external_rollback_complete=0
        fi
        ;;
      irrecoverable)
        printf 'Rollback: overwritten foreign content is not recoverable for %s: %s\n' "$shimmy_target_external_resource" "$shimmy_target_external_description" >&2
        shimmy_target_external_rollback_complete=0
        ;;
      *) shimmy_target_external_rollback_complete=0 ;;
    esac
  done <<EOF
$shimmy_target_external_reverse_records
EOF
  SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE=0
  if [ "$shimmy_target_external_rollback_complete" -eq 1 ]; then
    SHIMMY_TARGET_EXTERNAL_ROLLBACK_RESULT=complete
    printf 'Rollback result: complete after %s.\n' "$shimmy_target_external_reason" >&2
    return 0
  fi
  SHIMMY_TARGET_EXTERNAL_ROLLBACK_RESULT=incomplete
  printf 'Rollback result: incomplete after %s.\n' "$shimmy_target_external_reason" >&2
  return 1
}
