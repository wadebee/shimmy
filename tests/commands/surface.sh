#!/bin/sh

test_surface_fixture_setup() {
  setup_scenario
  TEST_SURFACE_CONFIG=$SCENARIO_DIR/config/shimmy
  TEST_SURFACE_PROFILE=$TEST_SURFACE_CONFIG/profiles/default
  TEST_SURFACE_LAUNCHER=$TEST_SURFACE_PROFILE/bin/shimmy
  mkdir -p "$TEST_SURFACE_PROFILE/bin" "$TEST_SURFACE_PROFILE/commands"
  cp "$ROOT_DIR/commands/help.sh" "$TEST_SURFACE_PROFILE/commands/help.sh"
  chmod 0755 "$TEST_SURFACE_PROFILE/commands/help.sh"
  shimmy_profile_launcher_render "$TEST_SURFACE_CONFIG" default > "$TEST_SURFACE_LAUNCHER"
  chmod 0755 "$TEST_SURFACE_LAUNCHER"
  printf '%s\n' 'damaged-manifest-for-help-ordering' > "$TEST_SURFACE_PROFILE/install-manifest.txt"
}

test_surface_help_run() {
  env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$SCENARIO_DIR/config" \
    "$TEST_SURFACE_LAUNCHER" "$@"
}

test_commands_surface_help_before_state() {
  test_surface_fixture_setup

  test_surface_root=$(test_surface_help_run)
  assert_equals "$(test_surface_help_run help)" "$test_surface_root"
  assert_equals "$(test_surface_help_run --help)" "$test_surface_root"
  assert_contains "$test_surface_root" 'shimmy <group> <command> [options]'
  assert_contains "$test_surface_root" 'Human-readable output is the default'
  assert_contains "$test_surface_root" 'Scope:'
  assert_contains "$test_surface_root" 'Overwrite warning:'
  assert_contains "$test_surface_root" 'without backup or recovery'
  assert_contains "$test_surface_root" 'Remediation:'
  assert_contains "$test_surface_root" 'profile activate <name> --dry-run'

  for test_surface_group in admin profile catalog shim ai-skill; do
    test_surface_group_help=$(test_surface_help_run "$test_surface_group")
    assert_equals "$(test_surface_help_run "$test_surface_group" --help)" \
      "$test_surface_group_help"
    assert_contains "$test_surface_group_help" 'Usage:'
    assert_contains "$test_surface_group_help" 'Commands:'
    assert_contains "$test_surface_group_help" 'Scope:'
    assert_contains "$test_surface_group_help" 'Remediation:'
  done
  test_surface_redirect_help=$(test_surface_help_run profile redirect)
  assert_equals "$(test_surface_help_run profile redirect --help)" \
    "$test_surface_redirect_help"
  assert_contains "$test_surface_redirect_help" 'Commands:'

  while IFS='|' read -r test_surface_path test_surface_usage; do
    [ -n "$test_surface_path" ] || continue
    set -- $test_surface_path
    test_surface_action_help=$(test_surface_help_run "$@" --help)
    assert_contains "$test_surface_action_help" "$test_surface_usage"
    assert_contains "$test_surface_action_help" 'Scope:'
    assert_contains "$test_surface_action_help" 'Options:'
    assert_contains "$test_surface_action_help" 'Defaults:'
    assert_contains "$test_surface_action_help" 'Remediation:'
    assert_contains "$test_surface_action_help" 'Examples:'
  done <<'EOF'
admin status|shimmy admin status [--format human|manifest]
admin network|shimmy admin network [--target <host-or-ip> ...]
admin uninstall|shimmy admin uninstall [--stop-running]
profile list|shimmy profile list [--format human|manifest]
profile status|shimmy profile status [--format human|manifest]
profile create|shimmy profile create <name> [--restart] [--stop-running] [--dry-run]
profile activate|shimmy profile activate <name> [--restart] [--stop-running] [--dry-run]
profile sync|shimmy profile sync
profile repair-startup|shimmy profile repair-startup
profile delete|shimmy profile delete <name> [--stop-running]
profile redirect list|shimmy profile redirect list [--format human|manifest]
profile redirect set|shimmy profile redirect set --prefix <logical> --location <physical> [--dry-run]
profile redirect delete|shimmy profile redirect delete (--prefix <logical> | --all)
catalog status|shimmy catalog status [--format human|manifest]
catalog tools|shimmy catalog tools [--generation <id>] [--format human|manifest]
catalog verify|shimmy catalog verify [--tool <tool[@version]> ...]
catalog publish|shimmy catalog publish
catalog rollback|shimmy catalog rollback
shim list|shimmy shim list [--format human|manifest]
shim add|shimmy shim add <tool[@version]>
shim remove|shimmy shim remove <tool[@version]>
shim set-version|shimmy shim set-version <tool@version>
shim sync|shimmy shim sync [<tool[@version]> ...]
shim test|shimmy shim test [<tool[@version]> ...]
ai-skill list|shimmy ai-skill list [--format human|manifest]
ai-skill repair|shimmy ai-skill repair
EOF

  set +e
  test_surface_state_output=$(test_surface_help_run profile status 2>&1)
  test_surface_state_status=$?
  set -e
  [ "$test_surface_state_status" -ne 0 ] ||
    fail_test 'rendered launcher accepted damaged state after rendering help'
  assert_contains "$test_surface_state_output" 'profile manifest identity is invalid'
  pass 'root, group, subgroup, and action help is complete and precedes installed-state validation'
}

test_commands_surface_assets() {
  test_surface_fixture_setup
  assert_file_executable "$ROOT_DIR/commands/help.sh"
  assert_file_executable "$TEST_SURFACE_PROFILE/commands/help.sh"
  assert_file_executable "$TEST_SURFACE_LAUNCHER"
  /bin/sh -n "$ROOT_DIR/commands/help.sh"
  /bin/sh -n "$TEST_SURFACE_PROFILE/commands/help.sh"
  /bin/sh -n "$TEST_SURFACE_LAUNCHER"
  shimmy_profile_launcher_validate "$TEST_SURFACE_LAUNCHER" \
    "$TEST_SURFACE_CONFIG" default || fail_test 'rendered launcher failed byte validation'
  pass 'source and rendered surface assets retain executable modes, POSIX syntax, and exact bytes'
}

test_commands_surface_run() {
  test_commands_surface_help_before_state
  test_commands_surface_assets
}
