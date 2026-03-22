#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/repo/shimmy-env.sh
source "$SCRIPT_DIR/../lib/repo/shimmy-env.sh"

shimmy::init_repo_vars "$(shimmy::repo_root_from_script_path "${BASH_SOURCE[0]}")"
REAL_HOME="${HOME:?HOME must be set}"
PODMAN_XDG_DATA_HOME="${XDG_DATA_HOME:-$REAL_HOME/.local/share}"
TMP_ROOT="$(mktemp -d)"
TEST_COUNT=0

cleanup() {
  cleanup_test_podman_tags
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

cleanup_test_podman_tags() {
  local image_ref

  command -v podman >/dev/null 2>&1 || return 0

  while IFS= read -r image_ref; do
    [[ -n "$image_ref" ]] || continue
    env \
      "HOME=$REAL_HOME" \
      "XDG_DATA_HOME=$PODMAN_XDG_DATA_HOME" \
      podman image rm "$image_ref" >/dev/null 2>&1 || true
  done < <(
    env \
      "HOME=$REAL_HOME" \
      "XDG_DATA_HOME=$PODMAN_XDG_DATA_HOME" \
      podman images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep '^localhost/shimmy-task:shimmy-test-' || true
  )
}

setup_scenario() {
  SCENARIO_DIR="$(mktemp -d "$TMP_ROOT/scenario.XXXXXX")"
  HOME_DIR="$SCENARIO_DIR/home"
  WORK_DIR="$SCENARIO_DIR/work"

  unset SHIMMY_INSTALL_DIR SHIMMY_SHIM_DIR SHIMMY_IMAGES_DIR SHIMMY_SHIM_LIB_DIR
  mkdir -p "$HOME_DIR" "$WORK_DIR"
  chmod 755 "$HOME_DIR" "$WORK_DIR"

  shimmy::init_home_vars "$HOME_DIR"
  shimmy::init_install_vars "$HOME_DIR/.local/bin/shimmy"
}

set_install_paths() {
  SHIMMY_INSTALL_DIR="${1%/}"
  SHIMMY_SHIM_DIR="${2%/}"
  SHIMMY_IMAGES_DIR="${3%/}"
  SHIMMY_SHIM_LIB_DIR="${4%/}"
  INSTALL_MANIFEST_FILE="$SHIMMY_INSTALL_DIR/install-manifest.txt"
}

setup_split_paths_scenario() {
  setup_scenario
  set_install_paths \
    "$HOME_DIR/.local/state/shimmy" \
    "$HOME_DIR/.local/bin/shims" \
    "$HOME_DIR/.local/share/shimmy-images" \
    "$HOME_DIR/.local/lib/shimmy-shims"
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
      -u SHIMMY_INSTALL_DIR \
      -u SHIMMY_SHIM_DIR \
      -u SHIMMY_IMAGES_DIR \
      -u SHIMMY_SHIM_LIB_DIR \
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
      --install-dir "$SHIMMY_INSTALL_DIR" \
      "$@" 2>&1
  )
}

run_installer_with_paths_env() {
  (
    cd "$ROOT_DIR"
    env \
      "HOME=$HOME_DIR" \
      "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR" \
      "SHIMMY_SHIM_DIR=$SHIMMY_SHIM_DIR" \
      "SHIMMY_IMAGES_DIR=$SHIMMY_IMAGES_DIR" \
      "SHIMMY_SHIM_LIB_DIR=$SHIMMY_SHIM_LIB_DIR" \
      bash "$ROOT_DIR/scripts/install-shimmy.sh" \
      --install-dir "$SHIMMY_INSTALL_DIR" \
      "$@" 2>&1
  )
}

run_uninstaller() {
  (
    cd "$ROOT_DIR"
    env "HOME=$HOME_DIR" bash "$ROOT_DIR/scripts/install-shimmy.sh" \
      --uninstall \
      --install-dir "$SHIMMY_INSTALL_DIR" \
      "$@" 2>&1
  )
}

