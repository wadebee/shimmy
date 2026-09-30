#!/bin/sh

test_tools_aba_safe_help_preview() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(SHIMMY_HOST_CA_BUNDLE="$ca_bundle" run_in_repo ./commands/run-tool.sh aba --preview-shim --help)
  case "$(uname -m)" in
    amd64|x86_64) expected_platform=linux/amd64 ;;
    aarch64|arm64) expected_platform=linux/arm64 ;;
    *) fail_test "unsupported test architecture: $(uname -m)" ;;
  esac

  assert_contains "$output" "'--platform' '$expected_platform'"
  assert_contains "$output" "'-v' '$ROOT_DIR:/work'"
  assert_contains "$output" "'-w' '/work'"
  assert_contains "$output" "'-e' 'HOME=/work'"
  assert_contains "$output" "'localhost/shimmy-aba-1_3:"
  assert_contains "$output" "'--help'"
  assert_contains "$output" "'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  assert_contains "$output" "'-e' 'SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem'"
  assert_not_contains "$output" fixture-ca
  assert_not_contains "$output" "'--connection'"
  assert_not_contains "$output" "'--privileged'"
  assert_not_contains "$output" "'--network' 'host'"
  assert_not_contains "$output" shimmy-aba-ssh-key
  assert_not_contains "$output" .pull-secret.json
  pass "aba help preview remains unprivileged and workspace-scoped"
}

test_tools_aba_operational_preview() {
  setup_scenario
  ssh_key="$SCENARIO_DIR/aba ssh key"
  pull_secret="$SCENARIO_DIR/aba pull secret.json"
  mirror_data="$SCENARIO_DIR/aba mirror data"
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  printf '%s\n' fixture-key > "$ssh_key"
  printf '%s\n' fixture-secret > "$pull_secret"
  printf '%s\n' fixture-ca > "$ca_bundle"
  mkdir -p "$mirror_data"

  output=$(SHIMMY_HOST_CA_BUNDLE="$ca_bundle" \
    SHIMMY_ABA_PRIVILEGED=1 \
    SHIMMY_ABA_NETWORK=host \
    SHIMMY_PODMAN_PRIVILEGED=1 \
    SHIMMY_PODMAN_PRIVILEGED_CONNECTION=shimmy-rootful \
    SHIMMY_ABA_SSH_KEY="$ssh_key" \
    SHIMMY_ABA_PULL_SECRET="$pull_secret" \
    SHIMMY_ABA_MIRROR_DATA_DIR="$mirror_data" \
    run_in_repo ./commands/run-tool.sh aba --preview-shim -d mirror install)

  assert_contains "$output" "'--connection' 'shimmy-rootful'"
  assert_contains "$output" "'--privileged'"
  assert_contains "$output" "'--network' 'host'"
  assert_contains "$output" "'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  assert_contains "$output" "'-v' '$ssh_key:/tmp/shimmy-aba-ssh-key:ro'"
  assert_contains "$output" "'-v' '$pull_secret:/work/.pull-secret.json:ro'"
  assert_contains "$output" "'-v' '$mirror_data:/work/mirror/data:rw'"
  assert_contains "$output" "'-e' 'HOME=/work'"
  assert_not_contains "$output" SHIMMY_ABA_SSH_KEY
  assert_not_contains "$output" SHIMMY_ABA_PULL_SECRET
  assert_not_contains "$output" fixture-secret
  assert_not_contains "$output" "$HOME/.ssh"
  pass "aba operational preview requires explicit privilege and maps only exact inputs"
}

