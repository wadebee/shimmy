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

  for claimed_path in shell-init.sh registries.conf machine-projection.txt install-manifest.txt bin bin/shimmy bin/jq commands config lib plugins tests tools; do
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
  set +e
  unknown_option_output=$(bootstrap_default --unknown-option 2>&1)
  unknown_option_status=$?
  set -e
  [ "$unknown_option_status" -ne 0 ] || fail_test "unknown install option unexpectedly succeeded"
  assert_contains "$unknown_option_output" 'unknown argument: --unknown-option'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"

  setup_scenario
  run_in_clean_source env -u XDG_CONFIG_HOME HOME="$HOME_DIR" ./bootstrap.sh --no-startup >/dev/null
  assert_file_exists "$HOME_DIR/.config/shimmy/profiles/default/bin/shimmy"

  setup_scenario
  run_in_clean_source env XDG_CONFIG_HOME= HOME="$HOME_DIR" ./bootstrap.sh --no-startup >/dev/null
  assert_file_exists "$HOME_DIR/.config/shimmy/profiles/default/bin/shimmy"

  setup_scenario
  mkdir -p "$XDG_CONFIG_HOME_DIR/shimmy"
  printf '%s\n' keep > "$XDG_CONFIG_HOME_DIR/shimmy/unmanaged-sibling"
  bootstrap_default >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_contains "$XDG_CONFIG_HOME_DIR/shimmy/unmanaged-sibling" keep
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/bin/unmanaged"
  default_shimmy install --shim task >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/unmanaged"
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/task"

  for invalid_request in \
    'install --shim task --stop-running' \
    'uninstall --stop-running --stop-running'; do
    set -- $invalid_request
    set +e
    invalid_output=$(default_shimmy "$@" 2>&1)
    invalid_status=$?
    set -e
    [ "$invalid_status" -ne 0 ] || fail_test "invalid lifecycle request unexpectedly succeeded: $invalid_request"
    assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  done
  set +e
  unnecessary_output=$(default_shimmy uninstall --stop-running 2>&1)
  unnecessary_status=$?
  set -e
  [ "$unnecessary_status" -ne 0 ] || fail_test 'unnecessary uninstall workload acknowledgement unexpectedly succeeded'
  assert_contains "$unnecessary_output" 'valid only when uninstall cleanup will stop an already running machine'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  pass "installer enforces XDG resolution, rejects unknown options before mutation, and preserves unmanaged siblings"
}
