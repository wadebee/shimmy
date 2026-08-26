#!/bin/sh
# AWS CLI preview-contract tests.

test_tools_aws_preview_contract() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  mkdir -p "$HOME_DIR/.aws"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(HOME="$HOME_DIR" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_AWS_IMAGE=example.invalid/shimmy/aws:test SHIMMY_AWS_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh aws --preview-shim --version)
  ca_mount="'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  ca_environment="'-e' 'AWS_CA_BUNDLE=/tmp/shimmy-host-ca-bundle.pem'"

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$HOME_DIR/.aws:/root/.aws:ro'"
  assert_contains "$output" "'AWS_*'"
  assert_contains "$output" "$ca_mount"
  assert_contains "$output" "$ca_environment"
  assert_contains "$output" "'example.invalid/shimmy/aws:test'"
  assert_not_contains "$output" "'SHIMMY_HOST_CA_BUNDLE"
  case "$output" in
    *"$ca_mount"*"$ca_mount"*) fail_test "AWS preview emitted the CA bundle mount more than once" ;;
  esac
  case "$output" in
    *"$ca_environment"*"$ca_environment"*) fail_test "AWS preview emitted the native CA environment assignment more than once" ;;
  esac
  case "$output" in
    *"'AWS_*'"*"$ca_environment"*) ;;
    *) fail_test "AWS native CA assignment did not follow AWS_* inheritance" ;;
  esac
  pass "AWS preview preserves credentials and maps one host CA bundle after wildcard forwarding"
}

test_tools_aws_ca_bundle_disabled() {
  setup_scenario

  unset SHIMMY_HOST_CA_BUNDLE
  unset_output=$(SHIMMY_AWS_IMAGE=example.invalid/shimmy/aws:test run_in_repo ./commands/run-tool.sh aws --preview-shim --version)
  empty_output=$(SHIMMY_HOST_CA_BUNDLE= SHIMMY_AWS_IMAGE=example.invalid/shimmy/aws:test run_in_repo ./commands/run-tool.sh aws --preview-shim --version)

  assert_not_contains "$unset_output" /tmp/shimmy-host-ca-bundle.pem
  assert_not_contains "$unset_output" AWS_CA_BUNDLE
  assert_not_contains "$empty_output" /tmp/shimmy-host-ca-bundle.pem
  assert_not_contains "$empty_output" AWS_CA_BUNDLE
  pass "AWS leaves the Podman command unchanged when host CA support is unset or empty"
}

test_tools_aws_ca_bundle_failure_before_podman() {
  setup_scenario
  fake_bin_dir=$SCENARIO_DIR/fake-bin
  fake_podman=$fake_bin_dir/podman
  podman_called=$SCENARIO_DIR/podman-called
  missing_bundle=$SCENARIO_DIR/missing-ca-bundle.pem
  mkdir -p "$fake_bin_dir"
  printf '%s\n' \
    '#!/bin/sh' \
    ': > "$FAKE_PODMAN_CALLED"' \
    'exit 90' \
    > "$fake_podman"
  chmod 0755 "$fake_podman"

  set +e
  output=$(PATH="$fake_bin_dir:/usr/bin:/bin" FAKE_PODMAN_CALLED="$podman_called" SHIMMY_HOST_CA_BUNDLE="$missing_bundle" SHIMMY_AWS_IMAGE=example.invalid/shimmy/aws:test run_in_repo ./commands/run-tool.sh aws --version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "AWS accepted a missing host CA bundle"
  assert_equals "$output" "ERROR: SHIMMY_HOST_CA_BUNDLE must name an absolute readable CA bundle file: $missing_bundle"
  assert_path_not_exists "$podman_called"
  pass "AWS rejects an invalid host CA bundle before invoking Podman"
}

test_tools_aws_run() {
  test_tools_aws_ca_bundle_disabled
  test_tools_aws_ca_bundle_failure_before_podman
  test_tools_aws_preview_contract
}
