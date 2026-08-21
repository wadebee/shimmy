#!/bin/sh

test_target_profile_named_create() {
  test_target_profile_create_name=$1
  test_target_profile_create_root=$TARGET_SHIM_CONFIG/profiles/$test_target_profile_create_name
  test_fixture_tree_copy "$TARGET_SHIM_PROFILE_ROOT" "$test_target_profile_create_root"
  shimmy_target_profile_manifest_render "$test_target_profile_create_name" https://example.invalid/shimmy.git \
    "$TARGET_SHIM_PINNED_COMMIT" \
    "default|$TARGET_SHIM_PINNED_GENERATION|$TARGET_SHIM_PINNED_COMMIT|$TARGET_SHIM_PINNED_FINGERPRINT" '' '' \
    > "$test_target_profile_create_root/install-manifest.txt"
  shimmy_target_shim_bundle_input_render "$test_target_profile_create_name" "$TARGET_SHIM_PINNED_GENERATION" \
    "$TARGET_SHIM_PINNED_FINGERPRINT" '' > "$test_target_profile_create_root/config/shim-bundle-input.conf"
  rm -rf "$test_target_profile_create_root/ai-skills/control" "$test_target_profile_create_root/ai-skills/shims"
  shimmy_target_ai_skill_control_bundle_materialize "$TARGET_SHIM_CHECKOUT" "$TARGET_SHIM_PINNED_COMMIT" \
    "$test_target_profile_create_name" "$test_target_profile_create_root/ai-skills/control" || fail_test 'unable to create named control bundle fixture'
  shimmy_target_ai_skill_shims_bundle_materialize "$test_target_profile_create_root/config/shim-bundle-input.conf" \
    "$TARGET_SHIM_PINNED_ROOT" "$test_target_profile_create_root/ai-skills/shims" || fail_test 'unable to create named shims bundle fixture'
  shimmy_registries_config_render "$test_target_profile_create_name" '' > "$test_target_profile_create_root/registries.conf"
  shimmy_target_profile_launcher_render "$TARGET_SHIM_CONFIG" "$test_target_profile_create_name" > "$test_target_profile_create_root/bin/shimmy"
  shimmy_target_profile_shell_init_render "$TARGET_SHIM_CONFIG" "$test_target_profile_create_name" > "$test_target_profile_create_root/shell-init.sh"
  chmod 0755 "$test_target_profile_create_root/bin/shimmy"
  chmod 0644 "$test_target_profile_create_root/install-manifest.txt" \
    "$test_target_profile_create_root/config/shim-bundle-input.conf" "$test_target_profile_create_root/registries.conf" \
    "$test_target_profile_create_root/shell-init.sh"
  shimmy_target_profile_candidate_resolve "$TARGET_SHIM_CONFIG" "$test_target_profile_create_name" ||
    fail_test "named profile fixture is invalid: $SHIMMY_TARGET_PROFILE_ERROR"
}

test_target_profile_fixture_setup() {
  test_target_shim_fixture_setup
  TARGET_PROFILE_TEAM=team-one
  TARGET_PROFILE_TEAM_ROOT=$TARGET_SHIM_CONFIG/profiles/$TARGET_PROFILE_TEAM
  TARGET_PROFILE_CONFIG_HOME=$(dirname -- "$TARGET_SHIM_CONFIG")
  TARGET_PROFILE_ACTIVE_LINK=$TARGET_PROFILE_CONFIG_HOME/containers/registries.conf.d/shimmy-active-profile.conf
  TARGET_PROFILE_PODMAN=$SCENARIO_DIR/podman
  TARGET_PROFILE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$TARGET_PROFILE_PODMAN"
  : > "$TARGET_PROFILE_PODMAN_LOG"
  test_target_profile_named_create "$TARGET_PROFILE_TEAM"
}

