#!/bin/sh
# Terraform preview-contract tests.

test_tools_terraform_preview_contract() {
  setup_scenario
  mkdir -p "$HOME_DIR/.aws" "$HOME_DIR/.terraform.d/plugin-cache"

  output=$(HOME="$HOME_DIR" SHIMMY_TF_IMAGE=example.invalid/shimmy/terraform:test SHIMMY_TF_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh terraform --preview-shim version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$HOME_DIR/.aws:/root/.aws:ro'"
  assert_contains "$output" "'$HOME_DIR/.terraform.d/plugin-cache:/root/.terraform.d/plugin-cache'"
  assert_contains "$output" "'AWS_*'"
  assert_contains "$output" "'TF_VAR_*'"
  assert_contains "$output" "'example.invalid/shimmy/terraform:test'"
  pass "terraform preview preserves credential, cache, and variable forwarding"
}

test_tools_terraform_run() {
  test_tools_terraform_preview_contract
}
