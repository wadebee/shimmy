#!/bin/sh
# Go toolchain preview-contract tests.

test_tools_go_preview_contract() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_GO_IMAGE=example.invalid/shimmy/go:test SHIMMY_GO_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh go --preview-shim version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'--entrypoint' 'go'"
  assert_contains "$output" "'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  assert_contains "$output" "'-e' 'SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem'"
  assert_contains "$output" "'example.invalid/shimmy/go:test'"
  pass "go preview preserves the Go entrypoint and maps the host CA bundle"
}

test_tools_go_run() {
  test_tools_go_preview_contract
}
