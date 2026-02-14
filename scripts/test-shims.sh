#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
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

setup_scenario() {
  SCENARIO_DIR="$(mktemp -d "$TMP_ROOT/scenario.XXXXXX")"
  HOME_DIR="$SCENARIO_DIR/home"
  BIN_DIR="$SCENARIO_DIR/bin"
  ARGS_FILE="$SCENARIO_DIR/podman.args"

  mkdir -p "$HOME_DIR" "$BIN_DIR"

  cat > "$BIN_DIR/podman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$PODMAN_ARGS_FILE"
EOF
  chmod +x "$BIN_DIR/podman"
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
    cd "$ROOT_DIR"
    env "HOME=$HOME_DIR" "PATH=$BIN_DIR:$PATH" "PODMAN_ARGS_FILE=$ARGS_FILE" "${env_vars[@]}" "$wrapper" "${wrapper_args[@]}"
  )
}

assert_args_equal() {
  local file="$1"
  shift
  local -a expected=("$@")
  local -a actual=()

  mapfile -t actual < "$file"

  if [[ "${#actual[@]}" -ne "${#expected[@]}" ]]; then
    echo "Expected ${#expected[@]} args, got ${#actual[@]}" >&2
    echo "Expected: ${expected[*]}" >&2
    echo "Actual:   ${actual[*]}" >&2
    return 1
  fi

  local i
  for i in "${!expected[@]}"; do
    if [[ "${actual[$i]}" != "${expected[$i]}" ]]; then
      echo "Arg[$i] mismatch" >&2
      echo "Expected: ${expected[$i]}" >&2
      echo "Actual:   ${actual[$i]}" >&2
      return 1
    fi
  done
}

test_aws_default() {
  setup_scenario

  run_wrapper "$ROOT_DIR/shims/aws" -- sts get-caller-identity

  local -a expected=(
    "run"
    "--rm"
    "-it"
    "-v"
    "$ROOT_DIR:/work"
    "-w"
    "/work"
    "-e"
    "AWS_PROFILE"
    "-e"
    "AWS_REGION"
    "-e"
    "AWS_ACCESS_KEY_ID"
    "-e"
    "AWS_SECRET_ACCESS_KEY"
    "-e"
    "AWS_SESSION_TOKEN"
    "amazon/aws-cli:2.15.0"
    "sts"
    "get-caller-identity"
  )

  assert_args_equal "$ARGS_FILE" "${expected[@]}"
  pass "aws default args"
}

test_aws_with_mount_and_pull() {
  setup_scenario
  mkdir -p "$HOME_DIR/.aws"

  run_wrapper "$ROOT_DIR/shims/aws" "AWS_IMAGE=public.ecr.aws/aws-cli/aws-cli:2.31.21" "AWS_IMAGE_PULL=always" -- --version

  local -a expected=(
    "run"
    "--rm"
    "-it"
    "--pull=always"
    "-v"
    "$ROOT_DIR:/work"
    "-w"
    "/work"
    "-v"
    "$HOME_DIR/.aws:/root/.aws:ro"
    "-e"
    "AWS_PROFILE"
    "-e"
    "AWS_REGION"
    "-e"
    "AWS_ACCESS_KEY_ID"
    "-e"
    "AWS_SECRET_ACCESS_KEY"
    "-e"
    "AWS_SESSION_TOKEN"
    "public.ecr.aws/aws-cli/aws-cli:2.31.21"
    "--version"
  )

  assert_args_equal "$ARGS_FILE" "${expected[@]}"
  pass "aws mount + pull args"
}

test_jq_default() {
  setup_scenario

  run_wrapper "$ROOT_DIR/shims/jq" -- --version

  local -a expected=(
    "run"
    "--rm"
    "-i"
    "-v"
    "$ROOT_DIR:/work"
    "-w"
    "/work"
    "docker.io/stedolan/jq:latest"
    "--version"
  )

  assert_args_equal "$ARGS_FILE" "${expected[@]}"
  pass "jq default args"
}

