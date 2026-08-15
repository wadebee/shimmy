#!/bin/sh
# Installed profile command tests.

test_commands_profile_help_and_validation() {
  setup_scenario_with_profiles default
  help_output=$(default_shimmy profile --help)
  assert_contains "$help_output" 'shimmy profile status'
  assert_contains "$help_output" 'shimmy profile activate'
  assert_contains "$help_output" 'shimmy profile redirect'
  assert_contains "$(default_shimmy profile status --help)" 'without mutation'
  assert_contains "$(default_shimmy profile activate --help)" '--stop-running'
  assert_contains "$(default_shimmy profile redirect --help)" 'not active engine policy'
  assert_contains "$(default_shimmy profile redirect list --help)" '--format human|manifest'
  assert_contains "$(default_shimmy profile redirect remove --help)" '--detach'

  for invalid_args in \
    'profile' \
    'profile unknown' \
    'profile status --profile upstream' \
    'profile activate --machine anything' \
    'profile activate --restart --restart' \
    'profile redirect mirror' \
    'profile redirect set' \
    'profile redirect registries' \
    'profile redirect upsert --prefix docker.io --location registry.example.com' \
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
  assert_contains "$status_output" 'registry_config=valid'
  assert_contains "$status_output" 'registry_policy=inactive'
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

test_commands_profile_redirect_crud() {
  setup_scenario_with_profiles default upstream
  default_config=$DEFAULT_PROFILE_ROOT/registries.conf
  upstream_config=$UPSTREAM_PROFILE_ROOT/registries.conf
  upstream_checksum=$(cksum < "$upstream_config")

  inactive_output=$(default_shimmy profile redirect list --format manifest)
  assert_contains "$inactive_output" 'registry_policy=inactive'
  assert_no_line_with_prefix "$inactive_output" 'redirect='

  dry_run_before=$(cksum < "$default_config")
  dry_run_output=$(default_shimmy profile redirect --prefix quay.io/team --location registry.corp.example:5443/quay --dry-run)
  assert_contains "$dry_run_output" 'prefix = "quay.io/team"'
  assert_contains "$dry_run_output" 'location = "registry.corp.example:5443/quay"'
  assert_equals "$(cksum < "$default_config")" "$dry_run_before"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/.registries.lock"

  default_shimmy profile redirect --prefix quay.io/team --location registry.corp.example:5443/quay
  default_shimmy profile redirect --prefix docker.io --location registry.corp.example/docker
  assert_regular_file_not_symlink "$default_config"
  assert_file_mode "$default_config" 644
  prepared_output=$(default_shimmy profile redirect list --format manifest)
  assert_contains "$prepared_output" 'registry_policy=prepared'
  redirect_lines=$(printf '%s\n' "$prepared_output" | sed -n 's/^redirect=//p')
  assert_equals "$redirect_lines" 'docker.io|registry.corp.example/docker
quay.io/team|registry.corp.example:5443/quay'
  assert_equals "$(cksum < "$upstream_config")" "$upstream_checksum"

  no_op_checksum=$(cksum < "$default_config")
  default_shimmy profile redirect --prefix docker.io --location registry.corp.example/docker
  assert_equals "$(cksum < "$default_config")" "$no_op_checksum"
  default_shimmy profile redirect --prefix docker.io --location registry.new.example/docker
  assert_file_contains "$default_config" 'location = "registry.new.example/docker"'
  assert_file_not_contains "$default_config" 'location = "registry.corp.example/docker"'

  remove_dry_run_before=$(cksum < "$default_config")
  remove_dry_run=$(default_shimmy profile redirect remove --prefix docker.io --dry-run)
  assert_not_contains "$remove_dry_run" 'prefix = "docker.io"'
  assert_contains "$remove_dry_run" 'prefix = "quay.io/team"'
  assert_equals "$(cksum < "$default_config")" "$remove_dry_run_before"

  default_shimmy profile redirect remove --prefix docker.io
  assert_file_not_contains "$default_config" 'prefix = "docker.io"'
  assert_file_contains "$default_config" 'prefix = "quay.io/team"'
  default_shimmy profile redirect remove --all --detach
  final_output=$(default_shimmy profile redirect list)
  assert_contains "$final_output" 'Policy: inactive (not active engine policy)'
  assert_contains "$final_output" 'Redirects: none'
  assert_equals "$(cksum < "$upstream_config")" "$upstream_checksum"
  pass "profile redirect dry-run, sorted upsert, no-op, replacement, exact removal, full removal, formats, and profile isolation are deterministic"
}

test_commands_profile_redirect_rejection() {
  setup_scenario_with_profiles default
  config_file=$DEFAULT_PROFILE_ROOT/registries.conf
  original_checksum=$(cksum < "$config_file")

  for invalid_args in \
    'profile redirect --prefix docker.io' \
    'profile redirect --location registry.example.com' \
    'profile redirect --prefix docker.io --location https://registry.example.com' \
    'profile redirect --prefix docker.io/repo:tag --location registry.example.com/repo' \
    'profile redirect remove' \
    'profile redirect remove --all --prefix docker.io' \
    'profile redirect remove --prefix docker.io --detach' \
    'profile redirect list --format json' \
    'profile redirect --prefix docker.io --location registry.example.com --profile upstream' \
    'profile redirect --prefix docker.io --location registry.example.com --machine anything'; do
    set +e
    invalid_output=$(default_shimmy $invalid_args 2>&1)
    invalid_status=$?
    set -e
    [ "$invalid_status" -ne 0 ] || fail_test "invalid redirect request unexpectedly succeeded: $invalid_args"
    assert_contains "$invalid_output" 'ERROR:'
    assert_equals "$(cksum < "$config_file")" "$original_checksum"
    assert_path_not_exists "$DEFAULT_PROFILE_ROOT/.registries.lock"
  done
  pass "redirect aliases, selectors, malformed endpoints, conflicting requests, and unknown formats fail before mutation"
}

test_commands_profile_run() {
  test_commands_profile_help_and_validation
  test_commands_profile_installed_status_and_materialization
  test_commands_profile_redirect_crud
  test_commands_profile_redirect_rejection
}
