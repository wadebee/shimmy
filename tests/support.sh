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

run_in_clean_source() {
  (
    cd "$SHIMMY_TEST_CLEAN_SOURCE_ROOT"
    "$@"
  )
}

bootstrap_default() {
  (
    cd "$SHIMMY_TEST_CLEAN_SOURCE_ROOT"
    if [ -f "$DEFAULT_PROFILE_ROOT/install-manifest.txt" ] || [ -L "$DEFAULT_PROFILE_ROOT/install-manifest.txt" ]; then
      env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile default "$@"
    else
      env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile default --no-startup "$@"
    fi
  )
}

bootstrap_upstream() {
  run_in_repo env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile upstream "$@"
}

default_shimmy() {
  if [ "${1:-}" = status ]; then
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      SHIMMY_TEST_PROFILE_OS="${SHIMMY_TEST_PROFILE_OS:-Unsupported}" \
      "$DEFAULT_PROFILE_ROOT/bin/shimmy" "$@"
    return
  fi
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/shimmy" "$@"
}

upstream_shimmy() {
  if [ "${1:-}" = status ]; then
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      SHIMMY_TEST_PROFILE_OS="${SHIMMY_TEST_PROFILE_OS:-Unsupported}" \
      "$UPSTREAM_PROFILE_ROOT/bin/shimmy" "$@"
    return
  fi
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

setup_scenario_with_profiles() {
  setup_scenario
  mkdir -p "$XDG_CONFIG_HOME_DIR/shimmy/profiles"
  test_fixture_tree_copy "$SHIMMY_TEST_CATALOG_FIXTURES_ROOT" "$XDG_CONFIG_HOME_DIR/shimmy/catalogs"

  for profile_name in "$@"; do
    case "$profile_name" in
      default)
        profile_target=$DEFAULT_PROFILE_ROOT
        ;;
      upstream)
        profile_target=$UPSTREAM_PROFILE_ROOT
        ;;
      *)
        fail_test "unknown pristine profile fixture: $profile_name"
        ;;
    esac

    profile_source=$SHIMMY_TEST_PROFILE_FIXTURES_ROOT/$profile_name
    test_fixture_tree_copy "$profile_source" "$profile_target"

    shell_init_file=$profile_target/shell-init.sh
    shell_init_tmp=$profile_target/.shell-init.sh.fixture.tmp
    quoted_bin_dir=$(shimmy_quote_shell_word "$profile_target/bin")
    {
      printf 'shimmy_shell_init_bin_dir=%s\n' "$quoted_bin_dir"
      sed -n '2,$p' "$shell_init_file"
    } > "$shell_init_tmp"
    mv "$shell_init_tmp" "$shell_init_file"
    chmod 644 "$shell_init_file"

    shimmy_profile_manifest_validate "$profile_target/install-manifest.txt" "$profile_name" ||
      fail_test "invalid cloned $profile_name profile fixture"
    assert_file_contains "$shell_init_file" "shimmy_shell_init_bin_dir=$quoted_bin_dir"
  done
}

test_fixture_copy_on_write_detect() {
  test_fixture_copy_probe=$TMP_ROOT/.copy-on-write-probe
  SHIMMY_TEST_COPY_ON_WRITE=0

  [ ! -e "$test_fixture_copy_probe" ] && [ ! -L "$test_fixture_copy_probe" ] ||
    fail_test "copy-on-write probe target already exists: $test_fixture_copy_probe"
  if cp -c "$ROOT_DIR/catalog.conf" "$test_fixture_copy_probe" 2>/dev/null; then
    SHIMMY_TEST_COPY_ON_WRITE=1
  fi
  rm -f "$test_fixture_copy_probe"
}

