#!/bin/sh

test_lib_runner_stub_first() {
  printf '%s\n' first
}

test_lib_runner_stub_second() {
  printf '%s\n' second
}

test_lib_runner_stub_third() {
  printf '%s\n' third
}

test_lib_runner_stub_failure() {
  printf '%s\n' second-failed
  return 7
}

test_lib_runner_stub_setup() {
  printf '%s\n' setup-complete
}

test_lib_runner_stub_setup_failure() {
  printf '%s\n' setup-failed
  return 7
}

test_lib_runner_stub_slow() {
  printf '%s\n' slow-started
  : > "$TEST_RUNNER_SLOW_MARKER"
  while :; do
    sleep 1
  done
}

test_lib_runner_stub_int_delivery() {
  kill -INT "$$"
}

test_lib_runner_stub_pass_first() {
  pass "synthetic first"
}

test_lib_runner_stub_pass_second() {
  pass "synthetic second"
}

test_lib_runner_stub_pass_third() {
  pass "synthetic third"
}

test_lib_runner_synthetic_registry_configure() {
  TEST_RUNNER_GROUP_REGISTRY_OVERRIDE='first|test_lib_runner_stub_pass_first
second|test_lib_runner_stub_pass_second
third|test_lib_runner_stub_pass_third'
  TEST_RUNNER_GROUP_ASSIGNMENT_OVERRIDE='first|two-a|three-a
second|two-b|three-b
third|two-a|three-c'
}

test_lib_runner_synthetic_workers_run() {
  test_runner_synthetic_output_root=$1
  test_runner_synthetic_jobs=$2
  test_lib_runner_synthetic_registry_configure
  TEST_RUNNER_OUTPUT_ROOT=$test_runner_synthetic_output_root
  TEST_COUNT=0
  SHIMMY_TEST_TIMING=0
  test_runner_options_parse --jobs "$test_runner_synthetic_jobs"
  test_runner_groups_run
}

test_lib_runner_synthetic_workers_prepare() {
  test_runner_synthetic_output_root=$1
  test_runner_synthetic_jobs=$2
  test_runner_synthetic_saved_count=$TEST_COUNT
  test_lib_runner_synthetic_registry_configure
  TEST_RUNNER_OUTPUT_ROOT=$test_runner_synthetic_output_root
  TEST_COUNT=0
  SHIMMY_TEST_TIMING=0
  test_runner_options_parse --jobs "$test_runner_synthetic_jobs"
  test_runner_worker_list_resolve
  test_runner_output_prepare
  test_runner_workers_start
  test_runner_workers_wait
  TEST_COUNT=$test_runner_synthetic_saved_count
}

test_lib_runner_registry_ordering() {
  test_runner_registry=$(test_runner_group_registry_read)
  test_runner_first_name=$(printf '%s\n' "$test_runner_registry" | sed -n '1s/|.*//p')
  test_runner_last_name=$(printf '%s\n' "$test_runner_registry" | sed -n '$s/|.*//p')
  assert_equals "$test_runner_first_name" runner
  assert_equals "$test_runner_last_name" tools-textual
  assert_equals "$(printf '%s\n' "$test_runner_registry" | sed -n '/^commands-lifecycle-/p')" \
    'commands-lifecycle-darwin-bootstrap|test_commands_lifecycle_darwin_bootstrap
commands-lifecycle-linux-bootstrap|test_commands_lifecycle_linux_bootstrap
commands-lifecycle-isolated|test_commands_lifecycle_owned_isolated
commands-lifecycle-uninstall|test_commands_lifecycle_global_owned_uninstall
commands-lifecycle-linux-workflow|test_commands_lifecycle_linux_workflow
commands-lifecycle-control-sync|test_commands_lifecycle_control_sync'
  pass "runner registry has stable canonical ordering and exact lifecycle mappings"
}

