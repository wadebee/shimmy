#!/bin/sh
# jq preview-contract tests.

test_tools_jq_preview_contract() {
  output=$(SHIMMY_JQ_IMAGE=example.invalid/shimmy/jq:test SHIMMY_JQ_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh jq --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'run' '--rm' '-i'"
  assert_contains "$output" "'example.invalid/shimmy/jq:test'"
  pass "jq preview remains stdin-friendly and honors image overrides"
}

test_tools_jq_run() {
  test_tools_jq_preview_contract
}
