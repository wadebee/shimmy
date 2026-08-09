#!/bin/sh

test_commands_install_run() {
  setup_scenario
  mkdir -p "$DEFAULT_PROFILE_ROOT"
  printf '%s\n' unmanaged > "$DEFAULT_PROFILE_ROOT/sentinel"
  set +e
  unmanaged_output=$(bootstrap_default 2>&1)
  unmanaged_status=$?
  set -e
  [ "$unmanaged_status" -ne 0 ] || fail_test "unmanaged profile root unexpectedly accepted"
  assert_contains "$unmanaged_output" 'non-empty unmanaged profile root'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/sentinel"

  for claimed_path in shell-init.sh install-manifest.txt bin bin/shimmy bin/jq commands config implementations lib plugins tests tools agent; do
    for collision_type in file directory symlink; do
      setup_scenario
      collision_path=$DEFAULT_PROFILE_ROOT/$claimed_path
      mkdir -p "$(dirname -- "$collision_path")"
      case "$collision_type" in
        file) printf '%s\n' keep > "$collision_path" ;;
        directory) mkdir -p "$collision_path" ;;
        symlink) ln -s "$SCENARIO_DIR/missing-target" "$collision_path" ;;
      esac
      set +e
      collision_output=$(bootstrap_default 2>&1)
      collision_status=$?
      set -e
      [ "$collision_status" -ne 0 ] || fail_test "$collision_type collision unexpectedly accepted at $claimed_path"
      case "$claimed_path:$collision_type" in
        install-manifest.txt:file|install-manifest.txt:symlink) assert_contains "$collision_output" 'invalid or unsupported Shimmy profile manifest' ;;
        *) assert_contains "$collision_output" 'non-empty unmanaged profile root' ;;
      esac
      [ -e "$collision_path" ] || [ -L "$collision_path" ] || fail_test "collision was mutated at $claimed_path"
    done
  done
  pass "fresh install rejects file, directory, and symlink collisions for every claimed profile asset"

  for symlink_parent in shimmy shimmy/profiles shimmy/profiles/default; do
    setup_scenario
    symlink_path=$XDG_CONFIG_HOME_DIR/$symlink_parent
    mkdir -p "$(dirname -- "$symlink_path")" "$SCENARIO_DIR/symlink-target"
    ln -s "$SCENARIO_DIR/symlink-target" "$symlink_path"
    set +e
    symlink_output=$(bootstrap_default 2>&1)
    symlink_status=$?
    set -e
    [ "$symlink_status" -ne 0 ] || fail_test "symlinked canonical parent unexpectedly accepted: $symlink_parent"
    assert_contains "$symlink_output" 'unable to resolve canonical Shimmy profile'
    assert_path_not_exists "$SCENARIO_DIR/symlink-target/bin/shimmy"
  done
  pass "canonical config, profiles, and profile roots reject symlink traversal"

  setup_scenario
  legacy_dir=$SCENARIO_DIR/legacy-override
  run_in_repo env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_INSTALL_DIR="$legacy_dir" SHIMMY_CONTROL_INSTALL_DIR="$legacy_dir" SHIMMY_UPSTREAM_DIR="$legacy_dir" ./install.sh --profile default --no-startup >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_path_not_exists "$legacy_dir"
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/bin/unmanaged"
  default_shimmy install --shim task --no-startup >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/unmanaged"
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/task"

  setup_scenario
  set +e
  removed_option_output=$(bootstrap_default --install-dir "$SCENARIO_DIR/legacy" 2>&1)
  removed_option_status=$?
  set -e
  [ "$removed_option_status" -ne 0 ] || fail_test "removed --install-dir option unexpectedly succeeded"
  assert_contains "$removed_option_output" 'unknown argument: --install-dir'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_path_not_exists "$SCENARIO_DIR/legacy"

  setup_scenario
  run_in_repo env -u XDG_CONFIG_HOME HOME="$HOME_DIR" ./install.sh --no-startup >/dev/null
  assert_file_exists "$HOME_DIR/.config/shimmy/profiles/default/bin/shimmy"

  setup_scenario
  run_in_repo env XDG_CONFIG_HOME= HOME="$HOME_DIR" ./install.sh --no-startup >/dev/null
  assert_file_exists "$HOME_DIR/.config/shimmy/profiles/default/bin/shimmy"

  setup_scenario
  mkdir -p "$XDG_CONFIG_HOME_DIR/shimmy"
  printf '%s\n' 'shimmy_install_manifest_version=2' > "$XDG_CONFIG_HOME_DIR/shimmy/install-manifest.txt"
  set +e
  version_two_output=$(bootstrap_default 2>&1)
  version_two_status=$?
  set -e
  [ "$version_two_status" -ne 0 ] || fail_test "version-2 shared manifest unexpectedly accepted"
  assert_contains "$version_two_output" 'version-2 Shimmy installation detected'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  pass "installer enforces XDG resolution, rejects v2 and retired options, ignores retired variables, and preserves siblings"
}
