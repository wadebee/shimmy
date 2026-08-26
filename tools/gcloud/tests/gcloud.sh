#!/bin/sh
# Google Cloud CLI configuration diagnostic tests.

test_tools_gcloud_config_help_missing_paths() {
  setup_scenario

  output=$(HOME="$HOME_DIR" run_in_repo ./commands/run-tool.sh gcloud --shimmy-config-help)

  assert_contains "$output" "Shimmy gcloud configuration help"
  assert_contains "$output" "Host HOME: $HOME_DIR"
  assert_contains "$output" "Expected gcloud config directory: $HOME_DIR/.config/gcloud (missing)"
  assert_contains "$output" "Expected kubeconfig file: $HOME_DIR/.kube/config (missing)"
  assert_contains "$output" "Host CLOUDSDK_CONFIG: <unset>"
  assert_contains "$output" "Effective host gcloud config directory: $HOME_DIR/.config/gcloud (missing, source: HOME)"
  assert_contains "$output" "Mount policy: Shimmy creates the gcloud config directory, then mounts it read-write."
  assert_contains "$output" "Container user: cloudsdk"
  assert_contains "$output" "Container HOME: /home/cloudsdk"
  assert_contains "$output" "Container CLOUDSDK_CONFIG: /home/cloudsdk/.config/gcloud"
  assert_contains "$output" "Mount policy: Shimmy mounts ~/.kube/config read-only when it exists."
  assert_path_not_exists "$HOME_DIR/.config/gcloud"
  pass "gcloud config help reports missing host paths without creating configuration"
}

test_tools_gcloud_config_help_override() {
  setup_scenario
  config_dir=$WORK_DIR/custom-gcloud-config

  mkdir -p "$config_dir" "$HOME_DIR/.kube"
  printf '%s\n' 'apiVersion: v1' > "$HOME_DIR/.kube/config"

  output=$(HOME="$HOME_DIR" CLOUDSDK_CONFIG="$config_dir" run_in_repo ./commands/run-tool.sh gcloud --shimmy-config-help)

  assert_contains "$output" "Expected gcloud config directory: $HOME_DIR/.config/gcloud (missing)"
  assert_contains "$output" "Expected kubeconfig file: $HOME_DIR/.kube/config (present)"
  assert_contains "$output" "Host CLOUDSDK_CONFIG: $config_dir (present)"
  assert_contains "$output" "Effective host gcloud config directory: $config_dir (present, source: CLOUDSDK_CONFIG)"
  assert_path_not_exists "$HOME_DIR/.config/gcloud"
  pass "gcloud config help reports CLOUDSDK_CONFIG override and kubeconfig"
}

test_tools_gcloud_config_help_present_paths() {
  setup_scenario

  mkdir -p "$HOME_DIR/.config/gcloud" "$HOME_DIR/.kube"
  printf '%s\n' 'apiVersion: v1' > "$HOME_DIR/.kube/config"

  output=$(HOME="$HOME_DIR" run_in_repo ./commands/run-tool.sh gcloud --shimmy-config-help)

  assert_contains "$output" "Expected gcloud config directory: $HOME_DIR/.config/gcloud (present)"
  assert_contains "$output" "Expected kubeconfig file: $HOME_DIR/.kube/config (present)"
  assert_contains "$output" "Effective host gcloud config directory: $HOME_DIR/.config/gcloud (present, source: HOME)"
  pass "gcloud config help reports present host paths"
}

test_tools_gcloud_preview_ca_bundle() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(HOME="$HOME_DIR" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_GCLOUD_IMAGE=example.invalid/shimmy/gcloud:test run_in_repo ./commands/run-tool.sh gcloud --preview-shim version)
  ca_mount="'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  ca_environment="'-e' 'CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE=/tmp/shimmy-host-ca-bundle.pem'"

  assert_contains "$output" "$ca_mount"
  assert_contains "$output" "$ca_environment"
  assert_contains "$output" "'CLOUDSDK_CONFIG=/home/cloudsdk/.config/gcloud'"
  assert_contains "$output" "'HOME=/home/cloudsdk'"
  case "$output" in
    *"$ca_mount"*"$ca_mount"*) fail_test "gcloud preview emitted the CA bundle mount more than once" ;;
  esac
  case "$output" in
    *"$ca_environment"*"$ca_environment"*) fail_test "gcloud preview emitted the native CA environment assignment more than once" ;;
  esac
  case "$output" in
    *"'CLOUDSDK_*'"*"$ca_environment"*) ;;
    *) fail_test "gcloud native CA assignment did not follow CLOUDSDK_* inheritance" ;;
  esac
  pass "gcloud preview maps one host CA bundle after wildcard forwarding"
}

test_tools_gcloud_run() {
  test_tools_gcloud_config_help_missing_paths
  test_tools_gcloud_config_help_override
  test_tools_gcloud_config_help_present_paths
  test_tools_gcloud_preview_ca_bundle
}
