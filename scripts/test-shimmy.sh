#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
SHIMMY_PODMAN_HELPER_FILE=$ROOT_DIR/lib/shims/shimmy-podman.sh
COMMON_HELPER_FILE=$ROOT_DIR/lib/repo/shimmy-common.sh
CATALOG_HELPER_FILE=$ROOT_DIR/lib/repo/shimmy-catalog.sh
PROFILE_HELPER_FILE=$ROOT_DIR/lib/repo/shimmy-profile.sh
TMP_PARENT=${TMPDIR:-/tmp}
case "$TMP_PARENT" in
  ''|/)
    TMP_PARENT=/tmp
    ;;
  */)
    TMP_PARENT=${TMP_PARENT%/}
    ;;
esac
TMP_ROOT=$(mktemp -d "$TMP_PARENT/shimmy-test.XXXXXX")
TEST_COUNT=0
SHIM_SMOKE_TEST_COUNT=0
REQUESTED_INSTALL_DIR=
SHIMMY_PROFILE_REQUESTED=
REQUESTED_TEST_ALL=0
REQUESTED_TEST_SHIM=
RUN_PROFILE_TESTS=0

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

if [ ! -f "$SHIMMY_PODMAN_HELPER_FILE" ]; then
  fail_test "missing Podman helper: $SHIMMY_PODMAN_HELPER_FILE"
fi

if [ ! -f "$CATALOG_HELPER_FILE" ]; then
  fail_test "missing catalog helper: $CATALOG_HELPER_FILE"
fi

if [ ! -f "$COMMON_HELPER_FILE" ]; then
  fail_test "missing common helper: $COMMON_HELPER_FILE"
fi

if [ ! -f "$PROFILE_HELPER_FILE" ]; then
  fail_test "missing profile helper: $PROFILE_HELPER_FILE"
fi

# shellcheck source=lib/shims/shimmy-podman.sh
. "$SHIMMY_PODMAN_HELPER_FILE"
# shellcheck source=lib/repo/shimmy-common.sh
. "$COMMON_HELPER_FILE"
# shellcheck source=lib/repo/shimmy-catalog.sh
. "$CATALOG_HELPER_FILE"
# shellcheck source=lib/repo/shimmy-profile.sh
. "$PROFILE_HELPER_FILE"

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

assert_path_symlink() {
  if [ ! -L "$1" ]; then
    fail_test "expected path to be a symlink: $1"
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

usage() {
  cat <<'EOF'
Run Shimmy tests.

Usage:
  scripts/test-shimmy.sh [--install-dir <dir>] [--profile default|upstream] [--shim <name>] [--all]

Without an explicit mode, install dir, SHIMMY_PROFILE_ACTIVE, or installed launcher
context, this runs the full source-checkout test suite. With a selected
profile, it validates root/profile manifests and tests root default shims.
Use --shim for one installed shim or --all for root default shims plus every
profile-owned shim recorded in the selected profile manifest.
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        [ "$#" -ge 2 ] || fail_test "missing value for --install-dir"
        REQUESTED_INSTALL_DIR=$2
        RUN_PROFILE_TESTS=1
        shift 2
        ;;
      --profile)
        [ "$#" -ge 2 ] || fail_test "missing value for --profile"
        SHIMMY_PROFILE_REQUESTED=$2
        RUN_PROFILE_TESTS=1
        shift 2
        ;;
      --all)
        REQUESTED_TEST_ALL=1
        RUN_PROFILE_TESTS=1
        shift
        ;;
      --shim)
        [ "$#" -ge 2 ] || fail_test "missing value for --shim"
        REQUESTED_TEST_SHIM=$2
        RUN_PROFILE_TESTS=1
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail_test "unknown argument: $1"
        ;;
    esac
  done

  if [ -n "${SHIMMY_PROFILE_ACTIVE:-}" ] || [ -n "${SHIMMY_CONTROL_INSTALL_DIR:-}" ]; then
    RUN_PROFILE_TESTS=1
  fi

  if [ "$REQUESTED_TEST_ALL" -eq 1 ] && [ -n "$REQUESTED_TEST_SHIM" ]; then
    fail_test "--all cannot be combined with --shim"
  fi
}

test_install_dir_resolve() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    shimmy_trim_path_trailing_slash "$REQUESTED_INSTALL_DIR"
    return 0
  fi

  shimmy_trim_path_trailing_slash "${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}"
}

test_profile_manifest_resolve() {
  printf '%s\n' "$SHIMMY_PROFILE_MANIFEST_PATH"
}

test_root_manifest_resolve() {
  printf '%s/install-manifest.txt\n' "$SHIMMY_PROFILE_INSTALL_DIR"
}

test_root_default_shim_contains() {
  root_manifest_file=$1
  shim_name_expected=$2

  while IFS= read -r default_shim_name; do
    [ -n "$default_shim_name" ] || continue
    if [ "$default_shim_name" = "$shim_name_expected" ]; then
      return 0
    fi
  done <<EOF
$(shimmy_read_manifest_values "$root_manifest_file" default_shim || true)
EOF

  return 1
}

test_root_shim_resolve() {
  root_manifest_file=$1

  if [ -n "$REQUESTED_TEST_SHIM" ]; then
    if test_root_default_shim_contains "$root_manifest_file" "$REQUESTED_TEST_SHIM"; then
      printf '%s\n' "$REQUESTED_TEST_SHIM"
    fi
    return 0
  fi

  shimmy_read_manifest_values "$root_manifest_file" default_shim || true
}

test_manifest_shim_contains() {
  manifest_file=$1
  shim_name_expected=$2

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    if [ "$shim_name" = "$shim_name_expected" ]; then
      return 0
    fi
  done <<EOF
$(shimmy_read_manifest_values "$manifest_file" shim || true)
EOF

  return 1
}

test_root_manifest_validate() {
  root_manifest_file=$1

  [ -f "$root_manifest_file" ] || fail_test "no Shimmy root manifest found: $root_manifest_file"
  root_install_dir=$(shimmy_read_manifest_value "$root_manifest_file" install_dir || true)
  [ -n "$root_install_dir" ] || fail_test "root manifest missing install_dir: $root_manifest_file"

  for shim_name in $(shimmy_default_shim_list); do
    if ! test_root_default_shim_contains "$root_manifest_file" "$shim_name"; then
      fail_test "root manifest missing default_shim=$shim_name: $root_manifest_file"
    fi
  done
}

assert_mode_flag_rejected() {
  command_name=$1
  shift

  setup_scenario
  removed_flag_prefix=--mo
  removed_profile_flag=${removed_flag_prefix}de

  set +e
  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy "$@" "$removed_profile_flag" default 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected removed profile flag to fail for $command_name"
  assert_contains "$output" "unknown argument: $removed_profile_flag"
}

test_profile_rejects_mode_flag() {
  assert_mode_flag_rejected "install" install
  assert_mode_flag_rejected "uninstall" uninstall
  assert_mode_flag_rejected "activate" activate
  assert_mode_flag_rejected "status" status
  assert_mode_flag_rejected "update" update
  assert_mode_flag_rejected "test" test

  pass "removed profile flag is rejected as an unknown argument"
}

test_profile_shim_resolve() {
  manifest_file=$1
  root_manifest_file=$2

  if [ -n "$REQUESTED_TEST_SHIM" ]; then
    if ! test_root_default_shim_contains "$root_manifest_file" "$REQUESTED_TEST_SHIM"; then
      printf '%s\n' "$REQUESTED_TEST_SHIM"
    fi
    return 0
  fi

  if [ "$REQUESTED_TEST_ALL" -eq 0 ]; then
    return 0
  fi

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    if ! test_root_default_shim_contains "$root_manifest_file" "$shim_name"; then
      printf '%s\n' "$shim_name"
    fi
  done <<EOF
$(shimmy_read_manifest_values "$manifest_file" shim || true)
EOF
}

test_shim_smoke_run() {
  shim_name=$1
  test_scope=$2
  manifest_file=$3
  bin_dir=$4
  dispatcher_dir=$5
  config_dir=$6

  test_manifest_shim_contains "$manifest_file" "$shim_name" || fail_test "shim not recorded in Shimmy profile manifest: $shim_name"

  shim_dispatcher_path=$dispatcher_dir/$shim_name
  shim_target_path=$bin_dir/$shim_name
  shim_config_file=$config_dir/shims/$shim_name.conf

  [ -x "$shim_dispatcher_path" ] || fail_test "expected dispatcher to be executable: $shim_dispatcher_path"
  [ -x "$shim_target_path" ] || fail_test "expected profile implementation to be executable: $shim_target_path"
  [ -f "$shim_config_file" ] || fail_test "missing installed shim config: $shim_config_file"

  set --
  while IFS= read -r shim_config_line || [ -n "$shim_config_line" ]; do
    case "$shim_config_line" in
      smoke_arg=*)
        set -- "$@" "${shim_config_line#smoke_arg=}"
        ;;
    esac
  done < "$shim_config_file"

  [ "$#" -gt 0 ] || fail_test "missing smoke_arg in installed shim config: $shim_config_file"

  printf '%s_test_shim=%s\n' "$test_scope" "$shim_name"
  for shim_smoke_arg in "$@"; do
    printf '%s_test_shim_smoke_arg=%s|%s\n' "$test_scope" "$shim_name" "$shim_smoke_arg"
  done

  set +e
  command_output=$(
    SHIMMY_PROFILE_ACTIVE=$SHIMMY_PROFILE_NAME "$shim_dispatcher_path" "$@" 2>&1
  )
  command_status=$?
  set -e

  printf '%s\n' "$command_output"
  [ "$command_status" -eq 0 ] || fail_test "$test_scope smoke command failed for $shim_name in profile $SHIMMY_PROFILE_NAME"
  SHIM_SMOKE_TEST_COUNT=$((SHIM_SMOKE_TEST_COUNT + 1))
}

run_profile_tests() {
  install_dir=$(test_install_dir_resolve)
  if ! shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$install_dir" "$ROOT_DIR"; then
    fail_test "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
  fi

  root_manifest_file=$(test_root_manifest_resolve)
  manifest_file=$(test_profile_manifest_resolve)
  test_root_manifest_validate "$root_manifest_file"

  if ! shimmy_profile_structure_validate "$manifest_file" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"; then
    install_hint=$(shimmy_profile_install_hint "$SHIMMY_PROFILE_NAME")
    fail_test "incomplete Shimmy profile for profile $SHIMMY_PROFILE_NAME: expected manifest at $manifest_file and implementation directory at $SHIMMY_PROFILE_IMPLEMENTATION_DIR; repair with $install_hint"
  fi

  if [ "$SHIMMY_PROFILE_NAME" = upstream ]; then
    source_checkout=$(shimmy_read_manifest_value "$manifest_file" source_checkout || true)
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_checkout" || true)
    if [ -n "$upstream_invalid_reason" ]; then
      fail_test "invalid upstream Shimmy checkout ($upstream_invalid_reason): $source_checkout; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
  fi

  bin_dir=$(shimmy_read_manifest_value "$manifest_file" bin_dir || true)
  [ -n "$bin_dir" ] || bin_dir=$SHIMMY_PROFILE_BIN_DIR
  dispatcher_dir=$(shimmy_read_manifest_value "$root_manifest_file" dispatcher_dir || true)
  [ -n "$dispatcher_dir" ] || dispatcher_dir=$SHIMMY_PROFILE_DISPATCHER_DIR
  config_dir=$(shimmy_read_manifest_value "$manifest_file" config_dir || true)
  [ -n "$config_dir" ] || config_dir=$SHIMMY_PROFILE_CONFIG_DIR

  printf 'Shimmy Test\n'
  printf 'Selected Shimmy profile: %s\n' "$SHIMMY_PROFILE_NAME"
  printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_NAME"
  printf 'install_dir=%s\n' "$SHIMMY_PROFILE_INSTALL_DIR"
  printf 'root_manifest_path=%s\n' "$root_manifest_file"
  printf 'manifest_path=%s\n' "$manifest_file"
  printf 'dispatcher_dir=%s\n' "$dispatcher_dir"
  printf 'bin_dir=%s\n' "$bin_dir"
  printf 'config_dir=%s\n' "$config_dir"

  root_shim_test_count=0
  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    test_shim_smoke_run "$shim_name" root "$manifest_file" "$bin_dir" "$dispatcher_dir" "$config_dir"
    root_shim_test_count=$((root_shim_test_count + 1))
  done <<EOF
$(test_root_shim_resolve "$root_manifest_file")
EOF

  if [ "$root_shim_test_count" -gt 0 ]; then
    printf 'root_smoke_tests=%s\n' "$root_shim_test_count"
  else
    printf 'root_smoke_tests=skipped\n'
  fi
  printf 'root_test=ok\n'
  pass "root test phase"

  profile_shim_test_count=0
  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    test_shim_smoke_run "$shim_name" profile "$manifest_file" "$bin_dir" "$dispatcher_dir" "$config_dir"
    profile_shim_test_count=$((profile_shim_test_count + 1))
  done <<EOF
$(test_profile_shim_resolve "$manifest_file" "$root_manifest_file")
EOF

  if [ "$profile_shim_test_count" -gt 0 ]; then
    printf 'profile_smoke_tests=%s\n' "$profile_shim_test_count"
  elif [ "$REQUESTED_TEST_ALL" -eq 1 ]; then
    printf 'profile_smoke_tests=0\n'
  else
    printf 'profile_smoke_tests=skipped\n'
  fi
  printf 'profile_test=ok\n'
  pass "profile test phase"
}

