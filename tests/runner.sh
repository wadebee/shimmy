#!/bin/sh
# Source-suite group registry, bounded worker orchestration, and timing helpers.

test_runner_group_registry_read() {
  if [ -n "${TEST_RUNNER_GROUP_REGISTRY_OVERRIDE:-}" ]; then
    printf '%s\n' "$TEST_RUNNER_GROUP_REGISTRY_OVERRIDE"
    return 0
  fi

  cat <<'EOF'
runner|test_lib_runner_run
lib-catalog|test_lib_catalog_run
lib-target-codec|test_lib_target_codec_run
lib-target-profile-state|test_lib_target_profile_state_run
lib-target-ai-skill-state|test_lib_target_ai_skill_state_run
lib-target-lock|test_lib_target_lock_run
lib-target-transaction|test_lib_target_transaction_run
lib-target-ai-skill-link|test_lib_target_ai_skill_link_run
lib-target-catalog|test_lib_target_catalog_run
lib-runtime|test_lib_runtime_run
lib-profile-activation|test_lib_profile_activation_run
lib-registries|test_lib_registries_run
lib-update|test_lib_update_run
commands-agent-preflight|test_commands_agent_preflight_run
commands-catalog|test_commands_catalog_run
commands-target-catalog|test_commands_target_catalog_run
commands-target-shim|test_commands_target_shim_run
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
tools-bats|test_tools_bats_run
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

test_runner_group_assignment_read() {
  if [ -n "${TEST_RUNNER_GROUP_ASSIGNMENT_OVERRIDE:-}" ]; then
    printf '%s\n' "$TEST_RUNNER_GROUP_ASSIGNMENT_OVERRIDE"
    return 0
  fi

  # Chunk 6's retained clean serial measurement supplies the weighted
  # assignments. Later fast target-library groups preserve equal worker group
  # counts without claiming a new timing calibration.
  cat <<'EOF'
runner|two-b|three-a
lib-catalog|two-b|three-a
lib-target-codec|two-a|three-a
lib-target-profile-state|two-b|three-b
lib-target-ai-skill-state|two-a|three-c
lib-target-lock|two-b|three-a
lib-target-transaction|two-a|three-c
lib-target-ai-skill-link|two-b|three-c
lib-target-catalog|two-a|three-b
lib-runtime|two-b|three-a
lib-profile-activation|two-a|three-b
lib-registries|two-b|three-c
lib-update|two-a|three-b
commands-agent-preflight|two-a|three-a
commands-catalog|two-a|three-b
commands-target-catalog|two-b|three-c
commands-target-shim|two-a|three-b
commands-images|two-b|three-a
commands-lifecycle|two-a|three-b
commands-management|two-b|three-b
commands-onboarding|two-a|three-a
commands-profiles|two-b|three-a
commands-profile|two-b|three-a
commands-status|two-b|three-c
commands-update|two-b|three-a
commands-startup|two-b|three-c
commands-skills|two-b|three-c
commands-dispatcher|two-b|three-c
commands-netinfo|two-a|three-b
tools-aws|two-a|three-b
tools-bats|two-a|three-b
tools-community-ansible-dev-tools|two-b|three-c
tools-gcloud|two-a|three-b
tools-gdrive|two-b|three-c
tools-gh|two-a|three-b
tools-go|two-a|three-b
tools-jq|two-a|three-b
tools-netcat|two-a|three-b
tools-nmap|two-b|three-c
tools-npx|two-a|three-b
tools-oc|two-a|three-b
tools-opnsense-mcp-read-only|two-a|three-a
tools-opnsense-mcp-admin|two-a|three-a
tools-rg|two-a|three-a
tools-skopeo|two-b|three-c
tools-task|two-a|three-a
tools-terraform|two-a|three-a
tools-tessl|two-b|three-c
tools-textual|two-b|three-c
commands-install|two-b|three-c
commands-test|two-b|three-c
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

test_runner_group_assignment_validate() {
  test_runner_assignment_names_seen=

  while IFS='|' read -r test_runner_assignment_name test_runner_assignment_two test_runner_assignment_three test_runner_assignment_extra; do
    [ -n "$test_runner_assignment_name" ] || fail_test "empty test group name in assignment registry"
    [ -z "$test_runner_assignment_extra" ] || fail_test "invalid test group assignment: $test_runner_assignment_name"
    test_runner_group_exists "$test_runner_assignment_name" ||
      fail_test "assignment references unknown test group: $test_runner_assignment_name"
    case "$test_runner_assignment_two" in
      two-a|two-b) ;;
      *) fail_test "invalid two-worker assignment for test group: $test_runner_assignment_name" ;;
    esac
    case "$test_runner_assignment_three" in
      three-a|three-b|three-c) ;;
      *) fail_test "invalid three-worker assignment for test group: $test_runner_assignment_name" ;;
    esac
    if shimmy_contains_line_list "$test_runner_assignment_names_seen" "$test_runner_assignment_name"; then
      fail_test "duplicate test group assignment: $test_runner_assignment_name"
    fi
    test_runner_assignment_names_seen=$(shimmy_append_line_list \
      "$test_runner_assignment_names_seen" "$test_runner_assignment_name")
  done <<EOF
