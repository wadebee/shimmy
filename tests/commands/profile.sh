#!/bin/sh

test_profile_named_create() {
  test_profile_create_name=$1
  test_profile_create_root=$TEST_SHIM_CONFIG/profiles/$test_profile_create_name
  test_fixture_tree_copy "$TEST_SHIM_PROFILE_ROOT" "$test_profile_create_root"
  shimmy_profile_manifest_render "$test_profile_create_name" https://example.invalid/shimmy.git \
    "$TEST_SHIM_PINNED_COMMIT" \
    "default|$TEST_SHIM_PINNED_GENERATION|$TEST_SHIM_PINNED_COMMIT|$TEST_SHIM_PINNED_FINGERPRINT" '' '' \
    > "$test_profile_create_root/install-manifest.txt"
  shimmy_shim_bundle_input_render "$test_profile_create_name" "$TEST_SHIM_PINNED_GENERATION" \
    "$TEST_SHIM_PINNED_FINGERPRINT" '' > "$test_profile_create_root/config/shim-bundle-input.conf"
  rm -rf "$test_profile_create_root/ai-skills/control" "$test_profile_create_root/ai-skills/shims"
  shimmy_ai_skill_control_bundle_materialize "$TEST_SHIM_CHECKOUT" "$TEST_SHIM_PINNED_COMMIT" \
    "$test_profile_create_name" "$test_profile_create_root/ai-skills/control" || fail_test 'unable to create named control bundle fixture'
  shimmy_ai_skill_shims_bundle_materialize "$test_profile_create_root/config/shim-bundle-input.conf" \
    "$TEST_SHIM_PINNED_ROOT" "$test_profile_create_root/ai-skills/shims" || fail_test 'unable to create named shims bundle fixture'
  shimmy_registries_config_render "$test_profile_create_name" '' > "$test_profile_create_root/registries.conf"
  shimmy_profile_launcher_render "$TEST_SHIM_CONFIG" "$test_profile_create_name" > "$test_profile_create_root/bin/shimmy"
  shimmy_profile_shell_init_render "$TEST_SHIM_CONFIG" "$test_profile_create_name" > "$test_profile_create_root/shell-init.sh"
  chmod 0755 "$test_profile_create_root/bin/shimmy"
  chmod 0644 "$test_profile_create_root/install-manifest.txt" \
    "$test_profile_create_root/config/shim-bundle-input.conf" "$test_profile_create_root/registries.conf" \
    "$test_profile_create_root/shell-init.sh"
  shimmy_profile_candidate_resolve "$TEST_SHIM_CONFIG" "$test_profile_create_name" ||
    fail_test "named profile fixture is invalid: $SHIMMY_PROFILE_ERROR"
}

test_profile_fixture_setup() {
  test_shim_fixture_setup
  TEST_PROFILE_TEAM=team-one
  TEST_PROFILE_TEAM_ROOT=$TEST_SHIM_CONFIG/profiles/$TEST_PROFILE_TEAM
  TEST_PROFILE_CONFIG_HOME=$(dirname -- "$TEST_SHIM_CONFIG")
  TEST_PROFILE_ACTIVE_LINK=$TEST_PROFILE_CONFIG_HOME/containers/registries.conf.d/shimmy-active-profile.conf
  TEST_PROFILE_PODMAN=$SCENARIO_DIR/podman
  TEST_PROFILE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$TEST_PROFILE_PODMAN"
  : > "$TEST_PROFILE_PODMAN_LOG"
  test_profile_named_create "$TEST_PROFILE_TEAM"
}

test_profile_linux_active_prepare() {
  mkdir -p "$(dirname -- "$TEST_PROFILE_ACTIVE_LINK")"
  ln -s "$TEST_SHIM_PROFILE_ROOT/registries.conf" "$TEST_PROFILE_ACTIVE_LINK"
}