test_target_profile_linux_active_prepare() {
  mkdir -p "$(dirname -- "$TARGET_PROFILE_ACTIVE_LINK")"
  ln -s "$TARGET_SHIM_PROFILE_ROOT/registries.conf" "$TARGET_PROFILE_ACTIVE_LINK"
}

test_target_profile_state_reset_default() {
  shimmy_target_active_profile_render default "$SCENARIO_DIR/home/.agents/skills" > "$TARGET_SHIM_CONFIG/active-profile.conf"
  chmod 0644 "$TARGET_SHIM_CONFIG/active-profile.conf"
  if [ -L "$TARGET_PROFILE_ACTIVE_LINK" ]; then rm -f "$TARGET_PROFILE_ACTIVE_LINK"; fi
  [ ! -e "$TARGET_PROFILE_ACTIVE_LINK" ] || fail_test 'foreign active-link state reached target profile reset'
  test_target_profile_linux_active_prepare
  for test_target_profile_reset_name in $(shimmy_target_ai_skill_control_names_render) shimmy-tool-stale; do
    test_target_profile_reset_path=$SCENARIO_DIR/home/.agents/skills/$test_target_profile_reset_name
    [ ! -L "$test_target_profile_reset_path" ] || rm -f "$test_target_profile_reset_path"
  done
  rm -f "$TARGET_SHIM_PROFILE_ROOT/machine-projection.txt" "$TARGET_PROFILE_TEAM_ROOT/machine-projection.txt"
  : > "$TARGET_PROFILE_PODMAN_LOG"
}

test_target_profile_run() {
  test_target_profile_run_invoking=$1
  shift
  env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TARGET_PROFILE_CONFIG_HOME" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" SHIMMY_TARGET_INVOKING_PROFILE="$test_target_profile_run_invoking" \
    SHIMMY_TEST_PROFILE_OS="${TARGET_PROFILE_OS:-Linux}" SHIMMY_TEST_PROFILE_PODMAN_BIN="$TARGET_PROFILE_PODMAN" \
    FAKE_PODMAN_LOG="$TARGET_PROFILE_PODMAN_LOG" FAKE_ACTIVE_LINK="$TARGET_PROFILE_ACTIVE_LINK" \
    FAKE_ACTIVE_CONFIG="$TARGET_SHIM_PROFILE_ROOT/registries.conf" FAKE_LINUX_INFO="${TARGET_PROFILE_LINUX_INFO:-true|false}" \
    FAKE_MACHINE_LIST="${TARGET_PROFILE_MACHINE_LIST:-}" FAKE_CONNECTION_LIST="${TARGET_PROFILE_CONNECTION_LIST:-}" \
    FAKE_WORKLOADS="${TARGET_PROFILE_WORKLOADS:-}" FAKE_DARWIN_INFO="${TARGET_PROFILE_DARWIN_INFO:-true|true}" \
    FAKE_DARWIN_PROJECTION_STATE="${TARGET_PROFILE_PROJECTION_STATE:-current}" \
    FAKE_FAIL_ACTION="${TARGET_PROFILE_FAIL_ACTION:-}" FAKE_ROLLBACK_FAIL="${TARGET_PROFILE_ROLLBACK_FAIL:-}" \
    FAKE_PRIOR_MACHINE="${TARGET_PROFILE_PRIOR_MACHINE:-}" FAKE_TARGET_MACHINE="${TARGET_PROFILE_TARGET_MACHINE:-}" \
    FAKE_PRIOR_DEFAULT="${TARGET_PROFILE_PRIOR_DEFAULT:-}" \
    "$ROOT_DIR/commands/profile.sh" "$@"
}

