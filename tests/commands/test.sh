#!/bin/sh

test_commands_test_run() {
  setup_scenario
  bootstrap_default >/dev/null
  help_output=$(default_shimmy test --help)
  assert_contains "$help_output" 'shimmy test [--shim'

  set +e
  rejected_output=$(default_shimmy test --profile upstream 2>&1)
  rejected_status=$?
  set -e
  [ "$rejected_status" -ne 0 ] || fail_test "installed test unexpectedly accepted --profile"
  assert_contains "$rejected_output" 'unknown argument: --profile'
  pass "installed test surface is bound to its enclosing profile"
}
