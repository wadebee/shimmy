#!/bin/sh

test_commands_management_guidance() {
  setup_scenario_with_profiles default
  help_output=$(default_shimmy)
  assert_contains "$help_output" 'shimmy <command> [options]'
  assert_contains "$help_output" 'install    Add tool shims to this profile.'
  assert_contains "$help_output" 'images     Verify configured remote image indexes and upstream drift.'
  assert_contains "$help_output" 'uninstall  Remove this profile, or explicitly remove all Shimmy-owned state.'
  assert_contains "$help_output" 'netinfo    Show host, VM, and container network perspectives.'
  assert_contains "$help_output" 'skills     Install, update, uninstall, or export Shimmy agent skills.'
  assert_contains "$help_output" 'status     Show installed shims, versions, and profile details.'
  assert_contains "$help_output" 'test       Validate this profile with non-mutating shim smoke commands.'
  assert_contains "$help_output" 'update     Refresh this profile and optionally pull or build tool images.'
  assert_contains "$help_output" 'shimmy install --shim jq'
  assert_not_contains "$help_output" 'activate'
  assert_contains "$help_output" "Run 'shimmy <command> --help' for command-specific options."
  assert_not_contains "$help_output" '<install|uninstall|activate|netinfo|skills|status|test|update>'

  explicit_help_output=$(default_shimmy help)
  assert_equals "$explicit_help_output" "$help_output"

  profile_manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")

  for command_name in catalog images install uninstall netinfo skills status test update; do
    command_help=$(default_shimmy "$command_name" --help)
    assert_contains "$command_help" 'Usage:'
    assert_contains "$command_help" 'Examples:'
    case "$command_name" in
      catalog|images|skills) assert_contains "$command_help" 'Commands:' ;;
      *) assert_contains "$command_help" 'Options:' ;;
    esac
  done

  catalog_help=$(default_shimmy catalog)
  assert_contains "$catalog_help" 'Commands:'
  assert_contains "$catalog_help" 'list      List every tool in a resolved named catalog.'
  assert_contains "$catalog_help" 'publish   Publish clean committed upstream content'
  assert_contains "$catalog_help" "Run 'shimmy catalog <command> --help'"
  assert_equals "$(default_shimmy catalog --help)" "$catalog_help"

  images_help=$(default_shimmy images)
  assert_contains "$images_help" 'Commands:'
  assert_contains "$images_help" 'verify  Validate configured image indexes'
  assert_contains "$images_help" "Run 'shimmy images verify --help'"
  assert_equals "$(default_shimmy images --help)" "$images_help"

  skills_help=$(default_shimmy skills)
  assert_contains "$skills_help" 'Commands:'
  assert_contains "$skills_help" 'install    Install selected or profile-derived skills'
  assert_contains "$skills_help" "Run 'shimmy skills <command> --help'"
  assert_equals "$(default_shimmy skills --help)" "$skills_help"

  for command_path in \
    'catalog list' \
    'catalog publish' \
    'catalog rollback' \
    'catalog rebind' \
    'images verify' \
    'skills install' \
    'skills update' \
    'skills uninstall'
  do
    set -- $command_path
    action_help=$(default_shimmy "$@" --help)
    assert_contains "$action_help" 'Usage:'
    assert_contains "$action_help" 'Options:'
    assert_contains "$action_help" 'Examples:'
  done

  assert_contains "$(default_shimmy catalog list --help)" '--name <catalog>'
  assert_contains "$(default_shimmy catalog list --help)" '--format human|manifest'
  assert_contains "$(default_shimmy catalog publish --help)" 'Run this command from the upstream profile.'
  assert_contains "$(default_shimmy catalog rollback --help)" 'A valid retained prior default'
  assert_contains "$(default_shimmy catalog rebind --help)" '--checkout <path>'
  assert_contains "$(default_shimmy images verify --help)" '--require-current-upstream'
  assert_contains "$(default_shimmy skills install --help)" '--export <path>'
  assert_contains "$(default_shimmy skills update --help)" 'prefers skills already tracked'
  assert_contains "$(default_shimmy skills uninstall --help)" '.shimmy-skills-manifest.txt'
  assert_contains "$(default_shimmy uninstall --help)" 'shimmy uninstall [--global]'
  assert_not_contains "$(default_shimmy uninstall --help)" '--shim <tool'

  set +e
  catalog_profile_error=$(default_shimmy catalog publish 2>&1)
  catalog_profile_status=$?
  set -e
  [ "$catalog_profile_status" -ne 0 ] || fail_test 'default profile unexpectedly published the catalog'
  assert_contains "$catalog_profile_error" "Run 'shimmy catalog publish --help' for requirements"
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$profile_manifest_checksum"
  pass "every second- and third-level management command exposes usage, options, and examples without mutation"
}

test_commands_management_profile_binding() {
  setup_scenario_with_profiles default upstream

  default_manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  upstream_manifest_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")
  default_catalog=$(default_shimmy catalog list --format manifest)
  upstream_catalog=$(upstream_shimmy catalog list --format manifest)
  default_named_upstream=$(default_shimmy catalog list --name upstream --format manifest)
  upstream_named_default=$(upstream_shimmy catalog list --format manifest --name default)
  assert_contains "$default_catalog" 'shimmy_catalog_name=default'
  assert_contains "$upstream_catalog" 'shimmy_catalog_name=upstream'
  assert_contains "$default_named_upstream" 'shimmy_catalog_name=upstream'
  assert_contains "$upstream_named_default" 'shimmy_catalog_name=default'
  assert_equals "$(printf '%s\n' "$default_named_upstream" | sed -n 's/^shimmy_catalog_tool=//p')" "$(printf '%s\n' "$upstream_catalog" | sed -n 's/^shimmy_catalog_tool=//p')"
  assert_equals "$(printf '%s\n' "$upstream_named_default" | sed -n 's/^shimmy_catalog_tool=//p')" "$(printf '%s\n' "$default_catalog" | sed -n 's/^shimmy_catalog_tool=//p')"
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$default_manifest_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" "$upstream_manifest_checksum"

  set +e
  error_output=$(default_shimmy status --profile upstream 2>&1)
  error_status=$?
  set -e
  [ "$error_status" -ne 0 ] || fail_test "installed status unexpectedly accepted --profile"
  assert_contains "$error_output" 'unknown argument: --profile'

  for command_name in catalog images install netinfo skills status test uninstall update; do
    set +e
    bound_output=$(default_shimmy "$command_name" --profile upstream 2>&1)
    bound_status=$?
    set -e
    [ "$bound_status" -ne 0 ] || fail_test "installed $command_name unexpectedly accepted --profile"
    assert_contains "$bound_output" 'unknown argument: --profile'
  done

  set +e
  missing_catalog_output=$(default_shimmy catalog list --name missing 2>&1)
  missing_catalog_status=$?
  set -e
  [ "$missing_catalog_status" -ne 0 ] || fail_test 'catalog list unexpectedly accepted a missing named catalog'
  assert_contains "$missing_catalog_output" 'missing catalog registry entry:'

  netinfo_output=$(run_in_repo ./commands/netinfo.sh --host-ip 192.0.2.10 --host-prefix 24 --format manifest)
  assert_contains "$netinfo_output" 'host_lan=192.0.2.0/24'
  pass "every installed management command remains profile-bound"
}

test_commands_management_run() {
  test_commands_management_guidance
  test_commands_management_profile_binding
}
