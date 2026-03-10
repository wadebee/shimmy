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
      --no-update-bashrc \
      "$@"
  )
}

assert_output_contains() {
  local output="$1"
  local expected="$2"

  [[ "$output" == *"$expected"* ]] || fail_test "Expected output to contain: $expected"
}

assert_file_exists() {
  local path="$1"

  [[ -f "$path" ]] || fail_test "Expected file to exist: $path"
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

test_install_creates_repo_profile_files() {
  setup_scenario

  local output
  output="$(run_installer)"

  local profile_dir="$HOME_DIR/.config/shimmy"
  local install_dir="$HOME_DIR/.local/bin/shimmy"

  assert_file_exists "$profile_dir/AGENTS.md"
  assert_file_exists "$profile_dir/docs/shimmy-project-prompt.md"
  assert_file_exists "$profile_dir/.agents/skills/aws/AGENTS.md"
  assert_file_exists "$profile_dir/.agents/skills/aws/SKILL.md"
  assert_file_exists "$install_dir/aws"
  assert_not_symlink "$install_dir/aws"
  assert_files_equal "$ROOT_DIR/AGENTS.md" "$profile_dir/AGENTS.md"
  assert_files_equal "$ROOT_DIR/docs/shimmy-project-prompt.md" "$profile_dir/docs/shimmy-project-prompt.md"
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
  output="$(run_installer)"

  assert_file_contains_text "$profile_dir/AGENTS.md" "existing repo agents"
  assert_file_contains_text "$profile_dir/.agents/skills/aws/SKILL.md" "existing aws skill"
  assert_file_exists "$profile_dir/.agents/skills/aws/AGENTS.md"
  assert_output_contains "$output" "Warning: profile file already exists at $profile_dir/AGENTS.md; leaving AGENTS.md unchanged."
  assert_output_contains "$output" "Warning: profile file already exists at $profile_dir/.agents/skills/aws/SKILL.md; leaving .agents/skills/aws/SKILL.md unchanged."
  pass "install preserves existing repo profile files"
}

test_install_symlink_mode() {
  setup_scenario

  local output
  output="$(run_installer --symlink)"

  local install_dir="$HOME_DIR/.local/bin/shimmy"

  assert_symlink_target "$install_dir/aws" "$ROOT_DIR/shims/aws"
  assert_output_contains "$output" "Installed shims into $install_dir (symlink)."
  pass "install symlink override"
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
  test_install_creates_repo_profile_files
  test_install_preserves_existing_repo_profile_files
  test_install_symlink_mode

  echo "All $TEST_COUNT shim tests passed."
}

main "$@"
