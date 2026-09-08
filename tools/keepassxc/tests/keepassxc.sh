#!/bin/sh
# KeePassXC CLI preview-contract tests.

test_tools_keepassxc_preview_contract() {
  output=$(SHIMMY_KEEPASSXC_IMAGE=example.invalid/shimmy/keepassxc:test SHIMMY_KEEPASSXC_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh keepassxc --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'run' '--rm' '-i'"
  assert_contains "$output" "'--entrypoint' 'keepassxc-cli'"
  assert_contains "$output" "'example.invalid/shimmy/keepassxc:test'"
  pass "keepassxc preview honors the CLI entrypoint and image overrides"
}

test_tools_keepassxc_run() {
  test_tools_keepassxc_preview_contract
}
