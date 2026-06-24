#!/bin/sh
# Source and installed dispatcher request-validation tests.

test_commands_dispatcher_install_unknown_version() {
  setup_scenario

  set +e
  output=$(HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim oc@9.99 --no-startup --no-skills 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "install accepted an unsupported concrete version"
  assert_contains "$output" "unsupported oc version: 9.99"
  assert_contains "$output" "Available oc versions: 4.18, 4.20, 4.22"
  pass "install rejects unsupported concrete versions with available values"
}

test_commands_dispatcher_installed_invalid_profile() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(cd "$WORK_DIR" && PATH="$INSTALL_DIR/bin:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=unsupported jq --preview-shim --version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "installed dispatcher accepted an unsupported active profile"
  assert_contains "$output" "unsupported SHIMMY_PROFILE_ACTIVE: unsupported"
  pass "installed dispatcher rejects unsupported active profiles"
}

test_commands_dispatcher_installed_recursive_target() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null
  profile_manifest=$INSTALL_DIR/profiles/default/install-manifest.txt
  manifest_tmp=$profile_manifest.tmp
  sed "s|^profile_implementation_dir=.*|profile_implementation_dir=$INSTALL_DIR/bin|" "$profile_manifest" > "$manifest_tmp"
  mv "$manifest_tmp" "$profile_manifest"

  set +e
  output=$(cd "$WORK_DIR" && PATH="$INSTALL_DIR/bin:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=default jq --preview-shim --version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "installed dispatcher accepted a recursive target"
  assert_contains "$output" "refusing recursive Shimmy dispatch for jq"
  pass "installed dispatcher rejects recursive implementation targets"
}

test_commands_dispatcher_source_invalid_kind() {
  set +e
  output=$(run_in_repo ./commands/run-tool.sh ../jq --preview-shim --version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "source dispatcher accepted an invalid tool kind"
  assert_contains "$output" "invalid tool kind: ../jq"
  pass "source dispatcher rejects invalid tool kind paths"
}

test_commands_dispatcher_source_selector() {
  set +e
  output=$(SHIMMY_OC_VERSION=9.99 run_in_repo ./commands/run-tool.sh oc --preview-shim version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "source dispatcher accepted an unsupported selector value"
  assert_contains "$output" "unsupported SHIMMY_OC_VERSION value: 9.99"
  assert_contains "$output" "Available oc versions: 4.18 4.20 4.22"
  pass "source dispatcher reports unsupported selector values"
}

test_commands_dispatcher_run() {
  test_commands_dispatcher_install_unknown_version
  test_commands_dispatcher_installed_invalid_profile
  test_commands_dispatcher_installed_recursive_target
  test_commands_dispatcher_source_invalid_kind
  test_commands_dispatcher_source_selector
}