test_lib_runner_group_selection() {
  setup_scenario
  test_runner_selection_output=$(
    SHIMMY_TEST_TIMING=0
    TEST_RUNNER_GROUP_REGISTRY_OVERRIDE='first|test_lib_runner_stub_first
second|test_lib_runner_stub_second'
    TEST_RUNNER_GROUP_ASSIGNMENT_OVERRIDE='first|two-a|three-a
second|two-b|three-b'
    TEST_RUNNER_OUTPUT_ROOT=$SCENARIO_DIR/selection-output
    test_runner_options_parse --group second --group first --jobs 3
    test_runner_groups_run
  )
  assert_equals "$test_runner_selection_output" 'first
second'
  pass "runner selection executes requested groups in registry order"
}

test_lib_runner_group_sigint_guard() {
  setup_scenario
  test_runner_sigint_output_root=$SCENARIO_DIR/sigint-output

  set +e
  test_runner_sigint_output=$(
    TEST_RUNNER_GROUP_REGISTRY_OVERRIDE='int-delivery|test_lib_runner_stub_int_delivery'
    TEST_RUNNER_GROUP_ASSIGNMENT_OVERRIDE='int-delivery|two-a|three-a'
    TEST_RUNNER_OUTPUT_ROOT=$test_runner_sigint_output_root
    TEST_COUNT=0
    SHIMMY_TEST_TIMING=0
    test_runner_options_parse --serial
    test_runner_groups_run 2>&1
  )
  test_runner_sigint_status=$?
  set -e

  [ "$test_runner_sigint_status" -ne 0 ] || fail_test 'runner allowed kernel-level SIGINT delivery inside a background test group'
  assert_contains "$test_runner_sigint_output" 'kernel-level SIGINT delivery is unsupported inside background test groups'
  pass 'runner fails fast when a background test group attempts kernel-level SIGINT delivery'
}

test_lib_runner_option_validation() {
  for test_runner_invalid_options in \
    '--group missing' \
    '--group first --group first' \
    '--group' \
    '--jobs 0' \
    '--jobs 4' \
    '--jobs two' \
    '--jobs' \
    '--jobs 2 --jobs 3' \
    '--serial --jobs 1' \
    '--list-groups --group first'
  do
    set +e
    test_runner_validation_output=$(
      exec 2>&1
      TEST_RUNNER_GROUP_REGISTRY_OVERRIDE='first|test_lib_runner_stub_first
second|test_lib_runner_stub_second'
      TEST_RUNNER_GROUP_ASSIGNMENT_OVERRIDE='first|two-a|three-a
second|two-b|three-b'
      # Intentional splitting exercises the command-line parser.
      # shellcheck disable=SC2086
      test_runner_options_parse $test_runner_invalid_options
    )
    test_runner_validation_status=$?
    set -e
    [ "$test_runner_validation_status" -ne 0 ] ||
      fail_test "runner unexpectedly accepted options: $test_runner_invalid_options"
    assert_contains "$test_runner_validation_output" 'FAIL:'
  done
  pass "runner rejects unknown, duplicate, missing, invalid, and conflicting options"
}

