#!/bin/sh
# AWS CLI preview-contract tests.

test_tools_aws_preview_contract() {
  setup_scenario
  mkdir -p "$HOME_DIR/.aws"

  output=$(HOME="$HOME_DIR" SHIMMY_AWS_IMAGE=example.invalid/shimmy/aws:test SHIMMY_AWS_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh aws --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$HOME_DIR/.aws:/root/.aws:ro'"
  assert_contains "$output" "'AWS_*'"
  assert_contains "$output" "'example.invalid/shimmy/aws:test'"
  pass "AWS preview preserves credential and environment forwarding"
}

test_tools_aws_run() {
  test_tools_aws_preview_contract
}
