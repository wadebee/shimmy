#!/bin/sh
# Go toolchain preview-contract tests.

test_tools_go_preview_contract() {
  output=$(SHIMMY_GO_IMAGE=example.invalid/shimmy/go:test SHIMMY_GO_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh go --preview-shim version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'--entrypoint' 'go'"
  assert_contains "$output" "'example.invalid/shimmy/go:test'"
  pass "go preview preserves the Go entrypoint and image override"
}

test_tools_go_run() {
  test_tools_go_preview_contract
}
