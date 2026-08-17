#!/bin/sh

test_lib_runner_stub_first() {
  printf '%s\n' first
}

test_lib_runner_stub_second() {
  printf '%s\n' second
}

test_lib_runner_registry_ordering() {
  test_runner_registry=$(test_runner_group_registry_read)
  test_runner_first_name=$(printf '%s\n' "$test_runner_registry" | sed -n '1s/|.*//p')
  test_runner_last_name=$(printf '%s\n' "$test_runner_registry" | sed -n '$s/|.*//p')
  assert_equals "$test_runner_first_name" runner
  assert_equals "$test_runner_last_name" commands-test
  assert_equals "$(printf '%s\n' "$test_runner_registry" | sed -n '/^commands-lifecycle|/p')" \
    'commands-lifecycle|test_runner_commands_lifecycle_run'
  pass "runner registry has stable canonical ordering and one lifecycle group"
}

test_lib_runner_group_selection() {
  test_runner_selection_output=$(
    SHIMMY_TEST_TIMING=0
    TEST_RUNNER_GROUP_REGISTRY_OVERRIDE='first|test_lib_runner_stub_first
second|test_lib_runner_stub_second'
    test_runner_options_parse --group second --group first --jobs 3
    test_runner_groups_run
  )
  assert_equals "$test_runner_selection_output" 'first
second'
  pass "runner selection executes requested groups in registry order"
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
  pass "runner timing records are stable and opt in"
}

test_lib_runner_lifecycle_grouping() {
  test_runner_lifecycle_output=$(
    test_commands_lifecycle_prepare() { printf '%s\n' prepare; }
    test_commands_lifecycle_complete() { printf '%s\n' complete; }
    test_runner_commands_lifecycle_run
  )
  assert_equals "$test_runner_lifecycle_output" 'prepare
complete'
  pass "runner lifecycle group keeps prepare and complete indivisible"
}

test_lib_runner_run() {
  test_lib_runner_registry_ordering
  test_lib_runner_group_selection
  test_lib_runner_option_validation
  test_lib_runner_timing_shape
  test_lib_runner_lifecycle_grouping
}