test_source_remote_create() {
  source_repo=$1
  remote_repo=$2

  mkdir -p "$source_repo"
  cp -R "$ROOT_DIR/." "$source_repo"
  rm -rf "$source_repo/.git"

  git init -q "$source_repo"
  git -C "$source_repo" config user.name "Shimmy Test"
  git -C "$source_repo" config user.email "shimmy-test@example.invalid"
  git -C "$source_repo" add .
  git -C "$source_repo" commit -q -m "test source"
  git -C "$source_repo" branch -M main

  git init --bare -q "$remote_repo"
  git -C "$remote_repo" symbolic-ref HEAD refs/heads/main
  git -C "$source_repo" remote add origin "$remote_repo"
  git -C "$source_repo" push -q -u origin main
}

test_source_remote_commit_status_marker() {
  source_repo=$1
  marker_line=$2

  {
    printf '\n'
    printf "printf '%%s\\n' '%s'\n" "$marker_line"
  } >> "$source_repo/scripts/status-shimmy.sh"

  git -C "$source_repo" add scripts/status-shimmy.sh
  git -C "$source_repo" commit -q -m "test status marker"
  git -C "$source_repo" push -q origin main
}

test_source_remote_commit_jq_pull_marker() {
  source_repo=$1
  pull_log=$2

  cat > "$source_repo/shims/jq" <<EOF
#!/bin/sh
if [ "\${SHIMMY_JQ_IMAGE_PULL:-}" = always ]; then
  printf '%s\n' pulled > "$pull_log"
fi
exit 0
EOF
  chmod 755 "$source_repo/shims/jq"

  git -C "$source_repo" add shims/jq
  git -C "$source_repo" commit -q -m "test jq pull marker"
  git -C "$source_repo" push -q origin main
}

test_upstream_checkout_create() {
  checkout_dir=$1

  mkdir -p "$checkout_dir"
  cp "$ROOT_DIR/shimmy" "$checkout_dir/shimmy"
  cp -R "$ROOT_DIR/scripts" "$checkout_dir/scripts"
  cp -R "$ROOT_DIR/lib" "$checkout_dir/lib"
  cp -R "$ROOT_DIR/shims" "$checkout_dir/shims"
  chmod 755 "$checkout_dir/shimmy"
}

test_manifest_source_url_replace() {
  manifest_file=$1
  source_url=$2
  manifest_tmp=$manifest_file.tmp

  sed "s|^shimmy_source_url=.*|shimmy_source_url=$source_url|" "$manifest_file" > "$manifest_tmp"
  mv "$manifest_tmp" "$manifest_file"
}

require_podman() {
  shimmy_podman_preflight_require "shimmy test"
  PODMAN_BIN=$SHIMMY_PODMAN_BIN
}

require_curl() {
  if ! command -v curl >/dev/null 2>&1; then
    fail_test "curl is required for opnsense-mcp-server URL preflight tests"
  fi
}

test_podman_platform_resolves_host_os() {
  linux_platform=$(
    SHIMMY_TEST_OS=Linux /bin/sh -c '. "$1"; shimmy_podman_platform_resolve; printf "%s\n" "$SHIMMY_PODMAN_PLATFORM"' sh "$SHIMMY_PODMAN_HELPER_FILE"
  )
  darwin_platform=$(
    SHIMMY_TEST_OS=Darwin /bin/sh -c '. "$1"; shimmy_podman_platform_resolve; printf "%s\n" "$SHIMMY_PODMAN_PLATFORM"' sh "$SHIMMY_PODMAN_HELPER_FILE"
  )

  assert_equals "$linux_platform" "linux/amd64"
  assert_equals "$darwin_platform" "linux/arm64"

  pass "Podman platform resolves from host OS"
}

test_podman_platform_tag_render() {
  platform_tag=$(
    /bin/sh -c '. "$1"; shimmy_podman_platform_tag_render linux/arm64' sh "$SHIMMY_PODMAN_HELPER_FILE"
  )

  assert_equals "$platform_tag" "linux-arm64"

  pass "Podman platform tag rendering"
}

test_podman_unreachable_guidance_agent() {
  output=$(
    /bin/sh -c '. "$1"; shimmy_podman_failure_print_unreachable "the rg shim" "/opt/podman/bin/podman"' sh "$SHIMMY_PODMAN_HELPER_FILE" 2>&1
  )

  assert_contains "$output" 'AI Agent note: if `podman info` succeeds but this shim still fails'
  assert_contains "$output" '["rg","--version"] or ["./shims/rg","--version"]'
  assert_contains "$output" 'Approving `podman info` alone does not approve Podman access through a Shimmy wrapper.'

  pass "Podman unreachable guidance includes AI Agent approval hint"
}

test_podman_privileged_connection_resolves_default_root() {
  require_podman

  default_connection=$("$PODMAN_BIN" system connection list --format '{{range .}}{{if .Default}}{{.Name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null | sed -n '1p' || printf '')

  if [ -z "$default_connection" ]; then
    pass "Podman privileged connection default-root resolution skipped without default connection"
    return 0
  fi

  root_connection=$default_connection-root
  connection_names=$("$PODMAN_BIN" system connection list --format '{{range .}}{{.Name}}{{"\n"}}{{end}}' 2>/dev/null || printf '')

  case "
$connection_names
" in
    *"
$root_connection
"*)
      ;;
    *)
      pass "Podman privileged connection default-root resolution skipped without rootful companion connection"
      return 0
      ;;
  esac

  unset SHIMMY_PODMAN_PRIVILEGED_CONNECTION
  shimmy_podman_privileged_connection_resolve || fail_test "expected rootful Podman companion connection to resolve"
  assert_equals "$SHIMMY_PODMAN_PRIVILEGED_CONNECTION" "$root_connection"

  pass "Podman privileged connection resolves default-root companion"
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
  assert_file_executable "$INSTALL_DIR/bin/shimmy"
  assert_file_exists "$INSTALL_DIR/shims/jq"
  assert_file_exists "$INSTALL_DIR/profiles/default/config/shims/jq.conf"
  assert_path_not_exists "$INSTALL_DIR/shims/opnsense-mcp-server"
  assert_dir_exists "$INSTALL_DIR/profiles/default/lib/shims"
  assert_dir_exists "$INSTALL_DIR/libexec/shimmy/scripts"
  assert_dir_exists "$INSTALL_DIR/libexec/shimmy/lib/repo"
  assert_dir_exists "$INSTALL_DIR/libexec/shimmy/lib/shims"
  assert_file_executable "$INSTALL_DIR/libexec/shimmy/scripts/dispatch-shimmy.sh"
  assert_file_executable "$INSTALL_DIR/libexec/shimmy/scripts/skills-shimmy.sh"
  assert_file_exists "$INSTALL_DIR/libexec/shimmy/.agents/skills/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$INSTALL_DIR/libexec/shimmy/.agents/skills/shimmy-tool-task/SKILL.md"
  assert_dir_exists "$INSTALL_DIR/libexec/shimmy/plugins/shimmy/skills"
  assert_file_exists "$INSTALL_DIR/libexec/shimmy/shims/opnsense-mcp-server"
  assert_file_exists "$HOME_DIR/.bashrc"
  assert_file_exists "$HOME_DIR/.bash_profile"

  manifest_contents=$(cat "$INSTALL_DIR/install-manifest.txt")
  assert_contains "$manifest_contents" "install_dir=$INSTALL_DIR"
  assert_contains "$manifest_contents" "control_bin=$INSTALL_DIR/bin/shimmy"
  assert_contains "$manifest_contents" "activate_file=$INSTALL_DIR/activate.sh"
  assert_contains "$manifest_contents" "startup_shell=bash"
  assert_contains "$manifest_contents" "startup_file=$HOME_DIR/.bashrc"
  assert_contains "$manifest_contents" "startup_file=$HOME_DIR/.bash_profile"
  assert_contains "$manifest_contents" "profile=default"
  assert_contains "$manifest_contents" "default_shim=jq"
  assert_contains "$manifest_contents" "default_shim=rg"
  assert_contains "$manifest_contents" "shimmy_install_manifest_version=1"
  assert_no_line_with_prefix "$manifest_contents" "shim="
  assert_not_contains "$manifest_contents" "shimmy_skill="
  assert_not_contains "$manifest_contents" "shim_dir="
  assert_not_contains "$manifest_contents" "images_dir="
  assert_not_contains "$manifest_contents" "shim_lib_dir="
  profile_contents=$(cat "$INSTALL_DIR/profiles/default/install-manifest.txt")
  assert_contains "$profile_contents" "shimmy_profile_manifest_version=1"
  assert_contains "$profile_contents" "shimmy_profile_name=default"
  assert_contains "$profile_contents" "shim=jq"
  assert_contains "$profile_contents" "shimmy_source_url="
  assert_contains "$profile_contents" "shimmy_source_ref="
  assert_not_contains "$profile_contents" "install_dir="
  assert_not_contains "$profile_contents" "shimmy_skill="
  assert_file_contains "$HOME_DIR/.bashrc" "# >>> shimmy onboarding >>>"
  assert_file_contains "$HOME_DIR/.bashrc" "$INSTALL_DIR/activate.sh"
  assert_file_contains "$HOME_DIR/.bash_profile" "# >>> shimmy onboarding >>>"
  assert_file_contains "$HOME_DIR/.bash_profile" "$INSTALL_DIR/activate.sh"
  assert_file_contains "$INSTALL_DIR/activate.sh" "$INSTALL_DIR/bin"
  assert_file_contains "$INSTALL_DIR/activate.sh" "$INSTALL_DIR/shims"

  pass "install writes manifest and startup file"
}

test_install_default_shims() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --no-startup --no-skills >/dev/null

  root_manifest_contents=$(cat "$INSTALL_DIR/install-manifest.txt")
  profile_manifest_contents=$(cat "$INSTALL_DIR/profiles/default/install-manifest.txt")

  assert_contains "$root_manifest_contents" "default_shim=jq"
  assert_contains "$root_manifest_contents" "default_shim=rg"
  assert_contains "$profile_manifest_contents" "shim=jq"
  assert_contains "$profile_manifest_contents" "shim=rg"
  assert_path_symlink "$INSTALL_DIR/shims/jq"
  assert_path_symlink "$INSTALL_DIR/shims/rg"
  assert_file_exists "$INSTALL_DIR/profiles/default/config/shims/jq.conf"
  assert_file_exists "$INSTALL_DIR/profiles/default/config/shims/rg.conf"
  assert_path_not_exists "$INSTALL_DIR/shims/aws"

  pass "bare install uses default jq and rg shims"
}

test_install_mode_default_profile_manifest() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null

  legacy_manifest=$INSTALL_DIR/install-manifest.txt
  profile_manifest=$INSTALL_DIR/profiles/default/install-manifest.txt

  assert_file_exists "$legacy_manifest"
  assert_file_exists "$profile_manifest"
  assert_path_symlink "$INSTALL_DIR/shims/jq"
  assert_file_executable "$INSTALL_DIR/shims/jq"
  assert_file_executable "$INSTALL_DIR/profiles/default/shims/jq"
  assert_file_exists "$INSTALL_DIR/profiles/default/config/shims/jq.conf"

  legacy_contents=$(cat "$legacy_manifest")
  profile_contents=$(cat "$profile_manifest")
  assert_contains "$legacy_contents" "shimmy_install_manifest_version=1"
  assert_contains "$legacy_contents" "install_dir=$INSTALL_DIR"
  assert_contains "$legacy_contents" "dispatcher_dir=$INSTALL_DIR/shims"
  assert_contains "$legacy_contents" "profile=default"
  assert_contains "$legacy_contents" "default_shim=jq"
  assert_contains "$legacy_contents" "default_shim=rg"
  assert_not_contains "$legacy_contents" "shim_source=copied-source-shim"
  assert_no_line_with_prefix "$legacy_contents" "shim="
  assert_contains "$profile_contents" "shimmy_profile_manifest_version=1"
  assert_contains "$profile_contents" "shimmy_profile_name=default"
  assert_contains "$profile_contents" "shim_source=copied-source-shim"
  assert_contains "$profile_contents" "bin_dir=$INSTALL_DIR/profiles/default/shims"
  assert_not_contains "$profile_contents" "install_dir="
  assert_not_contains "$profile_contents" "dispatcher_dir="

  status_output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --profile default --format manifest 2>&1
  )
  assert_contains "$status_output" "shimmy_installed=yes"
  assert_contains "$status_output" "shimmy_profile_manifest_path=$profile_manifest"
  assert_contains "$status_output" "shimmy_profile_shim_dir=$INSTALL_DIR/profiles/default/shims"
  assert_contains "$status_output" "shimmy_profile_shim=jq"

  pass "install default mode writes profile manifest and preserves legacy shims"
}

