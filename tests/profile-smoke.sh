#!/bin/sh
# Installed-profile smoke test mode.

test_profile_kind_version_find() {
  manifest_file=$1
  kind_name_expected=$2
  version_label_expected=$3

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    kind_name=${kind_version_entry%%|*}
    version_entry=${kind_version_entry#*|}
    version_label=${version_entry%%|*}
    version_name=${version_entry#*|}

    if [ "$kind_name" = "$kind_name_expected" ] && [ "$version_label" = "$version_label_expected" ]; then
      printf '%s\n' "$version_name"
      return 0
    fi
  done <<EOF
$(shimmy_read_manifest_kind_versions "$manifest_file" || true)
EOF

  return 1
}

test_profile_mode_parse() {
  TEST_PROFILE_INSTALL_DIR_REQUESTED=
  TEST_PROFILE_NAME_REQUESTED=
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
      --install-dir)
        [ "$#" -ge 2 ] || fail_test "missing value for --install-dir"
        TEST_PROFILE_INSTALL_DIR_REQUESTED=$2
        TEST_PROFILE_RUN=1
        shift 2
        ;;
      --profile)
        [ "$#" -ge 2 ] || fail_test "missing value for --profile"
        TEST_PROFILE_NAME_REQUESTED=$2
        TEST_PROFILE_RUN=1
        shift 2
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

  if [ -n "${SHIMMY_PROFILE_ACTIVE:-}" ] || [ -n "${SHIMMY_CONTROL_INSTALL_DIR:-}" ]; then
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
  tests/test.sh [--install-dir <dir>] [--profile default|upstream] [--shim <kind>[@<version>]] [--all]

Without an install directory, profile, shim request, active profile, or installed
launcher context, this runs the source-checkout test suite. With a selected
installed profile, it validates the manifests and runs live non-mutating smoke
commands through the installed wrappers.

Options:
  --install-dir <dir>  Test the Shimmy install rooted at <dir>.
  --profile <name>     Select default or upstream.
  --shim <name>        Test one installed kind or concrete kind@version.
  --all                Test installed public kinds and every installed concrete version.
EOF
}

test_profile_request_resolve() {
  test_profile_manifest_file=$1
  test_profile_requested_shim=$TEST_PROFILE_SHIM_REQUESTED

  TEST_PROFILE_REQUEST_KIND=
  TEST_PROFILE_REQUEST_VERSION=

  [ -n "$test_profile_requested_shim" ] || return 0

  case "$test_profile_requested_shim" in
    *@*)
      TEST_PROFILE_REQUEST_KIND=${test_profile_requested_shim%%@*}
      test_profile_requested_label=${test_profile_requested_shim#*@}
      case "$TEST_PROFILE_REQUEST_KIND:$test_profile_requested_label" in
        :*|*:@*|*:)
          fail_test "invalid shim request: $test_profile_requested_shim"
          ;;
      esac
      TEST_PROFILE_REQUEST_VERSION=$(test_profile_kind_version_find "$test_profile_manifest_file" "$TEST_PROFILE_REQUEST_KIND" "$test_profile_requested_label" || true)
      [ -n "$TEST_PROFILE_REQUEST_VERSION" ] || fail_test "version $test_profile_requested_shim is not recorded in the selected Shimmy profile"
      ;;
    *)
      TEST_PROFILE_REQUEST_KIND=$test_profile_requested_shim
      shimmy_contains_manifest_kind "$test_profile_manifest_file" "$TEST_PROFILE_REQUEST_KIND" || fail_test "kind $TEST_PROFILE_REQUEST_KIND is not recorded in the selected Shimmy profile"
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
  assert_file_exists "$smoke_env_file"
  assert_file_exists "$smoke_arg_file"

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
    test_profile_smoke_env_apply "$smoke_env_file" || exit 1
    SHIMMY_PROFILE_ACTIVE=$profile_name
    export SHIMMY_PROFILE_ACTIVE
    "$target_path" "$@"
  2>&1)
  smoke_status=$?
  set -e

  if [ "$smoke_status" -ne 0 ]; then
    printf 'Smoke output for %s %s:\n%s\n' "$smoke_scope" "$smoke_name" "$smoke_output" >&2
    fail_test "$smoke_scope smoke command failed for $smoke_name in profile $profile_name"
  fi

  pass "$smoke_scope smoke command succeeds for $smoke_name in profile $profile_name"
}

