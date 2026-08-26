#!/bin/sh
# Terraform preview-contract tests.

test_tools_terraform_preview_contract() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  mkdir -p "$HOME_DIR/.aws" "$HOME_DIR/.terraform.d/plugin-cache"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(HOME="$HOME_DIR" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_TF_IMAGE=example.invalid/shimmy/terraform:test SHIMMY_TF_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh terraform --preview-shim version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$HOME_DIR/.aws:/root/.aws:ro'"
  assert_contains "$output" "'$HOME_DIR/.terraform.d/plugin-cache:/root/.terraform.d/plugin-cache'"
  assert_contains "$output" "'AWS_*'"
  assert_contains "$output" "'TF_VAR_*'"
  assert_contains "$output" "'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  assert_contains "$output" "'-e' 'SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem'"
  assert_contains "$output" "'example.invalid/shimmy/terraform:test'"
  pass "terraform preview preserves credential, cache, and variable forwarding while mapping the host CA bundle"
}

test_tools_terraform_run() {
  test_tools_terraform_preview_contract
}