test_install_mode_invalid_environment_rejected() {
  setup_scenario

  set +e
  output=$(
    HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=invalid run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected invalid SHIMMY_PROFILE_ACTIVE to fail install"
  assert_contains "$output" "unsupported Shimmy profile: invalid"
  assert_path_not_exists "$INSTALL_DIR/install-manifest.txt"

  pass "install rejects invalid SHIMMY_PROFILE_ACTIVE"
}

test_install_mode_precedence() {
  setup_scenario

  HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=upstream run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null

  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  assert_file_exists "$INSTALL_DIR/profiles/default/install-manifest.txt"
  assert_path_not_exists "$INSTALL_DIR/profiles/upstream/install-manifest.txt"
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" "shimmy_profile_name=default"

  pass "install mode flag overrides environment"
}

test_install_mode_upstream_profile_manifest() {
  setup_scenario

  test_upstream_checkout_create "$SCENARIO_DIR/upstream-checkout"
  upstream_checkout_real=$(cd "$SCENARIO_DIR/upstream-checkout" && pwd -P)

  output=$(
    cd "$SCENARIO_DIR"
    HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR=upstream-checkout "$ROOT_DIR/shimmy" install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills 2>&1
  )

  profile_manifest=$INSTALL_DIR/profiles/upstream/install-manifest.txt
  assert_contains "$output" "Selected Shimmy profile: upstream"
  assert_file_exists "$profile_manifest"
  assert_file_executable "$INSTALL_DIR/bin/shimmy"
  assert_path_symlink "$INSTALL_DIR/shims/jq"
  assert_file_executable "$INSTALL_DIR/shims/jq"
  assert_file_executable "$INSTALL_DIR/profiles/upstream/shims/jq"
  assert_file_exists "$INSTALL_DIR/profiles/upstream/config/shims/jq.conf"
  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  dispatch_target=$(readlink "$INSTALL_DIR/shims/jq")
  assert_equals "$dispatch_target" "../libexec/shimmy/scripts/dispatch-shimmy.sh"
  assert_file_contains "$INSTALL_DIR/profiles/upstream/shims/jq" "shimmy_upstream_checkout='$upstream_checkout_real'"

  profile_contents=$(cat "$profile_manifest")
  assert_contains "$profile_contents" "shimmy_profile_name=upstream"
  assert_contains "$profile_contents" "config_dir=$INSTALL_DIR/profiles/upstream/config"
  assert_contains "$profile_contents" "bin_dir=$INSTALL_DIR/profiles/upstream/shims"
  assert_contains "$profile_contents" "source_checkout=$upstream_checkout_real"
  assert_contains "$profile_contents" "shim_source=generated-exec-wrapper"
  assert_contains "$profile_contents" "shim=jq"

  status_output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --profile upstream --format manifest 2>&1
  )
  assert_contains "$status_output" "shimmy_installed=yes"
  assert_contains "$status_output" "shimmy_profile_manifest_path=$profile_manifest"
  assert_contains "$status_output" "shimmy_profile_source_checkout=$upstream_checkout_real"
  assert_contains "$status_output" "shimmy_profile_shim=jq"

  pass "install upstream mode writes profile manifest"
}

test_installed_dispatcher_invalid_mode_rejected() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=invalid jq --version 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected invalid SHIMMY_PROFILE_ACTIVE to fail dispatcher"
  assert_contains "$output" "unsupported SHIMMY_PROFILE_ACTIVE: invalid"

  pass "installed dispatcher rejects invalid SHIMMY_PROFILE_ACTIVE"
}

test_installed_dispatcher_recursive_target_rejected() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null

  profile_manifest=$INSTALL_DIR/profiles/default/install-manifest.txt
  manifest_tmp=$profile_manifest.tmp
  sed "s|^bin_dir=.*|bin_dir=$INSTALL_DIR/shims|" "$profile_manifest" > "$manifest_tmp"
  mv "$manifest_tmp" "$profile_manifest"

  set +e
  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=default jq --version 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected recursive dispatch to fail"
  assert_contains "$output" "refusing recursive Shimmy dispatch for jq"

  pass "installed dispatcher rejects recursive target"
}

test_installed_dispatcher_parameterized_invocation() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  cat > "$checkout_dir/shims/jq" <<'EOF'
#!/bin/sh
printf 'param:%s\n' "$*"
EOF
  chmod 755 "$checkout_dir/shims/jq"

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  output=$(
    cd "$WORK_DIR"
    SHIMMY_PROFILE_ACTIVE=upstream "$INSTALL_DIR/libexec/shimmy/scripts/dispatch-shimmy.sh" jq one two 2>&1
  )

  assert_contains "$output" "param:one two"

  pass "central dispatcher supports parameterized invocation"
}

test_installed_dispatcher_upstream_checkout_reflects_edits() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  cat > "$checkout_dir/shims/jq" <<'EOF'
#!/bin/sh
printf 'first:%s\n' "$*"
EOF
  chmod 755 "$checkout_dir/shims/jq"

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  first_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=upstream jq alpha beta 2>&1
  )
  assert_contains "$first_output" "first:alpha beta"

  cat > "$checkout_dir/shims/jq" <<'EOF'
#!/bin/sh
printf 'second:%s\n' "$*"
EOF
  chmod 755 "$checkout_dir/shims/jq"

  second_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=upstream jq gamma 2>&1
  )
  assert_contains "$second_output" "second:gamma"

  pass "installed dispatcher reflects upstream checkout edits"
}

test_profile_fake_shim_write() {
  shim_path=$1
  marker_text=$2

  cat > "$shim_path" <<EOF
#!/bin/sh
printf '%s\n' '$marker_text'
printf 'args:%s\n' "\$*"
EOF
  chmod 755 "$shim_path"
}

test_shimmy_test_mode_default_profile() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --no-startup --no-skills >/dev/null
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/jq" "default-profile-test"
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/rg" "default-profile-rg-test"

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy test --profile default 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: default"
  assert_contains "$output" "shimmy_profile_name=default"
  assert_contains "$output" "bin_dir=$INSTALL_DIR/profiles/default/shims"
  assert_contains "$output" "root_test_shim=jq"
  assert_contains "$output" "root_test_shim=rg"
  assert_contains "$output" "root_test_shim_smoke_arg=jq|--version"
  assert_contains "$output" "root_test_shim_smoke_arg=rg|--version"
  assert_contains "$output" "default-profile-test"
  assert_contains "$output" "default-profile-rg-test"
  assert_contains "$output" "root_smoke_tests=2"
  assert_contains "$output" "root_test=ok"
  assert_contains "$output" "profile_smoke_tests=skipped"
  assert_contains "$output" "profile_test=ok"
  assert_not_contains "$output" "profile_test_shim="

  pass "shimmy test default mode tests root default shims"
}

test_shimmy_test_mode_default_profile_shim() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --no-startup --no-skills >/dev/null
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/jq" "default-profile-test"
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/rg" "default-profile-rg-test"

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy test --profile default --shim jq 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: default"
  assert_contains "$output" "shimmy_profile_name=default"
  assert_contains "$output" "bin_dir=$INSTALL_DIR/profiles/default/shims"
  assert_contains "$output" "config_dir=$INSTALL_DIR/profiles/default/config"
  assert_contains "$output" "root_test_shim=jq"
  assert_contains "$output" "root_test_shim_smoke_arg=jq|--version"
  assert_contains "$output" "default-profile-test"
  assert_contains "$output" "args:--version"
  assert_not_contains "$output" "default-profile-rg-test"
  assert_not_contains "$output" "profile_test_shim=jq"
  assert_contains "$output" "root_smoke_tests=1"
  assert_contains "$output" "root_test=ok"
  assert_contains "$output" "profile_smoke_tests=skipped"
  assert_contains "$output" "profile_test=ok"

  pass "shimmy test --shim reports root-owned shim in root section"
}

test_shimmy_test_mode_default_profile_only_shim() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim aws --no-startup --no-skills >/dev/null
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/aws" "default-profile-aws-test"

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy test --profile default --shim aws 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: default"
  assert_contains "$output" "shimmy_profile_name=default"
  assert_contains "$output" "root_smoke_tests=skipped"
  assert_contains "$output" "root_test=ok"
  assert_contains "$output" "profile_test_shim=aws"
  assert_contains "$output" "profile_test_shim_smoke_arg=aws|--version"
  assert_contains "$output" "default-profile-aws-test"
  assert_contains "$output" "args:--version"
  assert_contains "$output" "profile_smoke_tests=1"
  assert_contains "$output" "profile_test=ok"

  pass "shimmy test --shim reports profile-owned shim in profile section"
}

test_shimmy_test_mode_default_profile_all() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --shim rg --shim aws --no-startup --no-skills >/dev/null
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/jq" "default-all-jq"
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/rg" "default-all-rg"
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/aws" "default-all-aws"

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy test --profile default --all 2>&1
  )

  assert_contains "$output" "root_test_shim=jq"
  assert_contains "$output" "root_test_shim=rg"
  assert_contains "$output" "profile_test_shim=aws"
  assert_contains "$output" "default-all-jq"
  assert_contains "$output" "default-all-rg"
  assert_contains "$output" "default-all-aws"
  assert_contains "$output" "root_smoke_tests=2"
  assert_contains "$output" "root_test=ok"
  assert_contains "$output" "profile_smoke_tests=1"
  assert_contains "$output" "profile_test=ok"

  pass "shimmy test --all separates root and profile shim output"
}

test_shimmy_test_mode_all_rejects_shim() {
  setup_scenario

  set +e
  output=$(
    run_in_repo ./shimmy test --all --shim jq 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected --all --shim to fail"
  assert_contains "$output" "--all cannot be combined with --shim"

  pass "shimmy test rejects --all with --shim"
}

test_shimmy_test_mode_missing_config_rejected() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null
  rm -f "$INSTALL_DIR/profiles/default/config/shims/jq.conf"

  set +e
  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy test --profile default --shim jq 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected missing shim config to fail"
  assert_contains "$output" "missing installed shim config:"

  pass "shimmy test rejects missing installed shim config"
}

test_shimmy_test_mode_missing_smoke_arg_rejected() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null
  printf '%s\n' 'shim_config_version=1' 'shim_name=jq' > "$INSTALL_DIR/profiles/default/config/shims/jq.conf"

  set +e
  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy test --profile default --shim jq 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected missing smoke_arg to fail"
  assert_contains "$output" "missing smoke_arg in installed shim config:"

  pass "shimmy test rejects missing smoke_arg"
}

test_shimmy_test_mode_environment_fallback() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  test_profile_fake_shim_write "$checkout_dir/shims/jq" "upstream-env-jq-test"
  test_profile_fake_shim_write "$checkout_dir/shims/rg" "upstream-env-rg-test"

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --shim rg --no-startup --no-skills >/dev/null

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=upstream shimmy test 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: upstream"
  assert_contains "$output" "shimmy_profile_name=upstream"
  assert_contains "$output" "bin_dir=$INSTALL_DIR/profiles/upstream/shims"
  assert_contains "$output" "root_test_shim=jq"
  assert_contains "$output" "root_test_shim=rg"
  assert_contains "$output" "upstream-env-jq-test"
  assert_contains "$output" "upstream-env-rg-test"
  assert_contains "$output" "root_smoke_tests=2"
  assert_contains "$output" "profile_smoke_tests=skipped"
  assert_contains "$output" "profile_test=ok"

  pass "shimmy test uses SHIMMY_PROFILE_ACTIVE fallback"
}

test_shimmy_test_mode_invalid_environment_rejected() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=invalid shimmy test 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected invalid SHIMMY_PROFILE_ACTIVE to fail shimmy test"
  assert_contains "$output" "unsupported Shimmy profile: invalid"

  pass "shimmy test rejects invalid SHIMMY_PROFILE_ACTIVE"
}

