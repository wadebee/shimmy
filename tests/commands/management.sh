#!/bin/sh

test_commands_management_run() {
  activation_output=$(default_shimmy activate)
  assert_contains "$activation_output" "$DEFAULT_PROFILE_ROOT/bin"
  assert_not_contains "$activation_output" 'SHIMMY_PROFILE_ACTIVE'

  set +e
  error_output=$(default_shimmy status --profile upstream 2>&1)
  error_status=$?
  set -e
  [ "$error_status" -ne 0 ] || fail_test "installed status unexpectedly accepted --profile"
  assert_contains "$error_output" 'unknown argument: --profile'

  netinfo_output=$(run_in_repo ./commands/netinfo.sh --host-ip 192.0.2.10 --host-prefix 24 --format manifest)
  assert_contains "$netinfo_output" 'host_lan=192.0.2.0/24'
  pass "installed management is profile-bound and netinfo remains available"
}