test_profile_smoke_kind_run() {
  kind_name=$1
  manifest_file=$2
  public_bin_dir=$3
  config_dir=$4
  profile_name=$5

  version_name=$(test_profile_kind_version_find "$manifest_file" "$kind_name" default || true)
  [ -n "$version_name" ] || fail_test "kind $kind_name has no default version in the selected Shimmy profile"

  test_profile_smoke_command_run \
    "$public_bin_dir/$kind_name" \
    "$profile_name" \
    "$config_dir/shims/$kind_name.conf" \
    "$config_dir/shims/$version_name.conf" \
    public \
    "$kind_name"
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

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    version_name=${kind_version_entry##*|}
    [ -n "$version_name" ] || fail_test "invalid kind_version entry in $manifest_file: $kind_version_entry"
    if shimmy_contains_line_list "$version_names_seen" "$version_name"; then
      continue
    fi
    version_names_seen=$(shimmy_append_line_list "$version_names_seen" "$version_name")
    test_profile_smoke_version_run "$version_name" "$profile_implementation_dir" "$config_dir" "$profile_name"
  done <<EOF
$(shimmy_read_manifest_kind_versions "$manifest_file" || true)
EOF
}

test_profile_smoke_run() {
  if ! shimmy_profile_paths_resolve "$TEST_PROFILE_NAME_REQUESTED" "$TEST_PROFILE_INSTALL_DIR_REQUESTED" "$ROOT_DIR"; then
    fail_test "unsupported Shimmy profile: ${TEST_PROFILE_NAME_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
  fi

  root_manifest_file=$(shimmy_root_manifest_path_resolve "$SHIMMY_PROFILE_INSTALL_DIR")
  profile_manifest_file=$SHIMMY_PROFILE_MANIFEST_PATH
  assert_file_exists "$root_manifest_file"
  shimmy_install_layout_validate "$root_manifest_file" || fail_test "legacy Shimmy install layout detected; uninstall and reinstall"

  profile_implementation_dir=$(shimmy_read_manifest_value "$profile_manifest_file" profile_implementation_dir || true)
  [ -n "$profile_implementation_dir" ] || profile_implementation_dir=$SHIMMY_PROFILE_IMPLEMENTATION_DIR
  if ! shimmy_profile_structure_validate "$profile_manifest_file" "$profile_implementation_dir"; then
    fail_test "incomplete Shimmy profile for profile $SHIMMY_PROFILE_NAME; repair with $(shimmy_profile_install_hint "$SHIMMY_PROFILE_NAME")"
  fi

  if [ "$SHIMMY_PROFILE_NAME" = upstream ]; then
    source_checkout=$(shimmy_read_manifest_value "$profile_manifest_file" source_checkout || true)
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_checkout" || true)
    if [ -n "$upstream_invalid_reason" ]; then
      fail_test "invalid upstream Shimmy checkout ($upstream_invalid_reason): $source_checkout; rerun shimmy install --profile upstream from the desired Shimmy checkout"
    fi
  fi

  public_bin_dir=$(shimmy_read_manifest_value "$root_manifest_file" bin_dir || true)
  [ -n "$public_bin_dir" ] || public_bin_dir=$SHIMMY_INSTALL_BIN_DIR
  config_dir=$(shimmy_read_manifest_value "$profile_manifest_file" config_dir || true)
  [ -n "$config_dir" ] || config_dir=$SHIMMY_PROFILE_CONFIG_DIR
  test_profile_request_resolve "$profile_manifest_file"

  printf 'Shimmy Test\n'
  printf 'Selected Shimmy profile: %s\n' "$SHIMMY_PROFILE_NAME"
  printf 'install_dir=%s\n' "$SHIMMY_PROFILE_INSTALL_DIR"
  printf 'root_manifest_path=%s\n' "$root_manifest_file"
  printf 'profile_manifest_path=%s\n' "$profile_manifest_file"

  if [ -n "$TEST_PROFILE_REQUEST_VERSION" ]; then
    test_profile_smoke_version_run "$TEST_PROFILE_REQUEST_VERSION" "$profile_implementation_dir" "$config_dir" "$SHIMMY_PROFILE_NAME"
    return 0
  fi

  if [ -n "$TEST_PROFILE_REQUEST_KIND" ]; then
    test_profile_smoke_kind_run "$TEST_PROFILE_REQUEST_KIND" "$profile_manifest_file" "$public_bin_dir" "$config_dir" "$SHIMMY_PROFILE_NAME"
    return 0
  fi

  installed_kind_count=0
  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    test_profile_smoke_kind_run "$kind_name" "$profile_manifest_file" "$public_bin_dir" "$config_dir" "$SHIMMY_PROFILE_NAME"
    installed_kind_count=$((installed_kind_count + 1))
  done <<EOF
$(shimmy_read_manifest_kinds "$profile_manifest_file" || true)
EOF
  [ "$installed_kind_count" -gt 0 ] || fail_test "no installed kinds recorded in $profile_manifest_file"

  if [ "$TEST_PROFILE_TEST_ALL" -eq 1 ]; then
    test_profile_smoke_versions_run "$profile_manifest_file" "$profile_implementation_dir" "$config_dir" "$SHIMMY_PROFILE_NAME"
  fi
}