test_shimmy_test_mode_precedence() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  test_profile_fake_shim_write "$checkout_dir/shims/jq" "upstream-precedence-test"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --no-startup --no-skills >/dev/null
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/jq" "default-precedence-test"
  test_profile_fake_shim_write "$INSTALL_DIR/profiles/default/shims/rg" "default-precedence-rg-test"
  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=upstream shimmy test --profile default 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: default"
  assert_contains "$output" "shimmy_profile_name=default"
  assert_contains "$output" "bin_dir=$INSTALL_DIR/profiles/default/shims"
  assert_contains "$output" "root_test_shim=jq"
  assert_contains "$output" "root_test_shim=rg"
  assert_contains "$output" "default-precedence-test"
  assert_contains "$output" "default-precedence-rg-test"
  assert_contains "$output" "root_smoke_tests=2"
  assert_contains "$output" "profile_smoke_tests=skipped"
  assert_not_contains "$output" "upstream-precedence-test"

  pass "shimmy test mode flag overrides environment"
}

test_shimmy_test_mode_upstream_profile() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  test_profile_fake_shim_write "$checkout_dir/shims/jq" "upstream-profile-test"

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy test --profile upstream --shim jq 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: upstream"
  assert_contains "$output" "shimmy_profile_name=upstream"
  assert_contains "$output" "manifest_path="
  assert_contains "$output" "/profiles/upstream/install-manifest.txt"
  assert_contains "$output" "dispatcher_dir="
  assert_contains "$output" "/shims"
  assert_contains "$output" "bin_dir="
  assert_contains "$output" "/profiles/upstream/shims"
  assert_contains "$output" "root_test_shim=jq"
  assert_contains "$output" "root_test_shim_smoke_arg=jq|--version"
  assert_contains "$output" "upstream-profile-test"
  assert_contains "$output" "args:--version"
  assert_contains "$output" "root_smoke_tests=1"
  assert_contains "$output" "profile_smoke_tests=skipped"
  assert_contains "$output" "profile_test=ok"

  pass "shimmy test upstream mode uses upstream profile"
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
    /bin/sh -c 'PATH=/usr/bin; eval "$("./shimmy" activate --install-dir "$1")"; printf "HAS_SHIMMY_INSTALL_DIR=%s\n" "${SHIMMY_INSTALL_DIR+yes}"; printf "HAS_SHIMMY_SHIM_DIR=%s\n" "${SHIMMY_SHIM_DIR+yes}"; printf "SHIMMY_PROFILE_ACTIVE=%s\n" "${SHIMMY_PROFILE_ACTIVE:-}"; printf "PATH=%s\n" "$PATH"' sh "$INSTALL_DIR"
  )

  assert_contains "$output" "HAS_SHIMMY_INSTALL_DIR="
  assert_contains "$output" "HAS_SHIMMY_SHIM_DIR="
  assert_contains "$output" "SHIMMY_PROFILE_ACTIVE=default"
  assert_contains "$output" "PATH=$INSTALL_DIR/bin:$INSTALL_DIR/shims:/usr/bin"

  pass "activate eval updates PATH and exports default mode"
}

test_activate_mode_default_exports_mode() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null

  output=$(
    cd "$ROOT_DIR"
    /bin/sh -c 'PATH=/usr/bin; eval "$("./shimmy" activate --install-dir "$1" --profile default)"; printf "SHIMMY_PROFILE_ACTIVE=%s\n" "${SHIMMY_PROFILE_ACTIVE:-}"; printf "PATH=%s\n" "$PATH"' sh "$INSTALL_DIR"
  )

  assert_contains "$output" "SHIMMY_PROFILE_ACTIVE=default"
  assert_contains "$output" "PATH=$INSTALL_DIR/bin:$INSTALL_DIR/shims:/usr/bin"

  pass "activate default mode exports mode"
}

test_activate_mode_invalid_environment_rejected() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(
    HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=invalid run_in_repo ./shimmy activate --install-dir "$INSTALL_DIR" 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected invalid SHIMMY_PROFILE_ACTIVE to fail activate"
  assert_contains "$output" "unsupported Shimmy profile: invalid"

  pass "activate rejects invalid SHIMMY_PROFILE_ACTIVE"
}

test_activate_mode_precedence() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null

  output=$(
    cd "$ROOT_DIR"
    /bin/sh -c 'PATH=/usr/bin; SHIMMY_PROFILE_ACTIVE=upstream; export SHIMMY_PROFILE_ACTIVE; eval "$("./shimmy" activate --install-dir "$1" --profile default)"; printf "SHIMMY_PROFILE_ACTIVE=%s\n" "$SHIMMY_PROFILE_ACTIVE"; printf "PATH=%s\n" "$PATH"' sh "$INSTALL_DIR"
  )

  assert_contains "$output" "SHIMMY_PROFILE_ACTIVE=default"
  assert_contains "$output" "PATH=$INSTALL_DIR/bin:$INSTALL_DIR/shims:/usr/bin"

  pass "activate mode flag overrides environment"
}

test_activate_is_idempotent() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  output=$(
    cd "$ROOT_DIR"
    /bin/sh -c 'PATH=/usr/bin; eval "$("./shimmy" activate --install-dir "$1")"; eval "$("./shimmy" activate --install-dir "$1")"; shim_count=0; bin_count=0; old_ifs=$IFS; IFS=:; for path_entry in $PATH; do if [ "$path_entry" = "$1/shims" ]; then shim_count=$((shim_count + 1)); fi; if [ "$path_entry" = "$1/bin" ]; then bin_count=$((bin_count + 1)); fi; done; IFS=$old_ifs; printf "SHIM_COUNT=%s\nBIN_COUNT=%s\nPATH=%s\n" "$shim_count" "$bin_count" "$PATH"' sh "$INSTALL_DIR"
  )

  assert_contains "$output" "SHIM_COUNT=1"
  assert_contains "$output" "BIN_COUNT=1"
  assert_contains "$output" "PATH=$INSTALL_DIR/bin:$INSTALL_DIR/shims:/usr/bin"

  pass "activate path activation is idempotent"
}

test_activate_mode_upstream_exports_mode() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  output=$(
    cd "$ROOT_DIR"
    /bin/sh -c 'PATH=/usr/bin; eval "$("./shimmy" activate --install-dir "$1" --profile upstream)"; printf "SHIMMY_PROFILE_ACTIVE=%s\n" "${SHIMMY_PROFILE_ACTIVE:-}"; printf "PATH=%s\n" "$PATH"; printf "HAS_PROFILE_SHIMS="; case ":$PATH:" in *":$1/profiles/upstream/shims:"*) printf "yes\n" ;; *) printf "no\n" ;; esac' sh "$INSTALL_DIR"
  )

  assert_contains "$output" "SHIMMY_PROFILE_ACTIVE=upstream"
  assert_contains "$output" "PATH=$INSTALL_DIR/bin:$INSTALL_DIR/shims:/usr/bin"
  assert_contains "$output" "HAS_PROFILE_SHIMS=no"

  pass "activate upstream mode exports mode and dispatcher path"
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

test_skills_install_repo_target() {
  setup_scenario

  output=$(
    cd "$WORK_DIR"
    "$ROOT_DIR/shimmy" skills install --target repo 2>&1
  )

  assert_contains "$output" "Installed skill: shimmy-install"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-install/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-init/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-create/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-escalation/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt"

  manifest_contents=$(cat "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt")
  assert_contains "$manifest_contents" "shimmy_skills_manifest_version=1"
  assert_contains "$manifest_contents" "shimmy_skills_target=repo"
  assert_contains "$manifest_contents" "shimmy_skill=repo|shimmy-install|$WORK_DIR/.agents/skills/shimmy-install|"
  assert_contains "$manifest_contents" "shimmy_skill=repo|shimmy-escalation|$WORK_DIR/.agents/skills/shimmy-escalation|"

  pass "skills install writes core skills to repo target"
}

test_installed_launcher_skills_install_includes_installed_shim_skills() {
  setup_scenario

  HOME="$HOME_DIR" SHELL=/bin/bash run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task --shim opnsense-mcp-server --no-startup --no-skills >/dev/null

  output=$(
    cd "$WORK_DIR"
    "$INSTALL_DIR/bin/shimmy" skills install --target repo 2>&1
  )

  assert_contains "$output" "Installed skill: shimmy-tool-jq"
  assert_contains "$output" "Installed skill: shimmy-tool-task"
  assert_contains "$output" "Installed skill: shimmy-tool-opnsense-mcp"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-install/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-tool-task/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-tool-opnsense-mcp/SKILL.md"

  manifest_contents=$(cat "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt")
  assert_contains "$manifest_contents" "shimmy_skill=repo|shimmy-tool-jq|$WORK_DIR/.agents/skills/shimmy-tool-jq|"
  assert_contains "$manifest_contents" "shimmy_skill=repo|shimmy-tool-task|$WORK_DIR/.agents/skills/shimmy-tool-task|"
  assert_contains "$manifest_contents" "shimmy_skill=repo|shimmy-tool-opnsense-mcp|$WORK_DIR/.agents/skills/shimmy-tool-opnsense-mcp|"

  pass "installed launcher skills install includes installed shim skills"
}

test_skills_update_repo_target() {
  setup_scenario

  (
    cd "$WORK_DIR"
    "$ROOT_DIR/shimmy" skills install --target repo >/dev/null
    "$ROOT_DIR/shimmy" skills install --target repo shimmy-tool-task >/dev/null
  )
  printf '%s\n' stale > "$WORK_DIR/.agents/skills/shimmy-tool-task/SKILL.md"

  output=$(
    cd "$WORK_DIR"
    "$ROOT_DIR/shimmy" skills update --target repo 2>&1
  )

  assert_contains "$output" "Installed skill: shimmy-tool-task"
  assert_file_contains "$WORK_DIR/.agents/skills/shimmy-tool-task/SKILL.md" "name: shimmy-tool-task"
  core_manifest_count=$(sed -n 's/^shimmy_skill=repo|shimmy-install|.*/skill/p' "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt" | wc -l | tr -d ' ')
  task_manifest_count=$(sed -n 's/^shimmy_skill=repo|shimmy-tool-task|.*/skill/p' "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt" | wc -l | tr -d ' ')
  assert_equals "$core_manifest_count" "1"
  assert_equals "$task_manifest_count" "1"

  pass "skills update refreshes manifest-tracked repo skills idempotently"
}

test_skills_export_folder() {
  setup_scenario

  export_dir=$SCENARIO_DIR/exported-skills
  output=$(
    run_in_repo ./shimmy skills install --export "$export_dir" 2>&1
  )

  assert_contains "$output" "Exported skills folder: $export_dir"
  assert_file_exists "$export_dir/shimmy-install/SKILL.md"
  assert_file_exists "$export_dir/shimmy-init/SKILL.md"
  assert_file_exists "$export_dir/.shimmy-skills-manifest.txt"
  assert_file_contains "$export_dir/.shimmy-skills-manifest.txt" "shimmy_skills_target=export"

  pass "skills export writes a portable folder"
}