test_lib_runner_timing_shape() {
  test_runner_timing_output=$(SHIMMY_TEST_TIMING=1 test_runner_timing_record group first 0)
  assert_equals "$test_runner_timing_output" 'shimmy_test_timing=group|first|0'
  test_runner_timing_default=$(SHIMMY_TEST_TIMING=0 test_runner_timing_record group first 0)
  assert_equals "$test_runner_timing_default" ''
  test_runner_progress_output=$(SHIMMY_TEST_TIMING=1 test_runner_progress_record group first)
  assert_equals "$test_runner_progress_output" 'shimmy_test_progress=group|first|START'
  test_runner_progress_default=$(SHIMMY_TEST_TIMING=0 test_runner_progress_record group first)
  assert_equals "$test_runner_progress_default" ''
  test_runner_setup_output=$(
    SHIMMY_TEST_TIMING=1
    TEST_RUNNER_SETUP_PID=
    TEST_RUNNER_SETUP_NAME=
    TEST_RUNNER_SETUP_STARTED=
    test_runner_setup_run fixture-template test_lib_runner_stub_setup
  )
  assert_contains "$test_runner_setup_output" \
    'shimmy_test_progress=setup|fixture-template|START'
  assert_contains "$test_runner_setup_output" setup-complete
  assert_contains "$test_runner_setup_output" \
    'shimmy_test_timing=setup|fixture-template|'
  set +e
  test_runner_setup_failure=$(
    SHIMMY_TEST_TIMING=1
    TEST_RUNNER_SETUP_PID=
    TEST_RUNNER_SETUP_NAME=
    TEST_RUNNER_SETUP_STARTED=
    test_runner_setup_run fixture-template test_lib_runner_stub_setup_failure
  )
  test_runner_setup_failure_status=$?
  set -e
  assert_equals "$test_runner_setup_failure_status" 7
  assert_contains "$test_runner_setup_failure" setup-failed
  assert_contains "$test_runner_setup_failure" \
    'shimmy_test_timing=setup|fixture-template|'
  pass "runner timing and progress records cover successful and failed setup"
}

test_lib_runner_lifecycle_grouping() {
  setup_scenario
  test_runner_lifecycle_output=$(
    test_commands_lifecycle_darwin_bootstrap() { printf '%s\n' darwin-bootstrap; }
    test_commands_lifecycle_linux_bootstrap() { printf '%s\n' linux-bootstrap; }
    test_commands_lifecycle_owned_isolated() { printf '%s\n' isolated; }
    test_commands_lifecycle_global_owned_uninstall() { printf '%s\n' uninstall; }
    test_commands_lifecycle_linux_workflow() { printf '%s\n' linux-workflow; }
    test_commands_lifecycle_control_sync() { printf '%s\n' control-sync; }
    TEST_RUNNER_GROUP_REGISTRY_OVERRIDE='commands-lifecycle-darwin-bootstrap|test_commands_lifecycle_darwin_bootstrap
commands-lifecycle-linux-bootstrap|test_commands_lifecycle_linux_bootstrap
commands-lifecycle-isolated|test_commands_lifecycle_owned_isolated
commands-lifecycle-uninstall|test_commands_lifecycle_global_owned_uninstall
commands-lifecycle-linux-workflow|test_commands_lifecycle_linux_workflow
commands-lifecycle-control-sync|test_commands_lifecycle_control_sync'
    TEST_RUNNER_GROUP_ASSIGNMENT_OVERRIDE='commands-lifecycle-darwin-bootstrap|two-a|three-a
commands-lifecycle-linux-bootstrap|two-b|three-c
commands-lifecycle-isolated|two-b|three-b
commands-lifecycle-uninstall|two-b|three-a
commands-lifecycle-linux-workflow|two-a|three-b
commands-lifecycle-control-sync|two-b|three-c'
    TEST_RUNNER_OUTPUT_ROOT=$SCENARIO_DIR/lifecycle-groups
    TEST_COUNT=0
    SHIMMY_TEST_TIMING=0
    test_runner_options_parse --jobs 3
    test_runner_groups_run
  )
  assert_equals "$test_runner_lifecycle_output" 'darwin-bootstrap
linux-bootstrap
isolated
uninstall
linux-workflow
control-sync'

  TEST_RUNNER_GROUPS_SELECTED=runner
  if test_lifecycle_checkout_template_required; then
    fail_test 'non-lifecycle selection unexpectedly required the lifecycle template'
  fi
  for test_runner_lifecycle_group in \
    commands-lifecycle-darwin-bootstrap \
    commands-lifecycle-linux-bootstrap \
    commands-lifecycle-isolated \
    commands-lifecycle-uninstall \
    commands-lifecycle-linux-workflow \
    commands-lifecycle-control-sync
  do
    TEST_RUNNER_GROUPS_SELECTED=$test_runner_lifecycle_group
    test_lifecycle_checkout_template_required ||
      fail_test "lifecycle selection did not require the template: $test_runner_lifecycle_group"
  done
  TEST_RUNNER_GROUPS_SELECTED=
  test_lifecycle_checkout_template_required ||
    fail_test 'default selection did not require the lifecycle template'
  pass "runner keeps each lifecycle scenario independently selectable and indivisible"
}