test_profile_state_reset_default() {
  shimmy_active_profile_render default "$SCENARIO_DIR/home/.agents/skills" > "$TEST_SHIM_CONFIG/active-profile.conf"
  chmod 0644 "$TEST_SHIM_CONFIG/active-profile.conf"
  if [ -L "$TEST_PROFILE_ACTIVE_LINK" ]; then rm -f "$TEST_PROFILE_ACTIVE_LINK"; fi
  [ ! -e "$TEST_PROFILE_ACTIVE_LINK" ] || fail_test 'foreign active-link state reached profile reset'
  test_profile_linux_active_prepare
  while IFS= read -r test_profile_reset_name; do
    [ -n "$test_profile_reset_name" ] || continue
    test_profile_reset_path=$SCENARIO_DIR/home/.agents/skills/$test_profile_reset_name
    [ ! -L "$test_profile_reset_path" ] || rm -f "$test_profile_reset_path"
  done <<EOF
$TEST_SHIM_CONTROL_NAMES
shimmy-tool-stale
EOF
  rm -f "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt" "$TEST_PROFILE_TEAM_ROOT/machine-projection.txt"
  : > "$TEST_PROFILE_PODMAN_LOG"
}

test_profile_run() {
  test_profile_run_invoking=$1
  shift
  env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TEST_PROFILE_CONFIG_HOME" \
    SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" SHIMMY_INVOKING_PROFILE="$test_profile_run_invoking" \
    SHIMMY_TEST_PROFILE_OS="${TEST_PROFILE_OS:-Linux}" SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_PROFILE_PODMAN" \
    FAKE_PODMAN_LOG="$TEST_PROFILE_PODMAN_LOG" FAKE_ACTIVE_LINK="$TEST_PROFILE_ACTIVE_LINK" \
    FAKE_ACTIVE_CONFIG="$TEST_SHIM_PROFILE_ROOT/registries.conf" FAKE_LINUX_INFO="${TEST_PROFILE_LINUX_INFO:-true|false}" \
    FAKE_MACHINE_LIST="${TEST_PROFILE_MACHINE_LIST:-}" FAKE_CONNECTION_LIST="${TEST_PROFILE_CONNECTION_LIST:-}" \
    FAKE_WORKLOADS="${TEST_PROFILE_WORKLOADS:-}" FAKE_DARWIN_INFO="${TEST_PROFILE_DARWIN_INFO:-true|true}" \
    FAKE_DARWIN_PROJECTION_STATE="${TEST_PROFILE_PROJECTION_STATE:-current}" \
    FAKE_FAIL_ACTION="${TEST_PROFILE_FAIL_ACTION:-}" FAKE_ROLLBACK_FAIL="${TEST_PROFILE_ROLLBACK_FAIL:-}" \
    FAKE_PRIOR_MACHINE="${TEST_PROFILE_PRIOR_MACHINE:-}" FAKE_TARGET_MACHINE="${TEST_PROFILE_TARGET_MACHINE:-}" \
    FAKE_PRIOR_DEFAULT="${TEST_PROFILE_PRIOR_DEFAULT:-}" \
    "$ROOT_DIR/commands/profile.sh" "$@"
}

