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

assert_not_empty() {
  if [ -z "${1:-}" ]; then
    fail_test "expected output to be non-empty"
  fi
}

assert_file_contains() {
  file_path=$1
  needle=$2

  [ -f "$file_path" ] || fail_test "expected file to exist: $file_path"
  file_contents=$(cat "$file_path")
  assert_contains "$file_contents" "$needle"
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
  dash -n "$ROOT_DIR/lib/shims/custom-image.sh"
  dash -n "$ROOT_DIR/lib/shims/shimmy-log.sh"
  dash -n "$ROOT_DIR/lib/shims/shimmy-podman.sh"
  dash -n "$ROOT_DIR/lib/repo/shimmy-startup.sh"
  dash -n "$ROOT_DIR/shims/aws"
  dash -n "$ROOT_DIR/shims/jq"
  dash -n "$ROOT_DIR/shims/netcat"
  dash -n "$ROOT_DIR/shims/rg"
  dash -n "$ROOT_DIR/shims/task"
  dash -n "$ROOT_DIR/shims/terraform"
  dash -n "$ROOT_DIR/shims/textual"

  pass "dash parse checks"
}

test_install_manifest() {
  setup_scenario

  output=$(
    HOME="$HOME_DIR" SHELL=/bin/bash run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq 2>&1
  )

  assert_contains "$output" "Installed shimmy assets into $INSTALL_DIR"
  assert_contains "$output" "Updated startup file: ~/.bashrc"
  assert_contains "$output" "Activate this install with: eval"
  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  assert_file_exists "$INSTALL_DIR/shims/jq"
  assert_dir_exists "$INSTALL_DIR/lib/shims"
  assert_file_exists "$HOME_DIR/.bashrc"

  manifest_contents=$(cat "$INSTALL_DIR/install-manifest.txt")
  assert_contains "$manifest_contents" "install_dir=$INSTALL_DIR"
  assert_contains "$manifest_contents" "startup_shell=bash"
  assert_contains "$manifest_contents" "startup_file=$HOME_DIR/.bashrc"
  assert_contains "$manifest_contents" "shim=jq"
  assert_not_contains "$manifest_contents" "shim_dir="
  assert_not_contains "$manifest_contents" "images_dir="
  assert_not_contains "$manifest_contents" "shim_lib_dir="
  assert_file_contains "$HOME_DIR/.bashrc" "# >>> shimmy onboarding >>>"
  assert_file_contains "$HOME_DIR/.bashrc" "$INSTALL_DIR/shims"

  pass "install writes manifest and startup file"
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

test_install_no_startup() {
  setup_scenario

  output=$(
    HOME="$HOME_DIR" SHELL=/bin/bash run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup 2>&1
  )

  assert_contains "$output" "Future shells will load Shimmy from: manual activation only"
  assert_not_contains "$output" "Updated startup file:"
  assert_path_not_exists "$HOME_DIR/.bashrc"

  pass "install can skip startup file updates"
}

test_update_repair_startup() {
  setup_scenario

  startup_file=$HOME_DIR/.zshrc

  HOME="$HOME_DIR" SHELL=/bin/zsh run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  assert_file_contains "$startup_file" "# >>> shimmy onboarding >>>"
  rm -f "$startup_file"

  output=$(
    HOME="$HOME_DIR" SHELL=/bin/zsh run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --repair-startup 2>&1
  )

  assert_contains "$output" "Updated startup file: $startup_file"
  assert_file_contains "$startup_file" "# >>> shimmy onboarding >>>"
  assert_file_contains "$startup_file" "$INSTALL_DIR/shims"

  HOME="$HOME_DIR" SHELL=/bin/zsh run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --repair-startup >/dev/null
  marker_count=$(grep -c '^# >>> shimmy onboarding >>>$' "$startup_file")
  [ "$marker_count" -eq 1 ] || fail_test "expected one onboarding block marker, found $marker_count"

  pass "update can repair startup file idempotently"
}

test_status_reports_install() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task >/dev/null

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" 2>&1
  )

  assert_contains "$output" "installed: yes"
  assert_contains "$output" "install_dir=$INSTALL_DIR"
  assert_contains "$output" "shim_dir=$INSTALL_DIR/shims"
  assert_contains "$output" "- jq: docker.io/stedolan/jq:latest"
  assert_contains "$output" "- task: localhost/shimmy-task:"

  pass "status reports installed shim details"
}

test_update_reinstalls_selected_shims() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task >/dev/null
  rm -f "$INSTALL_DIR/shims/jq"
  rm -f "$INSTALL_DIR/shims/task"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" >/dev/null

  assert_file_exists "$INSTALL_DIR/shims/jq"
  assert_file_exists "$INSTALL_DIR/shims/task"

  pass "update reinstalls manifest-selected shims"
}

test_aws_shim_direct() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/aws" --version 2>&1
  )

  assert_contains "$output" "aws-cli/"

  pass "aws direct shim execution"
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

test_netcat_shim_direct() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/netcat" --help 2>&1
  )

  assert_contains "$output" "Ncat"

  pass "netcat direct shim execution"
}

test_rg_shim_direct() {
  setup_scenario
  require_podman

  cat > "$WORK_DIR/example.txt" <<'EOF'
needle
EOF

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/rg" needle example.txt 2>&1
  )

  assert_contains "$output" "needle"

  pass "rg direct shim execution"
}

test_task_shim_direct() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/task" --version 2>&1
  )

  assert_not_empty "$output"
  assert_not_contains "$output" "ERROR:"

  pass "task direct shim execution"
}

test_terraform_shim_direct() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/terraform" version 2>&1
  )

  assert_contains "$output" "Terraform v"

  pass "terraform direct shim execution"
}

test_textual_shim_direct() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/textual" --help 2>&1
  )

  assert_contains "$output" "Usage:"
  assert_contains "$output" "textual"

  pass "textual direct shim execution"
}

test_installed_task_shim() {
  setup_scenario
  require_podman

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim task >/dev/null

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$INSTALL_DIR/shims/task" --version 2>&1
  )

  assert_not_empty "$output"
  assert_not_contains "$output" "ERROR:"

  pass "installed task shim execution"
}

test_uninstall_cleanup() {
  setup_scenario

  startup_file=$HOME_DIR/.bashrc
  printf '# existing shell config\n' > "$startup_file"

  HOME="$HOME_DIR" SHELL=/bin/bash run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  HOME="$HOME_DIR" run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" >/dev/null

  assert_path_not_exists "$INSTALL_DIR"
  assert_file_contains "$startup_file" "# existing shell config"
  startup_contents=$(cat "$startup_file")
  assert_not_contains "$startup_contents" "# >>> shimmy onboarding >>>"
  assert_not_contains "$startup_contents" "$INSTALL_DIR/shims"

  pass "uninstall removes install root and startup block"
}

main() {
  test_dash_parse
  test_install_manifest
  test_activate_eval
  test_activate_is_idempotent
  test_install_no_startup
  test_update_repair_startup
  test_status_reports_install
  test_update_reinstalls_selected_shims
  test_aws_shim_direct
  test_jq_shim_direct
  test_jq_shim_pull_override
  test_installed_jq_shim
  test_netcat_shim_direct
  test_rg_shim_direct
  test_task_shim_direct
  test_terraform_shim_direct
  test_textual_shim_direct
  test_installed_task_shim
  test_uninstall_cleanup

  printf 'All %s shim tests passed.\n' "$TEST_COUNT"
}

main "$@"
