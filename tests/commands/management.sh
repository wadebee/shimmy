#!/bin/sh

test_commands_management_run() {
  help_output=$(default_shimmy)
  assert_contains "$help_output" 'shimmy <command> [options]'
  assert_contains "$help_output" 'install    Add tool shims to this profile.'
  assert_contains "$help_output" 'uninstall  Remove this profile and its managed startup integration.'
  assert_contains "$help_output" 'netinfo    Show host, VM, and container network perspectives.'
  assert_contains "$help_output" 'skills     Install, update, uninstall, or export Shimmy agent skills.'
  assert_contains "$help_output" 'status     Show installed shims, versions, and profile details.'
  assert_contains "$help_output" 'test       Validate this profile with non-mutating shim smoke commands.'
  assert_contains "$help_output" 'update     Refresh this profile and optionally pull or build tool images.'
  assert_contains "$help_output" 'shimmy install --shim jq'
  assert_not_contains "$help_output" 'activate'
  assert_contains "$help_output" "Run 'shimmy <command> --help' for command-specific options."
  assert_not_contains "$help_output" '<install|uninstall|activate|netinfo|skills|status|test|update>'

  explicit_help_output=$(default_shimmy help)
  assert_equals "$explicit_help_output" "$help_output"

  set +e
  error_output=$(default_shimmy status --profile upstream 2>&1)
  error_status=$?
  set -e
  [ "$error_status" -ne 0 ] || fail_test "installed status unexpectedly accepted --profile"
  assert_contains "$error_output" 'unknown argument: --profile'

  for command_name in install netinfo skills status test uninstall update; do
    set +e
    bound_output=$(default_shimmy "$command_name" --profile upstream 2>&1)
    bound_status=$?
    set -e
    [ "$bound_status" -ne 0 ] || fail_test "installed $command_name unexpectedly accepted --profile"
    assert_contains "$bound_output" 'unknown argument: --profile'
  done

  netinfo_output=$(run_in_repo ./commands/netinfo.sh --host-ip 192.0.2.10 --host-prefix 24 --format manifest)
  assert_contains "$netinfo_output" 'host_lan=192.0.2.0/24'
  pass "installed management help summarizes each command and every command remains profile-bound"
}
