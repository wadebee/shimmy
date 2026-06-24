#!/bin/sh
# ripgrep preview-contract tests.

test_tools_rg_preview_contract() {
  output=$(SHIMMY_RG_IMAGE=example.invalid/shimmy/rg:test SHIMMY_RG_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh rg --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'run' '--rm' '-i'"
  assert_contains "$output" "'example.invalid/shimmy/rg:test'"
  pass "rg preview remains stdin-friendly and honors image overrides"
}

test_tools_rg_run() {
  test_tools_rg_preview_contract
}
