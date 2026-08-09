#!/bin/sh

test_commands_startup_run() {
  setup_scenario
  startup_file=$SCENARIO_DIR/zshrc
  run_in_repo env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile default --shim jq --shell zsh --startup-file "$startup_file" --no-skills >/dev/null
  assert_file_contains "$startup_file" '# >>> shimmy default profile >>>'
  assert_file_contains "$startup_file" "$DEFAULT_PROFILE_ROOT/activate.sh"
  bootstrap_default --shim jq >/dev/null
  marker_count=$(grep -c '^# >>> shimmy default profile >>>$' "$startup_file")
  assert_equals "$marker_count" 1

  setup_scenario
  set +e
  upstream_output=$(run_in_repo env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile upstream --shim jq --shell zsh --startup-file "$SCENARIO_DIR/upstream-zshrc" --no-skills 2>&1)
  upstream_status=$?
  set -e
  [ "$upstream_status" -ne 0 ] || fail_test "upstream startup mutation unexpectedly succeeded"
  assert_contains "$upstream_output" 'manual-activation-only'
  assert_path_not_exists "$SCENARIO_DIR/upstream-zshrc"
  pass "default exclusively owns persistent startup integration"
}