test_commands_profile_identity_status_and_redirect() {
  test_profile_state_reset_default
  test_profile_list=$(test_profile_run default list --format manifest)
  assert_contains "$test_profile_list" 'shimmy_profile=default|yes|'
  assert_contains "$test_profile_list" 'shimmy_profile=team-one|no|'
  assert_contains "$test_profile_list" '|valid'
  test_profile_status=$(test_profile_run "$TEST_PROFILE_TEAM" status --format manifest)
  assert_contains "$test_profile_status" 'shimmy_profile_name=team-one'
  assert_contains "$test_profile_status" 'shimmy_profile_active=no'
  assert_contains "$test_profile_status" 'shimmy_engine_activation=ready'
  assert_contains "$test_profile_status" 'shimmy_profile_ai_skill_links=control|not-applicable|not-applicable'
  shimmy_profile_engine_context_resolve "$TEST_SHIM_CONFIG" "$TEST_PROFILE_TEAM"
  test_profile_status_human=$(test_profile_run "$TEST_PROFILE_TEAM" status)
  assert_contains "$test_profile_status_human" 'CATALOG PINNED CURRENT DRIFT HEALTH'
  assert_contains "$test_profile_status_human" 'SHIM DEFAULT MODE VERSIONS'
  assert_contains "$test_profile_status_human" 'BUNDLE STATUS LINKS REASON'

  team_registry_before=$(cksum < "$TEST_PROFILE_TEAM_ROOT/registries.conf")
  test_profile_active_link_before=$(readlink "$TEST_PROFILE_ACTIVE_LINK")
  test_profile_run "$TEST_PROFILE_TEAM" redirect set \
    --prefix docker.io --location registry.example.invalid/team >/dev/null
  [ "$(cksum < "$TEST_PROFILE_TEAM_ROOT/registries.conf")" != "$team_registry_before" ] ||
    fail_test 'inactive invoking profile did not update its source policy'
  assert_equals "$(readlink "$TEST_PROFILE_ACTIVE_LINK")" "$test_profile_active_link_before"
  test_profile_run default redirect set --prefix docker.io --location registry.example.invalid/docker
  assert_file_contains "$TEST_SHIM_PROFILE_ROOT/registries.conf" 'location = "registry.example.invalid/docker"'
  assert_contains "$(test_profile_run default redirect list --format manifest)" \
    'shimmy_profile_redirect=docker.io|registry.example.invalid/docker'
  pass 'safe arbitrary profiles list and report local state while inactive redirect mutation changes only its source policy'
}