run_uninstaller_with_install_env_only() {
  (
    cd "$ROOT_DIR"
    env \
      "HOME=$HOME_DIR" \
      "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR" \
      bash "$ROOT_DIR/scripts/install-shimmy.sh" \
      --uninstall \
      --install-dir "$SHIMMY_INSTALL_DIR" \
      "$@" 2>&1
  )
}

run_shimmy() {
  (
    cd "$ROOT_DIR"
    env \
      "HOME=$HOME_DIR" \
      "XDG_DATA_HOME=$PODMAN_XDG_DATA_HOME" \
      bash "$ROOT_DIR/shimmy" "$@" 2>&1
  )
}

run_shimmy_without_install_env() {
  (
    cd "$ROOT_DIR"
    env \
      -u SHIMMY_INSTALL_DIR \
      -u SHIMMY_SHIM_DIR \
      -u SHIMMY_IMAGES_DIR \
      -u SHIMMY_SHIM_LIB_DIR \
      "HOME=$HOME_DIR" \
      "XDG_DATA_HOME=$PODMAN_XDG_DATA_HOME" \
      bash "$ROOT_DIR/shimmy" "$@" 2>&1
  )
}

run_status() {
  (
    cd "$ROOT_DIR"
    env "HOME=$HOME_DIR" bash "$ROOT_DIR/scripts/status-shimmy.sh" 2>&1
  )
}

run_status_without_install_env() {
  (
    cd "$ROOT_DIR"
    env \
      -u SHIMMY_INSTALL_DIR \
      -u SHIMMY_SHIM_DIR \
      -u SHIMMY_IMAGES_DIR \
      -u SHIMMY_SHIM_LIB_DIR \
      "HOME=$HOME_DIR" \
      bash "$ROOT_DIR/scripts/status-shimmy.sh" 2>&1
  )
}

run_status_with_host_path() {
  (
    cd "$ROOT_DIR"
    env \
      "HOME=$HOME_DIR" \
      "SHIMMY_HOST_PATH=$SHIMMY_SHIM_DIR:${PATH:-}" \
      bash "$ROOT_DIR/scripts/status-shimmy.sh" 2>&1
  )
}

run_status_with_install_env_only() {
  (
    cd "$ROOT_DIR"
    env \
      "HOME=$HOME_DIR" \
      "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR" \
      bash "$ROOT_DIR/scripts/status-shimmy.sh" 2>&1
  )
}

run_sourced_shimmy_env() {
  env "HOME=$HOME_DIR" bash -lc '. "$1" && env | grep "^SHIMMY_" | sort' _ "$SHIMMY_BASH_FILE" 2>&1
}

run_eval_shimmy_shellenv() {
  env "HOME=$HOME_DIR" bash -lc 'eval "$("$1" shellenv)" && { env | grep "^SHIMMY_" | sort; printf "PATH=%s\n" "$PATH"; }' _ "$ROOT_DIR/shimmy" 2>&1
}

run_source_process_shimmy_shellenv() {
  env "HOME=$HOME_DIR" bash -lc 'source <("$1" shellenv) && { env | grep "^SHIMMY_" | sort; printf "PATH=%s\n" "$PATH"; }' _ "$ROOT_DIR/shimmy" 2>&1
}

run_sourced_shimmy_status() {
  env "HOME=$HOME_DIR" bash -lc '. "$1" status; shimmy_status=$?; printf "shimmy_status=%s\n" "$shimmy_status"; printf "shell_continued=yes\n"' _ "$ROOT_DIR/shimmy" 2>&1
}

run_sourced_shimmy_unknown_command() {
  env "HOME=$HOME_DIR" bash -lc '. "$1" not-a-command; shimmy_status=$?; printf "shimmy_status=%s\n" "$shimmy_status"; printf "shell_continued=yes\n"' _ "$ROOT_DIR/shimmy" 2>&1
}

