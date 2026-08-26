#!/bin/sh
# Google Drive MCP preview-contract tests.

test_tools_gdrive_preview_contract() {
  setup_scenario
  credentials_dir=$SCENARIO_DIR/gdrive-creds
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  mkdir -p "$credentials_dir"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(CLIENT_ID=client-id CLIENT_SECRET=client-secret GDRIVE_CREDS_DIR="$credentials_dir" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_GDRIVE_IMAGE=example.invalid/shimmy/gdrive:test SHIMMY_GDRIVE_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh gdrive --preview-shim)
  ca_mount="'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  ca_environment="'-e' 'NODE_EXTRA_CA_CERTS=/tmp/shimmy-host-ca-bundle.pem'"

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$credentials_dir:$credentials_dir:rw'"
  assert_contains "$output" "'CLIENT_ID=client-id'"
  assert_contains "$output" "'CLIENT_SECRET=client-secret'"
  assert_contains "$output" "$ca_mount"
  assert_contains "$output" "$ca_environment"
  assert_contains "$output" "'example.invalid/shimmy/gdrive:test'"
  case "$output" in
    *"$ca_mount"*"$ca_mount"*) fail_test "gdrive preview emitted the CA bundle mount more than once" ;;
  esac
  case "$output" in
    *"$ca_environment"*"$ca_environment"*) fail_test "gdrive preview emitted the native CA environment assignment more than once" ;;
  esac
  pass "gdrive preview preserves OAuth behavior and maps one host CA bundle"
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
