#!/bin/sh
# npx preview-contract tests.

test_tools_npx_preview_contract() {
  output=$(SHIMMY_NPX_IMAGE=example.invalid/shimmy/npx:test SHIMMY_NPX_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh npx --preview-shim --yes example-package@1.2.3 -- sample-argument)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'-i'"
  assert_not_contains "$output" "'-it'"
  assert_not_contains "$output" "'-t'"
  assert_contains "$output" "'$ROOT_DIR:/work:rw'"
  assert_contains "$output" "'-w' '/work'"
  assert_contains "$output" "'--entrypoint' 'npx'"
  assert_contains "$output" "'example.invalid/shimmy/npx:test' '--yes' 'example-package@1.2.3' '--' 'sample-argument'"
  assert_not_contains "$output" "'HOME="
  assert_not_contains "$output" "/.npm"
  assert_not_contains "$output" ".npmrc"
  pass "npx preview preserves entrypoint, workspace, I/O, argument, and isolation contracts"
}

test_tools_npx_run() {
  test_tools_npx_preview_contract
}