$(test_runner_group_assignment_read)
EOF

  while IFS='|' read -r test_runner_group_name test_runner_group_function; do
    if ! shimmy_contains_line_list "$test_runner_assignment_names_seen" "$test_runner_group_name"; then
      fail_test "missing assignment for test group: $test_runner_group_name"
    fi
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
  TEST_RUNNER_JOBS=3
  TEST_RUNNER_LIST_GROUPS=0
  test_runner_jobs_seen=0
  test_runner_serial_seen=0
  test_runner_list_seen=0

  test_runner_group_registry_validate
  test_runner_group_assignment_validate

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

test_runner_group_kill() {
  case "${1:-}" in
    -2|-INT|-int|-SIGINT|-sigint)
      fail_test 'kernel-level SIGINT delivery is unsupported inside background test groups; invoke the signal cleanup handler directly and assert status 130'
      ;;
    -n|-s|--signal)
      case "${2:-}" in
        2|INT|int|SIGINT|sigint)
          fail_test 'kernel-level SIGINT delivery is unsupported inside background test groups; invoke the signal cleanup handler directly and assert status 130'
          ;;
      esac
      ;;
  esac
  command kill "$@"
}

test_runner_usage() {
  cat <<'EOF'
Run the Shimmy source test suite.

Usage:
  ./tests/test.sh [--serial | --jobs <1-3>] [--group <name>]...
  ./tests/test.sh --list-groups

Options:
  --group <name>      Run one named group; repeat to select more groups.
  --jobs <1-3>        Run with at most this many workers (default: 3).
  --serial            Run with one worker for immediate failure diagnosis.
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

test_runner_group_worker_resolve() {
  test_runner_worker_group_expected=$1

  if [ "$TEST_RUNNER_JOBS" -eq 1 ]; then
    printf '%s\n' one-a
    return 0
  fi

  while IFS='|' read -r test_runner_assignment_name test_runner_assignment_two test_runner_assignment_three; do
    [ "$test_runner_assignment_name" = "$test_runner_worker_group_expected" ] || continue
    if [ "$TEST_RUNNER_JOBS" -eq 2 ]; then
      printf '%s\n' "$test_runner_assignment_two"
    else
      printf '%s\n' "$test_runner_assignment_three"
    fi
    return 0
  done <<EOF
$(test_runner_group_assignment_read)
EOF

  return 1
}

test_runner_worker_list_resolve() {
  TEST_RUNNER_WORKERS_SELECTED=

  while IFS='|' read -r test_runner_group_name test_runner_group_function; do
    test_runner_group_selected "$test_runner_group_name" || continue
    test_runner_worker_name=$(test_runner_group_worker_resolve "$test_runner_group_name") ||
      fail_test "unable to resolve worker for test group: $test_runner_group_name"
    if ! shimmy_contains_line_list "$TEST_RUNNER_WORKERS_SELECTED" "$test_runner_worker_name"; then
      TEST_RUNNER_WORKERS_SELECTED=$(shimmy_append_line_list \
        "$TEST_RUNNER_WORKERS_SELECTED" "$test_runner_worker_name")
    fi
  done <<EOF
$(test_runner_group_registry_read)
EOF
}

test_runner_output_prepare() {
  TEST_RUNNER_OUTPUT_ROOT=${TEST_RUNNER_OUTPUT_ROOT:-$TMP_ROOT/runner-output}
  [ ! -e "$TEST_RUNNER_OUTPUT_ROOT" ] && [ ! -L "$TEST_RUNNER_OUTPUT_ROOT" ] ||
    fail_test "test runner output path already exists: $TEST_RUNNER_OUTPUT_ROOT"
  mkdir -p "$TEST_RUNNER_OUTPUT_ROOT/groups" "$TEST_RUNNER_OUTPUT_ROOT/workers"
}

test_runner_result_value_read() {
  test_runner_result_file=$1
  test_runner_result_label=$2

  [ -f "$test_runner_result_file" ] && [ ! -L "$test_runner_result_file" ] || {
    printf 'FAIL: missing %s result: %s\n' "$test_runner_result_label" "$test_runner_result_file" >&2
    return 1
  }
  test_runner_result_value=$(cat "$test_runner_result_file")
  case "$test_runner_result_value" in
    ''|*[!0-9]*)
      printf 'FAIL: malformed %s result: %s\n' "$test_runner_result_label" "$test_runner_result_file" >&2
      return 1
      ;;
  esac
  printf '%s\n' "$test_runner_result_value"
}

