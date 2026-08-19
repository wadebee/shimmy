#!/bin/sh

test_commands_test_run() {
  setup_scenario_with_profiles default
  help_output=$(default_shimmy test --help)
  assert_contains "$help_output" 'shimmy test [--shim'
  pass "installed test exposes shim selection help"

  failing_smoke_dir=$TMP_ROOT/failing-profile-smoke
  mkdir -p "$failing_smoke_dir"
  failing_smoke=$failing_smoke_dir/failing-smoke
  failing_smoke_config=$failing_smoke_dir/failing-smoke.conf
  printf '%s\n' '#!/bin/sh' 'printf "%s\n" intentional-smoke-failure >&2' 'exit 7' > "$failing_smoke"
  chmod +x "$failing_smoke"
  printf '%s\n' 'shim_config_version=1' 'shim_name=failing_smoke' 'smoke_arg=--version' > "$failing_smoke_config"

  set +e
  failing_smoke_output=$(
    exec 2>&1
    test_profile_smoke_command_run \
      "$failing_smoke" default "$failing_smoke_config" \
      "$failing_smoke_config" version failing_smoke
  )
  failing_smoke_status=$?
  set -e
  [ "$failing_smoke_status" -ne 0 ] || fail_test "failing installed smoke unexpectedly passed"
  assert_contains "$failing_smoke_output" 'intentional-smoke-failure'
  assert_contains "$failing_smoke_output" 'version smoke command failed for failing_smoke'
  pass "installed test fails when a version-owned smoke command fails"
}
