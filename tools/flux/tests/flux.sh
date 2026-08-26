#!/bin/sh
# Flux CLI preview-contract tests.

test_tools_flux_default_preview_contract() {
  setup_scenario

  output=$(run_in_repo ./commands/run-tool.sh flux --preview-shim version --client)
  case "$(uname -m)" in
    amd64|x86_64) expected_platform=linux/amd64 ;;
    aarch64|arm64) expected_platform=linux/arm64 ;;
    *) fail_test "unsupported test architecture: $(uname -m)" ;;
  esac

  assert_contains "$output" "'--platform' '$expected_platform'"
  assert_contains "$output" "'-i'"
  assert_not_contains "$output" "'-t'"
  assert_contains "$output" "'-v' '$ROOT_DIR:/work'"
  assert_contains "$output" "'-w' '/work'"
  assert_contains "$output" "'ghcr.io/fluxcd/flux-cli@sha256:5260c79fb1b744c78755d98bcb271971c93e4ea214623c3f9f96ff59536d0398' 'version' '--client'"
  pass "flux default preview preserves the pinned image, native platform, workspace, stdin, and arguments"
}

test_tools_flux_configured_preview_contract() {
  setup_scenario
  kubeconfig=$SCENARIO_DIR/host\ kubeconfig
  ca_bundle=$SCENARIO_DIR/host\ CA\ bundle.pem
  printf '%s\n' fixture-kubeconfig > "$kubeconfig"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(FLUX_NS_FOLLOWS_KUBE_CONTEXT=true \
    GITHUB_TOKEN=github-secret-value \
    GITLAB_TOKEN=gitlab-secret-value \
    BITBUCKET_TOKEN=bitbucket-secret-value \
    SHIMMY_FLUX_KUBECONFIG="$kubeconfig" \
    SHIMMY_HOST_CA_BUNDLE="$ca_bundle" \
    SHIMMY_FLUX_IMAGE=example.invalid/shimmy/flux:test \
    SHIMMY_FLUX_IMAGE_PULL=always \
    run_in_repo ./commands/run-tool.sh flux --preview-shim version --client)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'-v' '$kubeconfig:/tmp/shimmy-flux-kubeconfig:ro'"
  assert_contains "$output" "'-e' 'KUBECONFIG=/tmp/shimmy-flux-kubeconfig'"
  assert_contains "$output" "'-e' 'FLUX_NS_FOLLOWS_KUBE_CONTEXT'"
  assert_contains "$output" "'-e' 'GITHUB_TOKEN'"
  assert_contains "$output" "'-e' 'GITLAB_TOKEN'"
  assert_contains "$output" "'-e' 'BITBUCKET_TOKEN'"
  assert_contains "$output" "'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  assert_contains "$output" "'-e' 'SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem'"
  assert_contains "$output" "'example.invalid/shimmy/flux:test'"
  assert_not_contains "$output" SHIMMY_FLUX_KUBECONFIG
  assert_not_contains "$output" SHIMMY_HOST_CA_BUNDLE
  assert_not_contains "$output" github-secret-value
  assert_not_contains "$output" gitlab-secret-value
  assert_not_contains "$output" bitbucket-secret-value
  pass "flux preview maps exact credential files and forwards only provider environment names"
}

test_tools_flux_kubeconfig_failure_before_podman() {
  setup_scenario
  fake_bin_dir=$SCENARIO_DIR/fake-bin
  fake_podman=$fake_bin_dir/podman
  podman_called=$SCENARIO_DIR/podman-called
  unsafe_kubeconfig=relative-kubeconfig
  mkdir -p "$fake_bin_dir"
  printf '%s\n' \
    '#!/bin/sh' \
    ': > "$FAKE_PODMAN_CALLED"' \
    'exit 90' \
    > "$fake_podman"
  chmod 0755 "$fake_podman"

  set +e
  output=$(PATH="$fake_bin_dir:/usr/bin:/bin" \
    FAKE_PODMAN_CALLED="$podman_called" \
    SHIMMY_FLUX_KUBECONFIG="$unsafe_kubeconfig" \
    SHIMMY_FLUX_IMAGE=example.invalid/shimmy/flux:test \
    run_in_repo ./commands/run-tool.sh flux version --client 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "flux accepted an unsafe kubeconfig path"
  assert_equals "$output" "ERROR: SHIMMY_FLUX_KUBECONFIG must name an absolute readable kubeconfig file: $unsafe_kubeconfig"
  assert_path_not_exists "$podman_called"
  pass "flux rejects an unsafe kubeconfig path before invoking Podman"
}

test_tools_flux_run() {
  test_tools_flux_default_preview_contract
  test_tools_flux_configured_preview_contract
  test_tools_flux_kubeconfig_failure_before_podman
}
