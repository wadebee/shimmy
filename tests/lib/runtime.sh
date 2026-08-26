#!/bin/sh
# Shared runtime helper tests.

test_lib_runtime_platform() {
  helper_file=$ROOT_DIR/lib/runtime/podman.sh
  for platform_case in \
    'Linux x86_64 linux/amd64' \
    'Linux amd64 linux/amd64' \
    'Linux aarch64 linux/arm64' \
    'Linux arm64 linux/arm64' \
    'Darwin x86_64 linux/amd64' \
    'Darwin amd64 linux/amd64' \
    'Darwin aarch64 linux/arm64' \
    'Darwin arm64 linux/arm64'; do
    set -- $platform_case
    resolved_platform=$(SHIMMY_TEST_OS=$1 SHIMMY_TEST_ARCH=$2 /bin/sh -c '. "$1"; shimmy_podman_platform_resolve; printf "%s\n" "$SHIMMY_PODMAN_PLATFORM"' sh "$helper_file")
    assert_equals "$resolved_platform" "$3"
  done

  required_platforms=$(/bin/sh -c '. "$1"; shimmy_podman_required_platforms_print' sh "$helper_file")
  assert_equals "$required_platforms" 'linux/amd64
linux/arm64'
  assert_equals "$(/bin/sh -c '. "$1"; shimmy_podman_platform_tag_render linux/arm64' sh "$helper_file")" linux-arm64
  pass "Podman platform resolves from supported host OS and architecture aliases"
}

test_lib_runtime_platform_failures() {
  helper_file=$ROOT_DIR/lib/runtime/podman.sh

  for platform_case in \
    'Plan9 amd64 unsupported host operating system' \
    'Linux riscv64 unsupported host architecture' \
    '__EMPTY__ amd64 unable to detect host operating system' \
    'Linux __EMPTY__ unable to detect host architecture'; do
    set -- $platform_case
    host_os=$1
    host_arch=$2
    expected_message=$3
    shift 3
    expected_message="$expected_message $*"
    [ "$host_os" != __EMPTY__ ] || host_os=
    [ "$host_arch" != __EMPTY__ ] || host_arch=

    set +e
    output=$(SHIMMY_TEST_OS=$host_os SHIMMY_TEST_ARCH=$host_arch /bin/sh -c '. "$1"; SHIMMY_PODMAN_PLATFORM=stale; shimmy_podman_platform_resolve; status=$?; printf "platform=%s\n" "$SHIMMY_PODMAN_PLATFORM"; exit "$status"' sh "$helper_file" 2>&1)
    status_code=$?
    set -e

    [ "$status_code" -ne 0 ] || fail_test "unsupported host unexpectedly resolved: $platform_case"
    assert_contains "$output" "$expected_message"
    assert_contains "$output" 'platform='
    assert_not_contains "$output" 'platform=linux/'
  done
  pass "Podman platform resolution fails closed for unreadable and unsupported hosts"
}

test_lib_runtime_preview_helpers() {
  helper_file=$ROOT_DIR/lib/runtime/podman.sh

  /bin/sh -c '. "$1"; shimmy_podman_preview_args_include one --preview-shim two' sh "$helper_file" || fail_test "preview flag was not detected"
  if /bin/sh -c '. "$1"; shimmy_podman_preview_args_include one --not-preview two' sh "$helper_file"; then
    fail_test "non-preview flag was detected"
  fi

  output=$(/bin/sh -c '. "$1"; shimmy_podman_command_preview_print podman run --preview-shim "has space"' sh "$helper_file")
  assert_equals "$output" "'podman' 'run' 'has space'"
  pass "Podman preview helpers strip and quote preview commands"
}

