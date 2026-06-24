#!/bin/sh
# Shared runtime helper tests.

test_core_runtime_platform() {
  helper_file=$ROOT_DIR/core/runtime/podman.sh
  linux_platform=$(SHIMMY_TEST_OS=Linux /bin/sh -c '. "$1"; shimmy_podman_platform_resolve; printf "%s\n" "$SHIMMY_PODMAN_PLATFORM"' sh "$helper_file")
  darwin_platform=$(SHIMMY_TEST_OS=Darwin /bin/sh -c '. "$1"; shimmy_podman_platform_resolve; printf "%s\n" "$SHIMMY_PODMAN_PLATFORM"' sh "$helper_file")

  assert_equals "$linux_platform" linux/amd64
  assert_equals "$darwin_platform" linux/arm64
  assert_equals "$(/bin/sh -c '. "$1"; shimmy_podman_platform_tag_render linux/arm64' sh "$helper_file")" linux-arm64
  pass "Podman platform resolves from host OS"
}

test_core_runtime_preview_helpers() {
  helper_file=$ROOT_DIR/core/runtime/podman.sh

  /bin/sh -c '. "$1"; shimmy_podman_preview_args_include one --preview-shim two' sh "$helper_file" || fail_test "preview flag was not detected"
  if /bin/sh -c '. "$1"; shimmy_podman_preview_args_include one --not-preview two' sh "$helper_file"; then
    fail_test "non-preview flag was detected"
  fi

  output=$(/bin/sh -c '. "$1"; shimmy_podman_command_preview_print podman run --preview-shim "has space"' sh "$helper_file")
  assert_equals "$output" "'podman' 'run' 'has space'"
  pass "Podman preview helpers strip and quote preview commands"
}

test_core_runtime_posix_syntax() {
  command -v dash >/dev/null 2>&1 || fail_test "dash is required for parser checks"

  parsed_file_count=0
  for parse_file in $(tracked_shell_file_list); do
    dash -n "$parse_file"
    parsed_file_count=$((parsed_file_count + 1))
  done
  [ "$parsed_file_count" -gt 0 ] || fail_test "expected shell files for parser checks"
  pass "dash parse checks"
}

test_core_runtime_unreachable_guidance() {
  helper_file=$ROOT_DIR/core/runtime/podman.sh
  output=$(/bin/sh -c '. "$1"; shimmy_podman_failure_print_unreachable "the rg shim" "/opt/podman/bin/podman"' sh "$helper_file" 2>&1)

  assert_contains "$output" 'AI Agent note: if `podman info` succeeds but this shim still fails'
  assert_contains "$output" '["rg","--version"] or ["./commands/run-tool.sh","rg","--version"]'
  assert_contains "$output" 'Approving `podman info` alone does not approve Podman access through a Shimmy wrapper.'
  pass "Podman unreachable guidance includes exact wrapper approval hints"
}

test_core_runtime_run() {
  test_core_runtime_platform
  test_core_runtime_preview_helpers
  test_core_runtime_posix_syntax
  test_core_runtime_unreachable_guidance
}
