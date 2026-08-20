#!/bin/sh
# Bats preview-contract tests.

test_tools_bats_preview_contract() {
  output=$(SHIMMY_BATS_IMAGE=example.invalid/shimmy/bats:test SHIMMY_BATS_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh bats --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'--entrypoint' 'bats'"
  assert_contains "$output" "'example.invalid/shimmy/bats:test'"
  pass "bats preview preserves the Bats entrypoint and image override"
}

test_tools_bats_run() {
  test_tools_bats_preview_contract
}