test_install_shares_management_skills_explicit_target() {
  setup_scenario

  output=$(
    cd "$WORK_DIR"
    HOME="$HOME_DIR" SHELL=/bin/bash "$ROOT_DIR/shimmy" install --install-dir "$INSTALL_DIR" --shim jq --no-startup --skills-target repo 2>&1
  )

  assert_contains "$output" "Installed skill: shimmy-install"
  assert_contains "$output" "Installed skill: shimmy-tool-jq"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-install/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-create/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt"

  root_manifest_contents=$(cat "$INSTALL_DIR/install-manifest.txt")
  profile_manifest_contents=$(cat "$INSTALL_DIR/profiles/default/install-manifest.txt")
  skills_manifest_contents=$(cat "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt")
  assert_not_contains "$root_manifest_contents" "shimmy_skill="
  assert_not_contains "$profile_manifest_contents" "shimmy_skill="
  assert_contains "$skills_manifest_contents" "shimmy_skill=repo|shimmy-install|$WORK_DIR/.agents/skills/shimmy-install|"
  assert_contains "$skills_manifest_contents" "shimmy_skill=repo|shimmy-create|$WORK_DIR/.agents/skills/shimmy-create|"
  assert_contains "$skills_manifest_contents" "shimmy_skill=repo|shimmy-tool-jq|$WORK_DIR/.agents/skills/shimmy-tool-jq|"

  pass "install shares management and installed shim skills with explicit target"
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

test_agent_shimmy_preflight_reports_upstream_profile() {
  setup_scenario

  mkdir -p "$WORK_DIR/bin"
  test_upstream_checkout_create "$SCENARIO_DIR/upstream-checkout"
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
  cat > "$SCENARIO_DIR/upstream-checkout/shims/rg" <<'EOF'
#!/bin/sh
printf '%s\n' 'fake rg'
EOF
  chmod +x "$WORK_DIR/bin/podman" "$SCENARIO_DIR/upstream-checkout/shims/rg"

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$SCENARIO_DIR/upstream-checkout" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim rg --no-startup --no-skills >/dev/null

  output=$(
    PATH="$WORK_DIR/bin:$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_INSTALL_DIR="$INSTALL_DIR" run_in_repo ./scripts/agent-shimmy-preflight.sh 2>&1
  )

  assert_contains "$output" "podman_info=ok"
  assert_contains "$output" "active_shim=rg"
  assert_contains "$output" "path=$INSTALL_DIR/shims/rg"
  assert_contains "$output" 'agent_prefix_rule=["rg","--version"]'
  assert_contains "$output" "smoke_command=rg --version"

  pass "AI Agent preflight reports upstream profile shims"
}

test_netinfo_help() {
  output=$(
    run_in_repo ./shimmy netinfo --help 2>&1
  )

  assert_contains "$output" "Print shell network perspective"
  assert_contains "$output" "--host-name <name>"
  assert_contains "$output" "hostname \"penguin\""

  pass "netinfo help"
}

test_netinfo_manifest_crostini_host_name_resolution() {
  setup_scenario

  mkdir -p "$WORK_DIR/bin"
  cat > "$WORK_DIR/bin/getent" <<'EOF'
#!/bin/sh
if [ "$1" = ahostsv4 ] && [ "$2" = chromebook-home ]; then
  printf '%s\n' '192.168.1.42 STREAM chromebook-home'
  printf '%s\n' '192.168.1.42 DGRAM chromebook-home'
  exit 0
fi
exit 2
EOF
  cat > "$WORK_DIR/bin/hostname" <<'EOF'
#!/bin/sh
printf '%s\n' penguin
EOF
  cat > "$WORK_DIR/bin/ip" <<'EOF'
#!/bin/sh
if [ "$1" = -br ] && [ "$2" = -4 ] && [ "$3" = addr ] && [ "$4" = show ]; then
  printf '%s\n' 'lo UNKNOWN 127.0.0.1/8'
  printf '%s\n' 'eth0 UP 100.115.92.205/28'
  exit 0
fi
if [ "$1" = -4 ] && [ "$2" = route ] && [ "$3" = show ] && [ "$4" = default ]; then
  printf '%s\n' 'default via 100.115.92.1 dev eth0'
  exit 0
fi
if [ "$1" = -4 ] && [ "$2" = route ] && [ "$3" = show ] && [ "$4" = scope ] && [ "$5" = link ]; then
  printf '%s\n' '100.115.92.192/28 dev eth0 proto kernel scope link src 100.115.92.205'
  exit 0
fi
if [ "$1" = -4 ] && [ "$2" = route ] && [ "$3" = get ]; then
  printf '%s\n' "$4 via 100.115.92.1 dev eth0 src 100.115.92.205"
  exit 0
fi
if [ "$1" = -4 ] && [ "$2" = neigh ] && [ "$3" = show ]; then
  printf '%s\n' '100.115.92.1 dev eth0 lladdr 00:11:22:33:44:55 REACHABLE'
  exit 0
fi
exit 1
EOF
  cat > "$WORK_DIR/bin/uname" <<'EOF'
#!/bin/sh
if [ "${1:-}" = -s ]; then
  printf '%s\n' Linux
else
  printf '%s\n' Linux
fi
EOF
  chmod +x "$WORK_DIR/bin/getent" "$WORK_DIR/bin/hostname" "$WORK_DIR/bin/ip" "$WORK_DIR/bin/uname"

  output=$(
    cd "$ROOT_DIR"
    PATH="$WORK_DIR/bin:/usr/bin:/bin" ./shimmy netinfo --format manifest --host-name chromebook-home --host-prefix 24 2>&1
  )

  assert_contains "$output" "perspective=shell"
  assert_contains "$output" "environment=crostini"
  assert_contains "$output" "shell_hostname=penguin"
  assert_contains "$output" "host_name=chromebook-home"
  assert_contains "$output" "host_name_resolution=resolved"
  assert_contains "$output" "host_ipv4=192.168.1.42"
  assert_contains "$output" "host_ipv4_source=getent_ahostsv4"
  assert_contains "$output" "host_lan=192.168.1.0/24"
  assert_contains "$output" "host_lan_source=host_prefix"
  assert_contains "$output" "interface_ipv4=eth0 UP 100.115.92.205/28"
  assert_contains "$output" "route_target=1.1.1.1 via 100.115.92.1 dev eth0 src 100.115.92.205"

  pass "netinfo manifest resolves Crostini host name"
}

test_netinfo_manifest_darwin_host_name_resolution() {
  setup_scenario

  mkdir -p "$WORK_DIR/bin"
  cat > "$WORK_DIR/bin/arp" <<'EOF'
#!/bin/sh
if [ "$1" = -an ]; then
  printf '%s\n' '? (192.168.10.1) at 00:11:22:33:44:55 on en0 ifscope [ethernet]'
  exit 0
fi
exit 1
EOF
  cat > "$WORK_DIR/bin/dscacheutil" <<'EOF'
#!/bin/sh
if [ "$1" = -q ] && [ "$2" = host ] && [ "$3" = -a ] && [ "$4" = name ] && [ "$5" = mac-mini ]; then
  printf '%s\n' 'name: mac-mini'
  printf '%s\n' 'ip_address: 192.168.10.95'
  exit 0
fi
exit 1
EOF
  cat > "$WORK_DIR/bin/hostname" <<'EOF'
#!/bin/sh
printf '%s\n' mac-mini
EOF
  cat > "$WORK_DIR/bin/getent" <<'EOF'
#!/bin/sh
exit 2
EOF
  cat > "$WORK_DIR/bin/ifconfig" <<'EOF'
#!/bin/sh
if [ "${1:-}" = en0 ]; then
  cat <<'IFCONFIG_EN0'
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 192.168.10.95 netmask 0xffffff00 broadcast 192.168.10.255
IFCONFIG_EN0
  exit 0
fi
cat <<'IFCONFIG'
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
	inet 127.0.0.1 netmask 0xff000000
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 192.168.10.95 netmask 0xffffff00 broadcast 192.168.10.255
IFCONFIG
EOF
  cat > "$WORK_DIR/bin/netstat" <<'EOF'
#!/bin/sh
cat <<'NETSTAT'
Routing tables

Internet:
Destination        Gateway            Flags           Netif Expire
default            192.168.10.1       UGScg             en0
192.168.10/24      link#11            UCS               en0      !
NETSTAT
EOF
  cat > "$WORK_DIR/bin/route" <<'EOF'
#!/bin/sh
if [ "$1" = -n ] && [ "$2" = get ]; then
  cat <<ROUTE
   route to: $3
destination: default
    gateway: 192.168.10.1
  interface: en0
ROUTE
  exit 0
fi
exit 1
EOF
  cat > "$WORK_DIR/bin/systemd-detect-virt" <<'EOF'
#!/bin/sh
exit 1
EOF
  chmod +x "$WORK_DIR/bin/arp" "$WORK_DIR/bin/dscacheutil" "$WORK_DIR/bin/getent" "$WORK_DIR/bin/hostname" "$WORK_DIR/bin/ifconfig" "$WORK_DIR/bin/netstat" "$WORK_DIR/bin/route" "$WORK_DIR/bin/systemd-detect-virt"

  output=$(
    cd "$ROOT_DIR"
    PATH="$WORK_DIR/bin:/usr/bin:/bin" SHIMMY_TEST_OS=Darwin ./shimmy netinfo --format manifest --host-name mac-mini --host-prefix 24 2>&1
  )

  assert_contains "$output" "perspective=shell"
  assert_contains "$output" "environment=darwin"
  assert_contains "$output" "kernel=Darwin"
  assert_contains "$output" "shell_hostname=mac-mini"
  assert_contains "$output" "host_name=mac-mini"
  assert_contains "$output" "host_name_resolution=resolved"
  assert_contains "$output" "host_ipv4=192.168.10.95"
  assert_contains "$output" "host_ipv4_source=dscacheutil_host"
  assert_contains "$output" "host_lan=192.168.10.0/24"
  assert_contains "$output" "interface_ipv4=en0 UP 192.168.10.95"
  assert_contains "$output" "default_route=default via 192.168.10.1 dev en0"
  assert_contains "$output" "route_target=1.1.1.1 via 192.168.10.1 dev en0 src 192.168.10.95"
  assert_contains "$output" "neighbor_ipv4=? (192.168.10.1) at 00:11:22:33:44:55 on en0 ifscope [ethernet]"

  pass "netinfo manifest resolves Darwin host name"
}

test_netinfo_manifest_auto_darwin_default_interface() {
  setup_scenario

  mkdir -p "$WORK_DIR/bin"
  cat > "$WORK_DIR/bin/arp" <<'EOF'
#!/bin/sh
exit 0
EOF
  cat > "$WORK_DIR/bin/hostname" <<'EOF'
#!/bin/sh
printf '%s\n' mac-mini
EOF
  cat > "$WORK_DIR/bin/ifconfig" <<'EOF'
#!/bin/sh
if [ "${1:-}" = en1 ]; then
  cat <<'IFCONFIG_EN1'
en1: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 192.168.10.240 netmask 0xffffff00 broadcast 192.168.10.255
IFCONFIG_EN1
  exit 0
fi
cat <<'IFCONFIG'
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
	inet 127.0.0.1 netmask 0xff000000
en1: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 192.168.10.240 netmask 0xffffff00 broadcast 192.168.10.255
IFCONFIG
EOF
  cat > "$WORK_DIR/bin/netstat" <<'EOF'
#!/bin/sh
cat <<'NETSTAT'
Routing tables

Internet:
Destination        Gateway            Flags           Netif Expire
default            192.168.10.1       UGScg             en1
192.168.10/24      link#15            UCS               en1      !
NETSTAT
EOF
  cat > "$WORK_DIR/bin/route" <<'EOF'
#!/bin/sh
exit 71
EOF
  cat > "$WORK_DIR/bin/systemd-detect-virt" <<'EOF'
#!/bin/sh
exit 1
EOF
  chmod +x "$WORK_DIR/bin/arp" "$WORK_DIR/bin/hostname" "$WORK_DIR/bin/ifconfig" "$WORK_DIR/bin/netstat" "$WORK_DIR/bin/route" "$WORK_DIR/bin/systemd-detect-virt"

  output=$(
    cd "$ROOT_DIR"
    PATH="$WORK_DIR/bin:/usr/bin:/bin" SHIMMY_TEST_OS=Darwin ./shimmy netinfo --format manifest 2>&1
  )

  assert_contains "$output" "environment=darwin"
  assert_contains "$output" "host_name=mac-mini"
  assert_contains "$output" "host_name_resolution=auto_shell_hostname"
  assert_contains "$output" "host_ipv4=192.168.10.240"
  assert_contains "$output" "host_ipv4_source=auto_default_interface"
  assert_contains "$output" "host_lan=192.168.10.0/24"
  assert_contains "$output" "host_lan_source=auto_interface_prefix"
  assert_contains "$output" "host_resolution_confidence=high"

  pass "netinfo manifest auto resolves Darwin default interface"
}

test_netinfo_manifest_auto_skips_crostini_shell_lan() {
  setup_scenario

  mkdir -p "$WORK_DIR/bin"
  cat > "$WORK_DIR/bin/hostname" <<'EOF'
#!/bin/sh
printf '%s\n' penguin
EOF
  cat > "$WORK_DIR/bin/ip" <<'EOF'
#!/bin/sh
if [ "$1" = -br ] && [ "$2" = -4 ] && [ "$3" = addr ] && [ "$4" = show ]; then
  printf '%s\n' 'lo UNKNOWN 127.0.0.1/8'
  printf '%s\n' 'eth0 UP 100.115.92.205/28'
  exit 0
fi
if [ "$1" = -4 ] && [ "$2" = route ] && [ "$3" = show ] && [ "$4" = default ]; then
  printf '%s\n' 'default via 100.115.92.1 dev eth0'
  exit 0
fi
if [ "$1" = -4 ] && [ "$2" = route ] && [ "$3" = show ] && [ "$4" = scope ] && [ "$5" = link ]; then
  printf '%s\n' '100.115.92.192/28 dev eth0 proto kernel scope link src 100.115.92.205'
  exit 0
fi
if [ "$1" = -4 ] && [ "$2" = route ] && [ "$3" = get ]; then
  printf '%s\n' "$4 via 100.115.92.1 dev eth0 src 100.115.92.205"
  exit 0
fi
if [ "$1" = -4 ] && [ "$2" = neigh ] && [ "$3" = show ]; then
  exit 0
fi
exit 1
EOF
  cat > "$WORK_DIR/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' Linux
EOF
  chmod +x "$WORK_DIR/bin/hostname" "$WORK_DIR/bin/ip" "$WORK_DIR/bin/uname"

  output=$(
    cd "$ROOT_DIR"
    PATH="$WORK_DIR/bin:/usr/bin:/bin" ./shimmy netinfo --format manifest 2>&1
  )

  assert_contains "$output" "shell_hostname=penguin"
  assert_contains "$output" "host_name=unknown"
  assert_contains "$output" "host_ipv4=unknown"
  assert_contains "$output" "host_lan=unknown"
  assert_contains "$output" "host_resolution_confidence=low"
  assert_contains "$output" "action_needed=provide_host_name_host_ip_prefix_or_host_lan"

  pass "netinfo manifest skips Crostini shell LAN auto resolution"
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
  assert_file_contains "$INSTALL_DIR/activate.sh" "$INSTALL_DIR/bin"
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
  assert_contains "$output" "shim_dir=$INSTALL_DIR/profiles/default/shims"
  assert_contains "$output" "- jq: ghcr.io/jqlang/jq:1.8.1"
  assert_contains "$output" "- task: localhost/shimmy-task:"
  assert_contains "$output" "-linux-arm64"

  pass "status reports installed shim details"
}

test_status_available_reports_remaining_shims() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task >/dev/null

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --available 2>&1
  )

  assert_contains "$output" "installed_shims:"
  assert_contains "$output" "- jq: ghcr.io/jqlang/jq:1.8.1"
  assert_contains "$output" "- task: localhost/shimmy-task:"
  assert_contains "$output" "available_shims:"
  assert_contains "$output" "- aws"
  assert_contains "$output" "- go"
  assert_contains "$output" "- nmap"
  assert_contains "$output" "- textual"
  assert_not_contains "$output" "- tessl"

  pass "status available reports remaining installable shims"
}

