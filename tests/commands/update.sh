#!/bin/sh
# Update lifecycle tests using disposable installs and source previews only.

setup_commands_update_both_profiles() {
  setup_scenario
  update_checkout_dir=$(cd -- "$ROOT_DIR" && pwd -P)

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null
  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$update_checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim rg --no-startup --no-skills >/dev/null
}

test_commands_update_all_profiles() {
  setup_commands_update_both_profiles

  rm -f "$INSTALL_DIR/bin/jq" "$INSTALL_DIR/bin/rg"
  rm -f "$INSTALL_DIR/profiles/default/bin/jq" "$INSTALL_DIR/profiles/upstream/bin/rg"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --all >/dev/null

  assert_path_symlink "$INSTALL_DIR/bin/jq"
  assert_path_symlink "$INSTALL_DIR/bin/rg"
  assert_file_executable "$INSTALL_DIR/profiles/default/bin/jq"
  assert_file_executable "$INSTALL_DIR/profiles/upstream/bin/rg"
  pass "update --all refreshes every installed profile"
}

test_commands_update_invalid_active_profile() {
  setup_scenario

  set +e
  output=$(HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=unsupported run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "update accepted an unsupported active profile"
  assert_contains "$output" "unsupported Shimmy profile: unsupported"
  pass "update rejects unsupported active profiles"
}

test_commands_update_missing_shim() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --shim task 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "update accepted an uninstalled shim"
  assert_contains "$output" "task not installed; run shimmy install --shim task"
  pass "update --shim rejects uninstalled kinds"
}

test_commands_update_preserves_manifest_fields() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null
  manifest_file=$INSTALL_DIR/profiles/default/install-manifest.txt
  {
    printf 'shimmy_update_policy=on-use\n'
    printf 'shimmy_update_interval_hours=12\n'
    printf 'shimmy_last_checked=2026-05-04T00:00:00Z\n'
  } >> "$manifest_file"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" >/dev/null

  assert_file_contains "$manifest_file" "shimmy_update_policy=on-use"
  assert_file_contains "$manifest_file" "shimmy_update_interval_hours=12"
  assert_file_contains "$manifest_file" "shimmy_last_checked=2026-05-04T00:00:00Z"
  pass "update preserves manifest lifecycle fields"
}

test_commands_update_selected_shim() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task --no-startup --no-skills >/dev/null
  rm -f "$INSTALL_DIR/bin/jq" "$INSTALL_DIR/bin/task"
  rm -f "$INSTALL_DIR/profiles/default/bin/jq" "$INSTALL_DIR/profiles/default/bin/task"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --shim task >/dev/null

  assert_path_not_exists "$INSTALL_DIR/bin/jq"
  assert_path_not_exists "$INSTALL_DIR/profiles/default/bin/jq"
  assert_path_symlink "$INSTALL_DIR/bin/task"
  assert_file_executable "$INSTALL_DIR/profiles/default/bin/task"
  pass "update --shim refreshes only the selected installed kind"
}

test_commands_update_run() {
  test_commands_update_all_profiles
  test_commands_update_invalid_active_profile
  test_commands_update_missing_shim
  test_commands_update_preserves_manifest_fields
  test_commands_update_selected_shim
}
