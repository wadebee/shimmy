#!/bin/sh
# Installed-profile smoke test mode.

test_profile_tool_version_find() {
  manifest_file=$1
  tool_name_expected=$2
  version_label_expected=$3

  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    tool_name=${tool_version_entry%%|*}
    version_entry=${tool_version_entry#*|}
    version_label=${version_entry%%|*}
    version_name=${version_entry#*|}

    if [ "$tool_name" = "$tool_name_expected" ] && [ "$version_label" = "$version_label_expected" ]; then
      printf '%s\n' "$version_name"
      return 0
    fi
  done <<EOF
$(shimmy_manifest_tool_version_list_read "$manifest_file" || true)
EOF

  return 1
}

test_profile_mode_parse() {
  TEST_PROFILE_RUN=0
  TEST_PROFILE_SHIM_REQUESTED=
  TEST_PROFILE_TEST_ALL=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --all)
        TEST_PROFILE_TEST_ALL=1
        TEST_PROFILE_RUN=1
        shift
        ;;
      --shim)
        [ "$#" -ge 2 ] || fail_test "missing value for --shim"
        TEST_PROFILE_SHIM_REQUESTED=$2
        TEST_PROFILE_RUN=1
        shift 2
        ;;
      -h|--help)
        test_profile_mode_usage
        exit 0
        ;;
      *)
        fail_test "unknown argument: $1"
        ;;
    esac
  done

  if [ -f "$ROOT_DIR/install-manifest.txt" ]; then
    TEST_PROFILE_RUN=1
  fi

  if [ "$TEST_PROFILE_TEST_ALL" -eq 1 ] && [ -n "$TEST_PROFILE_SHIM_REQUESTED" ]; then
    fail_test "--all cannot be combined with --shim"
  fi
}

test_profile_mode_usage() {
  cat <<'EOF'
Run Shimmy tests.

Usage:
  shimmy test [--shim <tool>[@<version>]] [--all]

From a source checkout this runs the repository suite. Through an installed
launcher it validates that launcher's profile and runs non-mutating smoke
commands through its installed wrappers.

Options:
  --shim <name>        Test one installed tool or concrete tool@version.
  --all                Test installed public tools and every installed concrete version.
  -h, --help           Show this help.

Examples:
  shimmy test
  shimmy test --shim jq
  shimmy test --shim aws@2.31
  shimmy test --all
EOF
}

test_profile_request_resolve() {
  test_profile_manifest_file=$1
  test_profile_requested_shim=$TEST_PROFILE_SHIM_REQUESTED

  TEST_PROFILE_REQUEST_TOOL=
  TEST_PROFILE_REQUEST_VERSION=

  [ -n "$test_profile_requested_shim" ] || return 0

  case "$test_profile_requested_shim" in
    *@*)
      TEST_PROFILE_REQUEST_TOOL=${test_profile_requested_shim%%@*}
      test_profile_requested_label=${test_profile_requested_shim#*@}
      case "$TEST_PROFILE_REQUEST_TOOL:$test_profile_requested_label" in
        :*|*:@*|*:)
          fail_test "invalid shim request: $test_profile_requested_shim"
          ;;
      esac
      TEST_PROFILE_REQUEST_VERSION=$(test_profile_tool_version_find "$test_profile_manifest_file" "$TEST_PROFILE_REQUEST_TOOL" "$test_profile_requested_label" || true)
      [ -n "$TEST_PROFILE_REQUEST_VERSION" ] || fail_test "version $test_profile_requested_shim is not recorded in the selected Shimmy profile"
      ;;
    *)
      TEST_PROFILE_REQUEST_TOOL=$test_profile_requested_shim
      shimmy_manifest_tool_contains "$test_profile_manifest_file" "$TEST_PROFILE_REQUEST_TOOL" || fail_test "tool $TEST_PROFILE_REQUEST_TOOL is not recorded in the selected Shimmy profile"
      ;;
  esac
}

test_profile_smoke_env_apply() {
  smoke_env_file=$1

  while IFS= read -r smoke_config_line || [ -n "$smoke_config_line" ]; do
    case "$smoke_config_line" in
      smoke_env=*)
        smoke_env=${smoke_config_line#smoke_env=}
        case "$smoke_env" in
          [A-Za-z_]*=*)
            export "$smoke_env"
            ;;
          *)
            printf 'invalid smoke_env in %s: %s\n' "$smoke_env_file" "$smoke_env" >&2
            return 1
            ;;
        esac
        ;;
    esac
  done < "$smoke_env_file"
}

