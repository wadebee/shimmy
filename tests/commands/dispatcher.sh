#!/bin/sh

test_commands_dispatcher_run() {
  setup_scenario
  bootstrap_default >/dev/null
  bootstrap_upstream >/dev/null
  assert_equals "$(readlink "$DEFAULT_PROFILE_ROOT/bin/jq")" '../commands/dispatch-tool.sh'
  assert_equals "$(readlink "$UPSTREAM_PROFILE_ROOT/bin/rg")" '../commands/dispatch-tool.sh'

  default_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version)
  assert_contains "$default_output" 'ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91'

  set +e
  unowned_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/commands/dispatch-tool.sh" task --preview-shim --version 2>&1)
  unowned_status=$?
  set -e
  [ "$unowned_status" -ne 0 ] || fail_test "unowned dispatcher request unexpectedly succeeded"
  assert_contains "$unowned_output" 'task is not owned by profile default'

  implementation=$DEFAULT_PROFILE_ROOT/implementations/jq
  rm -f "$implementation"
  ln -s ../commands/dispatch-tool.sh "$implementation"
  set +e
  recursive_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --version 2>&1)
  recursive_status=$?
  set -e
  [ "$recursive_status" -ne 0 ] || fail_test "symlinked implementation unexpectedly dispatched"
  assert_contains "$recursive_output" 'invalid Shimmy implementation'

  bootstrap_default >/dev/null
  chmod 644 "$DEFAULT_PROFILE_ROOT/implementations/jq"
  set +e
  non_executable_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --version 2>&1)
  non_executable_status=$?
  set -e
  [ "$non_executable_status" -ne 0 ] || fail_test "non-executable implementation unexpectedly dispatched"
  assert_contains "$non_executable_output" 'implementation is not executable'

  setup_scenario
  bootstrap_default >/dev/null
  set +e
  unknown_output=$(default_shimmy install --shim oc@9.99 --no-startup 2>&1)
  unknown_status=$?
  set -e
  [ "$unknown_status" -ne 0 ] || fail_test "unknown version unexpectedly installed"
  assert_contains "$unknown_output" 'unsupported oc version'
  pass "dispatchers are profile-bound and reject unowned, symlinked, non-executable, and unknown implementations"
}
