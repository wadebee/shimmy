#!/bin/sh
# Netcat preview-contract tests.

test_tools_netcat_preview_contract() {
  output=$(SHIMMY_NETCAT_IMAGE=example.invalid/shimmy/netcat:test SHIMMY_NETCAT_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh netcat --preview-shim --help)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$ROOT_DIR:/work:rw'"
  assert_contains "$output" "'example.invalid/shimmy/netcat:test'"
  pass "netcat preview preserves its writable working directory contract"
}

test_tools_netcat_run() {
  test_tools_netcat_preview_contract
}