test_status_manifest_format() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --format manifest 2>&1
  )

  assert_contains "$output" "shimmy_installed=yes"
  assert_contains "$output" "shimmy_install_dir=$INSTALL_DIR"
  assert_contains "$output" "shimmy_control_bin=$INSTALL_DIR/bin/shimmy"
  assert_contains "$output" "shimmy_profile_shim_dir=$INSTALL_DIR/profiles/default/shims"
  assert_contains "$output" "shimmy_path_active=no"
  assert_contains "$output" "shimmy_activate_file=$INSTALL_DIR/activate.sh"
  assert_contains "$output" "shimmy_profile_shim=jq"
  assert_contains "$output" "shimmy_profile_source_ref="
  assert_no_line_with_prefix "$output" "installed="
  assert_no_line_with_prefix "$output" "manifest_path="
  assert_not_contains "$output" "Shimmy Status"
  assert_not_contains "$output" "installed_shims:"

  pass "status manifest format is machine-readable"
}

test_status_available_manifest_format() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task >/dev/null

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --available --format manifest 2>&1
  )

  assert_contains "$output" "shimmy_installed=yes"
  assert_contains "$output" "shimmy_profile_shim=jq"
  assert_contains "$output" "shimmy_profile_shim=task"
  assert_contains "$output" "shimmy_available_shim=aws"
  assert_contains "$output" "shimmy_available_shim=go"
  assert_contains "$output" "shimmy_available_shim=nmap"
  assert_contains "$output" "shimmy_available_shim=textual"
  assert_not_contains "$output" "shimmy_available_shim=jq"
  assert_not_contains "$output" "shimmy_available_shim=task"
  assert_not_contains "$output" "shimmy_available_shim=tessl"
  assert_not_contains "$output" "available_shims:"

  pass "status available manifest format is machine-readable"
}

test_status_mode_invalid_environment_rejected() {
  setup_scenario

  set +e
  output=$(
    HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=invalid run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --format manifest 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected invalid SHIMMY_PROFILE_ACTIVE to fail"
  assert_contains "$output" "unsupported Shimmy profile: invalid"

  pass "status rejects invalid SHIMMY_PROFILE_ACTIVE"
}

test_status_mode_paths_are_distinct() {
  setup_scenario

  default_output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --profile default --format manifest 2>&1
  )
  upstream_output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --profile upstream --format manifest 2>&1
  )

  assert_contains "$default_output" "shimmy_profile_name=default"
  assert_contains "$default_output" "shimmy_profile_dir=$INSTALL_DIR/profiles/default"
  assert_contains "$default_output" "shimmy_profile_config_dir=$INSTALL_DIR/profiles/default/config"
  assert_contains "$default_output" "shimmy_dispatcher_dir=$INSTALL_DIR/shims"
  assert_contains "$default_output" "shimmy_profile_bin_dir=$INSTALL_DIR/profiles/default/shims"
  assert_contains "$default_output" "shimmy_profile_manifest_path=$INSTALL_DIR/profiles/default/install-manifest.txt"
  assert_contains "$default_output" "shimmy_profile_implementation_dir=$INSTALL_DIR/profiles/default/shims"

  assert_contains "$upstream_output" "shimmy_profile_name=upstream"
  assert_contains "$upstream_output" "shimmy_profile_dir=$INSTALL_DIR/profiles/upstream"
  assert_contains "$upstream_output" "shimmy_profile_config_dir=$INSTALL_DIR/profiles/upstream/config"
  assert_contains "$upstream_output" "shimmy_dispatcher_dir=$INSTALL_DIR/shims"
  assert_contains "$upstream_output" "shimmy_profile_bin_dir=$INSTALL_DIR/profiles/upstream/shims"
  assert_contains "$upstream_output" "shimmy_profile_manifest_path=$INSTALL_DIR/profiles/upstream/install-manifest.txt"
  assert_contains "$upstream_output" "shimmy_profile_implementation_dir=$INSTALL_DIR/profiles/upstream/shims"
  assert_not_contains "$upstream_output" "shimmy_profile_source_checkout="

  default_bin_dir=$(printf '%s\n' "$default_output" | sed -n 's/^shimmy_profile_bin_dir=//p' | sed -n '1p')
  upstream_bin_dir=$(printf '%s\n' "$upstream_output" | sed -n 's/^shimmy_profile_bin_dir=//p' | sed -n '1p')
  dispatcher_dir=$(printf '%s\n' "$default_output" | sed -n 's/^shimmy_dispatcher_dir=//p' | sed -n '1p')
  profile_implementation_dir=$(printf '%s\n' "$default_output" | sed -n 's/^shimmy_profile_implementation_dir=//p' | sed -n '1p')

  [ "$default_bin_dir" != "$upstream_bin_dir" ] || fail_test "expected default and upstream bin paths to differ"
  [ "$dispatcher_dir" != "$profile_implementation_dir" ] || fail_test "expected dispatcher and profile implementation paths to differ"

  pass "status resolves distinct profile paths"
}

test_status_mode_precedence() {
  setup_scenario

  env_output=$(
    HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=upstream run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --format manifest 2>&1
  )
  flag_output=$(
    HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=upstream run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --profile default --format manifest 2>&1
  )

  assert_contains "$env_output" "shimmy_profile_name=upstream"
  assert_contains "$flag_output" "shimmy_profile_name=default"

  pass "status mode flag overrides environment"
}

test_status_upstream_checkout_absolute_resolution() {
  setup_scenario

  test_upstream_checkout_create "$SCENARIO_DIR/upstream-checkout"
  upstream_checkout_real=$(cd "$SCENARIO_DIR/upstream-checkout" && pwd -P)
  (
    cd "$SCENARIO_DIR"
    HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR=upstream-checkout "$ROOT_DIR/shimmy" install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null
  )

  output=$(
    cd "$SCENARIO_DIR"
    HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR=upstream-checkout "$ROOT_DIR/shimmy" status --install-dir "$INSTALL_DIR" --profile upstream --format manifest 2>&1
  )

  assert_contains "$output" "shimmy_profile_source_checkout=$upstream_checkout_real"
  assert_contains "$output" "shimmy_profile_dir=$INSTALL_DIR/profiles/upstream"

  pass "status resolves upstream checkout to an absolute path"
}

test_installed_shimmy_management_command() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  status_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy status --format manifest 2>&1
  )

  assert_contains "$status_output" "shimmy_installed=yes"
  assert_contains "$status_output" "shimmy_install_dir=$INSTALL_DIR"
  assert_contains "$status_output" "shimmy_control_bin=$INSTALL_DIR/bin/shimmy"
  assert_contains "$status_output" "shimmy_profile_shim=jq"

  available_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy status --available --format manifest 2>&1
  )

  assert_contains "$available_output" "shimmy_available_shim=aws"
  assert_contains "$available_output" "shimmy_available_shim=task"
  assert_not_contains "$available_output" "shimmy_available_shim=jq"
  assert_not_contains "$available_output" "shimmy_available_shim=tessl"

  netinfo_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy netinfo --help 2>&1
  )

  assert_contains "$netinfo_output" "Print shell network perspective"

  activate_output=$(
    cd "$WORK_DIR"
    PATH=/usr/bin "$INSTALL_DIR/bin/shimmy" activate 2>&1
  )

  assert_contains "$activate_output" "$INSTALL_DIR/bin"
  assert_contains "$activate_output" "$INSTALL_DIR/shims"

  pass "installed shimmy management command works outside source checkout"
}

test_installed_shim_install_adds_available_shim() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy install --shim opnsense-mcp-server 2>&1
  )

  assert_contains "$output" "Installed shim: opnsense-mcp-server"
  assert_file_exists "$INSTALL_DIR/shims/jq"
  assert_file_exists "$INSTALL_DIR/shims/opnsense-mcp-server"

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy install --shim task 2>&1
  )

  assert_contains "$output" "Installed shim: task"
  assert_file_exists "$INSTALL_DIR/shims/task"
  assert_dir_exists "$INSTALL_DIR/profiles/default/images/task"

  output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy install --shim opnsense-mcp-server 2>&1
  )

  assert_contains "$output" "WARN: Shim already installed: opnsense-mcp-server; run shimmy update --shim opnsense-mcp-server to refresh it"

  manifest_contents=$(cat "$INSTALL_DIR/profiles/default/install-manifest.txt")
  assert_contains "$manifest_contents" "shim=jq"
  assert_contains "$manifest_contents" "shim=opnsense-mcp-server"
  assert_contains "$manifest_contents" "shim=task"
  opnsense_manifest_count=$(sed -n 's/^shim=opnsense-mcp-server$/shim/p' "$INSTALL_DIR/profiles/default/install-manifest.txt" | wc -l | tr -d ' ')
  assert_equals "$opnsense_manifest_count" "1"

  available_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy status --available --format manifest 2>&1
  )

  assert_contains "$available_output" "shimmy_profile_shim=jq"
  assert_contains "$available_output" "shimmy_profile_shim=opnsense-mcp-server"
  assert_contains "$available_output" "shimmy_profile_shim=task"
  assert_not_contains "$available_output" "shimmy_available_shim=opnsense-mcp-server"
  assert_not_contains "$available_output" "shimmy_available_shim=task"

  pass "installed shimmy installs available shims additively"
}

test_installed_shim_install_rejects_positional_name() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  if output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy install opnsense-mcp-server 2>&1
  ); then
    fail_test "expected installed shim install with positional shim name to fail"
  fi

  assert_contains "$output" "ERROR: unknown argument: opnsense-mcp-server"

  pass "installed shimmy install rejects positional shim names"
}

test_installed_update_fetches_manifest_source() {
  setup_scenario

  source_repo=$SCENARIO_DIR/source
  remote_repo=$SCENARIO_DIR/remote.git
  marker_line=self_update_marker=remote

  test_source_remote_create "$source_repo" "$remote_repo"
  test_source_remote_commit_status_marker "$source_repo" "$marker_line"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  test_manifest_source_url_replace "$INSTALL_DIR/profiles/default/install-manifest.txt" "$remote_repo"

  rm -f "$INSTALL_DIR/shims/jq"
  (
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy update >/dev/null
  )

  assert_file_exists "$INSTALL_DIR/shims/jq"

  status_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy status --format manifest 2>&1
  )

  assert_contains "$status_output" "$marker_line"

  pass "installed update fetches the manifest source URL"
}

test_repo_update_uses_current_checkout() {
  setup_scenario

  source_repo=$SCENARIO_DIR/source
  remote_repo=$SCENARIO_DIR/remote.git
  marker_line=self_update_marker=remote

  test_source_remote_create "$source_repo" "$remote_repo"
  test_source_remote_commit_status_marker "$source_repo" "$marker_line"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  test_manifest_source_url_replace "$INSTALL_DIR/profiles/default/install-manifest.txt" "$remote_repo"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" >/dev/null

  status_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy status --format manifest 2>&1
  )

  assert_not_contains "$status_output" "$marker_line"

  pass "repo-root update refreshes from the current checkout"
}

