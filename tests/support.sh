#!/bin/sh
# Shared POSIX test support.

assert_contains() {
  haystack=$1
  needle=$2

  case "$haystack" in
    *"$needle"*)
      ;;
    *)
      printf 'Actual output:\n%s\n' "$haystack" >&2
      fail_test "expected output to contain: $needle"
      ;;
  esac
}

assert_dir_exists() {
  if [ ! -d "$1" ]; then
    fail_test "expected directory to exist: $1"
  fi
}

assert_equals() {
  actual=$1
  expected=$2

  if [ "$actual" != "$expected" ]; then
    fail_test "expected '$expected', got '$actual'"
  fi
}

assert_file_contains() {
  file_path=$1
  needle=$2

  [ -f "$file_path" ] || fail_test "expected file to exist: $file_path"
  file_contents=$(cat "$file_path")
  assert_contains "$file_contents" "$needle"
}

assert_file_not_contains() {
  file_path=$1
  needle=$2

  [ -f "$file_path" ] || fail_test "expected file to exist: $file_path"
  file_contents=$(cat "$file_path")
  assert_not_contains "$file_contents" "$needle"
}

assert_file_executable() {
  if [ ! -x "$1" ]; then
    fail_test "expected file to be executable: $1"
  fi
}

assert_file_mode() {
  file_path=$1
  expected_mode=$2

  if file_mode=$(stat -f '%Lp' "$file_path" 2>/dev/null); then
    :
  else
    file_mode=$(stat -c '%a' "$file_path")
  fi
  assert_equals "$file_mode" "$expected_mode"
}

assert_file_exists() {
  if [ ! -f "$1" ]; then
    fail_test "expected file to exist: $1"
  fi
}

assert_no_line_with_prefix() {
  haystack=$1
  prefix=$2

  while IFS= read -r haystack_line; do
    case "$haystack_line" in
      "$prefix"*)
        printf 'Actual output:\n%s\n' "$haystack" >&2
        fail_test "expected no line beginning with: $prefix"
        ;;
    esac
  done <<EOF
$haystack
EOF
}

assert_not_contains() {
  haystack=$1
  needle=$2

  case "$haystack" in
    *"$needle"*)
      fail_test "expected output not to contain: $needle"
      ;;
    *)
      ;;
  esac
}

assert_not_empty() {
  if [ -z "${1:-}" ]; then
    fail_test "expected output to be non-empty"
  fi
}

assert_path_not_exists() {
  if [ -e "$1" ]; then
    fail_test "expected path to be absent: $1"
  fi
}

assert_path_symlink() {
  if [ ! -L "$1" ]; then
    fail_test "expected path to be a symlink: $1"
  fi
}

assert_regular_file_not_symlink() {
  if [ ! -f "$1" ] || [ -L "$1" ]; then
    fail_test "expected regular non-symlink file: $1"
  fi
}

fail_test() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

run_in_repo() {
  (
    cd "$ROOT_DIR"
    "$@"
  )
}

bootstrap_default() {
  run_in_repo env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile default --no-startup --no-skills "$@"
}

bootstrap_upstream() {
  run_in_repo env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile upstream --no-startup --no-skills "$@"
}

default_shimmy() {
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/shimmy" "$@"
}

upstream_shimmy() {
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$UPSTREAM_PROFILE_ROOT/bin/shimmy" "$@"
}

profile_manifest_value() {
  manifest_file=$1
  manifest_key=$2
  sed -n "s/^$manifest_key=//p" "$manifest_file" | sed -n '1p'
}

setup_scenario() {
  SCENARIO_DIR=$(mktemp -d "$TMP_ROOT/scenario.XXXXXX")
  HOME_DIR=$SCENARIO_DIR/home
  XDG_CONFIG_HOME_DIR=$SCENARIO_DIR/config
  DEFAULT_PROFILE_ROOT=$XDG_CONFIG_HOME_DIR/shimmy/profiles/default
  UPSTREAM_PROFILE_ROOT=$XDG_CONFIG_HOME_DIR/shimmy/profiles/upstream
  WORK_DIR=$SCENARIO_DIR/work
  mkdir -p "$HOME_DIR" "$XDG_CONFIG_HOME_DIR" "$WORK_DIR"
}

shimmy_test_cleanup() {
  rm -rf "$TMP_ROOT"
}

tracked_shell_file_list() {
  for shell_file in \
    "$ROOT_DIR/install.sh" \
    "$ROOT_DIR"/commands/*.sh \
    "$ROOT_DIR"/lib/*/*.sh \
    "$ROOT_DIR"/tests/*.sh \
    "$ROOT_DIR"/tests/*/*.sh \
    "$ROOT_DIR"/tools/*/tests/*.sh \
    "$ROOT_DIR"/tools/*/versions/*/*.sh
  do
    [ -f "$shell_file" ] || continue
    printf '%s\n' "$shell_file"
  done
}
