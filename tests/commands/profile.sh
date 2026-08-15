#!/bin/sh
# Installed profile command tests.

test_commands_profile_help_and_validation() {
  setup_scenario_with_profiles default
  help_output=$(default_shimmy profile --help)
  assert_contains "$help_output" 'shimmy profile status'
  assert_contains "$help_output" 'shimmy profile activate'
  assert_contains "$(default_shimmy profile status --help)" 'without mutation'
  assert_contains "$(default_shimmy profile activate --help)" '--stop-running'

  for invalid_args in \
    'profile' \
    'profile unknown' \
    'profile status --profile upstream' \
    'profile activate --machine anything' \
    'profile activate --restart --restart' \
    'profile status --format json'; do
    set +e
    invalid_output=$(default_shimmy $invalid_args 2>&1)
    invalid_status=$?
    set -e
    [ "$invalid_status" -ne 0 ] || fail_test "invalid profile request unexpectedly succeeded: $invalid_args"
    assert_contains "$invalid_output" 'ERROR:'
  done
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/.profile-activation.lock"
  pass "profile launcher help precedes engine access and unsupported selectors and aliases fail without mutation"
}

test_commands_profile_installed_status_and_materialization() {
  setup_scenario_with_profiles default upstream
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  fake_connections='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'

  status_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true
shimmy-upstream|false' FAKE_CONNECTION_LIST="$fake_connections" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile status --format manifest)
  assert_contains "$status_output" 'profile=default'
  assert_contains "$status_output" 'activation=active'
  assert_file_executable "$DEFAULT_PROFILE_ROOT/commands/profile.sh"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/lib/profile/activation.sh"
  assert_equals "$(profile_manifest_value "$DEFAULT_PROFILE_ROOT/install-manifest.txt" shimmy_install_manifest_version)" 2

  secret_uri='ssh://secret@example.invalid/run/user/1/podman/podman.sock'
  overridden_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    CONTAINER_HOST="$secret_uri" SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true' FAKE_CONNECTION_LIST="$fake_connections" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile status --format manifest)
  assert_contains "$overridden_output" 'connection_override=CONTAINER_HOST'
  assert_contains "$overridden_output" 'activation=overridden'
  assert_not_contains "$overridden_output" "$secret_uri"
  pass "fresh profiles materialize the profile control plane and status hides connection override values"
}

test_commands_profile_run() {
  test_commands_profile_help_and_validation
  test_commands_profile_installed_status_and_materialization
}
