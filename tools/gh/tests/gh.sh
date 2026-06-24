#!/bin/sh
# GitHub CLI preview-contract tests.

test_tools_gh_preview_contract() {
  setup_scenario
  config_dir=$SCENARIO_DIR/gh-config
  mkdir -p "$config_dir"

  output=$(GH_CONFIG_DIR="$config_dir" SHIMMY_GH_IMAGE=example.invalid/shimmy/gh:test SHIMMY_GH_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh gh --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$config_dir:/home/gh/.config/gh:rw'"
  assert_contains "$output" "'GH_*'"
  assert_contains "$output" "'GH_CONFIG_DIR=/home/gh/.config/gh'"
  assert_contains "$output" "'example.invalid/shimmy/gh:test'"
  pass "gh preview preserves config persistence and environment forwarding"
}

test_tools_gh_run() {
  test_tools_gh_preview_contract
}