test_commands_target_profile_identity_status_and_redirect() {
  test_target_profile_state_reset_default
  target_profile_list=$(test_target_profile_run default list --format manifest)
  assert_contains "$target_profile_list" 'shimmy_profile=default|yes|'
  assert_contains "$target_profile_list" 'shimmy_profile=team-one|no|'
  assert_contains "$target_profile_list" '|valid'
  target_profile_status=$(test_target_profile_run "$TARGET_PROFILE_TEAM" status --format manifest)
  assert_contains "$target_profile_status" 'shimmy_profile_name=team-one'
  assert_contains "$target_profile_status" 'shimmy_profile_active=no'
  assert_contains "$target_profile_status" 'shimmy_engine_activation=ready'
  assert_contains "$target_profile_status" 'shimmy_profile_ai_skill_links=control|not-applicable|not-applicable'
  shimmy_target_profile_engine_context_resolve "$TARGET_SHIM_CONFIG" "$TARGET_PROFILE_TEAM"
  target_profile_status_human=$(test_target_profile_run "$TARGET_PROFILE_TEAM" status)
  assert_contains "$target_profile_status_human" 'CATALOG PINNED CURRENT DRIFT HEALTH'
  assert_contains "$target_profile_status_human" 'SHIM DEFAULT MODE VERSIONS'
  assert_contains "$target_profile_status_human" 'BUNDLE STATUS LINKS REASON'

  team_registry_before=$(cksum < "$TARGET_PROFILE_TEAM_ROOT/registries.conf")
  set +e
  target_profile_inactive_redirect=$(test_target_profile_run "$TARGET_PROFILE_TEAM" redirect set \
    --prefix docker.io --location registry.example.invalid/docker 2>&1)
  target_profile_inactive_status=$?
  set -e
  [ "$target_profile_inactive_status" -ne 0 ] || fail_test 'inactive invoking profile changed redirects'
  assert_contains "$target_profile_inactive_redirect" 'requires the active invoking profile'
  assert_equals "$(cksum < "$TARGET_PROFILE_TEAM_ROOT/registries.conf")" "$team_registry_before"
  test_target_profile_run default redirect set --prefix docker.io --location registry.example.invalid/docker
  assert_file_contains "$TARGET_SHIM_PROFILE_ROOT/registries.conf" 'location = "registry.example.invalid/docker"'
  assert_contains "$(test_target_profile_run default redirect list --format manifest)" \
    'shimmy_profile_redirect=docker.io|registry.example.invalid/docker'
  pass 'safe arbitrary profiles list and report local state while redirect mutation remains active-only'
}