test_runner_worker_group_signal_handle() {
  test_runner_worker_signal_status=$1
  trap - HUP INT TERM
  if [ -n "${test_runner_group_pid:-}" ] && kill -0 "$test_runner_group_pid" 2>/dev/null; then
    kill -TERM "$test_runner_group_pid" 2>/dev/null || :
    wait "$test_runner_group_pid" 2>/dev/null || :
  fi
  exit "$test_runner_worker_signal_status"
}

test_runner_worker_run() {
  test_runner_worker_name=$1
  test_runner_worker_started=$(test_runner_now)
  test_runner_worker_status=0
  test_runner_worker_count=0
  test_runner_group_pid=
  trap 'test_runner_worker_group_signal_handle 129' HUP
  trap 'test_runner_worker_group_signal_handle 130' INT
  trap 'test_runner_worker_group_signal_handle 143' TERM
  test_runner_worker_groups=$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.groups
  : > "$test_runner_worker_groups"

  while IFS='|' read -r test_runner_group_name test_runner_group_function; do
    test_runner_group_selected "$test_runner_group_name" || continue
    test_runner_group_worker=$(test_runner_group_worker_resolve "$test_runner_group_name") || exit 1
    [ "$test_runner_group_worker" = "$test_runner_worker_name" ] || continue

    printf '%s\n' "$test_runner_group_name" >> "$test_runner_worker_groups"
    test_runner_group_log=$TEST_RUNNER_OUTPUT_ROOT/groups/$test_runner_group_name.log
    test_runner_group_count_file=$TEST_RUNNER_OUTPUT_ROOT/groups/$test_runner_group_name.count
    test_runner_group_status_file=$TEST_RUNNER_OUTPUT_ROOT/groups/$test_runner_group_name.status
    test_runner_group_worker_file=$TEST_RUNNER_OUTPUT_ROOT/groups/$test_runner_group_name.worker
    test_runner_group_started=$(test_runner_now)

    (
      set -e
      TEST_COUNT=0
      kill() { test_runner_group_kill "$@"; }
      "$test_runner_group_function"
      printf '%s\n' "$TEST_COUNT" > "$test_runner_group_count_file"
    ) > "$test_runner_group_log" 2>&1 &
    test_runner_group_pid=$!
    set +e
    wait "$test_runner_group_pid"
    test_runner_group_status=$?
    set -e
    test_runner_group_pid=

    if [ "$test_runner_group_status" -eq 0 ]; then
      test_runner_group_count=$(test_runner_result_value_read \
        "$test_runner_group_count_file" "group count") || exit 1
      test_runner_worker_count=$((test_runner_worker_count + test_runner_group_count))
    else
      test_runner_group_status=$?
      test_runner_worker_status=1
    fi

    test_runner_group_finished=$(test_runner_now)
    test_runner_timing_record group "$test_runner_group_name" \
      "$((test_runner_group_finished - test_runner_group_started))" >> "$test_runner_group_log"
    printf '%s\n' "$test_runner_group_status" > "$test_runner_group_status_file"
    printf '%s\n' "$test_runner_worker_name" > "$test_runner_group_worker_file"
    [ "$test_runner_group_status" -eq 0 ] || break
  done <<EOF
$(test_runner_group_registry_read)
EOF

  test_runner_worker_finished=$(test_runner_now)
  printf '%s\n' "$test_runner_worker_count" > "$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.count"
  printf '%s\n' "$((test_runner_worker_finished - test_runner_worker_started))" > \
    "$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.elapsed"
  printf '%s\n' "$test_runner_worker_status" > "$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.status"
  trap - HUP INT TERM
  exit "$test_runner_worker_status"
}

test_runner_workers_start() {
  TEST_RUNNER_WORKER_PIDS=

  while IFS= read -r test_runner_worker_name; do
    [ -n "$test_runner_worker_name" ] || continue
    (test_runner_worker_run "$test_runner_worker_name") &
    test_runner_worker_pid=$!
    TEST_RUNNER_WORKER_PIDS=$(shimmy_append_line_list "$TEST_RUNNER_WORKER_PIDS" \
      "$test_runner_worker_pid|$test_runner_worker_name")
  done <<EOF
$TEST_RUNNER_WORKERS_SELECTED
EOF
}

