#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
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
  exit 1
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

assert_files_equal() {
  local left="$1"
  local right="$2"

  cmp -s "$left" "$right" || fail_test "Expected files to match: $left $right"
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

test_install_creates_repo_profile_files() {
  setup_scenario

  local output
  output="$(run_installer --no-update-bashrc)"

  local profile_dir="$HOME_DIR/.config/shimmy"
  local install_dir="$HOME_DIR/.local/bin/shimmy"

  assert_file_exists "$profile_dir/AGENTS.md"
  assert_file_exists "$profile_dir/docs/prompt-shimmy-project.md"
  assert_file_exists "$profile_dir/.agents/skills/aws/AGENTS.md"
  assert_file_exists "$profile_dir/.agents/skills/aws/SKILL.md"
  assert_file_exists "$profile_dir/install-manifest.txt"
  assert_file_exists "$install_dir/aws"
  assert_file_exists "$install_dir/images/tessl/Containerfile"
  assert_file_exists "$install_dir/lib/custom-image.sh"
  assert_not_symlink "$install_dir/aws"
  assert_files_equal "$ROOT_DIR/AGENTS.md" "$profile_dir/AGENTS.md"
  assert_files_equal "$ROOT_DIR/docs/prompt-shimmy-project.md" "$profile_dir/docs/prompt-shimmy-project.md"
  assert_output_contains "$output" "Installed shims into $install_dir (copy)."
  assert_output_contains "$output" "Created profile file: $profile_dir/AGENTS.md"
  assert_output_contains "$output" "Created profile file: $profile_dir/.agents/skills/aws/SKILL.md"
  pass "install creates repo profile files"
}

test_install_preserves_existing_repo_profile_files() {
  setup_scenario

  local profile_dir="$HOME_DIR/.config/shimmy"
  mkdir -p "$profile_dir/.agents/skills/aws"
  printf '%s\n' 'existing repo agents' > "$profile_dir/AGENTS.md"
  printf '%s\n' 'existing aws skill' > "$profile_dir/.agents/skills/aws/SKILL.md"

  local output
  output="$(run_installer --no-update-bashrc)"

  assert_file_contains_text "$profile_dir/AGENTS.md" "existing repo agents"
  assert_file_contains_text "$profile_dir/.agents/skills/aws/SKILL.md" "existing aws skill"
  assert_file_exists "$profile_dir/.agents/skills/aws/AGENTS.md"
  assert_output_contains "$output" "Warning: profile already exists at $profile_dir/AGENTS.md; unchanged."
  assert_output_contains "$output" "Warning: profile already exists at $profile_dir/.agents/skills/aws/SKILL.md; leaving unchanged."
  pass "install preserves existing repo profile files"
}

test_install_symlink_mode() {
  setup_scenario

  local output
  output="$(run_installer --symlink --no-update-bashrc)"

  local install_dir="$HOME_DIR/.local/bin/shimmy"

  assert_symlink_target "$install_dir/aws" "$ROOT_DIR/shims/aws"
  assert_symlink_target "$install_dir/links" "$ROOT_DIR/runtime"
  assert_output_contains "$output" "Installed shims into $install_dir (symlink)."
  pass "install symlink override"
}

test_install_updates_bash_startup_files() {
  setup_scenario

  local output
  output="$(run_installer)"

  local install_dir="$HOME_DIR/.local/bin/shimmy"
  local bashrc_file="$HOME_DIR/.bashrc"
  local bash_profile_file="$HOME_DIR/.bash_profile"
  local bash_shimmy_file="$HOME_DIR/.bashrc_shimmy"
  local source_line='if [ -f ~/.bashrc_shimmy ]; then . ~/.bashrc_shimmy; fi'

  assert_file_exists "$bashrc_file"
  assert_file_exists "$bash_profile_file"
  assert_file_exists "$bash_shimmy_file"
  assert_file_contains_text "$bashrc_file" "$source_line"
  assert_file_contains_text "$bash_profile_file" "$source_line"
  assert_file_contains_text "$bash_shimmy_file" "if [ -d \"$SHIMMY_SHIM_DIR\" ]; then"
  assert_file_contains_text "$bash_shimmy_file" "*) export PATH=\"\$PATH:$SHIMMY_SHIM_DIR\" ;;"
  assert_output_contains "$output" "Updated Bash startup files: $bashrc_file, $bash_profile_file, $bash_shimmy_file."
  pass "install updates bash startup files"
}

test_uninstall_removes_installed_artifacts() {
  setup_scenario

  run_installer >/dev/null

  local install_dir="$HOME_DIR/.local/bin/shimmy"
  local profile_dir="$HOME_DIR/.config/shimmy"
  local bashrc_file="$HOME_DIR/.bashrc"
  local bash_profile_file="$HOME_DIR/.bash_profile"
  local bash_shimmy_file="$HOME_DIR/.bashrc_shimmy"
  local manifest_file="$profile_dir/install-manifest.txt"
  local output

  output="$(run_uninstaller)"

  assert_path_not_exists "$install_dir"
  assert_path_not_exists "$profile_dir"
  assert_path_not_exists "$bashrc_file"
  assert_path_not_exists "$bash_profile_file"
  assert_path_not_exists "$bash_shimmy_file"
  assert_path_not_exists "$manifest_file"
  assert_output_contains "$output" "Removed shimmy artifacts from $install_dir."
  pass "uninstall removes installed artifacts"
}

test_uninstall_preserves_preexisting_profile_files() {
  setup_scenario

  local profile_dir="$HOME_DIR/.config/shimmy"
  local existing_file="$profile_dir/AGENTS.md"
  mkdir -p "$profile_dir"
  printf '%s\n' 'preexisting profile file' > "$existing_file"

  run_installer >/dev/null
  run_uninstaller >/dev/null

  assert_file_contains_text "$existing_file" "preexisting profile file"
  assert_path_not_exists "$profile_dir/install-manifest.txt"
  pass "uninstall preserves preexisting profile files"
}

test_uninstall_preserves_preexisting_shell_files() {
  setup_scenario

  local bashrc_file="$HOME_DIR/.bashrc"
  : > "$bashrc_file"

  run_installer >/dev/null
  run_uninstaller >/dev/null

  assert_file_exists "$bashrc_file"
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
  test_tessl_default
  test_tessl_with_mounts_and_pull
  test_install_creates_repo_profile_files
  test_install_preserves_existing_repo_profile_files
  test_install_symlink_mode
  test_install_updates_bash_startup_files
  test_uninstall_removes_installed_artifacts
  test_uninstall_preserves_preexisting_profile_files
  test_uninstall_preserves_preexisting_shell_files

  echo "All $TEST_COUNT shim tests passed."
}

main "$@"