test_fixture_tree_copy() {
  test_fixture_copy_source=${1:-}
  test_fixture_copy_target=${2:-}

  [ "$#" -eq 2 ] || fail_test "fixture tree copy requires source and target"
  [ -n "$test_fixture_copy_source" ] || fail_test "fixture tree copy source is empty"
  [ -n "$test_fixture_copy_target" ] || fail_test "fixture tree copy target is empty"
  [ "$test_fixture_copy_source" != / ] || fail_test "fixture tree copy source cannot be root"
  [ "$test_fixture_copy_target" != / ] || fail_test "fixture tree copy target cannot be root"
  [ -d "$test_fixture_copy_source" ] && [ ! -L "$test_fixture_copy_source" ] ||
    fail_test "fixture tree copy source is not a regular directory: $test_fixture_copy_source"
  [ ! -e "$test_fixture_copy_target" ] && [ ! -L "$test_fixture_copy_target" ] ||
    fail_test "fixture tree copy target already exists: $test_fixture_copy_target"

  test_fixture_copy_source_real=$(cd -- "$test_fixture_copy_source" && pwd -P) ||
    fail_test "unable to resolve fixture tree copy source: $test_fixture_copy_source"
  test_fixture_copy_target_parent=${test_fixture_copy_target%/*}
  test_fixture_copy_target_name=${test_fixture_copy_target##*/}
  [ -n "$test_fixture_copy_target_parent" ] &&
    [ "$test_fixture_copy_target_parent" != "$test_fixture_copy_target" ] &&
    [ -n "$test_fixture_copy_target_name" ] &&
    [ "$test_fixture_copy_target_name" != . ] &&
    [ "$test_fixture_copy_target_name" != .. ] ||
    fail_test "fixture tree copy target is not an absolute child path: $test_fixture_copy_target"
  [ -d "$test_fixture_copy_target_parent" ] ||
    fail_test "fixture tree copy target parent is missing: $test_fixture_copy_target_parent"
  test_fixture_copy_target_parent_real=$(cd -- "$test_fixture_copy_target_parent" && pwd -P) ||
    fail_test "unable to resolve fixture tree copy target parent: $test_fixture_copy_target_parent"
  test_fixture_copy_target_real=$test_fixture_copy_target_parent_real/$test_fixture_copy_target_name

  case "$test_fixture_copy_target_real" in
    "$TMP_ROOT"/*)
      ;;
    *)
      fail_test "fixture tree copy target is outside the session root: $test_fixture_copy_target"
      ;;
  esac
  [ "$test_fixture_copy_target_real" != "$ROOT_DIR" ] ||
    fail_test "fixture tree copy target cannot be the repository: $test_fixture_copy_target"
  case "$test_fixture_copy_target_real" in
    "$test_fixture_copy_source_real"|"$test_fixture_copy_source_real"/*)
      fail_test "fixture tree copy target cannot equal or descend from its source: $test_fixture_copy_target"
      ;;
  esac

  if [ "${SHIMMY_TEST_COPY_ON_WRITE:-0}" -eq 1 ]; then
    cp -cR "$test_fixture_copy_source_real" "$test_fixture_copy_target_real" ||
      fail_test "unable to clone fixture tree: $test_fixture_copy_source_real"
  else
    cp -R "$test_fixture_copy_source_real" "$test_fixture_copy_target_real" ||
      fail_test "unable to copy fixture tree: $test_fixture_copy_source_real"
  fi
}

setup_clean_source_fixture() {
  clean_source_target=$1
  test_fixture_tree_copy "$ROOT_DIR" "$clean_source_target"
  [ -d "$clean_source_target/.git" ] || fail_test "copied source fixture is missing Git metadata"
  rm -rf "$clean_source_target/.git"
  git -C "$clean_source_target" init -q
  git -C "$clean_source_target" config user.email shimmy-tests@example.invalid
  git -C "$clean_source_target" config user.name 'Shimmy Tests'
  git -C "$clean_source_target" add -A
  git -C "$clean_source_target" commit -qm fixture
}

setup_session_profile_fixtures() {
  SHIMMY_TEST_PROFILE_FIXTURES_ROOT=$TMP_ROOT/profile-fixtures
  SHIMMY_TEST_CATALOG_FIXTURES_ROOT=$TMP_ROOT/catalog-fixtures
  SHIMMY_TEST_CLEAN_SOURCE_ROOT=$TMP_ROOT/clean-source
  fixture_home=$TMP_ROOT/profile-fixture-home
  fixture_config=$TMP_ROOT/profile-fixture-config
  HOME_DIR=$fixture_home
  XDG_CONFIG_HOME_DIR=$fixture_config
  DEFAULT_PROFILE_ROOT=$fixture_config/shimmy/profiles/default
  UPSTREAM_PROFILE_ROOT=$fixture_config/shimmy/profiles/upstream

  mkdir -p "$fixture_home" "$fixture_config" "$SHIMMY_TEST_PROFILE_FIXTURES_ROOT"
  test_fixture_copy_on_write_detect
  setup_clean_source_fixture "$SHIMMY_TEST_CLEAN_SOURCE_ROOT"

  (
    cd "$SHIMMY_TEST_CLEAN_SOURCE_ROOT"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile default --no-startup
  ) >/dev/null 2>&1
  bootstrap_upstream >/dev/null 2>&1
  mv "$DEFAULT_PROFILE_ROOT" "$SHIMMY_TEST_PROFILE_FIXTURES_ROOT/default"
  mv "$UPSTREAM_PROFILE_ROOT" "$SHIMMY_TEST_PROFILE_FIXTURES_ROOT/upstream"
  mv "$fixture_config/shimmy/catalogs" "$SHIMMY_TEST_CATALOG_FIXTURES_ROOT"
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