test_installed_update_requires_pull_for_image_refresh() {
  setup_scenario

  source_repo=$SCENARIO_DIR/source
  remote_repo=$SCENARIO_DIR/remote.git
  pull_log=$SCENARIO_DIR/jq-pull.log

  test_source_remote_create "$source_repo" "$remote_repo"
  test_source_remote_commit_jq_pull_marker "$source_repo" "$pull_log"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  test_manifest_source_url_replace "$INSTALL_DIR/profiles/default/install-manifest.txt" "$remote_repo"

  (
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy update >/dev/null
  )
  assert_path_not_exists "$pull_log"

  if ! shimmy_podman_preflight_require "shimmy test update --pull" >/dev/null 2>&1; then
    pass "installed update leaves shim images untouched unless --pull is requested; explicit pull skipped without Podman"
    return 0
  fi

  (
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/bin:/usr/bin:/bin" shimmy update --pull >/dev/null
  )
  assert_file_exists "$pull_log"

  pass "installed update forwards --pull for explicit image refresh"
}

test_update_reinstalls_default_shims_only() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task >/dev/null
  rm -f "$INSTALL_DIR/shims/jq"
  rm -f "$INSTALL_DIR/shims/task"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" >/dev/null

  assert_file_exists "$INSTALL_DIR/shims/jq"
  assert_path_not_exists "$INSTALL_DIR/shims/task"
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" "shim=task"

  pass "update reinstalls default shims only"
}

test_update_shim_reinstalls_selected_shim() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task >/dev/null
  rm -f "$INSTALL_DIR/shims/jq"
  rm -f "$INSTALL_DIR/shims/task"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --shim task >/dev/null

  assert_path_not_exists "$INSTALL_DIR/shims/jq"
  assert_file_exists "$INSTALL_DIR/shims/task"

  pass "update --shim reinstalls one selected shim"
}

test_update_shim_requires_installed_shim() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  if output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --shim task 2>&1
  ); then
    fail_test "expected update --shim for missing shim to fail"
  fi

  assert_contains "$output" "WARN: task not installed; run shimmy install --shim task"

  pass "update --shim rejects missing shims"
}

test_update_all_reinstalls_profile_shims() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task >/dev/null
  rm -f "$INSTALL_DIR/shims/jq"
  rm -f "$INSTALL_DIR/shims/task"

  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --all >/dev/null

  assert_file_exists "$INSTALL_DIR/shims/jq"
  assert_file_exists "$INSTALL_DIR/shims/task"

  pass "update --all reinstalls profile shims"
}

test_update_preserves_shimmy_manifest_fields() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq >/dev/null
  manifest_file=$INSTALL_DIR/profiles/default/install-manifest.txt
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

test_update_mode_default_profile() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null
  rm -f "$INSTALL_DIR/shims/jq"
  rm -f "$INSTALL_DIR/profiles/default/shims/jq"

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --profile default 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: default"
  assert_path_symlink "$INSTALL_DIR/shims/jq"
  assert_file_executable "$INSTALL_DIR/profiles/default/shims/jq"
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" "shimmy_profile_name=default"

  pass "update default mode refreshes default profile"
}

test_update_mode_environment_fallback() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  checkout_dir_real=$(cd "$checkout_dir" && pwd -P)
  test_profile_fake_shim_write "$checkout_dir/shims/jq" "upstream-update-env"

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null
  rm -f "$INSTALL_DIR/shims/jq"
  rm -f "$INSTALL_DIR/profiles/upstream/shims/jq"

  output=$(
    HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=upstream run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: upstream"
  assert_path_symlink "$INSTALL_DIR/shims/jq"
  assert_file_executable "$INSTALL_DIR/profiles/upstream/shims/jq"
  assert_file_contains "$INSTALL_DIR/profiles/upstream/shims/jq" "shimmy_upstream_checkout='$checkout_dir_real'"

  command_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=upstream jq --version 2>&1
  )
  assert_contains "$command_output" "upstream-update-env"

  pass "update uses SHIMMY_PROFILE_ACTIVE fallback"
}

test_update_mode_invalid_environment_rejected() {
  setup_scenario

  set +e
  output=$(
    HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=invalid run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected invalid SHIMMY_PROFILE_ACTIVE to fail update"
  assert_contains "$output" "unsupported Shimmy profile: invalid"

  pass "update rejects invalid SHIMMY_PROFILE_ACTIVE"
}

test_update_mode_precedence() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  test_profile_fake_shim_write "$checkout_dir/shims/jq" "upstream-update-precedence"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null
  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null
  rm -f "$INSTALL_DIR/profiles/default/shims/jq"
  rm -f "$INSTALL_DIR/profiles/upstream/shims/jq"

  output=$(
    HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=upstream run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --profile default 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: default"
  assert_file_executable "$INSTALL_DIR/profiles/default/shims/jq"
  assert_path_not_exists "$INSTALL_DIR/profiles/upstream/shims/jq"

  pass "update mode flag overrides environment"
}

test_update_mode_upstream_profile() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  checkout_dir_real=$(cd "$checkout_dir" && pwd -P)
  test_profile_fake_shim_write "$checkout_dir/shims/jq" "upstream-update-profile"

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null
  rm -f "$INSTALL_DIR/shims/jq"
  rm -f "$INSTALL_DIR/profiles/upstream/shims/jq"

  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --profile upstream 2>&1
  )

  assert_contains "$output" "Selected Shimmy profile: upstream"
  assert_path_symlink "$INSTALL_DIR/shims/jq"
  assert_file_executable "$INSTALL_DIR/profiles/upstream/shims/jq"
  assert_file_contains "$INSTALL_DIR/profiles/upstream/shims/jq" "shimmy_upstream_checkout='$checkout_dir_real'"
  assert_file_exists "$INSTALL_DIR/install-manifest.txt"

  command_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=upstream jq --version 2>&1
  )
  assert_contains "$command_output" "upstream-update-profile"

  pass "update upstream mode refreshes upstream profile"
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
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/go" env GOVERSION GOARCH 2>&1
  )

  assert_contains "$output" "go"
  assert_contains "$output" "$expected_goarch"

  pass "go direct shim execution and platform selection"
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
    PATH="$(dirname "$PODMAN_BIN"):$PATH" SHIMMY_JQ_IMAGE_PULL=always SHIMMY_JQ_IMAGE=ghcr.io/jqlang/jq:1.8.1 "$ROOT_DIR/shims/jq" --version 2>&1
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

test_installed_upstream_jq_shim() {
  setup_scenario
  require_podman

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$ROOT_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=upstream jq --version 2>&1
  )
  assert_contains "$output" "jq-1.8.1"

  test_output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$INSTALL_DIR/bin:$INSTALL_DIR/shims:/usr/bin:/bin" shimmy test --profile upstream --shim jq 2>&1
  )
  assert_contains "$test_output" "Selected Shimmy profile: upstream"
  assert_contains "$test_output" "shimmy_profile_name=upstream"
  assert_contains "$test_output" "root_test_shim=jq"
  assert_contains "$test_output" "root_smoke_tests=1"
  assert_contains "$test_output" "profile_smoke_tests=skipped"
  assert_contains "$test_output" "profile_test=ok"

  pass "installed upstream jq shim execution"
}

test_installed_go_shim() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim go >/dev/null

  assert_path_symlink "$INSTALL_DIR/shims/go"
  assert_file_executable "$INSTALL_DIR/shims/go"
  assert_file_executable "$INSTALL_DIR/profiles/default/shims/go"
  dispatch_target=$(readlink "$INSTALL_DIR/shims/go")
  assert_equals "$dispatch_target" "../libexec/shimmy/scripts/dispatch-shimmy.sh"
  cmp -s "$ROOT_DIR/shims/go" "$INSTALL_DIR/profiles/default/shims/go" || fail_test "expected default profile go shim to match source shim"

  pass "installed go dispatcher targets default profile shim"
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
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_LAN_SCAN=${SHIMMY_NMAP_LAN_SCAN:-}'
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_NETWORK=host'
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_NET_RAW_CAP_VALUE=NET_RAW'
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_NET_ADMIN_CAP_VALUE=NET_ADMIN'

  pass "nmap LAN scan opt-in wiring"
}

test_nmap_shim_network_opt_in() {
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_NETWORK=${SHIMMY_NMAP_NETWORK:-}'
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_NETWORK_ARG=--network'
  assert_file_contains "$ROOT_DIR/shims/nmap" '${SHIMMY_NMAP_NETWORK_ARG:+"$SHIMMY_NMAP_NETWORK_ARG"}'
  assert_file_contains "$ROOT_DIR/shims/nmap" '${SHIMMY_NMAP_NETWORK_VALUE:+"$SHIMMY_NMAP_NETWORK_VALUE"}'

  pass "nmap network opt-in wiring"
}

test_nmap_shim_nmap_privileged_opt_in() {
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_PRIVILEGED=${SHIMMY_NMAP_PRIVILEGED:-}'
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_PRIVILEGED_ARG=--privileged'
  assert_file_contains "$ROOT_DIR/shims/nmap" '${SHIMMY_NMAP_PRIVILEGED_ARG:+"$SHIMMY_NMAP_PRIVILEGED_ARG"}'

  pass "nmap Nmap privileged opt-in wiring"
}

test_nmap_shim_podman_privileged_opt_in() {
  setup_scenario
  require_podman

  if ! shimmy_podman_privileged_connection_resolve; then
    pass "nmap Podman privileged opt-in execution skipped without rootful Podman connection"
    return 0
  fi

  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" SHIMMY_NMAP_LAN_SCAN=1 SHIMMY_PODMAN_PRIVILEGED=1 "$ROOT_DIR/shims/nmap" --version 2>&1
  )

  assert_contains "$output" "Nmap version"

  pass "nmap Podman privileged opt-in execution"
}

test_nmap_shim_rootless_host_discovery_guidance() {
  setup_scenario
  require_podman

  rootless_value=$("$PODMAN_BIN" info --format '{{.Host.Security.Rootless}}' 2>/dev/null || printf false)

  if [ "$rootless_value" != true ]; then
    pass "nmap rootless host discovery guidance skipped for rootful Podman"
    return 0
  fi

  set +e
  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" "$ROOT_DIR/shims/nmap" -sn 127.0.0.1 2>&1
  )
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail_test "expected rootless nmap host discovery guidance to fail before execution"
  assert_contains "$output" "nmap host discovery (-sn/-sP) needs raw socket access"
  assert_contains "$output" "explicit Podman privileged escalation approval"
  assert_contains "$output" "Do not make SHIMMY_PODMAN_PRIVILEGED=1 a default."
  assert_contains "$output" '["env","SHIMMY_NMAP_LAN_SCAN=1","SHIMMY_PODMAN_PRIVILEGED=1","./shims/nmap"]'
  assert_contains "$output" "SHIMMY_NMAP_LAN_SCAN=1 SHIMMY_PODMAN_PRIVILEGED=1 nmap -sn <target>"
  assert_contains "$output" "use a rootful Podman connection for raw LAN discovery"

  pass "nmap rootless host discovery guidance"
}

test_nmap_shim_rootless_podman_privileged_bypasses_guidance() {
  setup_scenario
  require_podman

  if ! shimmy_podman_privileged_connection_resolve; then
    pass "nmap rootless Podman privileged guidance bypass skipped without rootful Podman connection"
    return 0
  fi

  rootless_value=$("$PODMAN_BIN" info --format '{{.Host.Security.Rootless}}' 2>/dev/null || printf false)

  if [ "$rootless_value" != true ]; then
    pass "nmap rootless Podman privileged guidance bypass skipped for rootful Podman"
    return 0
  fi

  set +e
  output=$(
    cd "$WORK_DIR"
    PATH="$(dirname "$PODMAN_BIN"):$PATH" SHIMMY_NMAP_LAN_SCAN=1 SHIMMY_PODMAN_PRIVILEGED=1 "$ROOT_DIR/shims/nmap" -sn 127.0.0.1 2>&1
  )
  set -e

  assert_not_contains "$output" "explicit Podman privileged escalation approval"
  assert_not_contains "$output" "Do not make SHIMMY_PODMAN_PRIVILEGED=1 a default."

  pass "nmap rootless Podman privileged guidance bypass"
}

test_nmap_shim_nmap_unprivileged_opt_in() {
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_PRIVILEGED=${SHIMMY_NMAP_PRIVILEGED:-}'
  assert_file_contains "$ROOT_DIR/shims/nmap" 'SHIMMY_NMAP_PRIVILEGED_ARG=--unprivileged'
  assert_file_contains "$ROOT_DIR/shims/nmap" '${SHIMMY_NMAP_PRIVILEGED_ARG:+"$SHIMMY_NMAP_PRIVILEGED_ARG"}'

  pass "nmap Nmap unprivileged opt-in wiring"
}

