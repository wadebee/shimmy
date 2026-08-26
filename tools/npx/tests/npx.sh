#!/bin/sh
# npx preview-contract tests.

test_tools_npx_preview_contract() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_NPX_IMAGE=example.invalid/shimmy/npx:test SHIMMY_NPX_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh npx --preview-shim --yes example-package@1.2.3 -- sample-argument)
  ca_mount="'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  ca_environment="'-e' 'NODE_EXTRA_CA_CERTS=/tmp/shimmy-host-ca-bundle.pem'"

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'-i'"
  assert_not_contains "$output" "'-it'"
  assert_not_contains "$output" "'-t'"
  assert_contains "$output" "'$ROOT_DIR:/work:rw'"
  assert_contains "$output" "'-w' '/work'"
  assert_contains "$output" "'--entrypoint' 'npx'"
  assert_contains "$output" "$ca_mount"
  assert_contains "$output" "$ca_environment"
  assert_contains "$output" "'example.invalid/shimmy/npx:test' '--yes' 'example-package@1.2.3' '--' 'sample-argument'"
  assert_not_contains "$output" "'HOME="
  assert_not_contains "$output" "/.npm"
  assert_not_contains "$output" ".npmrc"
  case "$output" in
    *"$ca_mount"*"$ca_mount"*) fail_test "npx preview emitted the CA bundle mount more than once" ;;
  esac
  case "$output" in
    *"$ca_environment"*"$ca_environment"*) fail_test "npx preview emitted the native CA environment assignment more than once" ;;
  esac
  pass "npx preview preserves execution boundaries and maps one host CA bundle"
}

test_tools_npx_run() {
  test_tools_npx_preview_contract
}
