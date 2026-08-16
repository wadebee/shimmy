#!/bin/sh
# Installed profile command tests.

profile_projection_record_write() {
  profile_root=$1
  profile_name=$2
  projection_fingerprint=$(shimmy_registries_config_fingerprint_render "$profile_root/registries.conf")
  (
    SHIMMY_CONFIG_ROOT=$XDG_CONFIG_HOME_DIR/shimmy
    shimmy_registries_machine_projection_record_render "$profile_name" "$projection_fingerprint"
  ) > "$profile_root/machine-projection.txt"
  chmod 0644 "$profile_root/machine-projection.txt"
}

test_commands_profile_help_and_validation() {
  setup_scenario_with_profiles default
  help_output=$(default_shimmy profile --help)
  assert_contains "$help_output" 'shimmy profile status'
  assert_contains "$help_output" 'shimmy profile activate'
  assert_contains "$help_output" 'shimmy profile redirect'
  assert_contains "$(default_shimmy profile status --help)" 'without mutation'
  assert_contains "$(default_shimmy profile activate --help)" '--stop-running'
  assert_contains "$(default_shimmy profile redirect --help)" 'deterministic Darwin machine'
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
  assert_contains "$status_output" 'activation=registry_restart_required'
  assert_contains "$status_output" 'registry_config=valid'
  assert_contains "$status_output" 'registry_policy=restart-required'
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
  assert_contains "$prepared_output" 'registry_policy=unverified'
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
  default_shimmy profile redirect remove --all
  final_output=$(default_shimmy profile redirect list)
  assert_contains "$final_output" 'Policy: inactive'
  assert_contains "$final_output" 'Redirects: none'
  assert_equals "$(cksum < "$upstream_config")" "$upstream_checksum"
  pass "profile redirect dry-run, sorted upsert, no-op, replacement, exact removal, full removal, formats, and profile isolation are deterministic"
}