test_commands_profile_linux_activation_and_rollback() {
  test_profile_state_reset_default
  test_profile_dry_run=$(test_profile_run default activate "$TEST_PROFILE_TEAM" --dry-run)
  assert_contains "$test_profile_dry_run" "would_target=$TEST_PROFILE_TEAM_ROOT/registries.conf"
  assert_contains "$test_profile_dry_run" 'would_activate_profile=team-one'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TEST_SHIM_CONFIG/active-profile.conf")" default
  assert_equals "$(readlink "$TEST_PROFILE_ACTIVE_LINK")" "$TEST_SHIM_PROFILE_ROOT/registries.conf"

  test_profile_activation=$(test_profile_run default activate "$TEST_PROFILE_TEAM")
  assert_contains "$test_profile_activation" 'Activated Shimmy profile team-one.'
  assert_contains "$test_profile_activation" \
    "Select it in the current shell with: . '$TEST_PROFILE_TEAM_ROOT/shell-init.sh'"
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TEST_SHIM_CONFIG/active-profile.conf")" team-one
  assert_equals "$(readlink "$TEST_PROFILE_ACTIVE_LINK")" "$TEST_PROFILE_TEAM_ROOT/registries.conf"
  assert_equals "$(readlink "$SCENARIO_DIR/home/.agents/skills/$TEST_SHIM_CONTROL_NAME")" \
    "$TEST_PROFILE_TEAM_ROOT/ai-skills/control/skills/$TEST_SHIM_CONTROL_NAME"

  set +e
  test_profile_rollback=$(env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TEST_PROFILE_CONFIG_HOME" \
    SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" SHIMMY_INVOKING_PROFILE=team-one \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_PROFILE_PODMAN" \
    SHIMMY_TEST_MODE=1 SHIMMY_TEST_PROFILE_FAILURE=after-active-record \
    FAKE_PODMAN_LOG="$TEST_PROFILE_PODMAN_LOG" FAKE_ACTIVE_LINK="$TEST_PROFILE_ACTIVE_LINK" \
    FAKE_ACTIVE_CONFIG="$TEST_PROFILE_TEAM_ROOT/registries.conf" FAKE_LINUX_INFO=true\|false \
    "$ROOT_DIR/commands/profile.sh" activate default 2>&1)
  test_profile_rollback_status=$?
  set -e
  [ "$test_profile_rollback_status" -ne 0 ] || fail_test 'injected activation failure unexpectedly succeeded'
  assert_contains "$test_profile_rollback" 'Rollback result: complete'
  assert_contains "$test_profile_rollback" 'Linux active registry link restored'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TEST_SHIM_CONFIG/active-profile.conf")" team-one
  assert_equals "$(readlink "$TEST_PROFILE_ACTIVE_LINK")" "$TEST_PROFILE_TEAM_ROOT/registries.conf"
  assert_equals "$(readlink "$SCENARIO_DIR/home/.agents/skills/$TEST_SHIM_CONTROL_NAME")" \
    "$TEST_PROFILE_TEAM_ROOT/ai-skills/control/skills/$TEST_SHIM_CONTROL_NAME"
  pass 'Linux profile activation commits engine authority before active record and links and restores all three on failure'
}

test_commands_profile_linux_recorded_active_recovery() {
  test_profile_state_reset_default
  TEST_PROFILE_OS=Linux
  TEST_PROFILE_LINUX_INFO='true|false'
  rm -f "$TEST_PROFILE_ACTIVE_LINK"

  test_profile_recovery=$(test_profile_run default activate default)
  assert_contains "$test_profile_recovery" 'Activated Shimmy profile default.'
  assert_path_symlink "$TEST_PROFILE_ACTIVE_LINK"
  assert_equals "$(readlink "$TEST_PROFILE_ACTIVE_LINK")" "$TEST_SHIM_PROFILE_ROOT/registries.conf"
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TEST_SHIM_CONFIG/active-profile.conf")" default
  assert_equals "$(readlink "$SCENARIO_DIR/home/.agents/skills/$TEST_SHIM_CONTROL_NAME")" \
    "$TEST_SHIM_PROFILE_ROOT/ai-skills/control/skills/$TEST_SHIM_CONTROL_NAME"
  pass 'Linux recorded-active recovery restores its exact managed registry link through ordinary activation'
}

test_commands_profile_darwin_recorded_active_recovery() {
  test_profile_state_reset_default
  TEST_PROFILE_OS=Darwin
  TEST_PROFILE_MACHINE_LIST='shimmy-default|false'
  TEST_PROFILE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
other|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  TEST_PROFILE_PRIOR_MACHINE=
  TEST_PROFILE_TARGET_MACHINE=shimmy-default
  TEST_PROFILE_PRIOR_DEFAULT=other
  TEST_PROFILE_WORKLOADS=
  TEST_PROFILE_PROJECTION_STATE=absent
  TEST_PROFILE_FAIL_ACTION=
  TEST_PROFILE_ROLLBACK_FAIL=

  test_profile_active_before=$(cksum < "$TEST_SHIM_CONFIG/active-profile.conf")
  test_profile_dry_run=$(test_profile_run default activate default --dry-run)
  assert_contains "$test_profile_dry_run" 'would_start=shimmy-default'
  assert_contains "$test_profile_dry_run" 'would_project=/etc/containers/registries.conf.d/shimmy-profile.conf'
  assert_contains "$test_profile_dry_run" "would_record=$TEST_SHIM_PROFILE_ROOT/machine-projection.txt"
  assert_contains "$test_profile_dry_run" 'would_set_default_connection=shimmy-default'
  assert_contains "$test_profile_dry_run" 'would_activate_profile=default'
  test_profile_dry_run_log=$(cat "$TEST_PROFILE_PODMAN_LOG")
  assert_not_contains "$test_profile_dry_run_log" 'machine stop '
  assert_not_contains "$test_profile_dry_run_log" 'machine start '
  assert_not_contains "$test_profile_dry_run_log" 'system connection default '
  assert_not_contains "$test_profile_dry_run_log" ' /bin/sh -s -- apply '
  assert_equals "$(cksum < "$TEST_SHIM_CONFIG/active-profile.conf")" "$test_profile_active_before"
  assert_path_not_exists "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt"
  assert_path_not_exists "$SCENARIO_DIR/home/.agents/skills/$TEST_SHIM_CONTROL_NAME"

  : > "$TEST_PROFILE_PODMAN_LOG"
  test_profile_recovery=$(test_profile_run default activate default)
  assert_contains "$test_profile_recovery" 'Activated Shimmy profile default.'
  test_profile_recovery_log=$(cat "$TEST_PROFILE_PODMAN_LOG")
  assert_contains "$test_profile_recovery_log" 'machine start shimmy-default'
  assert_contains "$test_profile_recovery_log" 'system connection default shimmy-default'
  test_profile_start_line=$(sed -n '/^machine start shimmy-default$/=' "$TEST_PROFILE_PODMAN_LOG")
  test_profile_projection_line=$(sed -n '/^machine ssh shimmy-default \/bin\/sh -s -- projection /=' "$TEST_PROFILE_PODMAN_LOG" | tail -n 1)
  test_profile_validate_line=$(sed -n '/^--connection shimmy-default info /=' "$TEST_PROFILE_PODMAN_LOG" | tail -n 1)
  test_profile_default_line=$(sed -n '/^system connection default shimmy-default$/=' "$TEST_PROFILE_PODMAN_LOG")
  [ "$test_profile_start_line" -lt "$test_profile_projection_line" ] &&
    [ "$test_profile_projection_line" -lt "$test_profile_validate_line" ] &&
    [ "$test_profile_validate_line" -lt "$test_profile_default_line" ] ||
    fail_test 'same-profile stopped recovery ordering is invalid'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TEST_SHIM_CONFIG/active-profile.conf")" default
  assert_regular_file_not_symlink "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt"
  shimmy_registries_machine_projection_record_validate \
    "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt" default ||
    fail_test 'same-profile stopped recovery did not record registry projection ownership'
  assert_equals "$(readlink "$SCENARIO_DIR/home/.agents/skills/$TEST_SHIM_CONTROL_NAME")" \
    "$TEST_SHIM_PROFILE_ROOT/ai-skills/control/skills/$TEST_SHIM_CONTROL_NAME"

  test_profile_state_reset_default
  TEST_PROFILE_FAIL_ACTION=test_validation
  test_profile_active_before=$(cksum < "$TEST_SHIM_CONFIG/active-profile.conf")
  set +e
  test_profile_validation_failure=$(test_profile_run default activate default 2>&1)
  test_profile_validation_failure_status=$?
  set -e
  [ "$test_profile_validation_failure_status" -ne 0 ] ||
    fail_test 'same-profile post-start validation failure unexpectedly succeeded'
  assert_contains "$test_profile_validation_failure" 'Rollback: target cleanup succeeded for shimmy-default'
  assert_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine start shimmy-default'
  assert_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine stop shimmy-default'
  assert_equals "$(cksum < "$TEST_SHIM_CONFIG/active-profile.conf")" "$test_profile_active_before"
  assert_path_not_exists "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt"
  assert_path_not_exists "$SCENARIO_DIR/home/.agents/skills/$TEST_SHIM_CONTROL_NAME"

  test_profile_state_reset_default
  TEST_PROFILE_MACHINE_LIST='shimmy-default|true'
  TEST_PROFILE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  TEST_PROFILE_PRIOR_MACHINE=shimmy-default
  TEST_PROFILE_PRIOR_DEFAULT=shimmy-default
  TEST_PROFILE_PROJECTION_STATE=current
  TEST_PROFILE_FAIL_ACTION=
  SHIMMY_CONFIG_ROOT=$TEST_SHIM_CONFIG \
    shimmy_registries_machine_projection_record_render default 0-0 \
      > "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt"
  chmod 0644 "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt"
  set +e
  test_profile_restart_required=$(test_profile_run default activate default 2>&1)
  test_profile_restart_required_status=$?
  set -e
  [ "$test_profile_restart_required_status" -ne 0 ] ||
    fail_test 'stale same-profile registry projection unexpectedly passed ordinary activation'
  assert_contains "$test_profile_restart_required" \
    "'$TEST_SHIM_PROFILE_ROOT/bin/shimmy' profile activate default --restart"
  assert_not_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine stop shimmy-default'

  : > "$TEST_PROFILE_PODMAN_LOG"
  test_profile_run default activate default --restart >/dev/null
  assert_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine stop shimmy-default'
  assert_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine start shimmy-default'
  shimmy_registries_machine_projection_record_validate \
    "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt" default ||
    fail_test 'same-profile restart did not refresh registry projection ownership'
  pass 'Darwin recorded-active recovery plans without mutation, starts and validates in order, rolls back failed starts, and retains explicit stale-projection restart'
}

test_commands_profile_bundle_policy() {
  test_profile_state_reset_default
  test_profile_control_bundle=$TEST_PROFILE_TEAM_ROOT/ai-skills/control/bundle.conf
  cp "$test_profile_control_bundle" "$test_profile_control_bundle.saved"
  printf 'malformed=1\n' >> "$test_profile_control_bundle"
  set +e
  test_profile_malformed=$(test_profile_run default activate "$TEST_PROFILE_TEAM" 2>&1)
  test_profile_malformed_status=$?
  set -e
  [ "$test_profile_malformed_status" -ne 0 ] || fail_test 'malformed supported bundle activated'
  assert_contains "$test_profile_malformed" 'supported AI-skill bundle consistency validation failed'
  assert_not_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine stop '
  assert_not_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine start '
  assert_not_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'system connection default '
  mv "$test_profile_control_bundle.saved" "$test_profile_control_bundle"

  test_profile_shims_bundle=$TEST_PROFILE_TEAM_ROOT/ai-skills/shims/bundle.conf
  sed 's/^shimmy_ai_skill_bundle_schema=1$/shimmy_ai_skill_bundle_schema=2/' \
    "$test_profile_shims_bundle" > "$test_profile_shims_bundle.tmp"
  mv "$test_profile_shims_bundle.tmp" "$test_profile_shims_bundle"
  test_profile_stale_source=$TEST_SHIM_PROFILE_ROOT/ai-skills/shims/skills/shimmy-tool-stale
  ln -s "$test_profile_stale_source" "$SCENARIO_DIR/home/.agents/skills/shimmy-tool-stale"
  test_profile_unsupported=$(test_profile_run default activate "$TEST_PROFILE_TEAM" 2>&1)
  assert_contains "$test_profile_unsupported" 'skipping unsupported shims AI-skill bundle'
  assert_path_not_exists "$SCENARIO_DIR/home/.agents/skills/shimmy-tool-stale"
  assert_path_symlink "$SCENARIO_DIR/home/.agents/skills/$TEST_SHIM_CONTROL_NAME"
  pass 'malformed supported bundles block before engine mutation while unsupported bundles warn, skip, and clean prior-kind links'
}

test_commands_profile_darwin_activation() {
  test_profile_state_reset_default
  TEST_PROFILE_OS=Darwin
  TEST_PROFILE_MACHINE_LIST='shimmy-default|true
shimmy-team-one|false'
  TEST_PROFILE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-team-one|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'
  TEST_PROFILE_PRIOR_MACHINE=shimmy-default
  TEST_PROFILE_TARGET_MACHINE=shimmy-team-one
  TEST_PROFILE_PRIOR_DEFAULT=shimmy-default
  test_profile_default_fingerprint=$(shimmy_registries_config_fingerprint_render "$TEST_SHIM_PROFILE_ROOT/registries.conf")
  SHIMMY_CONFIG_ROOT=$TEST_SHIM_CONFIG \
  shimmy_registries_machine_projection_record_render default "$test_profile_default_fingerprint" \
      > "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt"
  chmod 0644 "$TEST_SHIM_PROFILE_ROOT/machine-projection.txt"

  TEST_PROFILE_WORKLOADS='abc123|important'
  set +e
  test_profile_guard=$(test_profile_run default activate team-one 2>&1)
  test_profile_guard_status=$?
  set -e
  [ "$test_profile_guard_status" -ne 0 ] || fail_test 'unacknowledged profile workload switch succeeded'
  assert_contains "$test_profile_guard" 'abc123|important'
  assert_not_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine stop shimmy-default'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TEST_SHIM_CONFIG/active-profile.conf")" default

  : > "$TEST_PROFILE_PODMAN_LOG"
  test_profile_run default activate team-one --stop-running >/dev/null
  test_profile_darwin_log=$(cat "$TEST_PROFILE_PODMAN_LOG")
  assert_contains "$test_profile_darwin_log" 'machine stop shimmy-default'
  assert_contains "$test_profile_darwin_log" 'machine start shimmy-team-one'
  assert_contains "$test_profile_darwin_log" 'system connection default shimmy-team-one'
  test_profile_darwin_projection_line=$(sed -n '/^machine ssh shimmy-team-one \/bin\/sh -s -- projection /=' "$TEST_PROFILE_PODMAN_LOG" | tail -n 1)
  test_profile_darwin_validate_line=$(sed -n '/^--connection shimmy-team-one info /=' "$TEST_PROFILE_PODMAN_LOG" | tail -n 1)
  test_profile_darwin_default_line=$(sed -n '/^system connection default shimmy-team-one$/=' "$TEST_PROFILE_PODMAN_LOG")
  [ "$test_profile_darwin_projection_line" -lt "$test_profile_darwin_validate_line" ] &&
    [ "$test_profile_darwin_validate_line" -lt "$test_profile_darwin_default_line" ] ||
    fail_test 'Darwin profile activation ordering is invalid'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TEST_SHIM_CONFIG/active-profile.conf")" team-one
  assert_regular_file_not_symlink "$TEST_PROFILE_TEAM_ROOT/machine-projection.txt"

  : > "$TEST_PROFILE_PODMAN_LOG"
  TEST_PROFILE_MACHINE_LIST='shimmy-default|false
shimmy-team-one|true'
  TEST_PROFILE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
shimmy-team-one|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  TEST_PROFILE_PRIOR_MACHINE=shimmy-team-one
  TEST_PROFILE_TARGET_MACHINE=shimmy-team-one
  TEST_PROFILE_PRIOR_DEFAULT=shimmy-team-one
  TEST_PROFILE_WORKLOADS=
  test_profile_run team-one activate team-one --restart >/dev/null
  assert_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine stop shimmy-team-one'
  assert_contains "$(cat "$TEST_PROFILE_PODMAN_LOG")" 'machine start shimmy-team-one'
  pass 'Darwin arbitrary-profile activation guards workloads and preserves ordinary, restart, projection, validation, and connection ordering'
}

test_commands_profile_shell_selection() {
  test_profile_state_reset_default
  test_profile_shell_output=$(env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TEST_PROFILE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_PROFILE_PODMAN" \
    FAKE_PODMAN_LOG="$TEST_PROFILE_PODMAN_LOG" FAKE_ACTIVE_LINK="$TEST_PROFILE_ACTIVE_LINK" \
    FAKE_ACTIVE_CONFIG="$TEST_SHIM_PROFILE_ROOT/registries.conf" FAKE_LINUX_INFO=true\|false \
    TEST_DEFAULT_SHELL="$TEST_SHIM_PROFILE_ROOT/shell-init.sh" TEST_TEAM_BIN="$TEST_PROFILE_TEAM_ROOT/bin" \
    TEST_DEFAULT_BIN="$TEST_SHIM_PROFILE_ROOT/bin" /bin/sh -c '
      PATH=$TEST_DEFAULT_BIN:/usr/bin:$TEST_TEAM_BIN:/bin:$TEST_DEFAULT_BIN
      . "$TEST_DEFAULT_SHELL"
      selected_before=$(command -v shimmy)
      selected_path_before=$PATH
      shimmy profile activate team-one --dry-run >/dev/null
      printf "dry_same=%s\n" "$([ "$PATH" = "$selected_path_before" ] && printf yes || printf no)"
      shimmy profile activate missing-profile >/dev/null 2>&1
      failure_status=$?
      printf "failure_status=%s\nfailure_same=%s\n" "$failure_status" "$([ "$PATH" = "$selected_path_before" ] && printf yes || printf no)"
      shimmy profile activate team-one >/dev/null
      printf "selected=%s\npath=%s\nprior_function=%s\n" "$(command -v shimmy)" "$PATH" "$selected_before"
      printf "team_launcher=%s\n" "$(shimmy profile status --format manifest | sed -n "s/^shimmy_profile_name=//p")"
      [ "$selected_path_before" != "$PATH" ]
    ')
  assert_contains "$test_profile_shell_output" 'dry_same=yes'
  assert_contains "$test_profile_shell_output" 'failure_status=1'
  assert_contains "$test_profile_shell_output" 'failure_same=yes'
  assert_contains "$test_profile_shell_output" 'selected=shimmy'
  assert_contains "$test_profile_shell_output" "path=$TEST_PROFILE_TEAM_ROOT/bin:/usr/bin:/bin"
  assert_contains "$test_profile_shell_output" 'team_launcher=team-one'
  assert_contains "$test_profile_shell_output" 'prior_function=shimmy'

  test_profile_default_shell_status=$(env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TEST_PROFILE_CONFIG_HOME" \
    TEST_SHELL_INIT="$TEST_SHIM_PROFILE_ROOT/shell-init.sh" /bin/sh -c \
    '. "$TEST_SHELL_INIT"; shimmy profile status --format manifest')
  assert_contains "$test_profile_default_shell_status" 'shimmy_profile_name=default'
  assert_contains "$test_profile_default_shell_status" 'shimmy_profile_active=no'
  test_profile_team_shell_status=$(env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TEST_PROFILE_CONFIG_HOME" \
    TEST_SHELL_INIT="$TEST_PROFILE_TEAM_ROOT/shell-init.sh" /bin/sh -c \
    '. "$TEST_SHELL_INIT"; shimmy profile status --format manifest')
  assert_contains "$test_profile_team_shell_status" 'shimmy_profile_name=team-one'
  assert_contains "$test_profile_team_shell_status" 'shimmy_profile_active=yes'
  assert_contains "$test_profile_team_shell_status" 'shimmy_profile_ai_skill_links=control|'

  for test_profile_shell in /bin/bash /bin/zsh; do
    [ -x "$test_profile_shell" ] || continue
    env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TEST_PROFILE_CONFIG_HOME" \
      TEST_SHELL_INIT="$TEST_PROFILE_TEAM_ROOT/shell-init.sh" TEST_TEAM_BIN="$TEST_PROFILE_TEAM_ROOT/bin" \
      "$test_profile_shell" -c '. "$TEST_SHELL_INIT"; [ "$(command -v shimmy)" = shimmy ]; case "$PATH" in "$TEST_TEAM_BIN"*) ;; *) exit 1 ;; esac'
  done
  pass 'supported sourced shells defer exclusive PATH/function switching until successful non-dry-run activation'
}

test_commands_profile_run() {
  test_profile_fixture_setup
  test_commands_profile_identity_status_and_redirect
  test_commands_profile_linux_activation_and_rollback
  test_commands_profile_linux_recorded_active_recovery
  test_commands_profile_bundle_policy
  test_commands_profile_darwin_recorded_active_recovery
  test_commands_profile_darwin_activation
  test_commands_profile_shell_selection
}
