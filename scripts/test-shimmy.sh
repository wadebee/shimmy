#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
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

resolve_podman() {
  if command -v podman >/dev/null 2>&1; then
    command -v podman
    return 0
  fi

  if [ -x /opt/podman/bin/podman ]; then
    printf '%s\n' '/opt/podman/bin/podman'
    return 0
  fi

  return 1
}

require_podman() {
  PODMAN_BIN=$(resolve_podman || true)
  [ -n "$PODMAN_BIN" ] || fail_test "podman is an explicit Shimmy dependency and is required for live shim tests"
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
  dash -n "$ROOT_DIR/scripts/install-shimmy.sh"
  dash -n "$ROOT_DIR/scripts/shellenv-shimmy.sh"
  dash -n "$ROOT_DIR/scripts/test-shimmy.sh"
  dash -n "$ROOT_DIR/shims/jq"

  pass "dash parse checks"
}

test_install_copy_and_manifest() {
  setup_scenario

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --copy --shim jq 2>&1
  )

  assert_contains "$output" "Installed shimmy assets into $INSTALL_DIR"
  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  assert_file_exists "$INSTALL_DIR/shims/jq"
  assert_dir_exists "$INSTALL_DIR/lib/shims"

  manifest_contents=$(cat "$INSTALL_DIR/install-manifest.txt")
  assert_contains "$manifest_contents" "install_dir=$INSTALL_DIR"
  assert_contains "$manifest_contents" "shim=jq"

  pass "copy install writes manifest"
}

test_shellenv_eval() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --copy --shim jq >/dev/null

  output=$(
    cd "$ROOT_DIR"
    /bin/sh -c 'PATH=/usr/bin; eval "$("./shimmy" shellenv --install-dir "$1")"; printf "SHIMMY_INSTALL_DIR=%s\n" "$SHIMMY_INSTALL_DIR"; printf "SHIMMY_SHIM_DIR=%s\n" "$SHIMMY_SHIM_DIR"; printf "PATH=%s\n" "$PATH"' sh "$INSTALL_DIR"
  )

  assert_contains "$output" "SHIMMY_INSTALL_DIR=$INSTALL_DIR"
  assert_contains "$output" "SHIMMY_SHIM_DIR=$INSTALL_DIR/shims"
  assert_contains "$output" "PATH=/usr/bin:$INSTALL_DIR/shims"

  pass "shellenv eval exports install paths"
}

test_shellenv_is_idempotent() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --copy --shim jq >/dev/null

  output=$(
    cd "$ROOT_DIR"
    /bin/sh -c 'PATH=/usr/bin; eval "$("./shimmy" shellenv --install-dir "$1")"; eval "$("./shimmy" shellenv --install-dir "$1")"; printf "%s\n" "$PATH"' sh "$INSTALL_DIR"
  )

  if [ "$output" != "/usr/bin:$INSTALL_DIR/shims" ]; then
    fail_test "expected shellenv PATH activation to be idempotent"
  fi

  pass "shellenv path activation is idempotent"
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

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --copy --shim jq >/dev/null

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$INSTALL_DIR/shims/jq" --version 2>&1
  )

  assert_contains "$output" "jq-"

  pass "installed jq shim execution"
}

test_uninstall_cleanup() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --copy --shim jq >/dev/null
  HOME="$HOME_DIR" run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" >/dev/null

  assert_path_not_exists "$INSTALL_DIR"

  pass "uninstall removes install root"
}

main() {
  test_dash_parse
  test_install_copy_and_manifest
  test_shellenv_eval
  test_shellenv_is_idempotent
  test_jq_shim_direct
  test_jq_shim_pull_override
  test_installed_jq_shim
  test_uninstall_cleanup

  printf 'All %s shim tests passed.\n' "$TEST_COUNT"
}

main "$@"