test_commands_profile_linux_registry_activation_and_edit() {
  setup_scenario_with_profiles default upstream
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  active_link=$XDG_CONFIG_HOME_DIR/containers/registries.conf.d/shimmy-active-profile.conf
  default_config=$DEFAULT_PROFILE_ROOT/registries.conf
  common_env="XDG_CONFIG_HOME=$XDG_CONFIG_HOME_DIR HOME=$HOME_DIR SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN=$FAKE_PODMAN_BIN FAKE_PODMAN_LOG=$FAKE_PODMAN_LOG FAKE_LINUX_INFO=true|false FAKE_ACTIVE_LINK=$active_link FAKE_ACTIVE_CONFIG=$default_config"

  activation_output=$(env $common_env "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile activate)
  assert_contains "$activation_output" 'Activated Shimmy profile default registry policy'
  assert_path_symlink "$active_link"
  assert_equals "$(readlink "$active_link")" "$default_config"

  env $common_env "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect --prefix docker.io --location registry.corp.example/docker
  current_output=$(env $common_env "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect list --format manifest)
  assert_contains "$current_output" 'registry_active_link=current'
  assert_contains "$current_output" 'registry_active_profile=default'
  assert_contains "$current_output" 'registry_override=none'
  assert_contains "$current_output" 'registry_policy=current'

  before_failure=$SCENARIO_DIR/before-active-edit
  cp "$default_config" "$before_failure"
  set +e
  failed_edit_output=$(env $common_env FAKE_FAIL_LINUX_CONFIG_PATTERN=registry.fail.example \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect --prefix docker.io --location registry.fail.example/docker 2>&1)
  failed_edit_status=$?
  set -e
  [ "$failed_edit_status" -ne 0 ] || fail_test 'active Linux edit unexpectedly survived fresh-process validation failure'
  assert_contains "$failed_edit_output" 'prior configuration restored'
  cmp -s "$before_failure" "$default_config" || fail_test 'active Linux edit rollback did not restore exact prior bytes'

  upstream_before=$(cksum < "$UPSTREAM_PROFILE_ROOT/registries.conf")
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_TEST_PROFILE_OS=Linux \
    SHIMMY_TEST_PROFILE_PODMAN_BIN="$SCENARIO_DIR/missing-podman" \
    "$UPSTREAM_PROFILE_ROOT/bin/shimmy" profile redirect --prefix quay.io --location registry.corp.example/quay
  [ "$(cksum < "$UPSTREAM_PROFILE_ROOT/registries.conf")" != "$upstream_before" ] || fail_test 'inactive Linux profile edit was not committed'

  detach_dry_run=$(env $common_env "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect remove --all --detach --dry-run)
  assert_contains "$detach_dry_run" "would_detach=$active_link"
  assert_path_symlink "$active_link"
  env $common_env "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect remove --all --detach
  assert_path_not_exists "$active_link"
  assert_contains "$(env $common_env "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect list --format manifest)" 'registry_policy=inactive'
  pass 'installed Linux profile activation, current status, active-edit rollback, inactive edits, and detach are isolated'
}

test_commands_profile_linux_detach_refuses_sibling() {
  setup_scenario_with_profiles default upstream
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  active_link=$XDG_CONFIG_HOME_DIR/containers/registries.conf.d/shimmy-active-profile.conf
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_TEST_PROFILE_OS=Linux \
    SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_LINUX_INFO='true|false' \
    FAKE_ACTIVE_LINK="$active_link" FAKE_ACTIVE_CONFIG="$DEFAULT_PROFILE_ROOT/registries.conf" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile activate >/dev/null
  set +e
  detach_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_TEST_PROFILE_OS=Linux \
    "$UPSTREAM_PROFILE_ROOT/bin/shimmy" profile redirect remove --all --detach 2>&1)
  detach_status=$?
  set -e
  [ "$detach_status" -ne 0 ] || fail_test 'inactive sibling unexpectedly detached the active Linux profile'
  assert_contains "$detach_output" 'not actively linked to profile upstream'
  assert_equals "$(readlink "$active_link")" "$DEFAULT_PROFILE_ROOT/registries.conf"
  pass 'Linux detach is bound to the invoking active profile'
}

test_commands_profile_darwin_projection_edit_and_detach() {
  setup_scenario_with_profiles default upstream
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  default_config=$DEFAULT_PROFILE_ROOT/registries.conf
  record_path=$DEFAULT_PROFILE_ROOT/machine-projection.txt
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  fake_connections='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'

  edit_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true' \
    FAKE_CONNECTION_LIST="$fake_connections" FAKE_DARWIN_PROJECTION_STATE=current \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect --prefix docker.io --location registry.corp.example/docker)
  assert_contains "$edit_output" "'$DEFAULT_PROFILE_ROOT/bin/shimmy' profile activate --restart"
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop'
  stale_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true' \
    FAKE_CONNECTION_LIST="$fake_connections" FAKE_DARWIN_PROJECTION_STATE=current \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect list --format manifest)
  assert_contains "$stale_output" 'registry_machine_link=current'
  assert_contains "$stale_output" 'registry_projection_record=valid'
  assert_contains "$stale_output" 'registry_policy=restart-required'

  dry_run_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true' \
    FAKE_CONNECTION_LIST="$fake_connections" FAKE_DARWIN_PROJECTION_STATE=current \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect remove --all --detach --dry-run)
  assert_contains "$dry_run_output" "would_detach=shimmy-default:/etc/containers/registries.conf.d/shimmy-profile.conf"
  assert_file_exists "$record_path"
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true' \
    FAKE_CONNECTION_LIST="$fake_connections" FAKE_DARWIN_PROJECTION_STATE=current \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect remove --all --detach
  assert_path_not_exists "$record_path"
  assert_file_not_contains "$default_config" '[[registry]]'
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh --username root shimmy-default /bin/sh -s -- detach'

  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  before_stopped=$(cksum < "$record_path")
  set +e
  stopped_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|false' \
    FAKE_CONNECTION_LIST="$fake_connections" "$DEFAULT_PROFILE_ROOT/bin/shimmy" \
    profile redirect remove --all --detach 2>&1)
  stopped_status=$?
  set -e
  [ "$stopped_status" -ne 0 ] || fail_test 'stopped existing Darwin machine unexpectedly detached'
  assert_contains "$stopped_output" "'$DEFAULT_PROFILE_ROOT/bin/shimmy' profile activate"
  assert_equals "$(cksum < "$record_path")" "$before_stopped"

  : > "$FAKE_PODMAN_LOG"
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='other|false' \
    FAKE_CONNECTION_LIST="$fake_connections" "$DEFAULT_PROFILE_ROOT/bin/shimmy" \
    profile redirect remove --all --detach
  assert_path_not_exists "$record_path"
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh'

  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  set +e
  foreign_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true' \
    FAKE_CONNECTION_LIST="$fake_connections" FAKE_DARWIN_PROJECTION_STATE=foreign \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect remove --all --detach 2>&1)
  foreign_status=$?
  set -e
  [ "$foreign_status" -ne 0 ] || fail_test 'foreign Darwin projection unexpectedly detached'
  assert_contains "$foreign_output" 'foreign, absent, or invalid machine projection'
  assert_file_exists "$record_path"

  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true' \
    FAKE_CONNECTION_LIST="$fake_connections" FAKE_DARWIN_PROJECTION_STATE=current \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect --prefix docker.io --location registry.corp.example/docker >/dev/null
  failure_bin=$SCENARIO_DIR/failure-bin
  real_mv=$(command -v mv)
  mkdir "$failure_bin"
  {
    printf '%s\n' '#!/bin/sh' 'set -eu'
    printf '%s\n' 'if [ "${FAKE_FAIL_REGISTRY_REPLACE:-0}" -eq 1 ] && [ "${2:-}" = "${FAKE_FAIL_REGISTRY_PATH:-}" ]; then exit 77; fi'
    printf '%s\n' 'exec "$FAKE_REAL_MV" "$@"'
  } > "$failure_bin/mv"
  chmod 755 "$failure_bin/mv"
  before_failure_record=$(cksum < "$record_path")
  before_failure_config=$(cksum < "$default_config")
  : > "$FAKE_PODMAN_LOG"
  set +e
  rollback_output=$(env PATH="$failure_bin:$PATH" FAKE_REAL_MV="$real_mv" \
    FAKE_FAIL_REGISTRY_REPLACE=1 FAKE_FAIL_REGISTRY_PATH="$default_config" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true' \
    FAKE_CONNECTION_LIST="$fake_connections" FAKE_DARWIN_PROJECTION_STATE=current \
    FAKE_DARWIN_APPLY_RESULT=changed \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile redirect remove --all --detach 2>&1)
  rollback_status=$?
  set -e
  [ "$rollback_status" -ne 0 ] || fail_test 'failed Darwin detach transaction unexpectedly succeeded'
  assert_contains "$rollback_output" 'prior projection and record restored'
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh --username root shimmy-default /bin/sh -s -- detach'
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh --username root shimmy-default /bin/sh -s -- apply'
  assert_equals "$(cksum < "$record_path")" "$before_failure_record"
  assert_equals "$(cksum < "$default_config")" "$before_failure_config"
  pass 'Darwin active edits require restart and detach handles exact, stopped, missing-machine, foreign, and rollback state'
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
  test_commands_profile_linux_registry_activation_and_edit
  test_commands_profile_linux_detach_refuses_sibling
  test_commands_profile_darwin_projection_edit_and_detach
}