test_tools_aba_failure_before_podman() {
  setup_scenario
  fake_bin_dir=$SCENARIO_DIR/fake-bin
  fake_podman=$fake_bin_dir/podman
  podman_called=$SCENARIO_DIR/podman-called
  ca_bundle=$SCENARIO_DIR/host-ca-bundle.pem
  mkdir -p "$fake_bin_dir"
  printf '%s\n' fixture-ca > "$ca_bundle"
  printf '%s\n' '#!/bin/sh' ': > "$FAKE_PODMAN_CALLED"' 'exit 90' > "$fake_podman"
  chmod 0755 "$fake_podman"

  set +e
  output=$(PATH="$fake_bin_dir:/usr/bin:/bin" FAKE_PODMAN_CALLED="$podman_called" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" run_in_repo ./commands/run-tool.sh aba install 2>&1)
  status_code=$?
  set -e
  [ "$status_code" -ne 0 ] || fail_test "aba accepted an operational command without gates"
  assert_equals "$output" 'ERROR: operational ABA commands require SHIMMY_ABA_PRIVILEGED=1.'
  assert_path_not_exists "$podman_called"

  set +e
  output=$(PATH="$fake_bin_dir:/usr/bin:/bin" FAKE_PODMAN_CALLED="$podman_called" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_ABA_PRIVILEGED=1 SHIMMY_ABA_NETWORK=host SHIMMY_PODMAN_PRIVILEGED=1 SHIMMY_ABA_SSH_KEY=relative-key run_in_repo ./commands/run-tool.sh aba install 2>&1)
  status_code=$?
  set -e
  [ "$status_code" -ne 0 ] || fail_test "aba accepted an unsafe SSH key path"
  assert_equals "$output" 'ERROR: SHIMMY_ABA_SSH_KEY must name an absolute readable regular file: relative-key'
  assert_path_not_exists "$podman_called"

  set +e
  output=$(PATH="$fake_bin_dir:/usr/bin:/bin" FAKE_PODMAN_CALLED="$podman_called" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_ABA_PRIVILEGED=1 SHIMMY_ABA_NETWORK=bridge SHIMMY_PODMAN_PRIVILEGED=1 run_in_repo ./commands/run-tool.sh aba install 2>&1)
  status_code=$?
  set -e
  [ "$status_code" -ne 0 ] || fail_test "aba accepted an invalid network gate"
  assert_equals "$output" 'ERROR: operational ABA commands require SHIMMY_ABA_NETWORK=host.'
  assert_path_not_exists "$podman_called"

  set +e
  output=$(PATH="$fake_bin_dir:/usr/bin:/bin" FAKE_PODMAN_CALLED="$podman_called" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_ABA_PRIVILEGED=1 SHIMMY_ABA_NETWORK=host SHIMMY_PODMAN_PRIVILEGED=0 run_in_repo ./commands/run-tool.sh aba install 2>&1)
  status_code=$?
  set -e
  [ "$status_code" -ne 0 ] || fail_test "aba accepted an invalid privileged Podman gate"
  assert_equals "$output" 'ERROR: operational ABA commands require SHIMMY_PODMAN_PRIVILEGED=1.'
  assert_path_not_exists "$podman_called"

  set +e
  output=$(PATH="$fake_bin_dir:/usr/bin:/bin" FAKE_PODMAN_CALLED="$podman_called" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_ABA_PRIVILEGED=1 SHIMMY_ABA_NETWORK=host SHIMMY_PODMAN_PRIVILEGED=1 SHIMMY_ABA_PULL_SECRET=relative-secret run_in_repo ./commands/run-tool.sh aba install 2>&1)
  status_code=$?
  set -e
  [ "$status_code" -ne 0 ] || fail_test "aba accepted an unsafe pull-secret path"
  assert_equals "$output" 'ERROR: SHIMMY_ABA_PULL_SECRET must name an absolute readable regular file: relative-secret'
  assert_path_not_exists "$podman_called"

  set +e
  output=$(PATH="$fake_bin_dir:/usr/bin:/bin" FAKE_PODMAN_CALLED="$podman_called" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_ABA_PRIVILEGED=1 SHIMMY_ABA_NETWORK=host SHIMMY_PODMAN_PRIVILEGED=1 SHIMMY_ABA_MIRROR_DATA_DIR=relative-data run_in_repo ./commands/run-tool.sh aba install 2>&1)
  status_code=$?
  set -e
  [ "$status_code" -ne 0 ] || fail_test "aba accepted an unsafe mirror-data path"
  assert_equals "$output" 'ERROR: SHIMMY_ABA_MIRROR_DATA_DIR must name an absolute existing writable directory: relative-data'
  assert_path_not_exists "$podman_called"
  pass "aba rejects missing or invalid privilege controls and unsafe sensitive paths before Podman"
}

test_tools_aba_non_rootful_connection_stops_before_run() {
  setup_scenario
  fake_bin_dir=$SCENARIO_DIR/fake-bin
  fake_podman=$fake_bin_dir/podman
  podman_run_called=$SCENARIO_DIR/podman-run-called
  ca_bundle=$SCENARIO_DIR/host-ca-bundle.pem
  mkdir -p "$fake_bin_dir"
  printf '%s\n' fixture-ca > "$ca_bundle"
  printf '%s\n' '#!/bin/sh' 'if [ "$1" = "info" ]; then exit 0; fi' 'if [ "$1" = "--connection" ] && [ "$3" = "info" ]; then printf true; exit 0; fi' 'if [ "$1" = "run" ]; then : > "$FAKE_PODMAN_RUN_CALLED"; fi' 'exit 90' > "$fake_podman"
  chmod 0755 "$fake_podman"

  set +e
  output=$(PATH="$fake_bin_dir:/usr/bin:/bin" FAKE_PODMAN_RUN_CALLED="$podman_run_called" SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_ABA_PRIVILEGED=1 SHIMMY_ABA_NETWORK=host SHIMMY_PODMAN_PRIVILEGED=1 SHIMMY_PODMAN_PRIVILEGED_CONNECTION=not-rootful SHIMMY_ABA_IMAGE=example.invalid/shimmy/aba:test run_in_repo ./commands/run-tool.sh aba install 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "aba accepted a non-rootful privileged connection"
  assert_contains "$output" 'not a verified rootful Podman connection'
  assert_path_not_exists "$podman_run_called"
  pass "aba verifies rootful connection before Podman run"
}

test_tools_aba_run() {
  test_tools_aba_safe_help_preview
  test_tools_aba_operational_preview
  test_tools_aba_failure_before_podman
  test_tools_aba_non_rootful_connection_stops_before_run
}
