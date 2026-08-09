#!/bin/sh

test_commands_install_run() {
  setup_scenario
  mkdir -p "$DEFAULT_PROFILE_ROOT"
  printf '%s\n' unmanaged > "$DEFAULT_PROFILE_ROOT/sentinel"
  set +e
  unmanaged_output=$(bootstrap_default --shim jq 2>&1)
  unmanaged_status=$?
  set -e
  [ "$unmanaged_status" -ne 0 ] || fail_test "unmanaged profile root unexpectedly accepted"
  assert_contains "$unmanaged_output" 'non-empty unmanaged profile root'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/sentinel"

  setup_scenario
  legacy_dir=$SCENARIO_DIR/legacy-override
  run_in_repo env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_INSTALL_DIR="$legacy_dir" SHIMMY_CONTROL_INSTALL_DIR="$legacy_dir" SHIMMY_UPSTREAM_DIR="$legacy_dir" ./install.sh --profile default --shim jq --no-startup --no-skills >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_path_not_exists "$legacy_dir"

  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/bin/unmanaged"
  bootstrap_default --shim task >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/unmanaged"
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/task"

  setup_scenario
  run_in_repo env -u XDG_CONFIG_HOME HOME="$HOME_DIR" ./install.sh --shim jq --no-startup --no-skills >/dev/null
  assert_file_exists "$HOME_DIR/.config/shimmy/profiles/default/bin/shimmy"

  setup_scenario
  run_in_repo env XDG_CONFIG_HOME= HOME="$HOME_DIR" ./install.sh --shim jq --no-startup --no-skills >/dev/null
  assert_file_exists "$HOME_DIR/.config/shimmy/profiles/default/bin/shimmy"

  setup_scenario
  mkdir -p "$XDG_CONFIG_HOME_DIR/shimmy"
  printf '%s\n' 'shimmy_install_manifest_version=2' > "$XDG_CONFIG_HOME_DIR/shimmy/install-manifest.txt"
  set +e
  version_two_output=$(bootstrap_default --shim jq 2>&1)
  version_two_status=$?
  set -e
  [ "$version_two_status" -ne 0 ] || fail_test "version-2 shared manifest unexpectedly accepted"
  assert_contains "$version_two_output" 'version-2 Shimmy installation detected'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  pass "installer enforces XDG resolution, rejects unmanaged roots and v2, ignores retired variables, and preserves siblings"
}