test_jq_with_pull() {
  setup_scenario

  run_wrapper "$ROOT_DIR/shims/jq" "JQ_IMAGE=ghcr.io/jqlang/jq:latest" "JQ_IMAGE_PULL=always" -- .foo input.json

  local -a expected=(
    "run"
    "--rm"
    "-i"
    "--pull=always"
    "-v"
    "$ROOT_DIR:/work"
    "-w"
    "/work"
    "ghcr.io/jqlang/jq:latest"
    ".foo"
    "input.json"
  )

  assert_args_equal "$ARGS_FILE" "${expected[@]}"
  pass "jq pull args"
}

test_rg_default() {
  setup_scenario

  run_wrapper "$ROOT_DIR/shims/rg" -- --version

  local -a expected=(
    "run"
    "--rm"
    "-i"
    "-v"
    "$ROOT_DIR:/work"
    "-w"
    "/work"
    "docker.io/burntsushi/ripgrep:13.0.0"
    "--version"
  )

  assert_args_equal "$ARGS_FILE" "${expected[@]}"
  pass "rg default args"
}

test_rg_with_pull() {
  setup_scenario

  run_wrapper "$ROOT_DIR/shims/rg" "RG_IMAGE=ghcr.io/burntsushi/ripgrep:14.1.1" "RG_IMAGE_PULL=always" -- --files

  local -a expected=(
    "run"
    "--rm"
    "-i"
    "--pull=always"
    "-v"
    "$ROOT_DIR:/work"
    "-w"
    "/work"
    "ghcr.io/burntsushi/ripgrep:14.1.1"
    "--files"
  )

  assert_args_equal "$ARGS_FILE" "${expected[@]}"
  pass "rg pull args"
}

test_terraform_default() {
  setup_scenario

  run_wrapper "$ROOT_DIR/shims/terraform" -- version

  local -a expected=(
    "run"
    "--rm"
    "-it"
    "-v"
    "$ROOT_DIR:/work"
    "-w"
    "/work"
    "-e"
    "AWS_PROFILE"
    "-e"
    "AWS_REGION"
    "-e"
    "AWS_ACCESS_KEY_ID"
    "-e"
    "AWS_SECRET_ACCESS_KEY"
    "-e"
    "AWS_SESSION_TOKEN"
    "docker.io/hashicorp/terraform:1.5.6"
    "version"
  )

  assert_args_equal "$ARGS_FILE" "${expected[@]}"
  pass "terraform default args"
}

test_terraform_with_mounts_and_pull() {
  setup_scenario
  mkdir -p "$HOME_DIR/.aws" "$HOME_DIR/.terraform.d/plugin-cache"

  run_wrapper "$ROOT_DIR/shims/terraform" "TF_IMAGE=hashicorp/terraform:1.14.5" "TF_IMAGE_PULL=always" -- plan

  local -a expected=(
    "run"
    "--rm"
    "-it"
    "--pull=always"
    "-v"
    "$ROOT_DIR:/work"
    "-w"
    "/work"
    "-v"
    "$HOME_DIR/.aws:/root/.aws:ro"
    "-v"
    "$HOME_DIR/.terraform.d/plugin-cache:/root/.terraform.d/plugin-cache"
    "-e"
    "AWS_PROFILE"
    "-e"
    "AWS_REGION"
    "-e"
    "AWS_ACCESS_KEY_ID"
    "-e"
    "AWS_SECRET_ACCESS_KEY"
    "-e"
    "AWS_SESSION_TOKEN"
    "hashicorp/terraform:1.14.5"
    "plan"
  )

  assert_args_equal "$ARGS_FILE" "${expected[@]}"
  pass "terraform mounts + pull args"
}

main() {
  test_aws_default
  test_aws_with_mount_and_pull
  test_jq_default
  test_jq_with_pull
  test_rg_default
  test_rg_with_pull
  test_terraform_default
  test_terraform_with_mounts_and_pull

  echo "All $TEST_COUNT shim tests passed."
}

main "$@"