test_runner_workers_wait() {
  test_runner_worker_pid_records=$TEST_RUNNER_WORKER_PIDS
  test_runner_worker_pids_remaining=$test_runner_worker_pid_records

  while IFS='|' read -r test_runner_worker_pid test_runner_worker_name; do
    [ -n "$test_runner_worker_pid" ] || continue
    if wait "$test_runner_worker_pid"; then
      test_runner_worker_wait_status=0
    else
      test_runner_worker_wait_status=$?
    fi
    test_runner_worker_pids_next=
    test_runner_worker_pid_found=0
    while IFS= read -r test_runner_worker_pid_record; do
      [ -n "$test_runner_worker_pid_record" ] || continue
      if [ "$test_runner_worker_pid_found" -eq 0 ]; then
        if [ "$test_runner_worker_pid_record" = "$test_runner_worker_pid|$test_runner_worker_name" ]; then
          test_runner_worker_pid_found=1
        fi
        continue
      fi
      test_runner_worker_pids_next=$(shimmy_append_line_list \
        "$test_runner_worker_pids_next" "$test_runner_worker_pid_record")
    done <<EOF
$test_runner_worker_pids_remaining
EOF
    [ "$test_runner_worker_pid_found" -eq 1 ] ||
      fail_test "waited worker PID was not recorded: $test_runner_worker_name"
    test_runner_worker_pids_remaining=$test_runner_worker_pids_next
    TEST_RUNNER_WORKER_PIDS=$test_runner_worker_pids_remaining
    printf '%s\n' "$test_runner_worker_wait_status" > \
      "$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.wait"
  done <<EOF
$test_runner_worker_pid_records
EOF

  TEST_RUNNER_WORKER_PIDS=
}

test_runner_workers_terminate() {
  test_runner_worker_pid_records=${TEST_RUNNER_WORKER_PIDS:-}

  while IFS='|' read -r test_runner_worker_pid test_runner_worker_name; do
    [ -n "$test_runner_worker_pid" ] || continue
    if kill -0 "$test_runner_worker_pid" 2>/dev/null; then
      kill -TERM "$test_runner_worker_pid" 2>/dev/null || :
    fi
  done <<EOF
$test_runner_worker_pid_records
EOF

  while IFS='|' read -r test_runner_worker_pid test_runner_worker_name; do
    [ -n "$test_runner_worker_pid" ] || continue
    wait "$test_runner_worker_pid" 2>/dev/null || :
  done <<EOF
$test_runner_worker_pid_records
EOF

  TEST_RUNNER_WORKER_PIDS=
}

test_runner_signal_handle() {
  test_runner_signal_name=$1
  test_runner_signal_status=$2
  trap - EXIT HUP INT TERM
  test_runner_workers_terminate
  shimmy_test_cleanup
  printf 'FAIL: test suite interrupted by %s\n' "$test_runner_signal_name" >&2
  exit "$test_runner_signal_status"
}

test_runner_logs_replay() {
  test_runner_replay_status=0

  while IFS='|' read -r test_runner_group_name test_runner_group_function; do
    test_runner_group_selected "$test_runner_group_name" || continue
    test_runner_group_log=$TEST_RUNNER_OUTPUT_ROOT/groups/$test_runner_group_name.log
    if [ -f "$test_runner_group_log" ] && [ ! -L "$test_runner_group_log" ]; then
      cat "$test_runner_group_log"
    fi
  done <<EOF
$(test_runner_group_registry_read)
EOF

  return "$test_runner_replay_status"
}

