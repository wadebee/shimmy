#!/bin/sh
# Source-suite group registry, selection, and timing helpers.

test_runner_group_registry_read() {
  if [ -n "${TEST_RUNNER_GROUP_REGISTRY_OVERRIDE:-}" ]; then
    printf '%s\n' "$TEST_RUNNER_GROUP_REGISTRY_OVERRIDE"
    return 0
  fi

  cat <<'EOF'
runner|test_lib_runner_run
lib-catalog|test_lib_catalog_run
lib-runtime|test_lib_runtime_run
lib-profile-activation|test_lib_profile_activation_run
lib-registries|test_lib_registries_run
lib-update|test_lib_update_run
commands-agent-preflight|test_commands_agent_preflight_run
commands-catalog|test_commands_catalog_run
commands-images|test_commands_images_run
commands-lifecycle|test_runner_commands_lifecycle_run
commands-management|test_commands_management_run
commands-onboarding|test_commands_onboarding_run
commands-profiles|test_commands_profiles_run
commands-profile|test_commands_profile_run
commands-status|test_commands_status_run
commands-update|test_commands_update_run
commands-startup|test_commands_startup_run
commands-skills|test_commands_skills_run
commands-dispatcher|test_commands_dispatcher_run
commands-netinfo|test_commands_netinfo_run
tools-aws|test_tools_aws_run
tools-community-ansible-dev-tools|test_tools_community_ansible_dev_tools_run
tools-gcloud|test_tools_gcloud_run
tools-gdrive|test_tools_gdrive_run
tools-gh|test_tools_gh_run
tools-go|test_tools_go_run
tools-jq|test_tools_jq_run
tools-netcat|test_tools_netcat_run
tools-nmap|test_tools_nmap_run
tools-npx|test_tools_npx_run
tools-oc|test_tools_oc_run
tools-opnsense-mcp-read-only|test_tools_opnsense_mcp_read_only_run
tools-opnsense-mcp-admin|test_tools_opnsense_mcp_admin_run
tools-rg|test_tools_rg_run
tools-skopeo|test_tools_skopeo_run
tools-task|test_tools_task_run
tools-terraform|test_tools_terraform_run
tools-tessl|test_tools_tessl_run
tools-textual|test_tools_textual_run
commands-install|test_commands_install_run
commands-test|test_commands_test_run
EOF
}

test_runner_group_registry_validate() {
  test_runner_names_seen=
  test_runner_functions_seen=

  while IFS='|' read -r test_runner_group_name test_runner_group_function test_runner_group_extra; do
    [ -n "$test_runner_group_name" ] || fail_test "empty test group name in registry"
    [ -n "$test_runner_group_function" ] || fail_test "missing function for test group: $test_runner_group_name"
    [ -z "$test_runner_group_extra" ] || fail_test "invalid test group registry entry: $test_runner_group_name"
    case "$test_runner_group_name" in
      *[!a-z0-9-]*|-*|*-|*--*) fail_test "invalid test group name: $test_runner_group_name" ;;
    esac
    case "$test_runner_group_function" in
      *[!a-z0-9_]*|'') fail_test "invalid test group function: $test_runner_group_function" ;;
    esac
    if shimmy_contains_line_list "$test_runner_names_seen" "$test_runner_group_name"; then
      fail_test "duplicate test group: $test_runner_group_name"
    fi
    if shimmy_contains_line_list "$test_runner_functions_seen" "$test_runner_group_function"; then
      fail_test "duplicate test group function: $test_runner_group_function"
    fi
    test_runner_names_seen=$(shimmy_append_line_list "$test_runner_names_seen" "$test_runner_group_name")
    test_runner_functions_seen=$(shimmy_append_line_list "$test_runner_functions_seen" "$test_runner_group_function")
  done <<EOF
$(test_runner_group_registry_read)
EOF
}

test_runner_group_exists() {
  test_runner_group_expected=$1

  while IFS='|' read -r test_runner_group_name test_runner_group_function; do
    if [ "$test_runner_group_name" = "$test_runner_group_expected" ]; then
      return 0
    fi
  done <<EOF
$(test_runner_group_registry_read)
EOF

  return 1
}

test_runner_group_selected() {
  test_runner_group_expected=$1
  [ -z "$TEST_RUNNER_GROUPS_SELECTED" ] ||
    shimmy_contains_line_list "$TEST_RUNNER_GROUPS_SELECTED" "$test_runner_group_expected"
}

