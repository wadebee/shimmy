#!/bin/sh

test_lib_transaction_file_validate() {
  transaction_file=$1
  shimmy_text_file_validate "$transaction_file" || return 1
  case "$(cat "$transaction_file")" in state=old|state=new) return 0 ;; *) return 1 ;; esac
}

test_lib_transaction_authority_validate() {
  [ "${TEST_TRANSACTION_AUTHORITY_VALID:-0}" -eq 1 ]
}

test_lib_external_restore() {
  external_resource=$1
  external_prior=$2
  external_committed=$3
  [ "$(cat "$external_resource")" = "$external_committed" ] || return 1
  printf '%s\n' "$external_prior" > "$external_resource"
}

test_lib_external_restore_fail() {
  return 1
}

test_lib_filesystem_transaction() {
  setup_scenario
  transaction_target=$SCENARIO_DIR/state.conf
  transaction_lock_root=$SCENARIO_DIR/lock-root
  mkdir "$transaction_lock_root"
  SHIMMY_LOCK_HELD_RECORDS=
  printf 'state=old\n' > "$transaction_target"
  chmod 0644 "$transaction_target"
  TEST_TRANSACTION_AUTHORITY_VALID=1
  SHIMMY_TEST_MODE=1

  for transaction_failure in before-commit after-commit; do
    shimmy_filesystem_transaction_prepare "$transaction_target" || fail_test 'filesystem transaction prepare failed'
    printf 'state=new\n' > "$SHIMMY_FILESYSTEM_CANDIDATE_PATH"
    chmod 0644 "$SHIMMY_FILESYSTEM_CANDIDATE_PATH"
    shimmy_filesystem_transaction_candidate_validate test_lib_transaction_file_validate || fail_test 'candidate validation failed'
    shimmy_lock_acquire catalog "$transaction_lock_root" || fail_test "$SHIMMY_LOCK_ERROR"
    SHIMMY_TEST_FILESYSTEM_FAILURE=$transaction_failure
    if shimmy_filesystem_transaction_commit test_lib_transaction_authority_validate catalog; then
      fail_test "injected $transaction_failure filesystem transaction unexpectedly succeeded"
    fi
    assert_equals "$(cat "$transaction_target")" state=old
    if [ "$transaction_failure" = after-commit ]; then
      assert_equals "$SHIMMY_FILESYSTEM_ROLLBACK_RESULT" complete
    fi
    shimmy_locks_release_all || fail_test 'failed transaction lock release failed'
    shimmy_filesystem_transaction_cleanup || fail_test 'failed transaction cleanup failed'
  done

  SHIMMY_TEST_FILESYSTEM_FAILURE=
  shimmy_filesystem_transaction_prepare "$transaction_target" || fail_test 'successful filesystem transaction prepare failed'
  printf 'state=new\n' > "$SHIMMY_FILESYSTEM_CANDIDATE_PATH"
  chmod 0644 "$SHIMMY_FILESYSTEM_CANDIDATE_PATH"
  shimmy_filesystem_transaction_candidate_validate test_lib_transaction_file_validate || fail_test 'successful candidate validation failed'
  shimmy_lock_acquire activation "$transaction_lock_root" || fail_test "$SHIMMY_LOCK_ERROR"
  if shimmy_filesystem_transaction_commit test_lib_transaction_authority_validate catalog; then
    fail_test 'filesystem transaction accepted the wrong held lock'
  fi
  assert_equals "$(cat "$transaction_target")" state=old
  shimmy_locks_release_all || fail_test 'wrong transaction lock release failed'
  TEST_TRANSACTION_AUTHORITY_VALID=0
  shimmy_lock_acquire catalog "$transaction_lock_root" || fail_test "$SHIMMY_LOCK_ERROR"
  if shimmy_filesystem_transaction_commit test_lib_transaction_authority_validate catalog; then
    fail_test 'under-lock authority change unexpectedly committed'
  fi
  assert_equals "$(cat "$transaction_target")" state=old
  shimmy_locks_release_all || fail_test 'authority rejection lock release failed'
  shimmy_filesystem_transaction_cleanup || fail_test 'authority rejection cleanup failed'

  TEST_TRANSACTION_AUTHORITY_VALID=1
  shimmy_filesystem_transaction_prepare "$transaction_target" || fail_test 'final filesystem transaction prepare failed'
  printf 'state=new\n' > "$SHIMMY_FILESYSTEM_CANDIDATE_PATH"
  chmod 0644 "$SHIMMY_FILESYSTEM_CANDIDATE_PATH"
  shimmy_filesystem_transaction_candidate_validate test_lib_transaction_file_validate || fail_test 'final candidate validation failed'
  shimmy_lock_acquire catalog "$transaction_lock_root" || fail_test "$SHIMMY_LOCK_ERROR"
  shimmy_filesystem_transaction_commit test_lib_transaction_authority_validate catalog || fail_test 'valid filesystem transaction commit failed'
  assert_equals "$(cat "$transaction_target")" state=new
  assert_file_mode "$transaction_target" 644
  shimmy_locks_release_all || fail_test 'successful transaction lock release failed'
  shimmy_filesystem_transaction_cleanup || fail_test 'successful transaction cleanup failed'
  pass 'same-filesystem candidates revalidate under lock and commit complete new state or restore prior valid state'
}