test_lib_runner_worker_scheduling() {
  setup_scenario

  for test_runner_synthetic_jobs in 1 2 3; do
    test_runner_synthetic_output_root=$SCENARIO_DIR/jobs-$test_runner_synthetic_jobs
    test_runner_synthetic_output=$(
      test_lib_runner_synthetic_workers_run \
        "$test_runner_synthetic_output_root" "$test_runner_synthetic_jobs"
      test_runner_synthetic_worker_count=0
      for test_runner_synthetic_status_file in "$test_runner_synthetic_output_root"/workers/*.status; do
        [ -f "$test_runner_synthetic_status_file" ] || continue
        test_runner_synthetic_worker_count=$((test_runner_synthetic_worker_count + 1))
      done
      printf 'count=%s workers=%s\n' "$TEST_COUNT" "$test_runner_synthetic_worker_count"
    )
    assert_equals "$test_runner_synthetic_output" "PASS: synthetic first
PASS: synthetic second
PASS: synthetic third
count=3 workers=$test_runner_synthetic_jobs"
  done

  pass "runner schedules one, two, and three workers with deterministic logs and counts"
}

test_lib_runner_worker_failure_propagation() {
  setup_scenario
  test_runner_failure_output_root=$SCENARIO_DIR/failure-output

  set +e
  test_runner_failure_output=$(
    TEST_RUNNER_GROUP_REGISTRY_OVERRIDE='first|test_lib_runner_stub_first
second|test_lib_runner_stub_failure
third|test_lib_runner_stub_third'
    TEST_RUNNER_GROUP_ASSIGNMENT_OVERRIDE='first|two-a|three-c
second|two-b|three-a
third|two-a|three-b'
    TEST_RUNNER_OUTPUT_ROOT=$test_runner_failure_output_root
    TEST_COUNT=0
    SHIMMY_TEST_TIMING=1
    TEST_RUNNER_LOGS_REPLAYED=0
    test_runner_total_started=$(test_runner_now)
    test_runner_options_parse --jobs 3
    test_runner_suite_run 2>&1
  )
  test_runner_failure_status=$?
  set -e

  [ "$test_runner_failure_status" -ne 0 ] || fail_test "runner ignored a failed worker"
  assert_equals "$(printf '%s\n' "$test_runner_failure_output" | \
    sed -n '/^first$/p;/^second-failed$/p;/^third$/p')" 'first
second-failed
third'
  assert_contains "$test_runner_failure_output" 'shimmy_test_progress=group|second|START'
  assert_contains "$test_runner_failure_output" 'shimmy_test_timing=group|second|'
  assert_contains "$test_runner_failure_output" 'shimmy_test_timing=total|suite|'
  assert_contains "$test_runner_failure_output" 'FAIL: test worker failed: three-a'
  assert_file_contains "$test_runner_failure_output_root/groups/first.log" first
  assert_file_contains "$test_runner_failure_output_root/groups/second.log" second-failed
  assert_file_contains "$test_runner_failure_output_root/groups/third.log" third
  pass "runner propagates worker failure after retaining and replaying every group log"
}

test_lib_runner_missing_result_rejection() {
  setup_scenario
  test_runner_missing_output_root=$SCENARIO_DIR/missing-output
  test_lib_runner_synthetic_workers_prepare "$test_runner_missing_output_root" 2
  rm -f "$test_runner_missing_output_root/workers/two-b.elapsed"

  set +e
  test_runner_missing_output=$(test_runner_results_collect 2>&1)
  test_runner_missing_status=$?
  set -e

  [ "$test_runner_missing_status" -ne 0 ] || fail_test "runner accepted a missing worker result"
  assert_contains "$test_runner_missing_output" 'FAIL: missing worker elapsed result:'
  pass "runner fails closed when a worker result is missing"
}

test_lib_runner_count_mismatch_rejection() {
  setup_scenario
  test_runner_mismatch_output_root=$SCENARIO_DIR/mismatch-output
  test_lib_runner_synthetic_workers_prepare "$test_runner_mismatch_output_root" 2
  printf '%s\n' 99 > "$test_runner_mismatch_output_root/workers/two-a.count"

  set +e
  test_runner_mismatch_output=$(test_runner_results_collect 2>&1)
  test_runner_mismatch_status=$?
  set -e

  [ "$test_runner_mismatch_status" -ne 0 ] || fail_test "runner accepted a mismatched worker count"
  assert_contains "$test_runner_mismatch_output" 'FAIL: worker count mismatch: two-a'
  pass "runner rejects worker counts that differ from group results"
}

test_lib_runner_signal_cleanup() {
  setup_scenario
  test_runner_signal_retained=$SCENARIO_DIR/retained
  mkdir "$test_runner_signal_retained"

  for test_runner_signal_timing in 0 1; do
    test_runner_signal_session=$SCENARIO_DIR/signal-session-$test_runner_signal_timing
    test_runner_signal_pid_file=$SCENARIO_DIR/signal-worker-$test_runner_signal_timing.pid
    test_runner_signal_output=$SCENARIO_DIR/signal-output-$test_runner_signal_timing
    test_runner_signal_marker=$SCENARIO_DIR/signal-marker-$test_runner_signal_timing
    mkdir "$test_runner_signal_session"

    (
      TMP_ROOT=$test_runner_signal_session
      TEST_RUNNER_GROUP_REGISTRY_OVERRIDE='slow|test_lib_runner_stub_slow'
      TEST_RUNNER_GROUP_ASSIGNMENT_OVERRIDE='slow|two-a|three-a'
      TEST_RUNNER_OUTPUT_ROOT=$test_runner_signal_session/runner-output
      TEST_RUNNER_SLOW_MARKER=$test_runner_signal_marker
      TEST_RUNNER_WORKER_PIDS=
      TEST_RUNNER_LOGS_REPLAYED=0
      TEST_COUNT=0
      SHIMMY_TEST_TIMING=$test_runner_signal_timing
      test_runner_total_started=$(test_runner_now)
      trap 'test_runner_signal_handle TERM 143' TERM
      test_runner_options_parse --serial
      test_runner_worker_list_resolve
      test_runner_output_prepare
      test_runner_workers_start
      printf '%s\n' "$TEST_RUNNER_WORKER_PIDS" | sed 's/|.*//' > "$test_runner_signal_pid_file"
      test_runner_workers_wait
    ) > "$test_runner_signal_output" 2>&1 &
    test_runner_signal_controller_pid=$!

    test_runner_signal_wait=0
    while [ ! -f "$test_runner_signal_marker" ] && [ "$test_runner_signal_wait" -lt 50 ]; do
      sleep 0.1
      test_runner_signal_wait=$((test_runner_signal_wait + 1))
    done
    assert_file_exists "$test_runner_signal_marker"
    assert_file_exists "$test_runner_signal_pid_file"
    test_runner_signal_worker_pid=$(cat "$test_runner_signal_pid_file")

    kill -TERM "$test_runner_signal_controller_pid"
    set +e
    wait "$test_runner_signal_controller_pid"
    test_runner_signal_status=$?
    set -e

    assert_equals "$test_runner_signal_status" 143
    assert_path_not_exists "$test_runner_signal_session"
    assert_dir_exists "$test_runner_signal_retained"
    if kill -0 "$test_runner_signal_worker_pid" 2>/dev/null; then
      fail_test "signal cleanup left its recorded worker running"
    fi
    assert_file_contains "$test_runner_signal_output" 'FAIL: test suite interrupted by TERM'

    test_runner_signal_contents=$(cat "$test_runner_signal_output")
    if [ "$test_runner_signal_timing" -eq 1 ]; then
      assert_contains "$test_runner_signal_contents" 'shimmy_test_progress=group|slow|START'
      assert_contains "$test_runner_signal_contents" 'slow-started'
      assert_contains "$test_runner_signal_contents" 'shimmy_test_timing=group|slow|'
      assert_contains "$test_runner_signal_contents" 'shimmy_test_timing=total|suite|'
      assert_equals "$(printf '%s\n' "$test_runner_signal_contents" | \
        sed -n '/^shimmy_test_progress=group|slow|START$/p' | wc -l | tr -d ' ')" 1
    else
      assert_not_contains "$test_runner_signal_contents" 'shimmy_test_progress='
      assert_not_contains "$test_runner_signal_contents" 'shimmy_test_timing='
      assert_not_contains "$test_runner_signal_contents" 'slow-started'
    fi
  done

  pass "runner signal cleanup preserves opt-in partial evidence, terminates recorded workers, and removes only its session root"
}