test_runner_options_parse() {
  TEST_RUNNER_GROUPS_SELECTED=
  TEST_RUNNER_JOBS=1
  TEST_RUNNER_LIST_GROUPS=0
  test_runner_jobs_seen=0
  test_runner_serial_seen=0
  test_runner_list_seen=0

  test_runner_group_registry_validate

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --group)
        [ "$#" -ge 2 ] || fail_test "missing value for --group"
        case "$2" in ''|--*) fail_test "missing value for --group" ;; esac
        test_runner_group_exists "$2" || fail_test "unknown test group: $2"
        if shimmy_contains_line_list "$TEST_RUNNER_GROUPS_SELECTED" "$2"; then
          fail_test "duplicate test group request: $2"
        fi
        TEST_RUNNER_GROUPS_SELECTED=$(shimmy_append_line_list "$TEST_RUNNER_GROUPS_SELECTED" "$2")
        shift 2
        ;;
      --jobs)
        [ "$#" -ge 2 ] || fail_test "missing value for --jobs"
        [ "$test_runner_jobs_seen" -eq 0 ] || fail_test "duplicate --jobs option"
        case "$2" in 1|2|3) ;; *) fail_test "--jobs must be an integer from 1 to 3" ;; esac
        TEST_RUNNER_JOBS=$2
        test_runner_jobs_seen=1
        shift 2
        ;;
      --serial)
        [ "$test_runner_serial_seen" -eq 0 ] || fail_test "duplicate --serial option"
        TEST_RUNNER_JOBS=1
        test_runner_serial_seen=1
        shift
        ;;
      --list-groups)
        [ "$test_runner_list_seen" -eq 0 ] || fail_test "duplicate --list-groups option"
        TEST_RUNNER_LIST_GROUPS=1
        test_runner_list_seen=1
        shift
        ;;
      -h|--help)
        test_runner_usage
        exit 0
        ;;
      *)
        fail_test "unknown argument: $1"
        ;;
    esac
  done

  if [ "$test_runner_jobs_seen" -eq 1 ] && [ "$test_runner_serial_seen" -eq 1 ]; then
    fail_test "--serial cannot be combined with --jobs"
  fi
  if [ "$TEST_RUNNER_LIST_GROUPS" -eq 1 ] &&
    { [ -n "$TEST_RUNNER_GROUPS_SELECTED" ] || [ "$test_runner_jobs_seen" -eq 1 ] || [ "$test_runner_serial_seen" -eq 1 ]; }; then
    fail_test "--list-groups cannot be combined with execution options"
  fi
}

test_runner_group_list() {
  while IFS='|' read -r test_runner_group_name test_runner_group_function; do
    printf '%s\n' "$test_runner_group_name"
  done <<EOF
$(test_runner_group_registry_read)
EOF
}

test_runner_usage() {
  cat <<'EOF'
Run the Shimmy source test suite.

Usage:
  ./tests/test.sh [--serial | --jobs <1-3>] [--group <name>]...
  ./tests/test.sh --list-groups

Options:
  --group <name>      Run one named group; repeat to select more groups.
  --jobs <1-3>        Accept a bounded worker count; execution remains serial.
  --serial            Run with one worker.
  --list-groups       List groups in canonical execution order without setup.
  -h, --help          Show this help.
EOF
}

test_runner_now() {
  date +%s
}

test_runner_timing_record() {
  test_runner_timing_scope=$1
  test_runner_timing_name=$2
  test_runner_timing_elapsed=$3

  [ "${SHIMMY_TEST_TIMING:-0}" = 1 ] || return 0
  printf 'shimmy_test_timing=%s|%s|%s\n' \
    "$test_runner_timing_scope" "$test_runner_timing_name" "$test_runner_timing_elapsed"
}

test_runner_commands_lifecycle_run() {
  test_commands_lifecycle_prepare
  test_commands_lifecycle_complete
}

test_runner_groups_run() {
  while IFS='|' read -r test_runner_group_name test_runner_group_function; do
    test_runner_group_selected "$test_runner_group_name" || continue
    test_runner_group_started=$(test_runner_now)
    "$test_runner_group_function"
    test_runner_group_finished=$(test_runner_now)
    test_runner_timing_record group "$test_runner_group_name" \
      "$((test_runner_group_finished - test_runner_group_started))"
  done <<EOF
$(test_runner_group_registry_read)
EOF
}
