#!/bin/sh
# Google Drive MCP preview-contract tests.

test_tools_gdrive_preview_contract() {
  setup_scenario
  credentials_dir=$SCENARIO_DIR/gdrive-creds
  mkdir -p "$credentials_dir"

  output=$(CLIENT_ID=client-id CLIENT_SECRET=client-secret GDRIVE_CREDS_DIR="$credentials_dir" SHIMMY_GDRIVE_IMAGE=example.invalid/shimmy/gdrive:test SHIMMY_GDRIVE_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh gdrive --preview-shim)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$credentials_dir:$credentials_dir:rw'"
  assert_contains "$output" "'CLIENT_ID=client-id'"
  assert_contains "$output" "'CLIENT_SECRET=client-secret'"
  assert_contains "$output" "'example.invalid/shimmy/gdrive:test'"
  pass "gdrive preview preserves OAuth credential forwarding"
}

test_tools_gdrive_image_identity_inputs() {
  default_output=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=arm64 run_in_repo ./commands/run-tool.sh gdrive --preview-shim)
  source_output=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=arm64 SHIMMY_GDRIVE_SOURCE_REF=main run_in_repo ./commands/run-tool.sh gdrive --preview-shim)
  [ "$default_output" != "$source_output" ] || fail_test 'gdrive source override did not change local cache identity'
  assert_contains "$default_output" linux-arm64
  pass "gdrive source overrides select a distinct native-platform cache identity"
}

test_tools_gdrive_run() {
  test_tools_gdrive_image_identity_inputs
  test_tools_gdrive_preview_contract
}
