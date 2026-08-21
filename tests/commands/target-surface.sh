#!/bin/sh

test_target_surface_fixture_setup() {
  setup_scenario
  TARGET_SURFACE_CONFIG=$SCENARIO_DIR/config/shimmy
  TARGET_SURFACE_PROFILE=$TARGET_SURFACE_CONFIG/profiles/default
  TARGET_SURFACE_LAUNCHER=$TARGET_SURFACE_PROFILE/bin/shimmy
  mkdir -p "$TARGET_SURFACE_PROFILE/bin" "$TARGET_SURFACE_PROFILE/commands"
  cp "$ROOT_DIR/commands/help-target.sh" "$TARGET_SURFACE_PROFILE/commands/help-target.sh"
  chmod 0755 "$TARGET_SURFACE_PROFILE/commands/help-target.sh"
  shimmy_target_profile_launcher_render "$TARGET_SURFACE_CONFIG" default > "$TARGET_SURFACE_LAUNCHER"
  chmod 0755 "$TARGET_SURFACE_LAUNCHER"
  printf '%s\n' 'damaged-manifest-for-help-ordering' > "$TARGET_SURFACE_PROFILE/install-manifest.txt"
}

test_target_surface_help_run() {
  env HOME="$SCENARIO_DIR/home" XDG_CONFIG_HOME="$SCENARIO_DIR/config" \
    "$TARGET_SURFACE_LAUNCHER" "$@"
}

test_commands_target_surface_help_before_state() {
  test_target_surface_fixture_setup

  target_surface_root=$(test_target_surface_help_run)
  assert_equals "$(test_target_surface_help_run help)" "$target_surface_root"
  assert_equals "$(test_target_surface_help_run --help)" "$target_surface_root"
  assert_contains "$target_surface_root" 'shimmy <group> <command> [options]'
  assert_contains "$target_surface_root" 'Human-readable output is the default'
  assert_contains "$target_surface_root" 'Scope:'
  assert_contains "$target_surface_root" 'Overwrite warning:'
  assert_contains "$target_surface_root" 'without backup or recovery'
  assert_contains "$target_surface_root" 'Remediation:'
  assert_contains "$target_surface_root" 'profile activate <name> --dry-run'

  for target_surface_group in admin profile catalog shim ai-skill; do
    target_surface_group_help=$(test_target_surface_help_run "$target_surface_group")
    assert_equals "$(test_target_surface_help_run "$target_surface_group" --help)" \
      "$target_surface_group_help"
    assert_contains "$target_surface_group_help" 'Usage:'
    assert_contains "$target_surface_group_help" 'Commands:'
    assert_contains "$target_surface_group_help" 'Scope:'
    assert_contains "$target_surface_group_help" 'Remediation:'
  done
  target_surface_redirect_help=$(test_target_surface_help_run profile redirect)
  assert_equals "$(test_target_surface_help_run profile redirect --help)" \
    "$target_surface_redirect_help"
  assert_contains "$target_surface_redirect_help" 'Commands:'

  while IFS='|' read -r target_surface_path target_surface_usage; do
    [ -n "$target_surface_path" ] || continue
    set -- $target_surface_path
    target_surface_action_help=$(test_target_surface_help_run "$@" --help)
    assert_contains "$target_surface_action_help" "$target_surface_usage"
    assert_contains "$target_surface_action_help" 'Scope:'
    assert_contains "$target_surface_action_help" 'Options:'
    assert_contains "$target_surface_action_help" 'Defaults:'
    assert_contains "$target_surface_action_help" 'Remediation:'
    assert_contains "$target_surface_action_help" 'Examples:'
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

  assert_not_contains "$target_surface_root" 'shimmy images'
  assert_not_contains "$target_surface_root" 'shimmy install'
  assert_not_contains "$target_surface_root" 'shimmy skills'
  assert_not_contains "$(test_target_surface_help_run catalog --help)" 'shimmy catalog add'
  assert_not_contains "$(test_target_surface_help_run catalog --help)" 'shimmy catalog sync'
  assert_not_contains "$(test_target_surface_help_run shim --help)" '<catalog>/'

  set +e
  target_surface_state_output=$(test_target_surface_help_run profile status 2>&1)
  target_surface_state_status=$?
  set -e
  [ "$target_surface_state_status" -ne 0 ] ||
    fail_test 'target launcher accepted damaged state after rendering help'
  assert_contains "$target_surface_state_output" 'target profile manifest identity is invalid'
  pass 'target root, group, subgroup, and action help is complete and precedes installed-state validation'
}

test_commands_target_surface_assets() {
  test_target_surface_fixture_setup
  assert_file_executable "$ROOT_DIR/commands/help-target.sh"
  assert_file_executable "$TARGET_SURFACE_PROFILE/commands/help-target.sh"
  assert_file_executable "$TARGET_SURFACE_LAUNCHER"
  /bin/sh -n "$ROOT_DIR/commands/help-target.sh"
  /bin/sh -n "$TARGET_SURFACE_PROFILE/commands/help-target.sh"
  /bin/sh -n "$TARGET_SURFACE_LAUNCHER"
  shimmy_target_profile_launcher_validate "$TARGET_SURFACE_LAUNCHER" \
    "$TARGET_SURFACE_CONFIG" default || fail_test 'rendered target launcher failed byte validation'
  pass 'source and rendered target surface assets retain executable modes, POSIX syntax, and exact bytes'
}

test_commands_target_surface_run() {
  test_commands_target_surface_help_before_state
  test_commands_target_surface_assets
}
