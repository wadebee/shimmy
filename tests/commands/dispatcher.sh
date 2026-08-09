#!/bin/sh

test_commands_dispatcher_run() {
  setup_scenario
  bootstrap_default --shim jq >/dev/null
  assert_equals "$(readlink "$DEFAULT_PROFILE_ROOT/bin/jq")" '../commands/dispatch-tool.sh'

  implementation=$DEFAULT_PROFILE_ROOT/implementations/jq
  rm -f "$implementation"
  ln -s ../commands/dispatch-tool.sh "$implementation"
  set +e
  recursive_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --version 2>&1)
  recursive_status=$?
  set -e
  [ "$recursive_status" -ne 0 ] || fail_test "symlinked implementation unexpectedly dispatched"
  assert_contains "$recursive_output" 'invalid Shimmy implementation'

  setup_scenario
  set +e
  unknown_output=$(bootstrap_default --shim oc@9.99 2>&1)
  unknown_status=$?
  set -e
  [ "$unknown_status" -ne 0 ] || fail_test "unknown version unexpectedly installed"
  assert_contains "$unknown_output" 'unsupported oc version'
  pass "dispatchers use the profile-local target and reject unsafe implementations"
}
