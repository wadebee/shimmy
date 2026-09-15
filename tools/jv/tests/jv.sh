#!/bin/sh
# jv preview-contract tests.

test_tools_jv_preview_contract() {
  output=$(SHIMMY_JV_IMAGE=example.invalid/shimmy/jv:test SHIMMY_JV_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh jv --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'run' '--rm' '-i'"
  assert_contains "$output" "'-v' '$PWD:/work'"
  assert_contains "$output" "'-w' '/work'"
  assert_contains "$output" "'example.invalid/shimmy/jv:test'"
  pass "jv preview preserves stdin-friendly execution and image overrides"
}

test_tools_jv_run() {
  test_tools_jv_preview_contract
}
