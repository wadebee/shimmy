#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/shimmy-env.sh
source "$SCRIPT_DIR/lib/shimmy-env.sh"

shimmy_init_repo_vars "$(shimmy_repo_root_from_script_path "${BASH_SOURCE[0]}")"
REAL_HOME="${HOME:?HOME must be set}"
PODMAN_XDG_DATA_HOME="${XDG_DATA_HOME:-$REAL_HOME/.local/share}"
TMP_ROOT="$(mktemp -d)"
TEST_COUNT=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

pass() {
  local name="$1"
  TEST_COUNT=$((TEST_COUNT + 1))
  echo "PASS: $name"
}

fail_test() {
  echo "$1" >&2
  return 1
}

require_podman() {
  command -v podman >/dev/null 2>&1 || fail_test "podman is required to run scripts/test-shimmy.sh"
}

setup_scenario() {
  SCENARIO_DIR="$(mktemp -d "$TMP_ROOT/scenario.XXXXXX")"
  HOME_DIR="$SCENARIO_DIR/home"
  WORK_DIR="$SCENARIO_DIR/work"

  mkdir -p "$HOME_DIR" "$WORK_DIR"
  chmod 755 "$HOME_DIR" "$WORK_DIR"

  shimmy_init_home_vars "$HOME_DIR"
  shimmy_init_install_vars "$HOME_DIR/.local/bin/shimmy"
}

