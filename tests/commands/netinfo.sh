#!/bin/sh
# Deterministic netinfo rendering and request-validation tests.

test_commands_netinfo_cidr_rendering() {
  output=$(run_in_repo ./shimmy netinfo --format manifest --host-ip 198.51.100.255 --host-prefix 25 --target 198.51.100.1)

  assert_contains "$output" "host_ipv4=198.51.100.255"
  assert_contains "$output" "host_ipv4_source=explicit"
  assert_contains "$output" "host_lan=198.51.100.128/25"
  assert_contains "$output" "host_lan_source=host_prefix"
  pass "netinfo renders host-prefix CIDR boundaries"
}

test_commands_netinfo_explicit_lan_precedence() {
  output=$(run_in_repo ./shimmy netinfo --format manifest --host-ip 203.0.113.99 --host-prefix 24 --host-lan 203.0.113.64/26)

  assert_contains "$output" "host_ipv4=203.0.113.99"
  assert_contains "$output" "host_lan=203.0.113.64/26"
  assert_contains "$output" "host_lan_source=explicit"
  pass "netinfo prefers an explicit host LAN over a derived prefix"
}

test_commands_netinfo_help() {
  output=$(run_in_repo ./shimmy netinfo --help)

  assert_contains "$output" "Usage:"
  assert_contains "$output" "--host-lan <cidr>"
  assert_contains "$output" "--format human|manifest"
  pass "netinfo documents explicit host inputs"
}

test_commands_netinfo_invalid_inputs() {
  set +e
  invalid_ip_output=$(run_in_repo ./shimmy netinfo --host-ip 198.51.100.256 2>&1)
  invalid_ip_status=$?
  invalid_prefix_output=$(run_in_repo ./shimmy netinfo --host-prefix 33 2>&1)
  invalid_prefix_status=$?
  invalid_lan_output=$(run_in_repo ./shimmy netinfo --host-lan 203.0.113.1 2>&1)
  invalid_lan_status=$?
  set -e

  [ "$invalid_ip_status" -ne 0 ] || fail_test "netinfo accepted an invalid host IPv4 address"
  [ "$invalid_prefix_status" -ne 0 ] || fail_test "netinfo accepted an invalid host prefix"
  [ "$invalid_lan_status" -ne 0 ] || fail_test "netinfo accepted an invalid host LAN"
  assert_contains "$invalid_ip_output" "invalid --host-ip value: 198.51.100.256"
  assert_contains "$invalid_prefix_output" "invalid --host-prefix value: 33"
  assert_contains "$invalid_lan_output" "invalid --host-lan value: 203.0.113.1"
  pass "netinfo rejects malformed explicit host inputs"
}

test_commands_netinfo_run() {
  test_commands_netinfo_cidr_rendering
  test_commands_netinfo_explicit_lan_precedence
  test_commands_netinfo_help
  test_commands_netinfo_invalid_inputs
}
