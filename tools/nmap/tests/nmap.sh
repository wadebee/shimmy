#!/bin/sh
# Nmap preview safety and opt-in behavior tests.

test_tools_nmap_default_preview() {
  output=$("$ROOT_DIR/commands/run-tool.sh" nmap --preview-shim --version)

  assert_contains "$output" "'docker.io/instrumentisto/nmap:7.98-r2'"
  assert_not_contains "$output" "'--network' 'host'"
  assert_not_contains "$output" "'--cap-add' 'NET_RAW'"
  assert_not_contains "$output" "'--privileged'"
  pass "nmap preview keeps privileged network behavior opt-in"
}

test_tools_nmap_lan_scan_preview() {
  output=$(SHIMMY_NMAP_LAN_SCAN=1 "$ROOT_DIR/commands/run-tool.sh" nmap --preview-shim --version)

  assert_contains "$output" "'--network' 'host'"
  assert_contains "$output" "'--cap-add' 'NET_RAW'"
  assert_contains "$output" "'--cap-add' 'NET_ADMIN'"
  pass "nmap LAN scan opt-in adds host network capabilities"
}

test_tools_nmap_network_conflict() {
  set +e
  output=$(SHIMMY_NMAP_LAN_SCAN=1 SHIMMY_NMAP_NETWORK=none "$ROOT_DIR/commands/run-tool.sh" nmap --preview-shim --version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "nmap accepted conflicting LAN and network settings"
  assert_contains "$output" "SHIMMY_NMAP_LAN_SCAN=1 cannot be combined with SHIMMY_NMAP_NETWORK=none"
  pass "nmap rejects conflicting LAN and network settings"
}

test_tools_nmap_privilege_controls() {
  unprivileged_output=$(SHIMMY_NMAP_PRIVILEGED=0 "$ROOT_DIR/commands/run-tool.sh" nmap --preview-shim --version)
  assert_contains "$unprivileged_output" "'--unprivileged'"

  set +e
  output=$(SHIMMY_NMAP_PRIVILEGED=2 "$ROOT_DIR/commands/run-tool.sh" nmap --preview-shim --version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "nmap accepted an invalid privilege setting"
  assert_contains "$output" "SHIMMY_NMAP_PRIVILEGED must be 1, 0, or unset"
  pass "nmap validates explicit privilege controls"
}

test_tools_nmap_run() {
  test_tools_nmap_default_preview
  test_tools_nmap_lan_scan_preview
  test_tools_nmap_network_conflict
  test_tools_nmap_privilege_controls
}