test_runner_results_collect() {
  test_runner_results_status=0
  test_runner_total_count=0

  while IFS= read -r test_runner_worker_name; do
    [ -n "$test_runner_worker_name" ] || continue
    test_runner_worker_expected_groups=
    test_runner_worker_expected_count=0
    test_runner_worker_failed=0

    while IFS='|' read -r test_runner_group_name test_runner_group_function; do
      test_runner_group_selected "$test_runner_group_name" || continue
      test_runner_group_worker=$(test_runner_group_worker_resolve "$test_runner_group_name") || {
        printf 'FAIL: unable to resolve worker for test group: %s\n' "$test_runner_group_name" >&2
        test_runner_results_status=1
        continue
      }
      [ "$test_runner_group_worker" = "$test_runner_worker_name" ] || continue
      test_runner_worker_expected_groups=$(shimmy_append_line_list \
        "$test_runner_worker_expected_groups" "$test_runner_group_name")

      [ "$test_runner_worker_failed" -eq 0 ] || continue

      test_runner_group_log=$TEST_RUNNER_OUTPUT_ROOT/groups/$test_runner_group_name.log
      if [ ! -f "$test_runner_group_log" ] || [ -L "$test_runner_group_log" ]; then
        printf 'FAIL: missing test group log: %s\n' "$test_runner_group_name" >&2
        test_runner_results_status=1
      fi

      test_runner_group_worker_file=$TEST_RUNNER_OUTPUT_ROOT/groups/$test_runner_group_name.worker
      if [ ! -f "$test_runner_group_worker_file" ] || [ -L "$test_runner_group_worker_file" ] ||
        [ "$(cat "$test_runner_group_worker_file" 2>/dev/null)" != "$test_runner_worker_name" ]; then
        printf 'FAIL: missing or invalid worker ownership for test group: %s\n' "$test_runner_group_name" >&2
        test_runner_results_status=1
      fi

      if test_runner_group_status=$(test_runner_result_value_read \
        "$TEST_RUNNER_OUTPUT_ROOT/groups/$test_runner_group_name.status" "group status"); then
        if [ "$test_runner_group_status" -eq 0 ]; then
          if test_runner_group_count=$(test_runner_result_value_read \
            "$TEST_RUNNER_OUTPUT_ROOT/groups/$test_runner_group_name.count" "group count"); then
            test_runner_worker_expected_count=$((test_runner_worker_expected_count + test_runner_group_count))
          else
            test_runner_results_status=1
          fi
        else
          test_runner_worker_failed=1
        fi
      else
        test_runner_results_status=1
      fi
    done <<EOF
$(test_runner_group_registry_read)
EOF

    test_runner_worker_groups_file=$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.groups
    if [ ! -f "$test_runner_worker_groups_file" ] || [ -L "$test_runner_worker_groups_file" ] ||
      [ "$(cat "$test_runner_worker_groups_file" 2>/dev/null)" != "$test_runner_worker_expected_groups" ]; then
      printf 'FAIL: worker group coverage mismatch: %s\n' "$test_runner_worker_name" >&2
      test_runner_results_status=1
    fi

    if test_runner_worker_count=$(test_runner_result_value_read \
      "$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.count" "worker count"); then
      if [ "$test_runner_worker_count" -ne "$test_runner_worker_expected_count" ]; then
        printf 'FAIL: worker count mismatch: %s\n' "$test_runner_worker_name" >&2
        test_runner_results_status=1
      fi
    else
      test_runner_results_status=1
      test_runner_worker_count=0
    fi
    test_runner_result_value_read \
      "$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.elapsed" "worker elapsed" >/dev/null ||
      test_runner_results_status=1

    if test_runner_worker_status=$(test_runner_result_value_read \
      "$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.status" "worker status") &&
      test_runner_worker_wait_status=$(test_runner_result_value_read \
        "$TEST_RUNNER_OUTPUT_ROOT/workers/$test_runner_worker_name.wait" "worker wait status"); then
      if [ "$test_runner_worker_status" -ne "$test_runner_worker_wait_status" ]; then
        printf 'FAIL: worker status mismatch: %s\n' "$test_runner_worker_name" >&2
        test_runner_results_status=1
      fi
      if [ "$test_runner_worker_failed" -eq 0 ] && [ "$test_runner_worker_status" -ne 0 ]; then
        printf 'FAIL: worker failed without a failed group: %s\n' "$test_runner_worker_name" >&2
        test_runner_results_status=1
      fi
      if [ "$test_runner_worker_failed" -eq 1 ] && [ "$test_runner_worker_status" -eq 0 ]; then
        printf 'FAIL: worker passed with a failed group: %s\n' "$test_runner_worker_name" >&2
        test_runner_results_status=1
      fi
      if [ "$test_runner_worker_status" -ne 0 ]; then
        printf 'FAIL: test worker failed: %s\n' "$test_runner_worker_name" >&2
        test_runner_results_status=1
      fi
    else
      test_runner_results_status=1
    fi

    test_runner_total_count=$((test_runner_total_count + test_runner_worker_count))
  done <<EOF
$TEST_RUNNER_WORKERS_SELECTED
EOF

  if [ "$test_runner_results_status" -eq 0 ]; then
    TEST_COUNT=$test_runner_total_count
  fi
  return "$test_runner_results_status"
}

test_runner_groups_run() {
  test_runner_group_assignment_validate
  test_runner_worker_list_resolve
  test_runner_output_prepare
  test_runner_workers_start
  test_runner_workers_wait

  test_runner_run_status=0
  test_runner_logs_replay || test_runner_run_status=1
  test_runner_results_collect || test_runner_run_status=1
  return "$test_runner_run_status"
}
