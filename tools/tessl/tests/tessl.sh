#!/bin/sh
# Tessl preview-contract tests.

test_tools_tessl_preview_contract() {
  setup_scenario
  mkdir -p "$HOME_DIR/.tessl"

  output=$(HOME="$HOME_DIR" SHIMMY_TESSL_IMAGE=example.invalid/shimmy/tessl:test SHIMMY_TESSL_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh tessl --preview-shim --help)

  assert_contains "$output" "'-m' '300M'"
  assert_contains "$output" "'--memory-swap' '1G'"
  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$HOME_DIR/.tessl:/root/.tessl'"
  assert_contains "$output" "'SHIMMY_TESSL_*'"
  assert_contains "$output" "'example.invalid/shimmy/tessl:test'"
  pass "tessl preview preserves resource and configuration controls"
}

test_tools_tessl_run() {
  test_tools_tessl_preview_contract
}
