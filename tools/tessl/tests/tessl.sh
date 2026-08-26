#!/bin/sh
# Tessl preview-contract tests.

test_tools_tessl_preview_contract() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  mkdir -p "$HOME_DIR/.tessl"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(HOME="$HOME_DIR" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_TESSL_IMAGE=example.invalid/shimmy/tessl:test SHIMMY_TESSL_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh tessl --preview-shim --help)
  ca_mount="'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  ca_environment="'-e' 'NODE_EXTRA_CA_CERTS=/tmp/shimmy-host-ca-bundle.pem'"

  assert_contains "$output" "'-m' '300M'"
  assert_contains "$output" "'--memory-swap' '1G'"
  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$HOME_DIR/.tessl:/root/.tessl'"
  assert_contains "$output" "'SHIMMY_TESSL_*'"
  assert_contains "$output" "$ca_mount"
  assert_contains "$output" "$ca_environment"
  assert_contains "$output" "'example.invalid/shimmy/tessl:test'"
  case "$output" in
    *"$ca_mount"*"$ca_mount"*) fail_test "tessl preview emitted the CA bundle mount more than once" ;;
  esac
  case "$output" in
    *"$ca_environment"*"$ca_environment"*) fail_test "tessl preview emitted the native CA environment assignment more than once" ;;
  esac
  pass "tessl preview preserves resource controls and maps one host CA bundle"
}

test_tools_tessl_run() {
  test_tools_tessl_preview_contract
}