test_lib_runner_fixture_copy_clone_selection() {
  setup_scenario
  fixture_copy_source=$SCENARIO_DIR/clone-source
  fixture_copy_target=$SCENARIO_DIR/clone-target
  fixture_copy_marker=$SCENARIO_DIR/clone-option-used
  mkdir "$fixture_copy_source"
  printf '%s\n' clone > "$fixture_copy_source/payload"

  (
    cp() {
      [ "${1:-}" = -cR ] || return 97
      : > "$fixture_copy_marker"
      shift
      command cp -R "$@"
    }
    SHIMMY_TEST_COPY_ON_WRITE=1
    test_fixture_tree_copy "$fixture_copy_source" "$fixture_copy_target"
  )

  assert_file_exists "$fixture_copy_marker"
  assert_file_contains "$fixture_copy_target/payload" clone
  pass "fixture tree copy selects clone mode only when enabled"
}

test_lib_runner_fixture_copy_portable_fallback() {
  setup_scenario
  fixture_copy_source=$SCENARIO_DIR/portable-source
  fixture_copy_target=$SCENARIO_DIR/portable-target
  fixture_copy_marker=$SCENARIO_DIR/portable-option-used
  mkdir "$fixture_copy_source"
  printf '%s\n' portable > "$fixture_copy_source/payload"

  (
    cp() {
      case "${1:-}" in
        *c*) return 97 ;;
      esac
      : > "$fixture_copy_marker"
      command cp "$@"
    }
    SHIMMY_TEST_COPY_ON_WRITE=0
    test_fixture_tree_copy "$fixture_copy_source" "$fixture_copy_target"
  )

  assert_file_exists "$fixture_copy_marker"
  assert_file_contains "$fixture_copy_target/payload" portable
  pass "fixture tree copy portable fallback omits clone-only options"
}

