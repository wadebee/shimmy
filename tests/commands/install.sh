#!/bin/sh
# Additive installation and install-request validation tests.

test_commands_install_additive_kinds() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null
  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim task --no-startup --no-skills >/dev/null

  assert_path_symlink "$INSTALL_DIR/bin/jq"
  assert_path_symlink "$INSTALL_DIR/bin/task"
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" "kind=jq"
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" "kind=task"
  pass "additive install preserves previously installed tool kinds"
}

test_commands_install_additive_kind_refreshes_control_assets() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null
  rm -rf "$INSTALL_DIR/core/tools/logmine"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim logmine --no-startup --no-skills >/dev/null

  [ -f "$INSTALL_DIR/core/tools/logmine/tool.conf" ] || fail_test "additive install did not refresh installed tool metadata for logmine"
  assert_path_symlink "$INSTALL_DIR/bin/logmine"
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" "kind=logmine"
  pass "additive install refreshes installed control assets for newly added kinds"
}

test_commands_install_macos_podman_guidance() {
  setup_scenario

  output=$(SHIMMY_TEST_OS=Darwin HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills 2>&1)

  assert_contains "$output" "macOS Podman check: run 'podman info' in a normal shell before using Shimmy."
  assert_contains "$output" "If Podman is unreachable, run 'podman machine start' in that shell, then retry Shimmy."
  pass "install gives macOS Podman dependency guidance"
}

test_commands_install_uninstall_requires_profile() {
  setup_scenario

  set +e
  output=$(HOME="$HOME_DIR" run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" --no-skills 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "uninstall accepted a missing profile request"
  assert_contains "$output" "uninstall requires --profile default or --profile upstream"
  pass "uninstall requires an explicit profile selection"
}

test_commands_install_run() {
  test_commands_install_additive_kinds
  test_commands_install_additive_kind_refreshes_control_assets
  test_commands_install_macos_podman_guidance
  test_commands_install_uninstall_requires_profile
}
