#!/bin/sh
# Textual preview-contract tests.

test_tools_textual_preview_contract() {
  output=$(SHIMMY_TEXTUAL_IMAGE=example.invalid/shimmy/textual:test SHIMMY_TEXTUAL_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh textual --preview-shim --help)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$ROOT_DIR:/work:rw'"
  assert_contains "$output" "'example.invalid/shimmy/textual:test'"
  pass "textual preview preserves its writable working directory contract"
}

test_tools_textual_run() {
  test_tools_textual_preview_contract
}
