#!/bin/sh
# Task preview-contract tests.

test_tools_task_preview_contract() {
  setup_scenario

  output=$(HOME="$HOME_DIR" SHIMMY_TASK_IMAGE=example.invalid/shimmy/task:test SHIMMY_TASK_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh task --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$ROOT_DIR:$ROOT_DIR:rw'"
  assert_contains "$output" "'$ROOT_DIR:/work:rw'"
  assert_contains "$output" "'$HOME_DIR:$HOME_DIR:rw'"
  assert_contains "$output" "'/tmp:/tmp:rw'"
  assert_contains "$output" "'example.invalid/shimmy/task:test'"
  pass "task preview preserves documented host integration mounts"
}

test_tools_task_run() {
  test_tools_task_preview_contract
}