test_lib_runner_fixture_copy_rejections() {
  setup_scenario
  fixture_copy_source=$SCENARIO_DIR/rejection-source
  fixture_copy_preexisting=$SCENARIO_DIR/preexisting-target
  fixture_copy_outside=$TMP_ROOT-outside-copy-target
  mkdir "$fixture_copy_source" "$fixture_copy_preexisting"
  printf '%s\n' source-unchanged > "$fixture_copy_source/payload"
  printf '%s\n' target-unchanged > "$fixture_copy_preexisting/payload"
  fixture_copy_source_checksum=$(cksum < "$fixture_copy_source/payload")
  fixture_copy_target_checksum=$(cksum < "$fixture_copy_preexisting/payload")

  for fixture_copy_unsafe_target in \
    '' \
    / \
    "$ROOT_DIR" \
    "$fixture_copy_source" \
    "$fixture_copy_source/descendant" \
    "$fixture_copy_preexisting" \
    "$fixture_copy_outside"
  do
    set +e
    fixture_copy_rejection_output=$(test_fixture_tree_copy "$fixture_copy_source" "$fixture_copy_unsafe_target" 2>&1)
    fixture_copy_rejection_status=$?
    set -e
    [ "$fixture_copy_rejection_status" -ne 0 ] ||
      fail_test "fixture tree copy accepted unsafe target: $fixture_copy_unsafe_target"
    assert_contains "$fixture_copy_rejection_output" 'FAIL:'
  done

  assert_equals "$(cksum < "$fixture_copy_source/payload")" "$fixture_copy_source_checksum"
  assert_equals "$(cksum < "$fixture_copy_preexisting/payload")" "$fixture_copy_target_checksum"
  assert_path_not_exists "$fixture_copy_source/descendant"
  assert_path_not_exists "$fixture_copy_outside"
  pass "fixture tree copy rejects unsafe and pre-existing targets without mutation"
}