test_lib_runtime_ca_bundle_prepare_disabled() {
  helper_file=$ROOT_DIR/lib/runtime/podman.sh

  for disabled_state in unset empty; do
    output=$(/bin/sh -c '
      . "$1"
      SHIMMY_PODMAN_CA_BUNDLE_SOURCE=stale-source
      SHIMMY_PODMAN_CA_BUNDLE_TARGET=stale-target
      SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT=stale-assignment
      if [ "$2" = unset ]; then
        unset SHIMMY_HOST_CA_BUNDLE
      else
        SHIMMY_HOST_CA_BUNDLE=
      fi
      shimmy_podman_ca_bundle_prepare SSL_CERT_FILE
      printf "source=%s\ntarget=%s\nassignment=%s\n" \
        "$SHIMMY_PODMAN_CA_BUNDLE_SOURCE" \
        "$SHIMMY_PODMAN_CA_BUNDLE_TARGET" \
        "$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"
    ' sh "$helper_file" "$disabled_state")
    assert_equals "$output" 'source=
target=
assignment='
  done

  pass "CA bundle preparation treats unset and empty input as disabled and clears stale state"
}

test_lib_runtime_ca_bundle_prepare_paths() {
  setup_scenario
  helper_file=$ROOT_DIR/lib/runtime/podman.sh
  bundle_with_spaces="$SCENARIO_DIR/host CA bundle.pem"
  bundle_parent=$SCENARIO_DIR/actual-ca-parent
  bundle_parent_link=$SCENARIO_DIR/linked-ca-parent
  linked_bundle=$bundle_parent_link/bundle.pem
  printf '%s\n' fixture-ca > "$bundle_with_spaces"
  mkdir -p "$bundle_parent"
  printf '%s\n' linked-fixture-ca > "$bundle_parent/bundle.pem"
  ln -s "$bundle_parent" "$bundle_parent_link"

  for bundle_path in "$bundle_with_spaces" "$linked_bundle"; do
    output=$(SHIMMY_HOST_CA_BUNDLE=$bundle_path /bin/sh -c '
      . "$1"
      shimmy_podman_ca_bundle_prepare NODE_EXTRA_CA_CERTS
      printf "source=%s\ntarget=%s\nassignment=%s\n" \
        "$SHIMMY_PODMAN_CA_BUNDLE_SOURCE" \
        "$SHIMMY_PODMAN_CA_BUNDLE_TARGET" \
        "$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"
    ' sh "$helper_file")
    assert_equals "$output" "source=$bundle_path
target=/tmp/shimmy-host-ca-bundle.pem
assignment=NODE_EXTRA_CA_CERTS=/tmp/shimmy-host-ca-bundle.pem"
  done

  pass "CA bundle preparation preserves paths containing spaces and symlinked parent components"
}

test_lib_runtime_ca_bundle_prepare_name_failure() {
  helper_file=$ROOT_DIR/lib/runtime/podman.sh

  set +e
  output=$(SHIMMY_HOST_CA_BUNDLE= /bin/sh -c '
    . "$1"
    SHIMMY_PODMAN_CA_BUNDLE_SOURCE=stale-source
    SHIMMY_PODMAN_CA_BUNDLE_TARGET=stale-target
    SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT=stale-assignment
    shimmy_podman_ca_bundle_prepare "BAD-NAME"
    status_code=$?
    printf "source=%s\ntarget=%s\nassignment=%s\n" \
      "$SHIMMY_PODMAN_CA_BUNDLE_SOURCE" \
      "$SHIMMY_PODMAN_CA_BUNDLE_TARGET" \
      "$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"
    exit "$status_code"
  ' sh "$helper_file" 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "malformed native CA environment name unexpectedly passed"
  assert_equals "$output" 'ERROR: invalid native CA environment variable name: BAD-NAME
source=
target=
assignment='
  pass "CA bundle preparation rejects malformed native environment names after clearing stale state"
}

test_lib_runtime_ca_bundle_prepare_path_failures() {
  setup_scenario
  helper_file=$ROOT_DIR/lib/runtime/podman.sh
  bundle_contents=fixture-ca-contents-must-not-appear
  relative_bundle=relative-ca-bundle.pem
  missing_bundle=$SCENARIO_DIR/missing-ca-bundle.pem
  directory_bundle=$SCENARIO_DIR/ca-bundle-directory
  unreadable_bundle=$SCENARIO_DIR/unreadable-ca-bundle.pem
  printf '%s\n' "$bundle_contents" > "$SCENARIO_DIR/$relative_bundle"
  mkdir -p "$directory_bundle"
  printf '%s\n' "$bundle_contents" > "$directory_bundle/contents.pem"
  printf '%s\n' "$bundle_contents" > "$unreadable_bundle"

  for invalid_bundle in "$relative_bundle" "$missing_bundle" "$directory_bundle"; do
    set +e
    output=$(cd "$SCENARIO_DIR" && SHIMMY_HOST_CA_BUNDLE=$invalid_bundle /bin/sh -c '
      . "$1"
      SHIMMY_PODMAN_CA_BUNDLE_SOURCE=stale-source
      SHIMMY_PODMAN_CA_BUNDLE_TARGET=stale-target
      SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT=stale-assignment
      shimmy_podman_ca_bundle_prepare SSL_CERT_FILE
      status_code=$?
      printf "source=%s\ntarget=%s\nassignment=%s\n" \
        "$SHIMMY_PODMAN_CA_BUNDLE_SOURCE" \
        "$SHIMMY_PODMAN_CA_BUNDLE_TARGET" \
        "$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"
      exit "$status_code"
    ' sh "$helper_file" 2>&1)
    status_code=$?
    set -e

    [ "$status_code" -ne 0 ] || fail_test "invalid CA bundle unexpectedly passed: $invalid_bundle"
    assert_equals "$output" "ERROR: SHIMMY_HOST_CA_BUNDLE must name an absolute readable CA bundle file: $invalid_bundle
source=
target=
assignment="
    assert_not_contains "$output" "$bundle_contents"
  done

  chmod 000 "$unreadable_bundle"
  if [ ! -r "$unreadable_bundle" ]; then
    set +e
    output=$(SHIMMY_HOST_CA_BUNDLE=$unreadable_bundle /bin/sh -c '
      . "$1"
      shimmy_podman_ca_bundle_prepare SSL_CERT_FILE
    ' sh "$helper_file" 2>&1)
    status_code=$?
    set -e
    [ "$status_code" -ne 0 ] || fail_test "unreadable CA bundle unexpectedly passed"
    assert_equals "$output" "ERROR: SHIMMY_HOST_CA_BUNDLE must name an absolute readable CA bundle file: $unreadable_bundle"
    assert_not_contains "$output" "$bundle_contents"
  fi
  chmod 0600 "$unreadable_bundle"

  pass "CA bundle preparation rejects invalid configured paths without printing file contents"
}

test_lib_runtime_profile_affinity() {
  setup_scenario
  affinity_profile_name=team-one
  affinity_profile_root=$XDG_CONFIG_HOME_DIR/shimmy/profiles/$affinity_profile_name
  affinity_runtime_dir=$affinity_profile_root/lib/runtime
  fake_podman=$SCENARIO_DIR/podman
  fake_log=$SCENARIO_DIR/podman.log
  mkdir -p "$affinity_runtime_dir" "$affinity_profile_root/lib/common" "$affinity_profile_root/lib/profile" \
    "$affinity_profile_root/lib/registries" "$affinity_profile_root/lib/engine" \
    "$HOME_DIR/.agents/skills" "$XDG_CONFIG_HOME_DIR/shimmy/engines/shared"
  cp "$ROOT_DIR/lib/common/common.sh" "$affinity_profile_root/lib/common/common.sh"
  cp "$ROOT_DIR/lib/profile/profile.sh" "$affinity_profile_root/lib/profile/profile.sh"
  cp "$ROOT_DIR/lib/profile/state.sh" "$affinity_profile_root/lib/profile/state.sh"
  cp "$ROOT_DIR/lib/profile/activation.sh" "$affinity_profile_root/lib/profile/activation.sh"
  cp "$ROOT_DIR/lib/registries/registries.sh" "$affinity_profile_root/lib/registries/registries.sh"
  for affinity_engine_helper in state podman ownership projection registry; do
    cp "$ROOT_DIR/lib/engine/$affinity_engine_helper.sh" \
      "$affinity_profile_root/lib/engine/$affinity_engine_helper.sh"
  done
  printf '%s\n' \
    'shimmy_install_manifest_version=2' \
    'shimmy_install_layout=profile-materialized-root' \
    'shimmy_profile_manifest_version=2' \
    "shimmy_profile_name=$affinity_profile_name" \
    > "$affinity_profile_root/install-manifest.txt"
  shimmy_registries_config_render "$affinity_profile_name" '' > "$affinity_profile_root/registries.conf"
  chmod 0644 "$affinity_profile_root/registries.conf"
  shimmy_engine_binding_write "$affinity_profile_root/engine-binding.conf" \
    "$affinity_profile_name" shared shared
  shimmy_active_profile_render "$affinity_profile_name" "$HOME_DIR/.agents/skills" \
    > "$XDG_CONFIG_HOME_DIR/shimmy/active-profile.conf"
  chmod 0644 "$XDG_CONFIG_HOME_DIR/shimmy/active-profile.conf"
  profile_activation_fake_create "$fake_podman"
  : > "$fake_log"
  affinity_machines='shimmy|true'
  affinity_connections='shimmy|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_PODMAN_LOG=$fake_log FAKE_MACHINE_LIST=$affinity_machines \
    FAKE_CONNECTION_LIST=$affinity_connections \
    SHIMMY_TEST_ENGINE_PODMAN_BIN=$fake_podman
  export FAKE_PODMAN_LOG FAKE_MACHINE_LIST FAKE_CONNECTION_LIST SHIMMY_TEST_ENGINE_PODMAN_BIN
  shimmy_engine_podman_bin_require
  affinity_identity=$(shimmy_engine_podman_machine_identity_fingerprint_render shimmy shimmy)
  affinity_token=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  affinity_engine_root=$XDG_CONFIG_HOME_DIR/shimmy/engines/shared
  shimmy_engine_record_write "$affinity_engine_root/engine.conf" shared darwin-machine \
    installation shimmy shimmy applehv shimmy-created "$affinity_token" "$affinity_identity"
  cp "$affinity_profile_root/registries.conf" "$affinity_engine_root/registries.conf"
  chmod 0644 "$affinity_engine_root/registries.conf"
  affinity_source_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$affinity_profile_root/registries.conf")
  affinity_effective_fingerprint=$(shimmy_engine_projection_effective_fingerprint_render '')
  shimmy_engine_projection_render shared "$affinity_profile_name" \
    "$affinity_profile_root/registries.conf" "$affinity_source_fingerprint" \
    "$affinity_effective_fingerprint" "$affinity_effective_fingerprint" > \
    "$affinity_engine_root/projection.conf"
  chmod 0644 "$affinity_engine_root/projection.conf"

  test_affinity_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" PATH="$SCENARIO_DIR:/usr/bin:/bin" \
    SHIMMY_TEST_OS=Darwin SHIMMY_RUNTIME_DIR="$affinity_runtime_dir" FAKE_PODMAN_LOG="$fake_log" \
    FAKE_MACHINE_LIST="$affinity_machines" FAKE_CONNECTION_LIST="$affinity_connections" \
    FAKE_DARWIN_PROJECTION_STATE=current /bin/sh -c \
    'set -e; . "$1"; shimmy_podman_bin_require; shimmy_podman_profile_affinity_require; printf profile-active-ok' \
    sh "$ROOT_DIR/lib/runtime/podman.sh")
  assert_equals "$test_affinity_output" profile-active-ok

  shimmy_active_profile_render default "$HOME_DIR/.agents/skills" \
    > "$XDG_CONFIG_HOME_DIR/shimmy/active-profile.conf"
  chmod 0644 "$XDG_CONFIG_HOME_DIR/shimmy/active-profile.conf"
  set +e
  test_inactive_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" PATH="$SCENARIO_DIR:/usr/bin:/bin" \
    SHIMMY_TEST_OS=Darwin SHIMMY_RUNTIME_DIR="$affinity_runtime_dir" FAKE_PODMAN_LOG="$fake_log" \
    FAKE_MACHINE_LIST="$affinity_machines" FAKE_CONNECTION_LIST="$affinity_connections" \
    /bin/sh -c '. "$1"; shimmy_podman_bin_require; shimmy_podman_profile_affinity_require' \
    sh "$ROOT_DIR/lib/runtime/podman.sh" 2>&1)
  test_inactive_status=$?
  set -e
  [ "$test_inactive_status" -ne 0 ] || fail_test 'inactive version-2 arbitrary profile passed runtime affinity'
  assert_contains "$test_inactive_output" 'active record belongs to another profile'
  pass 'two profiles sharing one engine still require invoking-profile active-record affinity'
}

test_lib_runtime_posix_syntax() {
  command -v dash >/dev/null 2>&1 || fail_test "dash is required for parser checks"

  parsed_file_count=0
  for parse_file in $(tracked_shell_file_list); do
    dash -n "$parse_file"
    parsed_file_count=$((parsed_file_count + 1))
  done
  [ "$parsed_file_count" -gt 0 ] || fail_test "expected shell files for parser checks"
  pass "dash parse checks"
}

test_lib_runtime_executable_contract() {
  assert_file_executable "$ROOT_DIR/bootstrap.sh"
  assert_file_executable "$ROOT_DIR/tests/test.sh"
  assert_file_executable "$ROOT_DIR/tests/context-tree.sh"
  [ ! -x "$ROOT_DIR/lib/install/launcher-template.sh" ] || fail_test "launcher template must not be executable"

  for executable_file in "$ROOT_DIR"/commands/*.sh "$ROOT_DIR"/tools/*/versions/*/run.sh "$ROOT_DIR"/tools/*/versions/*/refresh.sh; do
    [ -f "$executable_file" ] || continue
    assert_file_executable "$executable_file"
  done
  pass "repository launchers, command entrypoints, runtimes, and refresh hooks have the required modes"
}

test_lib_runtime_unreachable_guidance() {
  helper_file=$ROOT_DIR/lib/runtime/podman.sh
  output=$(/bin/sh -c '. "$1"; shimmy_podman_failure_print_unreachable "the rg shim" "/opt/podman/bin/podman"' sh "$helper_file" 2>&1)

  assert_contains "$output" 'AI Agent note: if `podman info` succeeds but this shim still fails'
  assert_contains "$output" '["rg","--version"] or ["./commands/run-tool.sh","rg","--version"]'
  assert_contains "$output" 'Approving `podman info` alone does not approve Podman access through a Shimmy wrapper.'
  pass "Podman unreachable guidance includes exact wrapper approval hints"
}

test_lib_runtime_run() {
  test_lib_runtime_platform
  test_lib_runtime_platform_failures
  test_lib_runtime_preview_helpers
  test_lib_runtime_ca_bundle_prepare_disabled
  test_lib_runtime_ca_bundle_prepare_paths
  test_lib_runtime_ca_bundle_prepare_name_failure
  test_lib_runtime_ca_bundle_prepare_path_failures
  test_lib_runtime_profile_affinity
  test_lib_runtime_posix_syntax
  test_lib_runtime_executable_contract
  test_lib_runtime_unreachable_guidance
}
