#!/bin/sh
# Version-local update refresh hook coverage.

test_core_update_refresh_hook_contract() {
  for version_dir in "$ROOT_DIR"/tools/*/versions/*; do
    [ -d "$version_dir" ] || continue
    refresh_hook=$version_dir/refresh.sh
    assert_file_executable "$refresh_hook"

    set +e
    output=$("$refresh_hook" unsupported 2>&1)
    status_code=$?
    set -e
    [ "$status_code" -ne 0 ] || fail_test "refresh hook accepted an unsupported action: $refresh_hook"
    assert_contains "$output" "Usage: refresh.sh pull|build"

    if [ -d "$version_dir/container" ]; then
      "$refresh_hook" pull
    else
      "$refresh_hook" build
    fi
  done

  pass "version refresh hooks validate actions and skip irrelevant refreshes"
}

test_core_update_refresh_hook_dispatch() {
  setup_scenario
  install_core_dir=$SCENARIO_DIR/core
  refresh_hook_dir=$install_core_dir/tools/aws/versions/2.31
  refresh_hook=$refresh_hook_dir/refresh.sh
  mkdir -p "$refresh_hook_dir"
  printf '%s\n' '#!/bin/sh' 'printf "%s:%s\\n" "$SHIMMY_PROFILE_ACTIVE" "$1"' > "$refresh_hook"
  chmod 755 "$refresh_hook"

  output=$(SHIMMY_INSTALL_CORE_DIR="$install_core_dir" SHIMMY_TOOLS_DIR="$ROOT_DIR/tools" /bin/sh -c '
    fail() {
      printf "ERROR: %s\\n" "$*" >&2
      exit 1
    }
    . "$1"
    . "$2"
    shimmy_update_refresh_hooks_run pull default aws_2_31
  ' sh "$ROOT_DIR/core/catalog/catalog.sh" "$ROOT_DIR/core/update/refresh.sh")

  assert_equals "$output" "default:pull"

  set +e
  output=$(SHIMMY_INSTALL_CORE_DIR="$install_core_dir" SHIMMY_TOOLS_DIR="$ROOT_DIR/tools" /bin/sh -c '
    fail() {
      printf "ERROR: %s\\n" "$*" >&2
      exit 1
    }
    . "$1"
    . "$2"
    shimmy_update_refresh_hooks_run pull default jq_1_8
  ' sh "$ROOT_DIR/core/catalog/catalog.sh" "$ROOT_DIR/core/update/refresh.sh" 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "refresh dispatch accepted a missing hook"
  assert_contains "$output" "missing refresh hook for jq_1_8"
  pass "update dispatches only installed version-local refresh hooks"
}

test_core_update_run() {
  test_core_update_refresh_hook_contract
  test_core_update_refresh_hook_dispatch
}
