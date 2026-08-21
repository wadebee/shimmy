#!/bin/sh

test_lib_lock_fixture_create() {
  setup_scenario
  TEST_LOCK_CONFIG_ROOT=$SCENARIO_DIR/config/shimmy-locks
  mkdir -p "$TEST_LOCK_CONFIG_ROOT/profiles/alpha" "$TEST_LOCK_CONFIG_ROOT/profiles/beta"
  SHIMMY_LOCK_HELD_RECORDS=
  SHIMMY_LOCK_SEQUENCE=0
}

test_lib_lock_order_and_stale() {
  test_lib_lock_fixture_create
  shimmy_lock_acquire catalog "$TEST_LOCK_CONFIG_ROOT" || fail_test "$SHIMMY_LOCK_ERROR"
  shimmy_lock_acquire activation "$TEST_LOCK_CONFIG_ROOT" || fail_test "$SHIMMY_LOCK_ERROR"
  shimmy_lock_acquire profile "$TEST_LOCK_CONFIG_ROOT" alpha || fail_test "$SHIMMY_LOCK_ERROR"
  shimmy_lock_acquire profile "$TEST_LOCK_CONFIG_ROOT" beta || fail_test "$SHIMMY_LOCK_ERROR"
  shimmy_lock_acquire registry "$TEST_LOCK_CONFIG_ROOT" beta || fail_test "$SHIMMY_LOCK_ERROR"
  shimmy_lock_release || fail_test 'registry lock release failed'
  assert_path_not_exists "$TEST_LOCK_CONFIG_ROOT/profiles/beta/.registries.lock"
  assert_file_exists "$TEST_LOCK_CONFIG_ROOT/profiles/beta/.profile.lock"
  shimmy_locks_release_all || fail_test 'ordered lock release failed'
  assert_path_not_exists "$TEST_LOCK_CONFIG_ROOT/.catalog.lock"
  assert_path_not_exists "$TEST_LOCK_CONFIG_ROOT/.activation.lock"
  assert_path_not_exists "$TEST_LOCK_CONFIG_ROOT/profiles/alpha/.profile.lock"
  assert_path_not_exists "$TEST_LOCK_CONFIG_ROOT/profiles/beta/.profile.lock"

  shimmy_lock_acquire activation "$TEST_LOCK_CONFIG_ROOT" || fail_test "$SHIMMY_LOCK_ERROR"
  if shimmy_lock_acquire catalog "$TEST_LOCK_CONFIG_ROOT"; then
    fail_test 'lock-order inversion unexpectedly succeeded'
  fi
  assert_contains "$SHIMMY_LOCK_ERROR" 'inversion'
  shimmy_locks_release_all || fail_test 'activation lock release failed'

  shimmy_lock_acquire profile "$TEST_LOCK_CONFIG_ROOT" beta || fail_test "$SHIMMY_LOCK_ERROR"
  if shimmy_lock_acquire profile "$TEST_LOCK_CONFIG_ROOT" alpha; then
    fail_test 'reverse lexical profile locking unexpectedly succeeded'
  fi
  assert_contains "$SHIMMY_LOCK_ERROR" 'lexical order'
  shimmy_locks_release_all || fail_test 'profile lock release failed'

  stale_lock=$TEST_LOCK_CONFIG_ROOT/profiles/alpha/.profile.lock
  shimmy_lock_owner_render profile alpha 2147483647 2147483647-1 > "$stale_lock"
  chmod 0600 "$stale_lock"
  shimmy_lock_acquire profile "$TEST_LOCK_CONFIG_ROOT" alpha || fail_test "$SHIMMY_LOCK_ERROR"
  assert_file_contains "$stale_lock" "shimmy_lock_pid=$$"
  shimmy_locks_release_all || fail_test 'stale replacement lock release failed'
  pass 'locks enforce hierarchy, lexical profile order, reverse release, and classified stale-owner cleanup'
}

test_lib_lock_concurrency_and_ownership() {
  test_lib_lock_fixture_create
  shimmy_lock_acquire catalog "$TEST_LOCK_CONFIG_ROOT" || fail_test "$SHIMMY_LOCK_ERROR"
  concurrent_output=$(env TEST_LOCK_CONFIG_ROOT="$TEST_LOCK_CONFIG_ROOT" ROOT_DIR="$ROOT_DIR" /bin/sh -c '
    . "$ROOT_DIR/lib/common/common.sh"
    . "$ROOT_DIR/lib/common/lock.sh"
    if shimmy_lock_acquire catalog "$TEST_LOCK_CONFIG_ROOT"; then exit 0; fi
    printf "%s\n" "$SHIMMY_LOCK_ERROR"
    exit 1
  ' 2>&1) && fail_test 'concurrent lock acquisition unexpectedly succeeded'
  assert_contains "$concurrent_output" 'live process'

  lock_owner=$TEST_LOCK_CONFIG_ROOT/.catalog.lock
  lock_owner_saved=$SCENARIO_DIR/owner.saved
  cp "$lock_owner" "$lock_owner_saved"
  sed 's/shimmy_lock_token=.*/shimmy_lock_token=1-1/' "$lock_owner_saved" > "$lock_owner"
  if shimmy_lock_release; then fail_test 'changed lock ownership unexpectedly released'; fi
  assert_contains "$SHIMMY_LOCK_ERROR" 'ownership changed'
  cp "$lock_owner_saved" "$lock_owner"
  shimmy_locks_release_all || fail_test 'owned lock release failed'
  pass 'locks reject concurrent acquisition and release only exact recorded ownership'
}

test_lib_lock_signal_cleanup() {
  test_lib_lock_fixture_create
  signal_output=$SCENARIO_DIR/signal.out
  env TEST_LOCK_CONFIG_ROOT="$TEST_LOCK_CONFIG_ROOT" ROOT_DIR="$ROOT_DIR" /bin/sh -c '
    set -eu
    . "$ROOT_DIR/lib/common/common.sh"
    . "$ROOT_DIR/lib/common/lock.sh"
    shimmy_locks_cleanup_install
    shimmy_lock_acquire catalog "$TEST_LOCK_CONFIG_ROOT"
    printf "ready\n"
    while :; do sleep 1; done
  ' > "$signal_output" 2>&1 &
  signal_pid=$!
  signal_ready=0
  signal_attempt=0
  while [ "$signal_attempt" -lt 200 ]; do
    if grep -q '^ready$' "$signal_output" 2>/dev/null; then
      signal_ready=1
      break
    fi
    kill -0 "$signal_pid" 2>/dev/null || break
    sleep 0.01
    signal_attempt=$((signal_attempt + 1))
  done
  [ "$signal_ready" -eq 1 ] || fail_test 'signal cleanup child did not acquire its lock'
  kill -TERM "$signal_pid"
  if wait "$signal_pid"; then fail_test 'signal cleanup child unexpectedly returned success'; fi
  assert_path_not_exists "$TEST_LOCK_CONFIG_ROOT/.catalog.lock"
  assert_file_contains "$signal_output" ready
  pass 'lock signal cleanup releases only locks owned by the interrupted process'
}

test_lib_lock_run() {
  test_lib_lock_order_and_stale
  test_lib_lock_concurrency_and_ownership
  test_lib_lock_signal_cleanup
}