test_profile_smoke_command_run() {
  target_path=$1
  profile_name=$2
  smoke_env_file=$3
  smoke_arg_file=$4
  smoke_scope=$5
  smoke_name=$6

  assert_file_executable "$target_path"
  [ -f "$smoke_env_file" ] || fail_test "missing installed shim config: $smoke_env_file"
  [ -f "$smoke_arg_file" ] || fail_test "missing installed shim config: $smoke_arg_file"

  set --
  while IFS= read -r smoke_config_line || [ -n "$smoke_config_line" ]; do
    case "$smoke_config_line" in
      smoke_arg=*)
        smoke_arg=${smoke_config_line#smoke_arg=}
        [ -n "$smoke_arg" ] || fail_test "empty smoke_arg in $smoke_arg_file"
        set -- "$@" "$smoke_arg"
        ;;
    esac
  done < "$smoke_arg_file"

  [ "$#" -gt 0 ] || fail_test "missing smoke_arg in $smoke_arg_file"

  set +e
  smoke_output=$(
    exec 2>&1
    test_profile_smoke_env_apply "$smoke_env_file" || exit 1
    "$target_path" "$@"
  )
  smoke_status=$?
  set -e

  if [ "$smoke_status" -ne 0 ]; then
    printf 'Smoke output for %s %s:\n%s\n' "$smoke_scope" "$smoke_name" "$smoke_output" >&2
    fail_test "$smoke_scope smoke command failed for $smoke_name in profile $profile_name"
  fi

  pass "$smoke_scope smoke command succeeds for $smoke_name in profile $profile_name"
}

test_profile_smoke_tool_run() {
  tool_name=$1
  manifest_file=$2
  public_bin_dir=$3
  config_dir=$4
  profile_name=$5

  version_name=$(test_profile_tool_version_find "$manifest_file" "$tool_name" default || true)
  [ -n "$version_name" ] || fail_test "tool $tool_name has no default version in the selected Shimmy profile"

  test_profile_smoke_command_run \
    "$public_bin_dir/$tool_name" \
    "$profile_name" \
    "$config_dir/shims/$tool_name.conf" \
    "$config_dir/shims/$version_name.conf" \
    public \
    "$tool_name"
}

test_profile_smoke_version_run() {
  version_name=$1
  profile_implementation_dir=$2
  config_dir=$3
  profile_name=$4

  test_profile_smoke_command_run \
    "$profile_implementation_dir/$version_name" \
    "$profile_name" \
    "$config_dir/shims/$version_name.conf" \
    "$config_dir/shims/$version_name.conf" \
    version \
    "$version_name"
}

test_profile_smoke_versions_run() {
  manifest_file=$1
  profile_implementation_dir=$2
  config_dir=$3
  profile_name=$4
  version_names_seen=

  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    version_name=${tool_version_entry##*|}
    [ -n "$version_name" ] || fail_test "invalid tool_version entry in $manifest_file: $tool_version_entry"
    if shimmy_contains_line_list "$version_names_seen" "$version_name"; then
      continue
    fi
    version_names_seen=$(shimmy_append_line_list "$version_names_seen" "$version_name")
    test_profile_smoke_version_run "$version_name" "$profile_implementation_dir" "$config_dir" "$profile_name"
  done <<EOF
$(shimmy_manifest_tool_version_list_read "$manifest_file" || true)
EOF
}

test_profile_smoke_run() {
  shimmy_profile_context_resolve "$ROOT_DIR" || fail_test "installed tests must run from a canonical profile root"
  profile_manifest_file=$SHIMMY_PROFILE_MANIFEST_PATH
  profile_implementation_dir=$SHIMMY_PROFILE_IMPLEMENTATION_DIR
  shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME" || fail_test "incomplete or damaged Shimmy profile"

  public_bin_dir=$SHIMMY_PROFILE_BIN_DIR
  config_dir=$SHIMMY_PROFILE_CONFIG_DIR
  test_profile_request_resolve "$profile_manifest_file"

  printf 'Shimmy Test\n'
  printf 'Selected Shimmy profile: %s\n' "$SHIMMY_PROFILE_NAME"
  printf 'profile_root=%s\n' "$SHIMMY_PROFILE_ROOT"
  printf 'profile_manifest_path=%s\n' "$profile_manifest_file"

  if [ -n "$TEST_PROFILE_REQUEST_VERSION" ]; then
    test_profile_smoke_version_run "$TEST_PROFILE_REQUEST_VERSION" "$profile_implementation_dir" "$config_dir" "$SHIMMY_PROFILE_NAME"
    return 0
  fi

  if [ -n "$TEST_PROFILE_REQUEST_TOOL" ]; then
    test_profile_smoke_tool_run "$TEST_PROFILE_REQUEST_TOOL" "$profile_manifest_file" "$public_bin_dir" "$config_dir" "$SHIMMY_PROFILE_NAME"
    return 0
  fi

  installed_tool_count=0
  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    test_profile_smoke_tool_run "$tool_name" "$profile_manifest_file" "$public_bin_dir" "$config_dir" "$SHIMMY_PROFILE_NAME"
    installed_tool_count=$((installed_tool_count + 1))
  done <<EOF
$(shimmy_manifest_tool_list_read "$profile_manifest_file" || true)
EOF
  [ "$installed_tool_count" -gt 0 ] || fail_test "no installed tools recorded in $profile_manifest_file"

  if [ "$TEST_PROFILE_TEST_ALL" -eq 1 ]; then
    test_profile_smoke_versions_run "$profile_manifest_file" "$profile_implementation_dir" "$config_dir" "$SHIMMY_PROFILE_NAME"
  fi
}