test_commands_target_profile_linux_activation_and_rollback() {
  test_target_profile_state_reset_default
  target_profile_dry_run=$(test_target_profile_run default activate "$TARGET_PROFILE_TEAM" --dry-run)
  assert_contains "$target_profile_dry_run" "would_target=$TARGET_PROFILE_TEAM_ROOT/registries.conf"
  assert_contains "$target_profile_dry_run" 'would_activate_profile=team-one'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TARGET_SHIM_CONFIG/active-profile.conf")" default
  assert_equals "$(readlink "$TARGET_PROFILE_ACTIVE_LINK")" "$TARGET_SHIM_PROFILE_ROOT/registries.conf"

  target_profile_activation=$(test_target_profile_run default activate "$TARGET_PROFILE_TEAM")
  assert_contains "$target_profile_activation" 'Activated Shimmy profile team-one.'
  assert_contains "$target_profile_activation" \
    "Select it in the current shell with: . '$TARGET_PROFILE_TEAM_ROOT/shell-init.sh'"
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TARGET_SHIM_CONFIG/active-profile.conf")" team-one
  assert_equals "$(readlink "$TARGET_PROFILE_ACTIVE_LINK")" "$TARGET_PROFILE_TEAM_ROOT/registries.conf"
  assert_equals "$(readlink "$SCENARIO_DIR/home/.agents/skills/shimmy-catalog")" \
    "$TARGET_PROFILE_TEAM_ROOT/ai-skills/control/skills/shimmy-catalog"

  set +e
  target_profile_rollback=$(env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TARGET_PROFILE_CONFIG_HOME" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" SHIMMY_TARGET_INVOKING_PROFILE=team-one \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TARGET_PROFILE_PODMAN" \
    SHIMMY_TARGET_TEST_MODE=1 SHIMMY_TARGET_TEST_PROFILE_FAILURE=after-active-record \
    FAKE_PODMAN_LOG="$TARGET_PROFILE_PODMAN_LOG" FAKE_ACTIVE_LINK="$TARGET_PROFILE_ACTIVE_LINK" \
    FAKE_ACTIVE_CONFIG="$TARGET_PROFILE_TEAM_ROOT/registries.conf" FAKE_LINUX_INFO=true\|false \
    "$ROOT_DIR/commands/profile.sh" activate default 2>&1)
  target_profile_rollback_status=$?
  set -e
  [ "$target_profile_rollback_status" -ne 0 ] || fail_test 'injected activation failure unexpectedly succeeded'
  assert_contains "$target_profile_rollback" 'Rollback result: complete'
  assert_contains "$target_profile_rollback" 'Linux active registry link restored'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TARGET_SHIM_CONFIG/active-profile.conf")" team-one
  assert_equals "$(readlink "$TARGET_PROFILE_ACTIVE_LINK")" "$TARGET_PROFILE_TEAM_ROOT/registries.conf"
  assert_equals "$(readlink "$SCENARIO_DIR/home/.agents/skills/shimmy-catalog")" \
    "$TARGET_PROFILE_TEAM_ROOT/ai-skills/control/skills/shimmy-catalog"
  pass 'Linux target activation commits engine authority before active record and links and restores all three on failure'
}

test_commands_target_profile_bundle_policy() {
  test_target_profile_state_reset_default
  target_profile_control_bundle=$TARGET_PROFILE_TEAM_ROOT/ai-skills/control/bundle.conf
  cp "$target_profile_control_bundle" "$target_profile_control_bundle.saved"
  printf 'malformed=1\n' >> "$target_profile_control_bundle"
  set +e
  target_profile_malformed=$(test_target_profile_run default activate "$TARGET_PROFILE_TEAM" 2>&1)
  target_profile_malformed_status=$?
  set -e
  [ "$target_profile_malformed_status" -ne 0 ] || fail_test 'malformed supported bundle activated'
  assert_contains "$target_profile_malformed" 'supported target AI-skill bundle consistency validation failed'
  assert_not_contains "$(cat "$TARGET_PROFILE_PODMAN_LOG")" 'machine stop '
  assert_not_contains "$(cat "$TARGET_PROFILE_PODMAN_LOG")" 'machine start '
  assert_not_contains "$(cat "$TARGET_PROFILE_PODMAN_LOG")" 'system connection default '
  mv "$target_profile_control_bundle.saved" "$target_profile_control_bundle"

  target_profile_shims_bundle=$TARGET_PROFILE_TEAM_ROOT/ai-skills/shims/bundle.conf
  sed 's/^shimmy_ai_skill_bundle_schema=1$/shimmy_ai_skill_bundle_schema=2/' \
    "$target_profile_shims_bundle" > "$target_profile_shims_bundle.tmp"
  mv "$target_profile_shims_bundle.tmp" "$target_profile_shims_bundle"
  target_profile_stale_source=$TARGET_SHIM_PROFILE_ROOT/ai-skills/shims/skills/shimmy-tool-stale
  ln -s "$target_profile_stale_source" "$SCENARIO_DIR/home/.agents/skills/shimmy-tool-stale"
  target_profile_unsupported=$(test_target_profile_run default activate "$TARGET_PROFILE_TEAM" 2>&1)
  assert_contains "$target_profile_unsupported" 'skipping unsupported shims AI-skill bundle'
  assert_path_not_exists "$SCENARIO_DIR/home/.agents/skills/shimmy-tool-stale"
  assert_path_symlink "$SCENARIO_DIR/home/.agents/skills/shimmy-catalog"
  pass 'malformed supported bundles block before engine mutation while unsupported bundles warn, skip, and clean prior-kind links'
}

test_commands_target_profile_darwin_activation() {
  test_target_profile_state_reset_default
  TARGET_PROFILE_OS=Darwin
  TARGET_PROFILE_MACHINE_LIST='shimmy-default|true
shimmy-team-one|false'
  TARGET_PROFILE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-team-one|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'
  TARGET_PROFILE_PRIOR_MACHINE=shimmy-default
  TARGET_PROFILE_TARGET_MACHINE=shimmy-team-one
  TARGET_PROFILE_PRIOR_DEFAULT=shimmy-default
  target_profile_default_fingerprint=$(shimmy_registries_config_fingerprint_render "$TARGET_SHIM_PROFILE_ROOT/registries.conf")
  SHIMMY_CONFIG_ROOT=$TARGET_SHIM_CONFIG \
  shimmy_registries_machine_projection_record_render default "$target_profile_default_fingerprint" \
      > "$TARGET_SHIM_PROFILE_ROOT/machine-projection.txt"
  chmod 0644 "$TARGET_SHIM_PROFILE_ROOT/machine-projection.txt"

  TARGET_PROFILE_WORKLOADS='abc123|important'
  set +e
  target_profile_guard=$(test_target_profile_run default activate team-one 2>&1)
  target_profile_guard_status=$?
  set -e
  [ "$target_profile_guard_status" -ne 0 ] || fail_test 'unacknowledged target-profile workload switch succeeded'
  assert_contains "$target_profile_guard" 'abc123|important'
  assert_not_contains "$(cat "$TARGET_PROFILE_PODMAN_LOG")" 'machine stop shimmy-default'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TARGET_SHIM_CONFIG/active-profile.conf")" default

  : > "$TARGET_PROFILE_PODMAN_LOG"
  test_target_profile_run default activate team-one --stop-running >/dev/null
  target_profile_darwin_log=$(cat "$TARGET_PROFILE_PODMAN_LOG")
  assert_contains "$target_profile_darwin_log" 'machine stop shimmy-default'
  assert_contains "$target_profile_darwin_log" 'machine start shimmy-team-one'
  assert_contains "$target_profile_darwin_log" 'system connection default shimmy-team-one'
  target_profile_darwin_projection_line=$(sed -n '/^machine ssh shimmy-team-one \/bin\/sh -s -- projection /=' "$TARGET_PROFILE_PODMAN_LOG" | tail -n 1)
  target_profile_darwin_validate_line=$(sed -n '/^--connection shimmy-team-one info /=' "$TARGET_PROFILE_PODMAN_LOG" | tail -n 1)
  target_profile_darwin_default_line=$(sed -n '/^system connection default shimmy-team-one$/=' "$TARGET_PROFILE_PODMAN_LOG")
  [ "$target_profile_darwin_projection_line" -lt "$target_profile_darwin_validate_line" ] &&
    [ "$target_profile_darwin_validate_line" -lt "$target_profile_darwin_default_line" ] ||
    fail_test 'Darwin target activation ordering is invalid'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TARGET_SHIM_CONFIG/active-profile.conf")" team-one
  assert_regular_file_not_symlink "$TARGET_PROFILE_TEAM_ROOT/machine-projection.txt"

  : > "$TARGET_PROFILE_PODMAN_LOG"
  TARGET_PROFILE_MACHINE_LIST='shimmy-default|false
shimmy-team-one|true'
  TARGET_PROFILE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
shimmy-team-one|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  TARGET_PROFILE_PRIOR_MACHINE=shimmy-team-one
  TARGET_PROFILE_TARGET_MACHINE=shimmy-team-one
  TARGET_PROFILE_PRIOR_DEFAULT=shimmy-team-one
  TARGET_PROFILE_WORKLOADS=
  test_target_profile_run team-one activate team-one --restart >/dev/null
  assert_contains "$(cat "$TARGET_PROFILE_PODMAN_LOG")" 'machine stop shimmy-team-one'
  assert_contains "$(cat "$TARGET_PROFILE_PODMAN_LOG")" 'machine start shimmy-team-one'
  pass 'Darwin arbitrary-profile activation guards workloads and preserves ordinary, restart, projection, validation, and connection ordering'
}

test_commands_target_profile_shell_selection() {
  test_target_profile_state_reset_default
  target_profile_shell_output=$(env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TARGET_PROFILE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TARGET_PROFILE_PODMAN" \
    FAKE_PODMAN_LOG="$TARGET_PROFILE_PODMAN_LOG" FAKE_ACTIVE_LINK="$TARGET_PROFILE_ACTIVE_LINK" \
    FAKE_ACTIVE_CONFIG="$TARGET_SHIM_PROFILE_ROOT/registries.conf" FAKE_LINUX_INFO=true\|false \
    TEST_DEFAULT_SHELL="$TARGET_SHIM_PROFILE_ROOT/shell-init.sh" TEST_TEAM_BIN="$TARGET_PROFILE_TEAM_ROOT/bin" \
    TEST_DEFAULT_BIN="$TARGET_SHIM_PROFILE_ROOT/bin" /bin/sh -c '
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
  assert_contains "$target_profile_shell_output" 'dry_same=yes'
  assert_contains "$target_profile_shell_output" 'failure_status=1'
  assert_contains "$target_profile_shell_output" 'failure_same=yes'
  assert_contains "$target_profile_shell_output" 'selected=shimmy'
  assert_contains "$target_profile_shell_output" "path=$TARGET_PROFILE_TEAM_ROOT/bin:/usr/bin:/bin"
  assert_contains "$target_profile_shell_output" 'team_launcher=team-one'
  assert_contains "$target_profile_shell_output" 'prior_function=shimmy'

  target_profile_default_shell_status=$(env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TARGET_PROFILE_CONFIG_HOME" \
    TEST_SHELL_INIT="$TARGET_SHIM_PROFILE_ROOT/shell-init.sh" /bin/sh -c \
    '. "$TEST_SHELL_INIT"; shimmy profile status --format manifest')
  assert_contains "$target_profile_default_shell_status" 'shimmy_profile_name=default'
  assert_contains "$target_profile_default_shell_status" 'shimmy_profile_active=no'
  target_profile_team_shell_status=$(env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TARGET_PROFILE_CONFIG_HOME" \
    TEST_SHELL_INIT="$TARGET_PROFILE_TEAM_ROOT/shell-init.sh" /bin/sh -c \
    '. "$TEST_SHELL_INIT"; shimmy profile status --format manifest')
  assert_contains "$target_profile_team_shell_status" 'shimmy_profile_name=team-one'
  assert_contains "$target_profile_team_shell_status" 'shimmy_profile_active=yes'
  assert_contains "$target_profile_team_shell_status" 'shimmy_profile_ai_skill_links=control|'

  for target_profile_shell in /bin/bash /bin/zsh; do
    [ -x "$target_profile_shell" ] || continue
    env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$TARGET_PROFILE_CONFIG_HOME" \
      TEST_SHELL_INIT="$TARGET_PROFILE_TEAM_ROOT/shell-init.sh" TEST_TEAM_BIN="$TARGET_PROFILE_TEAM_ROOT/bin" \
      "$target_profile_shell" -c '. "$TEST_SHELL_INIT"; [ "$(command -v shimmy)" = shimmy ]; case "$PATH" in "$TEST_TEAM_BIN"*) ;; *) exit 1 ;; esac'
  done
  pass 'supported sourced shells defer exclusive PATH/function switching until successful non-dry-run activation'
}

test_commands_target_profile_run() {
  test_target_profile_fixture_setup
  test_commands_target_profile_identity_status_and_redirect
  test_commands_target_profile_linux_activation_and_rollback
  test_commands_target_profile_bundle_policy
  test_commands_target_profile_darwin_activation
  test_commands_target_profile_shell_selection
}
