#!/bin/sh
# Public test-command request validation.

test_commands_test_profile_request_validation() {
  setup_scenario

  set +e
  output=$(HOME="$HOME_DIR" run_in_repo ./shimmy test --all --shim jq 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "test accepted --all with --shim"
  assert_contains "$output" "--all cannot be combined with --shim"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(HOME="$HOME_DIR" run_in_repo ./shimmy test --install-dir "$INSTALL_DIR" --profile default --shim rg 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "test accepted an uninstalled requested kind"
  assert_contains "$output" "kind rg is not recorded in the selected Shimmy profile"
  pass "test validates installed profile shim requests before smoke execution"
}

test_commands_test_usage() {
  output=$(run_in_repo ./shimmy test --help)

  assert_contains "$output" "Run Shimmy tests."
  assert_contains "$output" "--profile default|upstream"
  assert_contains "$output" "--shim <name>"
  pass "test documents installed-profile smoke mode"
}

test_commands_test_run() {
  test_commands_test_profile_request_validation
  test_commands_test_usage
}