test_lib_runner_fixture_copy_preservation() {
  setup_scenario
  fixture_copy_source=$SCENARIO_DIR/preservation-source
  fixture_copy_target=$SCENARIO_DIR/preservation-target
  mkdir -p "$fixture_copy_source/bin" "$fixture_copy_source/data"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$fixture_copy_source/bin/example"
  printf '%s\n' original > "$fixture_copy_source/data/value"
  chmod 751 "$fixture_copy_source/bin/example"
  ln -s ../data/value "$fixture_copy_source/bin/value-link"
  ln -s data "$fixture_copy_source/data-link"
  git -C "$fixture_copy_source" init -q
  git -C "$fixture_copy_source" config user.email shimmy-tests@example.invalid
  git -C "$fixture_copy_source" config user.name 'Shimmy Tests'
  git -C "$fixture_copy_source" add -A
  git -C "$fixture_copy_source" commit -qm fixture
  TEST_LIFECYCLE_CHECKOUT_TEMPLATE=$fixture_copy_source
  TEST_LIFECYCLE_CHECKOUT_TEMPLATE_HEAD=$(git -C "$fixture_copy_source" rev-parse HEAD)
  test_lifecycle_checkout_template_validate

  test_fixture_tree_copy "$fixture_copy_source" "$fixture_copy_target"

  assert_file_mode "$fixture_copy_target/bin/example" 751
  assert_path_symlink "$fixture_copy_target/bin/value-link"
  assert_equals "$(readlink "$fixture_copy_target/bin/value-link")" ../data/value
  assert_path_symlink "$fixture_copy_target/data-link"
  assert_equals "$(readlink "$fixture_copy_target/data-link")" data
  git -C "$fixture_copy_target" rev-parse --verify HEAD >/dev/null
  assert_equals "$(git -C "$fixture_copy_target" status --porcelain)" ''
  printf '%s\n' changed > "$fixture_copy_target/data/value"
  assert_file_contains "$fixture_copy_source/data/value" original
  assert_file_contains "$fixture_copy_target/data/value" changed
  test_lifecycle_checkout_template_validate
  pass "fixture tree copy preserves modes, symlinks, Git metadata, and mutation independence"
}

test_lib_runner_run() {
  test_lib_runner_registry_ordering
  test_lib_runner_group_selection
  test_lib_runner_group_sigint_guard
  test_lib_runner_option_validation
  test_lib_runner_timing_shape
  test_lib_runner_lifecycle_grouping
  test_lib_runner_worker_scheduling
  test_lib_runner_worker_failure_propagation
  test_lib_runner_missing_result_rejection
  test_lib_runner_count_mismatch_rejection
  test_lib_runner_signal_cleanup
  test_lib_runner_fixture_copy_clone_selection
  test_lib_runner_fixture_copy_portable_fallback
  test_lib_runner_fixture_copy_rejections
  test_lib_runner_fixture_copy_preservation
}
