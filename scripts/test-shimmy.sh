#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
PODMAN_HELPER_FILE=$ROOT_DIR/lib/shims/shimmy-podman.sh
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/shimmy-test.XXXXXX")
TEST_COUNT=0

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT HUP INT TERM

pass() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

fail_test() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

if [ ! -f "$PODMAN_HELPER_FILE" ]; then
  fail_test "missing Podman helper: $PODMAN_HELPER_FILE"
fi

# shellcheck source=lib/shims/shimmy-podman.sh
. "$PODMAN_HELPER_FILE"

assert_contains() {
  haystack=$1
  needle=$2

  case "$haystack" in
    *"$needle"*)
      ;;
    *)
      fail_test "expected output to contain: $needle"
      ;;
  esac
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

assert_file_exists() {
  if [ ! -f "$1" ]; then
    fail_test "expected file to exist: $1"
  fi
}

assert_dir_exists() {
  if [ ! -d "$1" ]; then
    fail_test "expected directory to exist: $1"
  fi
}

assert_path_not_exists() {
  if [ -e "$1" ]; then
    fail_test "expected path to be absent: $1"
  fi
}

setup_scenario() {
  SCENARIO_DIR=$(mktemp -d "$TMP_ROOT/scenario.XXXXXX")
  HOME_DIR=$SCENARIO_DIR/home
  INSTALL_DIR=$SCENARIO_DIR/install
  WORK_DIR=$SCENARIO_DIR/work
  mkdir -p "$HOME_DIR" "$WORK_DIR"
}

require_podman() {
  shimmy_podman_preflight_require "shimmy test"
  PODMAN_BIN=$SHIMMY_PODMAN_BIN
}

run_in_repo() {
  (
    cd "$ROOT_DIR"
    "$@"
  )
}

test_dash_parse() {
  command -v dash >/dev/null 2>&1 || fail_test "dash is required for parser checks"

  dash -n "$ROOT_DIR/shimmy"
  dash -n "$ROOT_DIR/scripts/activate-shimmy.sh"
  dash -n "$ROOT_DIR/scripts/install-shimmy.sh"
  dash -n "$ROOT_DIR/scripts/status-shimmy.sh"
  dash -n "$ROOT_DIR/scripts/test-shimmy.sh"
  dash -n "$ROOT_DIR/scripts/update-shimmy.sh"
  dash -n "$ROOT_DIR/lib/shims/shimmy-podman.sh"
  dash -n "$ROOT_DIR/shims/jq"

  pass "dash parse checks"
}

test_install_manifest() {
  setup_scenario

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq 2>&1
  )

  assert_contains "$output" "Installed shimmy assets into $INSTALL_DIR"
  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  assert_file_exists "$INSTALL_DIR/shims/jq"
  assert_dir_exists "$INSTALL_DIR/lib/shims"

  manifest_contents=$(cat "$INSTALL_DIR/install-manifest.txt")
  assert_contains "$manifest_contents" "install_dir=$INSTALL_DIR"
  assert_contains "$manifest_contents" "shim=jq"
  assert_not_contains "$manifest_contents" "shim_dir="
  assert_not_contains "$manifest_contents" "images_dir="
  assert_not_contains "$manifest_contents" "shim_lib_dir="

  pass "install writes single-root manifest"
}

test_activate_eval() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  output=$(
    cd "$ROOT_DIR"
    /bin/sh -c 'PATH=/usr/bin; eval "$("./shimmy" activate --install-dir "$1")"; printf "HAS_SHIMMY_INSTALL_DIR=%s\n" "${SHIMMY_INSTALL_DIR+yes}"; printf "HAS_SHIMMY_SHIM_DIR=%s\n" "${SHIMMY_SHIM_DIR+yes}"; printf "PATH=%s\n" "$PATH"' sh "$INSTALL_DIR"
  )

  assert_contains "$output" "HAS_SHIMMY_INSTALL_DIR="
  assert_contains "$output" "HAS_SHIMMY_SHIM_DIR="
  assert_contains "$output" "PATH=$INSTALL_DIR/shims:/usr/bin"

  pass "activate eval only updates PATH"
}

test_activate_is_idempotent() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  output=$(
    cd "$ROOT_DIR"
    /bin/sh -c 'PATH=/usr/bin; eval "$("./shimmy" activate --install-dir "$1")"; eval "$("./shimmy" activate --install-dir "$1")"; path_count=0; old_ifs=$IFS; IFS=:; for path_entry in $PATH; do if [ "$path_entry" = "$1/shims" ]; then path_count=$((path_count + 1)); fi; done; IFS=$old_ifs; printf "COUNT=%s\nPATH=%s\n" "$path_count" "$PATH"' sh "$INSTALL_DIR"
  )

  assert_contains "$output" "COUNT=1"
  assert_contains "$output" "PATH=$INSTALL_DIR/shims:/usr/bin"

  pass "activate path activation is idempotent"
}

test_status_reports_install() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" 2>&1
  )

  assert_contains "$output" "installed: yes"
  assert_contains "$output" "install_dir=$INSTALL_DIR"
  assert_contains "$output" "shim_dir=$INSTALL_DIR/shims"
  assert_contains "$output" "- jq: docker.io/stedolan/jq:latest"

  pass "status reports installed shim details"
}

test_update_reinstalls_selected_shims() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  rm -f "$INSTALL_DIR/shims/jq"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" >/dev/null

  assert_file_exists "$INSTALL_DIR/shims/jq"

  pass "update reinstalls manifest-selected shims"
}

test_jq_shim_direct() {
  setup_scenario
  require_podman

  cat > "$WORK_DIR/input.json" <<'EOF'
{"foo":"bar"}
EOF

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/jq" -r .foo input.json 2>&1
  )

  assert_contains "$output" "bar"

  pass "jq direct shim execution"
}

test_jq_shim_pull_override() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" JQ_IMAGE_PULL=always JQ_IMAGE=ghcr.io/jqlang/jq:latest "$ROOT_DIR/shims/jq" --version 2>&1
  )

  assert_contains "$output" "jq-"

  pass "jq pull override execution"
}

test_installed_jq_shim() {
  setup_scenario
  require_podman

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$INSTALL_DIR/shims/jq" --version 2>&1
  )

  assert_contains "$output" "jq-"

  pass "installed jq shim execution"
}

test_uninstall_cleanup() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  HOME="$HOME_DIR" run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" >/dev/null

  assert_path_not_exists "$INSTALL_DIR"

  pass "uninstall removes install root"
}

main() {
  test_dash_parse
  test_install_manifest
  test_activate_eval
  test_activate_is_idempotent
  test_status_reports_install
  test_update_reinstalls_selected_shims
  test_jq_shim_direct
  test_jq_shim_pull_override
  test_installed_jq_shim
  test_uninstall_cleanup

  printf 'All %s shim tests passed.\n' "$TEST_COUNT"
}

main "$@"
