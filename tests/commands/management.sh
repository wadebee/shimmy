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

  for command_name in activate install netinfo skills status test uninstall update; do
    set +e
    bound_output=$(default_shimmy "$command_name" --profile upstream 2>&1)
    bound_status=$?
    set -e
    [ "$bound_status" -ne 0 ] || fail_test "installed $command_name unexpectedly accepted --profile"
    assert_contains "$bound_output" 'unknown argument: --profile'
  done

  selector_status=$(env SHIMMY_PROFILE_ACTIVE=upstream XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/shimmy" status --format manifest)
  assert_contains "$selector_status" 'shimmy_profile_name=default'

  netinfo_output=$(run_in_repo ./commands/netinfo.sh --host-ip 192.0.2.10 --host-prefix 24 --format manifest)
  assert_contains "$netinfo_output" 'host_lan=192.0.2.0/24'
  pass "every installed management command is profile-bound and retired profile selectors have no semantics"
}