run_update() {
  (
    cd "$ROOT_DIR"
    env \
      "HOME=$HOME_DIR" \
      "XDG_DATA_HOME=$PODMAN_XDG_DATA_HOME" \
      bash "$ROOT_DIR/scripts/update-shimmy.sh" "$@" 2>&1
  )
}

run_update_without_install_env() {
  (
    cd "$ROOT_DIR"
    env \
      -u SHIMMY_INSTALL_DIR \
      -u SHIMMY_SHIM_DIR \
      -u SHIMMY_IMAGES_DIR \
      -u SHIMMY_SHIM_LIB_DIR \
      "HOME=$HOME_DIR" \
      "XDG_DATA_HOME=$PODMAN_XDG_DATA_HOME" \
      bash "$ROOT_DIR/scripts/update-shimmy.sh" "$@" 2>&1
  )
}

run_update_with_install_env_only() {
  (
    cd "$ROOT_DIR"
    env \
      "HOME=$HOME_DIR" \
      "XDG_DATA_HOME=$PODMAN_XDG_DATA_HOME" \
      "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR" \
      bash "$ROOT_DIR/scripts/update-shimmy.sh" "$@" 2>&1
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

test_netcat_default() {
  setup_scenario

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/netcat" -- --help 2>&1)"

  assert_output_contains "$output" "Ncat"
  pass "netcat default exec"
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

test_task_default() {
  setup_scenario

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/task" -- --version 2>&1)"

  assert_output_contains "$output" "3.45.5"
  pass "task default exec"
}

test_task_with_build_arg_override() {
  setup_scenario

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/task" "TASK_BASE_IMAGE=alpine:3.22" "TASK_VERSION=v3.45.5" -- --version 2>&1)"

  assert_output_contains "$output" "3.45.5"
  pass "task build arg override exec"
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

test_textual_default() {
  setup_scenario

  local output
  output="$(run_wrapper "$ROOT_DIR/shims/textual" -- --help 2>&1)"

  assert_output_contains "$output" "Usage:"
  pass "textual default exec"
}

test_install_creates_managed_files() {
  setup_scenario

  local output
  output="$(run_installer --no-update-bashrc)"

  assert_file_exists "$INSTALL_MANIFEST_FILE"
  assert_file_exists "$SHIMMY_SHIM_DIR/aws"
  assert_file_exists "$SHIMMY_SHIM_DIR/netcat"
  assert_file_exists "$SHIMMY_SHIM_DIR/task"
  assert_file_exists "$SHIMMY_IMAGES_DIR/netcat/Containerfile"
  assert_file_exists "$SHIMMY_IMAGES_DIR/task/Containerfile"
  assert_file_exists "$SHIMMY_IMAGES_DIR/tessl/Containerfile"
  assert_file_exists "$SHIMMY_IMAGES_DIR/textual/Containerfile"
  assert_file_exists "$SHIMMY_SHIM_LIB_DIR/custom-image.sh"
  assert_file_exists "$SHIMMY_SHIM_LIB_DIR/shim-bootstrap.sh"
  assert_file_exists "$SHIMMY_SHIM_LIB_DIR/shimmy-log.sh"
  assert_not_symlink "$SHIMMY_SHIM_DIR/aws"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "install creates managed files"
}

test_install_honors_split_paths_globals() {
  setup_split_paths_scenario

  local output
  output="$(run_installer_with_paths_env --no-update-bashrc --shim task)"

  assert_file_exists "$INSTALL_MANIFEST_FILE"
  assert_file_exists "$SHIMMY_SHIM_DIR/task"
  assert_file_exists "$SHIMMY_IMAGES_DIR/task/Containerfile"
  assert_file_exists "$SHIMMY_SHIM_LIB_DIR/shim-bootstrap.sh"
  assert_file_exists "$SHIMMY_SHIM_LIB_DIR/shimmy-log.sh"
  assert_file_exists "$SHIMMY_SHIM_LIB_DIR/task-shim.sh"
  assert_path_not_exists "$SHIMMY_INSTALL_DIR/shims"
  assert_path_not_exists "$SHIMMY_INSTALL_DIR/images"
  assert_path_not_exists "$SHIMMY_INSTALL_DIR/lib/shims"
  assert_file_contains_text "$INSTALL_MANIFEST_FILE" "shim_dir=$SHIMMY_SHIM_DIR"
  assert_file_contains_text "$INSTALL_MANIFEST_FILE" "images_dir=$SHIMMY_IMAGES_DIR"
  assert_file_contains_text "$INSTALL_MANIFEST_FILE" "shim_lib_dir=$SHIMMY_SHIM_LIB_DIR"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "install honors split paths globals"
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

  assert_output_contains "$output" "DEBUG: Refreshing shared shim helper support in $SHIMMY_SHIM_LIB_DIR using mode copy"
  assert_output_contains "$output" "INFO: Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "install log level debug emits debug"
}

test_install_symlink_mode() {
  setup_scenario

  local output
  output="$(run_installer --symlink --no-update-bashrc)"

  assert_symlink_target "$SHIMMY_SHIM_DIR/aws" "$ROOT_DIR/shims/aws"
  assert_symlink_target "$SHIMMY_IMAGES_DIR/task" "$ROOT_DIR/images/task"
  assert_symlink_target "$SHIMMY_IMAGES_DIR/textual" "$ROOT_DIR/images/textual"
  assert_symlink_target "$SHIMMY_SHIM_LIB_DIR" "$ROOT_DIR/lib/shims"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (symlink)."
  pass "install symlink override"
}

test_install_updates_bash_startup_files() {
  setup_scenario

  local output
  output="$(run_installer)"

  local source_line
  local install_export_line
  local shim_export_line
  local images_export_line
  local shim_lib_export_line
  local guard_line
  local export_line

  source_line="$(shimmy::shell_init_source_line "$SHIMMY_BASH_FILE")"
  install_export_line="$(shimmy::install_dir_export_line "$SHIMMY_INSTALL_DIR")"
  shim_export_line="$(shimmy::shim_dir_export_line "$SHIMMY_SHIM_DIR")"
  images_export_line="$(shimmy::images_dir_export_line "$SHIMMY_IMAGES_DIR")"
  shim_lib_export_line="$(shimmy::shim_lib_dir_export_line "$SHIMMY_SHIM_LIB_DIR")"
  guard_line="$(shimmy::path_block_guard_line "$SHIMMY_SHIM_DIR")"
  export_line="$(shimmy::path_block_export_line "$SHIMMY_SHIM_DIR")"

  assert_file_exists "$BASHRC_FILE"
  assert_file_exists "$BASH_PROFILE_FILE"
  assert_file_exists "$SHIMMY_BASH_FILE"
  assert_file_contains_text "$BASHRC_FILE" "$source_line"
  assert_file_contains_text "$BASH_PROFILE_FILE" "$source_line"
  assert_file_contains_text "$SHIMMY_BASH_FILE" "$install_export_line"
  assert_file_contains_text "$SHIMMY_BASH_FILE" "$shim_export_line"
  assert_file_contains_text "$SHIMMY_BASH_FILE" "$images_export_line"
  assert_file_contains_text "$SHIMMY_BASH_FILE" "$shim_lib_export_line"
  assert_file_contains_text "$SHIMMY_BASH_FILE" "$guard_line"
  assert_file_contains_text "$SHIMMY_BASH_FILE" "$export_line"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "install updates bash startup files"
}

test_shimmy_shell_file_exports_install_env() {
  setup_scenario

  run_installer >/dev/null

  local output
  output="$(run_sourced_shimmy_env)"

  assert_output_contains "$output" "SHIMMY_IMAGES_DIR=$SHIMMY_IMAGES_DIR"
  assert_output_contains "$output" "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR"
  assert_output_contains "$output" "SHIMMY_SHIM_LIB_DIR=$SHIMMY_SHIM_LIB_DIR"
  assert_output_contains "$output" "SHIMMY_SHIM_DIR=$SHIMMY_SHIM_DIR"
  pass "shimmy shell file exports install env"
}

test_shimmy_uninstall_removes_installed_artifacts() {
  setup_scenario

  run_installer >/dev/null

  local output

  output="$(run_shimmy uninstall --install-dir "$SHIMMY_INSTALL_DIR")"

  assert_path_not_exists "$SHIMMY_INSTALL_DIR"
  assert_path_not_exists "$BASHRC_FILE"
  assert_path_not_exists "$BASH_PROFILE_FILE"
  assert_path_not_exists "$SHIMMY_BASH_FILE"
  assert_path_not_exists "$INSTALL_MANIFEST_FILE"
  assert_output_contains "$output" "Removed shimmy artifacts from $SHIMMY_INSTALL_DIR."
  pass "shimmy uninstall removes installed artifacts"
}

test_uninstall_preserves_preexisting_shell_files() {
  setup_scenario

  : > "$BASHRC_FILE"

  run_installer >/dev/null
  run_uninstaller >/dev/null

  assert_file_exists "$BASHRC_FILE"
  pass "uninstall preserves preexisting shell files"
}

test_uninstall_removes_empty_preexisting_shimmy_shell_file() {
  setup_scenario

  : > "$SHIMMY_BASH_FILE"

  run_installer >/dev/null
  run_uninstaller >/dev/null

  assert_path_not_exists "$SHIMMY_BASH_FILE"
  pass "uninstall removes empty preexisting shimmy shell file"
}

test_shimmy_install_installs_default_shimmy_paths() {
  setup_scenario
  shimmy::init_install_vars "$DEFAULT_INSTALL_DIR"

  local output
  output="$(run_shimmy install)"

  assert_file_exists "$INSTALL_MANIFEST_FILE"
  assert_file_exists "$SHIMMY_SHIM_DIR/aws"
  assert_file_exists "$SHIMMY_SHIM_DIR/task"
  assert_file_exists "$SHIMMY_SHIM_DIR/terraform"
  assert_file_exists "$SHIMMY_IMAGES_DIR/task/Containerfile"
  assert_file_exists "$SHIMMY_IMAGES_DIR/netcat/Containerfile"
  assert_file_exists "$SHIMMY_SHIM_LIB_DIR/task-shim.sh"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "shimmy install installs default shimmy paths"
}

test_shimmy_shellenv_activates_installed_paths() {
  setup_scenario
  shimmy::init_install_vars "$DEFAULT_INSTALL_DIR"

  run_shimmy install --no-update-bashrc >/dev/null

  local eval_output
  local source_output
  eval_output="$(run_eval_shimmy_shellenv)"
  source_output="$(run_source_process_shimmy_shellenv)"

  assert_output_contains "$eval_output" "SHIMMY_IMAGES_DIR=$SHIMMY_IMAGES_DIR"
  assert_output_contains "$eval_output" "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR"
  assert_output_contains "$eval_output" "SHIMMY_SHIM_LIB_DIR=$SHIMMY_SHIM_LIB_DIR"
  assert_output_contains "$eval_output" "SHIMMY_SHIM_DIR=$SHIMMY_SHIM_DIR"
  assert_output_contains "$eval_output" ":$SHIMMY_SHIM_DIR"
  assert_output_contains "$source_output" "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR"
  assert_output_contains "$source_output" ":$SHIMMY_SHIM_DIR"
  pass "shimmy shellenv activates installed paths"
}

test_shimmy_status_discovers_default_install_from_manifest() {
  setup_scenario
  shimmy::init_install_vars "$DEFAULT_INSTALL_DIR"

  run_shimmy install >/dev/null

  local output
  output="$(run_shimmy_without_install_env status)"

  assert_output_contains "$output" "installed: yes"
  assert_output_contains "$output" "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR"
  assert_output_contains "$output" "- task: localhost/shimmy-task:"
  pass "shimmy status discovers default install from manifest"
}

test_sourced_shimmy_status_returns_without_exiting_shell() {
  setup_scenario

  run_installer --no-update-bashrc >/dev/null

  local output
  output="$(run_sourced_shimmy_status)"

  assert_output_contains "$output" "shimmy_status=0"
  assert_output_contains "$output" "shell_continued=yes"
  assert_output_contains "$output" "installed: yes"
  pass "sourced shimmy status returns without exiting shell"
}

test_sourced_shimmy_failure_returns_non_zero_without_exiting_shell() {
  setup_scenario

  local output
  output="$(run_sourced_shimmy_unknown_command)"

  assert_output_contains "$output" "ERROR: unknown command: not-a-command"
  assert_output_contains "$output" "shimmy_status=1"
  assert_output_contains "$output" "shell_continued=yes"
  pass "sourced shimmy failure returns non-zero without exiting shell"
}

test_shimmy_update_discovers_default_install_from_manifest() {
  setup_scenario
  shimmy::init_install_vars "$DEFAULT_INSTALL_DIR"

  run_shimmy install >/dev/null
  rm -f "$SHIMMY_SHIM_DIR/aws"

  local output
  output="$(run_shimmy_without_install_env update)"

  assert_file_exists "$SHIMMY_SHIM_DIR/aws"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "shimmy update discovers default install from manifest"
}

test_status_reports_install_state() {
  setup_scenario

  local output
  output="$(run_status)"
  assert_output_contains "$output" "installed: no"
  assert_output_contains "$output" "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR"

  run_installer --no-update-bashrc >/dev/null

  output="$(run_status)"
  assert_output_contains "$output" "installed: yes"
  assert_output_contains "$output" "path_active: no"
  assert_output_contains "$output" "- aws: docker.io/amazon/aws-cli:2.15.0"
  assert_output_contains "$output" "- task: localhost/shimmy-task:"
  pass "status reports install state"
}

test_status_reports_host_path_activity() {
  setup_scenario

  run_installer --no-update-bashrc >/dev/null

  local output
  output="$(run_status_with_host_path)"

  assert_output_contains "$output" "path_active: yes"
  pass "status reports host path activity"
}

test_status_uses_manifest_paths() {
  setup_split_paths_scenario

  run_installer_with_paths_env --no-update-bashrc --shim task >/dev/null

  local output
  output="$(run_status_with_install_env_only)"

  assert_output_contains "$output" "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR"
  assert_output_contains "$output" "SHIMMY_SHIM_DIR=$SHIMMY_SHIM_DIR"
  assert_output_contains "$output" "SHIMMY_IMAGES_DIR=$SHIMMY_IMAGES_DIR"
  assert_output_contains "$output" "SHIMMY_SHIM_LIB_DIR=$SHIMMY_SHIM_LIB_DIR"
  assert_output_contains "$output" "- task: localhost/shimmy-task:"
  pass "status uses manifest paths"
}

test_update_restores_missing_shim() {
  setup_scenario

  run_installer --no-update-bashrc >/dev/null
  rm -f "$SHIMMY_SHIM_DIR/aws"

  local output
  output="$(run_update)"

  assert_file_exists "$SHIMMY_SHIM_DIR/aws"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "update restores missing shim"
}

test_installed_task_shim_uses_split_paths_globals() {
  setup_split_paths_scenario

  run_installer_with_paths_env --no-update-bashrc --shim task >/dev/null

  local output
  output="$(
    run_wrapper \
      "$SHIMMY_SHIM_DIR/task" \
      "SHIMMY_INSTALL_DIR=$SHIMMY_INSTALL_DIR" \
      "SHIMMY_SHIM_DIR=$SHIMMY_SHIM_DIR" \
      "SHIMMY_IMAGES_DIR=$SHIMMY_IMAGES_DIR" \
      "SHIMMY_SHIM_LIB_DIR=$SHIMMY_SHIM_LIB_DIR" \
      -- --version 2>&1
  )"

  assert_output_contains "$output" "3.45.5"
  pass "installed task shim uses split paths globals"
}

test_update_uses_manifest_paths() {
  setup_split_paths_scenario

  run_installer_with_paths_env --no-update-bashrc >/dev/null
  rm -f "$SHIMMY_SHIM_DIR/aws"

  local output
  output="$(run_update_with_install_env_only)"

  assert_file_exists "$SHIMMY_SHIM_DIR/aws"
  assert_path_not_exists "$SHIMMY_INSTALL_DIR/shims/aws"
  assert_output_contains "$output" "Installed shims into $SHIMMY_INSTALL_DIR (copy)."
  pass "update uses manifest paths"
}

test_uninstall_uses_manifest_paths() {
  setup_split_paths_scenario

  run_installer_with_paths_env --no-update-bashrc --shim task >/dev/null

  local output
  output="$(run_uninstaller_with_install_env_only)"

  assert_path_not_exists "$SHIMMY_INSTALL_DIR"
  assert_path_not_exists "$SHIMMY_SHIM_DIR"
  assert_path_not_exists "$SHIMMY_IMAGES_DIR"
  assert_path_not_exists "$SHIMMY_SHIM_LIB_DIR"
  assert_output_contains "$output" "Removed shimmy artifacts from $SHIMMY_INSTALL_DIR."
  pass "uninstall uses manifest paths"
}

test_update_build_prunes_stale_local_tags() {
  setup_scenario

  run_installer --no-update-bashrc --shim task >/dev/null
  run_wrapper "$SHIMMY_SHIM_DIR/task" -- --version >/dev/null 2>&1

  # shellcheck source=lib/shims/custom-image.sh
  source "$ROOT_DIR/lib/shims/custom-image.sh"

  local current_ref old_ref output
  current_ref="localhost/shimmy-task:$(shimmy::compute_context_hash "$SHIMMY_IMAGES_DIR/task")"
  old_ref="localhost/shimmy-task:shimmy-test-$RANDOM"

  run_podman tag "$current_ref" "$old_ref"
  if ! output="$(run_update --build)"; then
    fail_test "Expected update --build to succeed"
  fi

  if run_podman image exists "$old_ref"; then
    fail_test "Expected stale image tag to be pruned: $old_ref"
  fi

  assert_output_contains "$output" "WARN: Removed stale shim image: $old_ref"
  run_podman image exists "$current_ref" >/dev/null 2>&1 || fail_test "Expected current task image to remain: $current_ref"
  pass "update build prunes stale local tags"
}

main() {
  require_podman

  test_aws_default
  test_aws_with_mount_and_pull
  test_jq_default
  test_jq_with_pull
  test_netcat_default
  test_rg_default
  test_rg_with_pull
  test_task_default
  test_task_with_build_arg_override
  test_terraform_default
  test_terraform_with_mounts_and_pull
  test_textual_default
  # test_tessl_default
  # test_tessl_with_mounts_and_pull
  test_install_creates_managed_files
  test_install_honors_split_paths_globals
  test_install_log_level_error_hides_info_and_debug
  test_install_log_level_debug_emits_debug
  test_install_symlink_mode
  test_install_updates_bash_startup_files
  test_shimmy_shell_file_exports_install_env
  test_shimmy_uninstall_removes_installed_artifacts
  test_uninstall_preserves_preexisting_shell_files
  test_uninstall_removes_empty_preexisting_shimmy_shell_file
  test_shimmy_install_installs_default_shimmy_paths
  test_shimmy_shellenv_activates_installed_paths
  test_shimmy_status_discovers_default_install_from_manifest
  test_sourced_shimmy_status_returns_without_exiting_shell
  test_sourced_shimmy_failure_returns_non_zero_without_exiting_shell
  test_shimmy_update_discovers_default_install_from_manifest
  test_status_reports_install_state
  test_status_reports_host_path_activity
  test_status_uses_manifest_paths
  test_update_restores_missing_shim
  test_installed_task_shim_uses_split_paths_globals
  test_update_uses_manifest_paths
  test_update_build_prunes_stale_local_tags
  test_uninstall_uses_manifest_paths

  echo "All $TEST_COUNT shim tests passed."
}

main "$@"