test_opnsense_mcp_server_shim_direct() {
  setup_scenario

  set +e
  output=$(
    cd "$WORK_DIR" && "$ROOT_DIR/shims/opnsense-mcp-server" 2>&1
  )
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail_test "expected opnsense-mcp-server to require configuration"
  assert_contains "$output" "ERROR: OPNSENSE_URL is required for the opnsense-mcp-server shim."
  assert_contains "$output" "Set OPNSENSE_URL to the OPNsense API base URL, including /api."

  pass "opnsense-mcp-server requires OPNSENSE_URL before execution"
}

test_opnsense_mcp_server_shim_url_invalid() {
  setup_scenario

  set +e
  output=$(
    cd "$WORK_DIR" && OPNSENSE_URL=opnsense.local/api "$ROOT_DIR/shims/opnsense-mcp-server" 2>&1
  )
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail_test "expected opnsense-mcp-server to reject invalid OPNSENSE_URL"
  assert_contains "$output" "ERROR: OPNSENSE_URL must be an http:// or https:// URL with a host: opnsense.local/api"

  pass "opnsense-mcp-server rejects invalid OPNSENSE_URL"
}

test_opnsense_mcp_server_shim_url_unreachable() {
  setup_scenario
  require_curl

  set +e
  output=$(
    cd "$WORK_DIR" && OPNSENSE_URL=http://127.0.0.1:9/api "$ROOT_DIR/shims/opnsense-mcp-server" 2>&1
  )
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail_test "expected opnsense-mcp-server to reject unreachable OPNSENSE_URL"
  assert_contains "$output" "ERROR: OPNSENSE_URL did not respond to curl: http://127.0.0.1:9/api"
  assert_contains "$output" "Confirm the URL, network path, firewall reachability, and OPNSENSE_VERIFY_SSL setting."

  pass "opnsense-mcp-server rejects unreachable OPNSENSE_URL"
}

test_opnsense_mcp_server_shim_verify_ssl_default() {
  setup_scenario

  mkdir -p "$WORK_DIR/bin"
  curl_args_file=$WORK_DIR/curl.args
  cat > "$WORK_DIR/bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$SHIMMY_TEST_CURL_ARGS_FILE"
exit 1
EOF
  chmod +x "$WORK_DIR/bin/curl"

  set +e
  output=$(
    cd "$WORK_DIR" &&
      PATH="$WORK_DIR/bin:$PATH" \
      SHIMMY_TEST_CURL_ARGS_FILE="$curl_args_file" \
      OPNSENSE_URL=https://opnsense.local/api \
      "$ROOT_DIR/shims/opnsense-mcp-server" 2>&1
  )
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail_test "expected opnsense-mcp-server preflight to stop after failed curl"
  assert_contains "$output" "ERROR: OPNSENSE_URL did not respond to curl: https://opnsense.local/api"
  curl_args=$(cat "$curl_args_file")
  assert_contains "$curl_args" "--insecure"
  assert_contains "$curl_args" "--connect-timeout"
  assert_contains "$curl_args" "10"
  assert_contains "$curl_args" "--max-time"
  assert_contains "$curl_args" "20"

  pass "opnsense-mcp-server defaults OPNSENSE_VERIFY_SSL to false"
}

test_opnsense_mcp_server_shim_secret_selectors() {
  assert_file_contains "$ROOT_DIR/shims/opnsense-mcp-server" 'SHIMMY_OPNSENSE_MCP_API_KEY=${SHIMMY_OPNSENSE_MCP_API_KEY:-opnsense_mcp_api_key}'
  assert_file_contains "$ROOT_DIR/shims/opnsense-mcp-server" 'SHIMMY_OPNSENSE_MCP_API_SECRET=${SHIMMY_OPNSENSE_MCP_API_SECRET:-opnsense_mcp_api_secret}'
  assert_file_contains "$ROOT_DIR/shims/opnsense-mcp-server" '--secret "$SHIMMY_OPNSENSE_MCP_API_KEY,type=env,target=OPNSENSE_API_KEY"'
  assert_file_contains "$ROOT_DIR/shims/opnsense-mcp-server" '--secret "$SHIMMY_OPNSENSE_MCP_API_SECRET,type=env,target=OPNSENSE_API_SECRET"'

  pass "opnsense-mcp-server secret selectors wire Podman secret names"
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

test_installed_opnsense_mcp_server_shim() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim opnsense-mcp-server >/dev/null

  set +e
  output=$(
    cd "$WORK_DIR" && "$INSTALL_DIR/shims/opnsense-mcp-server" 2>&1
  )
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail_test "expected installed opnsense-mcp-server to require configuration"
  assert_contains "$output" "ERROR: OPNSENSE_URL is required for the opnsense-mcp-server shim."
  assert_contains "$output" "Set OPNSENSE_URL to the OPNsense API base URL, including /api."

  pass "installed opnsense-mcp-server requires OPNSENSE_URL before execution"
}

test_uninstall_requires_mode() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(
    HOME="$HOME_DIR" run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected uninstall without mode to fail"
  assert_contains "$output" "uninstall requires --profile default or --profile upstream"
  assert_file_exists "$INSTALL_DIR/profiles/default/install-manifest.txt"

  pass "uninstall requires explicit mode"
}

test_uninstall_mode_default_preserves_upstream() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  test_profile_fake_shim_write "$checkout_dir/shims/jq" "upstream-after-default-uninstall"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null
  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=upstream run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" --profile default >/dev/null

  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  assert_file_contains "$INSTALL_DIR/install-manifest.txt" "profile=upstream"
  root_manifest_contents=$(cat "$INSTALL_DIR/install-manifest.txt")
  assert_not_contains "$root_manifest_contents" "profile=default"
  assert_path_not_exists "$INSTALL_DIR/profiles/default"
  assert_file_exists "$INSTALL_DIR/profiles/upstream/install-manifest.txt"
  assert_path_symlink "$INSTALL_DIR/shims/jq"
  assert_file_executable "$INSTALL_DIR/bin/shimmy"

  command_output=$(
    cd "$WORK_DIR"
    PATH="$INSTALL_DIR/shims:/usr/bin:/bin" SHIMMY_PROFILE_ACTIVE=upstream jq --version 2>&1
  )
  assert_contains "$command_output" "upstream-after-default-uninstall"

  pass "uninstall default mode preserves upstream profile"
}

test_uninstall_mode_invalid_environment_rejected() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(
    HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=invalid run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" 2>&1
  )
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "expected invalid SHIMMY_PROFILE_ACTIVE to fail uninstall"
  assert_contains "$output" "unsupported Shimmy profile: invalid"
  assert_file_exists "$INSTALL_DIR/profiles/default/install-manifest.txt"

  pass "uninstall rejects invalid SHIMMY_PROFILE_ACTIVE"
}

test_uninstall_mode_upstream_last_profile_cleanup() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  test_profile_fake_shim_write "$checkout_dir/shims/jq" "upstream-last-profile"

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  HOME="$HOME_DIR" run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" --profile upstream >/dev/null

  assert_path_not_exists "$INSTALL_DIR"

  pass "uninstall upstream mode removes install when last profile"
}

test_uninstall_mode_upstream_preserves_default() {
  setup_scenario

  checkout_dir=$SCENARIO_DIR/upstream-checkout
  test_upstream_checkout_create "$checkout_dir"
  test_profile_fake_shim_write "$checkout_dir/shims/jq" "upstream-before-uninstall"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null
  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  HOME="$HOME_DIR" run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" --profile upstream >/dev/null

  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  assert_file_exists "$INSTALL_DIR/profiles/default/install-manifest.txt"
  assert_path_not_exists "$INSTALL_DIR/profiles/upstream"
  assert_path_symlink "$INSTALL_DIR/shims/jq"
  assert_file_executable "$INSTALL_DIR/profiles/default/shims/jq"
  assert_file_executable "$INSTALL_DIR/bin/shimmy"

  pass "uninstall upstream mode preserves default profile"
}

main() {
  parse_args "$@"

  if [ "$RUN_PROFILE_TESTS" -eq 1 ]; then
    run_profile_tests
    printf 'All %s shim smoke tests passed.\n' "$SHIM_SMOKE_TEST_COUNT"
    return 0
  fi

  test_podman_platform_resolves_host_os
  test_podman_platform_tag_render
  test_podman_unreachable_guidance_agent
  test_podman_privileged_connection_resolves_default_root
  test_dash_parse
  test_profile_rejects_mode_flag
  test_install_manifest
  test_install_default_shims
  test_install_mode_default_profile_manifest
  test_install_mode_invalid_environment_rejected
  test_install_mode_precedence
  test_install_mode_upstream_profile_manifest
  test_installed_dispatcher_invalid_mode_rejected
  test_installed_dispatcher_recursive_target_rejected
  test_installed_dispatcher_parameterized_invocation
  test_installed_dispatcher_upstream_checkout_reflects_edits
  test_shimmy_test_mode_default_profile
  test_shimmy_test_mode_default_profile_shim
  test_shimmy_test_mode_default_profile_only_shim
  test_shimmy_test_mode_default_profile_all
  test_shimmy_test_mode_all_rejects_shim
  test_shimmy_test_mode_missing_config_rejected
  test_shimmy_test_mode_missing_smoke_arg_rejected
  test_shimmy_test_mode_environment_fallback
  test_shimmy_test_mode_invalid_environment_rejected
  test_shimmy_test_mode_precedence
  test_shimmy_test_mode_upstream_profile
  test_install_removes_legacy_shell_init_block
  test_install_bash_uses_existing_profile_login_file
  test_activate_eval
  test_activate_mode_default_exports_mode
  test_activate_mode_invalid_environment_rejected
  test_activate_mode_precedence
  test_activate_is_idempotent
  test_activate_mode_upstream_exports_mode
  test_install_no_startup
  test_skills_install_repo_target
  test_installed_launcher_skills_install_includes_installed_shim_skills
  test_skills_update_repo_target
  test_skills_export_folder
  test_install_shares_management_skills_explicit_target
  test_install_macos_podman_guidance
  test_agent_shimmy_preflight_reports_approvals
  test_agent_shimmy_preflight_reports_upstream_profile
  test_netinfo_help
  test_netinfo_manifest_crostini_host_name_resolution
  test_netinfo_manifest_darwin_host_name_resolution
  test_netinfo_manifest_auto_darwin_default_interface
  test_netinfo_manifest_auto_skips_crostini_shell_lan
  test_update_repair_startup
  test_status_reports_install
  test_status_available_reports_remaining_shims
  test_status_manifest_format
  test_status_available_manifest_format
  test_status_mode_invalid_environment_rejected
  test_status_mode_paths_are_distinct
  test_status_mode_precedence
  test_status_upstream_checkout_absolute_resolution
  test_installed_shimmy_management_command
  test_installed_shim_install_adds_available_shim
  test_installed_shim_install_rejects_positional_name
  test_installed_update_fetches_manifest_source
  test_repo_update_uses_current_checkout
  test_installed_update_requires_pull_for_image_refresh
  test_update_reinstalls_default_shims_only
  test_update_shim_reinstalls_selected_shim
  test_update_shim_requires_installed_shim
  test_update_all_reinstalls_profile_shims
  test_update_preserves_shimmy_manifest_fields
  test_update_mode_default_profile
  test_update_mode_environment_fallback
  test_update_mode_invalid_environment_rejected
  test_update_mode_precedence
  test_update_mode_upstream_profile
  test_aws_shim_direct
  test_go_shim_direct
  test_go_shim_help_test
  test_jq_shim_direct
  test_jq_shim_pull_override
  test_installed_go_shim
  test_installed_jq_shim
  test_installed_upstream_jq_shim
  test_netcat_shim_direct
  test_nmap_shim_direct
  test_nmap_shim_lan_scan_opt_in
  test_nmap_shim_network_opt_in
  test_nmap_shim_nmap_privileged_opt_in
  test_nmap_shim_podman_privileged_opt_in
  test_nmap_shim_rootless_host_discovery_guidance
  test_nmap_shim_rootless_podman_privileged_bypasses_guidance
  test_nmap_shim_nmap_unprivileged_opt_in
  test_opnsense_mcp_server_shim_direct
  test_opnsense_mcp_server_shim_url_invalid
  test_opnsense_mcp_server_shim_url_unreachable
  test_opnsense_mcp_server_shim_verify_ssl_default
  test_opnsense_mcp_server_shim_secret_selectors
  test_rg_shim_direct
  test_task_shim_direct
  test_terraform_shim_direct
  test_textual_shim_direct
  test_installed_opnsense_mcp_server_shim
  test_installed_task_shim
  test_uninstall_requires_mode
  test_uninstall_mode_default_preserves_upstream
  test_uninstall_mode_invalid_environment_rejected
  test_uninstall_mode_upstream_last_profile_cleanup
  test_uninstall_mode_upstream_preserves_default

  printf 'All %s shim tests passed.\n' "$TEST_COUNT"
}

main "$@"