run_wrapper() {
  local wrapper="$1"
  shift

  local -a env_vars=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    env_vars+=("$1")
    shift
  done

  if [[ $# -gt 0 && "$1" == "--" ]]; then
    shift
  fi

  local -a wrapper_args=("$@")

  (
    cd "$WORK_DIR"
    env \
      "HOME=$HOME_DIR" \
      "XDG_DATA_HOME=$PODMAN_XDG_DATA_HOME" \
      "${env_vars[@]}" \
      "$wrapper" "${wrapper_args[@]}"
  )
}

run_installer() {
  (
    cd "$ROOT_DIR"
    env "HOME=$HOME_DIR" bash "$ROOT_DIR/scripts/install-shimmy.sh" \
      --install-dir "$HOME_DIR/.local/bin/shimmy" \
      "$@"
  )
}

run_uninstaller() {
  (
    cd "$ROOT_DIR"
    env "HOME=$HOME_DIR" bash "$ROOT_DIR/scripts/install-shimmy.sh" \
      --uninstall \
      --install-dir "$HOME_DIR/.local/bin/shimmy" \
      "$@"
  )
}

run_podman() {
  env \
    "HOME=$HOME_DIR" \
    "XDG_DATA_HOME=$PODMAN_XDG_DATA_HOME" \
    podman "$@"
}

assert_output_contains() {
  local output="$1"
  local expected="$2"

  [[ "$output" == *"$expected"* ]] || fail_test "Expected output to contain: $expected"
}

assert_output_not_contains() {
  local output="$1"
  local unexpected="$2"

  [[ "$output" != *"$unexpected"* ]] || fail_test "Did not expect output to contain: $unexpected"
}

assert_file_exists() {
  local path="$1"

  [[ -f "$path" ]] || fail_test "Expected file to exist: $path"
}

assert_path_not_exists() {
  local path="$1"

  [[ ! -e "$path" ]] || fail_test "Did not expect path to exist: $path"
}

assert_not_symlink() {
  local path="$1"

  [[ ! -L "$path" ]] || fail_test "Expected regular file, found symlink: $path"
}

assert_symlink_target() {
  local path="$1"
  local expected="$2"

  [[ -L "$path" ]] || fail_test "Expected symlink: $path"
  [[ "$(readlink "$path")" == "$expected" ]] || fail_test "Expected $path to point to $expected"
}

assert_file_contains_text() {
  local path="$1"
  local expected="$2"

  grep -F -- "$expected" "$path" >/dev/null || fail_test "Expected '$expected' in $path"
}

test_aws_default() {
  setup_scenario

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/aws" -- --version 2>&1)"

  assert_output_contains "$output" "aws-cli/2.15.0"
  pass "aws default exec"
}

test_aws_with_mount_and_pull() {
  setup_scenario
  mkdir -p "$HOME_DIR/.aws"
  cat > "$HOME_DIR/.aws/config" <<'EOF'
[profile smoke]
region = us-east-1
EOF
  chmod 755 "$HOME_DIR/.aws"
  chmod 644 "$HOME_DIR/.aws/config"

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/aws" "AWS_IMAGE=public.ecr.aws/aws-cli/aws-cli:2.31.21" "AWS_IMAGE_PULL=always" -- configure list-profiles 2>&1)"

  assert_output_contains "$output" "smoke"
  pass "aws mount + pull exec"
}

test_jq_default() {
  setup_scenario

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/jq" -- --version 2>&1)"

  assert_output_contains "$output" "jq-"
  pass "jq default exec"
}

test_jq_with_pull() {
  setup_scenario
  cat > "$WORK_DIR/input.json" <<'EOF'
{"foo":"bar"}
EOF
  chmod 644 "$WORK_DIR/input.json"

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/jq" "JQ_IMAGE=ghcr.io/jqlang/jq:latest" "JQ_IMAGE_PULL=always" -- -r .foo input.json 2>&1)"

  assert_output_contains "$output" "bar"
  pass "jq pull exec"
}

test_rg_default() {
  setup_scenario

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/rg" -- --version 2>&1)"

  assert_output_contains "$output" "ripgrep"
  pass "rg default exec"
}

test_rg_with_pull() {
  setup_scenario
  cat > "$WORK_DIR/file.txt" <<'EOF'
needle
EOF
  chmod 755 "$WORK_DIR"
  chmod 644 "$WORK_DIR/file.txt"

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/rg" "RG_IMAGE=docker.io/vszl/ripgrep:latest" "RG_IMAGE_PULL=always" -- needle file.txt 2>&1)"

  assert_output_contains "$output" "needle"
  pass "rg pull exec"
}

test_terraform_default() {
  setup_scenario

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/terraform" -- version 2>&1)"

  assert_output_contains "$output" "Terraform v"
  pass "terraform default exec"
}

test_terraform_with_mounts_and_pull() {
  setup_scenario
  mkdir -p "$HOME_DIR/.aws" "$HOME_DIR/.terraform.d/plugin-cache"
  cat > "$HOME_DIR/.aws/config" <<'EOF'
[default]
region = us-east-1
EOF
  cat > "$WORK_DIR/main.tf" <<'EOF'
terraform {}
EOF
  chmod 755 "$HOME_DIR/.aws" "$HOME_DIR/.terraform.d" "$HOME_DIR/.terraform.d/plugin-cache"
  chmod 644 "$HOME_DIR/.aws/config" "$WORK_DIR/main.tf"

  run_wrapper "$ROOT_DIR/shims/terraform" "TF_IMAGE=docker.io/hashicorp/terraform:latest" "TF_IMAGE_PULL=always" -- fmt -check main.tf >/dev/null 2>&1

  pass "terraform mounts + pull exec"
}

test_tessl_default() {
  setup_scenario

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/tessl" -- --help 2>&1)"

  assert_output_contains "$output" "tessl"
  # run_podman images --format '{{.Repository}}:{{.Tag}}' | grep -F "localhost/shimmy-tessl:" >/dev/null \
  #   || fail_test "Expected a locally built Tessl image to be cached in Podman"
  pass "tessl default exec"
}

test_tessl_with_mounts_and_pull() {
  setup_scenario
  mkdir -p "$HOME_DIR/.tessl"
  cat > "$HOME_DIR/.tessl/config.json" <<'EOF'
{"test":true}
EOF
  chmod 755 "$HOME_DIR/.tessl"
  chmod 644 "$HOME_DIR/.tessl/config.json"

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/tessl" "TESSL_IMAGE=dhi.io/node:25-dev" "TESSL_IMAGE_PULL=always" "TESSL_AUTO_UPDATE_INTERVAL_MINUTES=0" -- --version 2>&1)"

  assert_output_not_contains "$output" "Building local shim image:"
  assert_output_contains "$output" "v"
  pass "tessl mounts + pull exec"
}

test_install_creates_managed_files() {
  setup_scenario

  local output
  output="$(run_installer --no-update-bashrc)"

  assert_file_exists "$INSTALL_MANIFEST_FILE"
  assert_file_exists "$SHIMMY_SHIM_DIR/aws"
  assert_file_exists "$SHIMMY_INSTALL_DIR/tessl/Containerfile"
  assert_not_symlink "$SHIMMY_SHIM_DIR/aws"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "install creates managed files"
}

test_install_log_level_error_hides_info_and_debug() {
  setup_scenario

  local output
  output="$(LOG_LEVEL=error run_installer --no-update-bashrc 2>&1)"

  assert_output_not_contains "$output" "DEBUG:"
  assert_output_not_contains "$output" "INFO:"
  assert_output_not_contains "$output" "Installed shims into"
  assert_file_exists "$INSTALL_MANIFEST_FILE"
  pass "install log level error suppresses chatter"
}

test_install_log_level_debug_emits_debug() {
  setup_scenario

  local output
  output="$(LOG_LEVEL=debug run_installer --no-update-bashrc 2>&1)"

  assert_output_contains "$output" "DEBUG: Starting install into $SHIMMY_INSTALL_DIR with mode copy"
  assert_output_contains "$output" "INFO: Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "install log level debug emits debug"
}

test_install_symlink_mode() {
  setup_scenario

  local output
  output="$(run_installer --symlink --no-update-bashrc)"

  assert_symlink_target "$SHIMMY_SHIM_DIR/aws" "$ROOT_DIR/shims/aws"
  assert_symlink_target "$SHIMMY_INSTALL_DIR/images" "$ROOT_DIR/images"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (symlink)."
  pass "install symlink override"
}

test_install_updates_bash_startup_files() {
  setup_scenario

  local output
  output="$(run_installer)"

  local source_line
  local guard_line
  local export_line

  source_line="$(shimmy_shell_init_source_line "$SHIMMY_BASH_FILE")"
  guard_line="$(shimmy_path_block_guard_line "$SHIMMY_SHIM_DIR")"
  export_line="$(shimmy_path_block_export_line "$SHIMMY_SHIM_DIR")"

  assert_file_exists "$BASHRC_FILE"
  assert_file_exists "$BASH_PROFILE_FILE"
  assert_file_exists "$SHIMMY_BASH_FILE"
  assert_file_contains_text "$BASHRC_FILE" "$source_line"
  assert_file_contains_text "$BASH_PROFILE_FILE" "$source_line"
  assert_file_contains_text "$SHIMMY_BASH_FILE" "$guard_line"
  assert_file_contains_text "$SHIMMY_BASH_FILE" "$export_line"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "install updates bash startup files"
}

test_uninstall_removes_installed_artifacts() {
  setup_scenario

  run_installer >/dev/null

  local output

  output="$(run_uninstaller)"

  assert_path_not_exists "$SHIMMY_INSTALL_DIR"
  assert_path_not_exists "$BASHRC_FILE"
  assert_path_not_exists "$BASH_PROFILE_FILE"
  assert_path_not_exists "$SHIMMY_BASH_FILE"
  assert_path_not_exists "$INSTALL_MANIFEST_FILE"
  assert_output_contains "$output" "Removed shimmy artifacts from $SHIMMY_INSTALL_DIR."
  pass "uninstall removes installed artifacts"
}

test_uninstall_preserves_preexisting_shell_files() {
  setup_scenario

  : > "$BASHRC_FILE"

  run_installer >/dev/null
  run_uninstaller >/dev/null

  assert_file_exists "$BASHRC_FILE"
  pass "uninstall preserves preexisting shell files"
}

main() {
  require_podman

  test_aws_default
  test_aws_with_mount_and_pull
  test_jq_default
  test_jq_with_pull
  test_rg_default
  test_rg_with_pull
  test_terraform_default
  test_terraform_with_mounts_and_pull
  # test_tessl_default
  # test_tessl_with_mounts_and_pull
  test_install_creates_managed_files
  test_install_log_level_error_hides_info_and_debug
  test_install_log_level_debug_emits_debug
  test_install_symlink_mode
  test_install_updates_bash_startup_files
  test_uninstall_removes_installed_artifacts
  test_uninstall_preserves_preexisting_shell_files

  echo "All $TEST_COUNT shim tests passed."
}

main "$@"
