#!/bin/sh
# Profile selection, status, and profile-isolation tests.

setup_commands_profiles_both() {
  setup_scenario
  profile_checkout_dir=$(cd -- "$ROOT_DIR" && pwd -P)

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null
  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$profile_checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim rg --no-startup --no-skills >/dev/null
}

test_commands_profiles_activation_missing_profile() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(HOME="$HOME_DIR" run_in_repo ./shimmy activate --install-dir "$INSTALL_DIR" --profile upstream 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "activation accepted an uninstalled upstream profile"
  assert_contains "$output" "incomplete Shimmy profile for profile upstream"
  assert_contains "$output" "repair with shimmy install --profile upstream"
  pass "activation gives profile-specific repair guidance"
}

test_commands_profiles_invalid_active_profile() {
  setup_scenario

  set +e
  output=$(HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=unsupported run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --format manifest 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "status accepted an unsupported active profile"
  assert_contains "$output" "unsupported Shimmy profile"
  pass "management commands reject unsupported active profiles"
}

test_commands_profiles_precedence() {
  setup_commands_profiles_both

  default_status=$(HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --format manifest)
  active_status=$(HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=upstream run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --format manifest)
  explicit_status=$(HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=upstream run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --profile default --format manifest)

  assert_contains "$default_status" "shimmy_profile_name=default"
  assert_contains "$default_status" "shimmy_profile_kind=jq"
  assert_not_contains "$default_status" "shimmy_profile_kind=rg"
  assert_contains "$active_status" "shimmy_profile_name=upstream"
  assert_contains "$active_status" "shimmy_profile_kind=rg"
  assert_not_contains "$active_status" "shimmy_profile_kind=jq"
  assert_contains "$explicit_status" "shimmy_profile_name=default"
  assert_contains "$explicit_status" "shimmy_profile_kind=jq"
  assert_not_contains "$explicit_status" "shimmy_profile_kind=rg"
  pass "profile selection uses explicit, active, then default precedence"
}

test_commands_profiles_status_available() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null

  status_output=$(HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --available --format manifest)

  assert_contains "$status_output" "shimmy_installed=yes"
  assert_contains "$status_output" "shimmy_profile_kind=jq"
  assert_not_contains "$status_output" "shimmy_available_kind=jq"
  assert_contains "$status_output" "shimmy_available_kind=rg"
  pass "status distinguishes installed and available tool kinds"
}

test_commands_profiles_uninstall_isolation() {
  setup_commands_profiles_both

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --uninstall --no-skills >/dev/null

  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  assert_path_not_exists "$INSTALL_DIR/profiles/default"
  assert_file_exists "$INSTALL_DIR/profiles/upstream/install-manifest.txt"
  assert_path_not_exists "$INSTALL_DIR/bin/jq"
  assert_path_symlink "$INSTALL_DIR/bin/rg"

  upstream_status=$(HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --profile upstream --format manifest)
  assert_contains "$upstream_status" "shimmy_installed=yes"
  assert_contains "$upstream_status" "shimmy_profile_kind=rg"
  pass "uninstalling one profile preserves the other profile assets"
}

test_commands_profiles_run() {
  test_commands_profiles_activation_missing_profile
  test_commands_profiles_invalid_active_profile
  test_commands_profiles_precedence
  test_commands_profiles_status_available
  test_commands_profiles_uninstall_isolation
}
