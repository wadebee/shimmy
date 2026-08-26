#!/bin/sh
# GitHub CLI preview-contract tests.

test_tools_gh_preview_contract() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  config_dir=$SCENARIO_DIR/gh-config
  mkdir -p "$config_dir"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(GH_CONFIG_DIR="$config_dir" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_GH_IMAGE=example.invalid/shimmy/gh:test SHIMMY_GH_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh gh --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$config_dir:/home/gh/.config/gh:rw'"
  assert_contains "$output" "'GH_*'"
  assert_contains "$output" "'GH_CONFIG_DIR=/home/gh/.config/gh'"
  assert_contains "$output" "'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  assert_contains "$output" "'-e' 'SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem'"
  assert_contains "$output" "'example.invalid/shimmy/gh:test'"
  pass "gh preview preserves config persistence and environment forwarding while mapping the host CA bundle"
}

test_tools_gh_target_archives() {
  container_file=$ROOT_DIR/tools/gh/versions/2.94/container/Containerfile
  assert_file_contains "$container_file" "x86_64) gh_arch='amd64'"
  assert_file_contains "$container_file" "aarch64) gh_arch='arm64'"
  assert_file_contains "$container_file" 'gh_${SHIMMY_GH_VERSION}_linux_${gh_arch}.tar.gz'
  pass "gh local build selects the release archive for the target architecture"
}

test_tools_gh_image_identity_inputs() {
  default_output=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 run_in_repo ./commands/run-tool.sh gh --preview-shim --version)
  base_output=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 SHIMMY_GH_BASE_IMAGE=example.invalid/base@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa run_in_repo ./commands/run-tool.sh gh --preview-shim --version)
  version_output=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 SHIMMY_GH_VERSION=2.94.1 run_in_repo ./commands/run-tool.sh gh --preview-shim --version)

  [ "$default_output" != "$base_output" ] || fail_test 'gh base override did not change local cache identity'
  [ "$default_output" != "$version_output" ] || fail_test 'gh version override did not change local cache identity'
  assert_contains "$default_output" linux-amd64
  pass "gh base and release overrides select distinct local cache identities"
}

test_tools_gh_run() {
  test_tools_gh_image_identity_inputs
  test_tools_gh_preview_contract
  test_tools_gh_target_archives
}
