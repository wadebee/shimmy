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
  assert_file_executable "$ROOT_DIR/install.sh"
  assert_file_executable "$ROOT_DIR/tests/test.sh"
  assert_file_executable "$ROOT_DIR/tests/context-tree.sh"
  [ ! -x "$ROOT_DIR/lib/install/launcher-template.sh" ] || fail_test "launcher template must not be executable"

  for executable_file in "$ROOT_DIR"/commands/*.sh "$ROOT_DIR"/tools/*/versions/*/run.sh "$ROOT_DIR"/tools/*/versions/*/refresh.sh; do
    [ -f "$executable_file" ] || continue
    assert_file_executable "$executable_file"
  done
  pass "repository launchers, command entrypoints, runtimes, and refresh hooks have the required modes"
}

test_lib_runtime_source_checkout_contract() {
  setup_scenario
  valid_checkout=$SCENARIO_DIR/valid-checkout
  mkdir -p "$valid_checkout/commands" "$valid_checkout/lib/install" "$valid_checkout/tools"
  cp "$ROOT_DIR/install.sh" "$valid_checkout/install.sh"
  chmod 755 "$valid_checkout/install.sh"
  cp "$ROOT_DIR/lib/install/launcher-template.sh" "$valid_checkout/lib/install/launcher-template.sh"
  shimmy_upstream_checkout_validate "$valid_checkout" || fail_test "minimal current source checkout was rejected"

  for missing_path in install.sh commands lib tools lib/install/launcher-template.sh; do
    broken_checkout=$SCENARIO_DIR/broken-$(printf '%s' "$missing_path" | tr / -)
    cp -R "$valid_checkout" "$broken_checkout"
    if [ -d "$broken_checkout/$missing_path" ]; then
      rm -rf "$broken_checkout/$missing_path"
    else
      rm -f "$broken_checkout/$missing_path"
    fi
    invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$broken_checkout" || true)
    assert_contains "$invalid_reason" invalid_source_checkout
  done

  stale_checkout=$SCENARIO_DIR/stale-core-checkout
  mkdir -p "$stale_checkout/commands" "$stale_checkout/core/install" "$stale_checkout/tools"
  cp "$ROOT_DIR/install.sh" "$stale_checkout/install.sh"
  chmod 755 "$stale_checkout/install.sh"
  cp "$ROOT_DIR/lib/install/launcher-template.sh" "$stale_checkout/core/install/launcher-template.sh"
  assert_equals "$(shimmy_upstream_checkout_invalid_reason "$stale_checkout" || true)" invalid_source_checkout_missing_lib
  assert_path_not_exists "$valid_checkout/shimmy"
  pass "source-checkout validation requires the current bootstrap and lib layout without a repository launcher"
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
  test_lib_runtime_posix_syntax
  test_lib_runtime_executable_contract
  test_lib_runtime_source_checkout_contract
  test_lib_runtime_unreachable_guidance
}
