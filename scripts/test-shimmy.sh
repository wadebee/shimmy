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

assert_file_executable() {
  if [ ! -x "$1" ]; then
    fail_test "expected file to be executable: $1"
  fi
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

test_podman_platform_resolves_host_os() {
  linux_platform=$(
    SHIMMY_TEST_OS=Linux /bin/sh -c '. "$1"; shimmy_podman_platform_resolve; printf "%s\n" "$SHIMMY_PODMAN_PLATFORM"' sh "$PODMAN_HELPER_FILE"
  )
  darwin_platform=$(
    SHIMMY_TEST_OS=Darwin /bin/sh -c '. "$1"; shimmy_podman_platform_resolve; printf "%s\n" "$SHIMMY_PODMAN_PLATFORM"' sh "$PODMAN_HELPER_FILE"
  )

  assert_equals "$linux_platform" "linux/amd64"
  assert_equals "$darwin_platform" "linux/arm64"

  pass "Podman platform resolves from host OS"
}

test_podman_platform_tag_render() {
  platform_tag=$(
    /bin/sh -c '. "$1"; shimmy_podman_platform_tag_render linux/arm64' sh "$PODMAN_HELPER_FILE"
  )

  assert_equals "$platform_tag" "linux-arm64"

  pass "Podman platform tag rendering"
}

test_podman_unreachable_guidance_agent() {
  output=$(
    /bin/sh -c '. "$1"; shimmy_podman_failure_print_unreachable "the rg shim" "/opt/podman/bin/podman"' sh "$PODMAN_HELPER_FILE" 2>&1
  )

  assert_contains "$output" 'AI Agent note: if `podman info` succeeds but this shim still fails'
  assert_contains "$output" '["rg","--version"] or ["./shims/rg","--version"]'
  assert_contains "$output" 'Approving `podman info` alone does not approve Podman access through a Shimmy wrapper.'

  pass "Podman unreachable guidance includes AI Agent approval hint"
}

run_in_repo() {
  (
    cd "$ROOT_DIR"
    "$@"
  )
}

tracked_shell_file_list() {
  git -C "$ROOT_DIR" ls-files | while IFS= read -r tracked_path; do
    case "$tracked_path" in
      shimmy|scripts/*.sh|lib/*/*.sh|shims/*)
        [ -f "$ROOT_DIR/$tracked_path" ] || continue
        printf '%s\n' "$ROOT_DIR/$tracked_path"
        ;;
    esac
  done
}

test_dash_parse() {
  command -v dash >/dev/null 2>&1 || fail_test "dash is required for parser checks"

  parsed_file_count=0
  while IFS= read -r parse_file; do
    [ -n "$parse_file" ] || continue
    dash -n "$parse_file"
    parsed_file_count=$((parsed_file_count + 1))
  done <<EOF
$(tracked_shell_file_list)
EOF

  [ "$parsed_file_count" -gt 0 ] || fail_test "expected tracked shell files for parser checks"

  pass "dash parse checks"
}

test_install_manifest() {
  setup_scenario

  output=$(
    HOME="$HOME_DIR" SHELL=/bin/bash run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq 2>&1
  )

  assert_contains "$output" "Installed shimmy assets into $INSTALL_DIR"
  assert_contains "$output" "Updated startup file: $HOME_DIR/.bashrc"
  assert_contains "$output" "Updated startup file: $HOME_DIR/.bash_profile"
  assert_contains "$output" "Activate this install with: eval"
  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  assert_file_exists "$INSTALL_DIR/activate.sh"
  assert_file_exists "$INSTALL_DIR/shims/jq"
  assert_dir_exists "$INSTALL_DIR/lib/shims"
  assert_file_exists "$HOME_DIR/.bashrc"
  assert_file_exists "$HOME_DIR/.bash_profile"

  manifest_contents=$(cat "$INSTALL_DIR/install-manifest.txt")
  assert_contains "$manifest_contents" "install_dir=$INSTALL_DIR"
  assert_contains "$manifest_contents" "activate_file=$INSTALL_DIR/activate.sh"
  assert_contains "$manifest_contents" "startup_shell=bash"
  assert_contains "$manifest_contents" "startup_file=$HOME_DIR/.bashrc"
  assert_contains "$manifest_contents" "startup_file=$HOME_DIR/.bash_profile"
  assert_contains "$manifest_contents" "shim=jq"
  assert_contains "$manifest_contents" "shimmy_manifest_version=1"
  assert_contains "$manifest_contents" "shimmy_source_url="
  assert_contains "$manifest_contents" "shimmy_source_ref="
  assert_not_contains "$manifest_contents" "shim_dir="
  assert_not_contains "$manifest_contents" "images_dir="
  assert_not_contains "$manifest_contents" "shim_lib_dir="
  assert_file_contains "$HOME_DIR/.bashrc" "# >>> shimmy onboarding >>>"
  assert_file_contains "$HOME_DIR/.bashrc" "$INSTALL_DIR/activate.sh"
  assert_file_contains "$HOME_DIR/.bash_profile" "# >>> shimmy onboarding >>>"
  assert_file_contains "$HOME_DIR/.bash_profile" "$INSTALL_DIR/activate.sh"
  assert_file_contains "$INSTALL_DIR/activate.sh" "$INSTALL_DIR/shims"

  pass "install writes manifest and startup file"
}

test_install_removes_legacy_shell_init_block() {
  setup_scenario

  startup_file=$HOME_DIR/.bash_profile
  {
    printf '# existing shell config\n'
    printf '# >>> shimmy shell init >>>\n'
    printf 'if [ -f "%s/.bashrc_shimmy" ]; then . "%s/.bashrc_shimmy"; fi\n' "$HOME_DIR" "$HOME_DIR"
    printf '# <<< shimmy shell init <<<\n'
  } > "$startup_file"

  HOME="$HOME_DIR" SHELL=/bin/bash run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  startup_contents=$(cat "$startup_file")
  assert_contains "$startup_contents" "# existing shell config"
  assert_contains "$startup_contents" "# >>> shimmy onboarding >>>"
  assert_contains "$startup_contents" "$INSTALL_DIR/activate.sh"
  assert_not_contains "$startup_contents" "# >>> shimmy shell init >>>"
  assert_not_contains "$startup_contents" ".bashrc_shimmy"

  pass "install removes legacy shell init block"
}

test_install_bash_uses_existing_profile_login_file() {
  setup_scenario

  printf '# existing profile config\n' > "$HOME_DIR/.profile"

  HOME="$HOME_DIR" SHELL=/bin/bash run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  assert_file_contains "$HOME_DIR/.bashrc" "$INSTALL_DIR/activate.sh"
  assert_file_contains "$HOME_DIR/.profile" "# existing profile config"
  assert_file_contains "$HOME_DIR/.profile" "$INSTALL_DIR/activate.sh"
  assert_path_not_exists "$HOME_DIR/.bash_profile"

  manifest_contents=$(cat "$INSTALL_DIR/install-manifest.txt")
  assert_contains "$manifest_contents" "startup_file=$HOME_DIR/.bashrc"
  assert_contains "$manifest_contents" "startup_file=$HOME_DIR/.profile"
  assert_not_contains "$manifest_contents" "startup_file=$HOME_DIR/.bash_profile"

  pass "bash install uses existing profile login file"
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
  assert_file_exists "$INSTALL_DIR/activate.sh"
  assert_path_not_exists "$HOME_DIR/.bashrc"
  assert_path_not_exists "$HOME_DIR/.bash_profile"

  pass "install can skip startup file updates"
}

test_install_macos_podman_guidance() {
  setup_scenario

  output=$(
    SHIMMY_TEST_OS=Darwin HOME="$HOME_DIR" SHELL=/bin/bash run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup 2>&1
  )

  assert_contains "$output" "macOS Podman check: run 'podman info' in a normal shell before using Shimmy."
  assert_contains "$output" "If Podman is unreachable, run 'podman machine start' in that shell, then retry Shimmy."

  pass "install prints macOS Podman guidance"
}

test_agent_shimmy_preflight_reports_approvals() {
  setup_scenario

  mkdir -p "$WORK_DIR/bin"
  cat > "$WORK_DIR/bin/podman" <<'EOF'
#!/bin/sh
case "${1:-}" in
  info)
    exit 0
    ;;
  *)
    printf '%s\n' 'fake podman'
    exit 0
    ;;
esac
EOF
  chmod +x "$WORK_DIR/bin/podman"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim rg --no-startup >/dev/null

  output=$(
    PATH="$WORK_DIR/bin:$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_INSTALL_DIR="$INSTALL_DIR" run_in_repo ./scripts/agent-shimmy-preflight.sh 2>&1
  )

  assert_file_executable "$ROOT_DIR/scripts/agent-shimmy-preflight.sh"
  assert_contains "$output" "podman_info=ok"
  assert_contains "$output" "active_shim=rg"
  assert_contains "$output" 'agent_prefix_rule=["rg","--version"]'
  assert_contains "$output" "smoke_command=rg --version"
  assert_contains "$output" "repo_shim=rg"
  assert_contains "$output" 'agent_prefix_rule=["./shims/rg","--version"]'
  assert_contains "$output" 'approving ["podman", "info"] alone does not approve a Shimmy wrapper.'

  pass "AI Agent preflight reports narrow shim approvals"
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
  assert_file_contains "$startup_file" "$INSTALL_DIR/activate.sh"
  assert_file_contains "$INSTALL_DIR/activate.sh" "$INSTALL_DIR/shims"

  HOME="$HOME_DIR" SHELL=/bin/zsh run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --repair-startup >/dev/null
  marker_count=$(grep -c '^# >>> shimmy onboarding >>>$' "$startup_file")
  [ "$marker_count" -eq 1 ] || fail_test "expected one onboarding block marker, found $marker_count"

  pass "update can repair startup file idempotently"
}

test_status_reports_install() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task >/dev/null

  output=$(
    HOME="$HOME_DIR" SHIMMY_TEST_OS=Darwin run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" 2>&1
  )

  assert_contains "$output" "installed: yes"
  assert_contains "$output" "install_dir=$INSTALL_DIR"
  assert_contains "$output" "shim_dir=$INSTALL_DIR/shims"
  assert_contains "$output" "- jq: ghcr.io/jqlang/jq:1.8.1"
  assert_contains "$output" "- task: localhost/shimmy-task:"
  assert_contains "$output" "-linux-arm64"

  pass "status reports installed shim details"
}

test_status_manifest_format() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --format manifest 2>&1
  )

  assert_contains "$output" "installed=yes"
  assert_contains "$output" "install_dir=$INSTALL_DIR"
  assert_contains "$output" "shim_dir=$INSTALL_DIR/shims"
  assert_contains "$output" "path_active=no"
  assert_contains "$output" "activate_file=$INSTALL_DIR/activate.sh"
  assert_contains "$output" "shim=jq"
  assert_contains "$output" "shimmy_manifest_version=1"
  assert_not_contains "$output" "Shimmy Status"
  assert_not_contains "$output" "installed_shims:"

  pass "status manifest format is machine-readable"
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

test_update_preserves_shimmy_manifest_fields() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  manifest_file=$INSTALL_DIR/install-manifest.txt
  original_source_ref=$(sed -n 's/^shimmy_source_ref=//p' "$manifest_file" | sed -n '1p')

  {
    printf 'shimmy_update_policy=on-use\n'
    printf 'shimmy_update_interval_hours=12\n'
    printf 'shimmy_last_checked=2026-05-04T00:00:00Z\n'
  } >> "$manifest_file"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" >/dev/null

  manifest_contents=$(cat "$manifest_file")
  assert_contains "$manifest_contents" "shimmy_update_policy=on-use"
  assert_contains "$manifest_contents" "shimmy_update_interval_hours=12"
  assert_contains "$manifest_contents" "shimmy_last_checked=2026-05-04T00:00:00Z"
  if [ -n "$original_source_ref" ]; then
    assert_contains "$manifest_contents" "shimmy_previous_source_ref=$original_source_ref"
  fi

  pass "update preserves shimmy manifest lifecycle fields"
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

test_go_shim_direct() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/go" version 2>&1
  )

  assert_contains "$output" "go version go"

  pass "go direct shim execution"
}

test_go_shim_help_test() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/go" help test 2>&1
  )

  assert_contains "$output" "usage: go test"
  assert_not_contains "$output" "forwarding signal"
  assert_not_contains "$output" "container has already been removed"

  pass "go help test shim execution"
}

test_go_shim_platform_execution() {
  setup_scenario
  require_podman

  case "$(uname -s 2>/dev/null || printf unknown)" in
    Darwin)
      expected_goarch=arm64
      ;;
    Linux)
      expected_goarch=amd64
      ;;
    *)
      expected_goarch=amd64
      ;;
  esac

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/go" env GOARCH 2>&1
  )

  assert_contains "$output" "$expected_goarch"

  pass "go shim platform selection"
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
    PATH="$(dirname "$PODMAN_BIN"):$PATH" JQ_IMAGE_PULL=always JQ_IMAGE=ghcr.io/jqlang/jq:1.8.1 "$ROOT_DIR/shims/jq" --version 2>&1
  )

  assert_contains "$output" "jq-1.8.1"

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

  assert_contains "$output" "jq-1.8.1"

  pass "installed jq shim execution"
}

test_installed_go_shim() {
  setup_scenario
  require_podman

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim go >/dev/null

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$INSTALL_DIR/shims/go" version 2>&1
  )

  assert_contains "$output" "go version go"

  pass "installed go shim execution"
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

test_nmap_shim_direct() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/nmap" --version 2>&1
  )

  assert_contains "$output" "Nmap version"

  pass "nmap direct shim execution"
}

test_nmap_shim_lan_scan_opt_in() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" SHIMMY_NMAP_LAN_SCAN=1 "$ROOT_DIR/shims/nmap" --version 2>&1
  )

  assert_contains "$output" "Nmap version"

  pass "nmap LAN scan opt-in execution"
}

test_nmap_shim_network_opt_in() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" SHIMMY_NMAP_NETWORK=none "$ROOT_DIR/shims/nmap" --version 2>&1
  )

  assert_contains "$output" "Nmap version"

  pass "nmap network opt-in execution"
}

test_nmap_shim_privileged_opt_in() {
  setup_scenario
  require_podman

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" SHIMMY_NMAP_LAN_SCAN=1 SHIMMY_NMAP_PRIVILEGED=1 "$ROOT_DIR/shims/nmap" --version 2>&1
  )

  assert_contains "$output" "Nmap version"

  pass "nmap privileged opt-in execution"
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
  bash_profile_file=$HOME_DIR/.bash_profile
  printf '# existing shell config\n' > "$startup_file"
  printf '# existing profile config\n' > "$bash_profile_file"

  HOME="$HOME_DIR" SHELL=/bin/bash run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  HOME="$HOME_DIR" run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" >/dev/null

  assert_path_not_exists "$INSTALL_DIR"
  assert_file_contains "$startup_file" "# existing shell config"
  assert_file_contains "$bash_profile_file" "# existing profile config"
  startup_contents=$(cat "$startup_file")
  bash_profile_contents=$(cat "$bash_profile_file")
  assert_not_contains "$startup_contents" "# >>> shimmy onboarding >>>"
  assert_not_contains "$startup_contents" "$INSTALL_DIR/activate.sh"
  assert_not_contains "$bash_profile_contents" "# >>> shimmy onboarding >>>"
  assert_not_contains "$bash_profile_contents" "$INSTALL_DIR/activate.sh"

  pass "uninstall removes install root and startup block"
}

main() {
  test_podman_platform_resolves_host_os
  test_podman_platform_tag_render
  test_podman_unreachable_guidance_agent
  test_dash_parse
  test_install_manifest
  test_install_removes_legacy_shell_init_block
  test_install_bash_uses_existing_profile_login_file
  test_activate_eval
  test_activate_is_idempotent
  test_install_no_startup
  test_install_macos_podman_guidance
  test_agent_shimmy_preflight_reports_approvals
  test_update_repair_startup
  test_status_reports_install
  test_status_manifest_format
  test_update_reinstalls_selected_shims
  test_update_preserves_shimmy_manifest_fields
  test_aws_shim_direct
  test_go_shim_direct
  test_go_shim_help_test
  test_go_shim_platform_execution
  test_jq_shim_direct
  test_jq_shim_pull_override
  test_installed_go_shim
  test_installed_jq_shim
  test_netcat_shim_direct
  test_nmap_shim_direct
  test_nmap_shim_lan_scan_opt_in
  test_nmap_shim_network_opt_in
  test_nmap_shim_privileged_opt_in
  test_rg_shim_direct
  test_task_shim_direct
  test_terraform_shim_direct
  test_textual_shim_direct
  test_installed_task_shim
  test_uninstall_cleanup

  printf 'All %s shim tests passed.\n' "$TEST_COUNT"
}

main "$@"
