#!/bin/sh

test_commands_profiles_run() {
  setup_scenario
  bootstrap_default --shim jq >/dev/null
  bootstrap_upstream --shim rg >/dev/null

  default_status=$(default_shimmy status --format manifest)
  upstream_status=$(upstream_shimmy status --format manifest)
  assert_contains "$default_status" 'shimmy_profile_name=default'
  assert_contains "$upstream_status" 'shimmy_profile_name=upstream'

  set +e
  copied_output=$(cp "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "$UPSTREAM_PROFILE_ROOT/install-manifest.txt" 2>&1 && upstream_shimmy status 2>&1)
  copied_status=$?
  set -e
  [ "$copied_status" -ne 0 ] || fail_test "copied wrong-profile manifest unexpectedly succeeded"
  assert_contains "$copied_output" 'invalid or unsupported Shimmy profile manifest'

  setup_scenario
  set +e
  relative_output=$(run_in_repo env XDG_CONFIG_HOME=relative HOME="$HOME_DIR" ./install.sh --shim jq --no-startup --no-skills 2>&1)
  relative_status=$?
  set -e
  [ "$relative_status" -ne 0 ] || fail_test "relative XDG_CONFIG_HOME unexpectedly succeeded"
  assert_contains "$relative_output" 'unable to resolve canonical Shimmy profile'
  assert_path_not_exists "$ROOT_DIR/relative"
  pass "profile identity is directory-bound and relative XDG roots are rejected"
}