test_lib_external_rollback_results() {
  setup_scenario
  external_one=$SCENARIO_DIR/external-one
  external_two=$SCENARIO_DIR/external-two
  printf 'prior-one\n' > "$external_one"
  printf 'prior-two\n' > "$external_two"
  shimmy_external_transaction_begin || fail_test 'external transaction begin failed'
  shimmy_external_rollback_register "$external_one" test_lib_external_restore prior-one committed-one 'restore registry projection' || fail_test 'external rollback registration failed'
  shimmy_external_rollback_register "$external_two" test_lib_external_restore prior-two committed-two 'restore startup block' || fail_test 'external rollback registration failed'
  printf 'committed-one\n' > "$external_one"
  printf 'committed-two\n' > "$external_two"
  external_complete_output=$SCENARIO_DIR/external-complete.out
  shimmy_external_transaction_rollback 'injected external failure' 2> "$external_complete_output" || fail_test 'complete external rollback returned failure'
  assert_equals "$SHIMMY_EXTERNAL_ROLLBACK_RESULT" complete
  assert_equals "$(cat "$external_one")" prior-one
  assert_equals "$(cat "$external_two")" prior-two
  assert_file_contains "$external_complete_output" 'Rollback result: complete'
  assert_file_contains "$external_complete_output" 'restored Shimmy state'

  printf 'committed-one\n' > "$external_one"
  shimmy_external_transaction_begin || fail_test 'second external transaction begin failed'
  external_foreign=$SCENARIO_DIR/user-skills/exact-name
  shimmy_external_irrecoverable_register "$external_foreign" 'foreign directory was overwritten without backup' || fail_test 'irrecoverable registration failed'
  shimmy_external_rollback_register "$external_one" test_lib_external_restore_fail prior-one committed-one 'restore engine selection' || fail_test 'failing rollback registration failed'
  external_incomplete_output=$SCENARIO_DIR/external-incomplete.out
  if shimmy_external_transaction_rollback 'injected rollback failure' 2> "$external_incomplete_output"; then
    fail_test 'incomplete external rollback unexpectedly returned success'
  fi
  assert_equals "$SHIMMY_EXTERNAL_ROLLBACK_RESULT" incomplete
  assert_file_contains "$external_incomplete_output" 'Rollback result: incomplete'
  assert_file_contains "$external_incomplete_output" 'overwritten foreign content is not recoverable'
  external_incomplete_contents=$(cat "$external_incomplete_output")
  assert_not_contains "$external_incomplete_contents" "restored Shimmy state for $external_foreign"
  pass 'external rollback reports complete or incomplete and never claims recovery of overwritten foreign content'
}

test_lib_transaction_run() {
  test_lib_filesystem_transaction
  test_lib_external_rollback_results
}
