#!/bin/sh

test_commands_dispatcher_run() {
  setup_scenario_with_profiles default upstream
  assert_equals "$(readlink "$DEFAULT_PROFILE_ROOT/bin/jq")" '../commands/dispatch-tool.sh'
  assert_equals "$(readlink "$UPSTREAM_PROFILE_ROOT/bin/rg")" '../commands/dispatch-tool.sh'

  default_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version)
  assert_contains "$default_output" 'ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91'

  default_shimmy install --shim oc@4.18 >/dev/null
  selector_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_OC_VERSION=4.18 \
    "$DEFAULT_PROFILE_ROOT/bin/oc" --preview-shim version)
  assert_contains "$selector_output" 'localhost/shimmy-oc-4_18'
  assert_contains "$selector_output" "'version'"

  set +e
  unowned_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/commands/dispatch-tool.sh" task --preview-shim --version 2>&1)
  unowned_status=$?
  set -e
  [ "$unowned_status" -ne 0 ] || fail_test "unowned dispatcher request unexpectedly succeeded"
  assert_contains "$unowned_output" 'task is not owned by profile default'

  runtime_dispatcher=$DEFAULT_PROFILE_ROOT/commands/run-tool.sh
  rm -f "$runtime_dispatcher"
  ln -s dispatch-tool.sh "$runtime_dispatcher"
  set +e
  recursive_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --version 2>&1)
  recursive_status=$?
  set -e
  [ "$recursive_status" -ne 0 ] || fail_test "symlinked tool dispatcher target unexpectedly dispatched"
  assert_contains "$recursive_output" 'invalid Shimmy tool dispatcher target'

  setup_scenario_with_profiles default
  chmod 644 "$DEFAULT_PROFILE_ROOT/commands/run-tool.sh"
  set +e
  non_executable_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --version 2>&1)
  non_executable_status=$?
  set -e
  [ "$non_executable_status" -ne 0 ] || fail_test "non-executable tool dispatcher target unexpectedly dispatched"
  assert_contains "$non_executable_output" 'Shimmy tool dispatcher target is not executable'

  setup_scenario_with_profiles default
  set +e
  unknown_output=$(default_shimmy install --shim oc@9.99 2>&1)
  unknown_status=$?
  set -e
  [ "$unknown_status" -ne 0 ] || fail_test "unknown version unexpectedly installed"
  assert_contains "$unknown_output" 'unsupported oc version'
  pass "dispatchers are profile-bound and reject unowned tools, damaged fixed targets, and unknown versions"
}
