#!/bin/sh
# Profile activation state-machine tests using a purpose-built Podman seam.

profile_activation_fake_create() {
  fake_path=$1
  {
    printf '%s\n' '#!/bin/sh' 'set -eu'
    printf '%s\n' 'printf "%s\n" "$*" >> "$FAKE_PODMAN_LOG"'
    printf '%s\n' 'case "$*" in'
    printf '%s\n' \
      "  \"machine list --format {{.Name}}|{{.Running}}\") printf '%s\\n' \"\${FAKE_MACHINE_LIST:-}\" ;;" \
      "  \"system connection list --format {{.Name}}|{{.URI}}|{{.Default}}\") printf '%s\\n' \"\${FAKE_CONNECTION_LIST:-}\" ;;" \
      '  "--connection "*" ps --format {{.ID}}|{{.Names}}")' \
      '    [ "${FAKE_FAIL_ACTION:-}" != workload ] || exit 42' \
      "    printf '%s\\n' \"\${FAKE_WORKLOADS:-}\"" \
      '    ;;' \
      '  "--connection "*" info --format {{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}")' \
      '    [ "${FAKE_FAIL_ACTION:-}" != target_validation ] || exit 43' \
      "    printf '%s\\n' \"\${FAKE_DARWIN_INFO:-true|true}\"" \
      '    ;;' \
      '  "info --format {{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}")' \
      "    printf '%s\\n' \"\${FAKE_LINUX_INFO:-true|false}\"" \
      '    ;;' \
      '  "machine stop "*)' \
      '    machine_name=${3:-}' \
      '    if [ "${FAKE_FAIL_ACTION:-}" = stop ] && [ "$machine_name" = "${FAKE_PRIOR_MACHINE:-}" ]; then exit 44; fi' \
      '    if [ "${FAKE_ROLLBACK_FAIL:-}" = target_cleanup ] && [ "$machine_name" = "${FAKE_TARGET_MACHINE:-}" ]; then exit 45; fi' \
      '    ;;' \
      '  "machine start "*)' \
      '    machine_name=${3:-${2:-}}' \
      '    if [ "${FAKE_FAIL_ACTION:-}" = target_start ] && [ "$machine_name" = "${FAKE_TARGET_MACHINE:-}" ]; then exit 46; fi' \
      '    if [ "${FAKE_ROLLBACK_FAIL:-}" = prior_restart ] && [ "$machine_name" = "${FAKE_PRIOR_MACHINE:-}" ]; then exit 47; fi' \
      '    ;;' \
      '  "system connection default "*)' \
      '    connection_name=${4:-${3:-}}' \
      '    if [ "${FAKE_FAIL_ACTION:-}" = default_commit ] && [ "$connection_name" = "${FAKE_TARGET_MACHINE:-}" ]; then exit 48; fi' \
      '    if [ "${FAKE_ROLLBACK_FAIL:-}" = default_restore ] && [ "$connection_name" = "${FAKE_PRIOR_DEFAULT:-}" ]; then exit 49; fi' \
      '    ;;' \
      '  *) printf "unexpected fake Podman command: %s\n" "$*" >&2; exit 90 ;;' \
      'esac'
  } > "$fake_path"
  chmod 755 "$fake_path"
}

profile_activation_library_run() {
  profile_name=$1
  host_os=$2
  action=$3
  shift 3
  env SHIMMY_TEST_PROFILE_OS="$host_os" SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    SHIMMY_TEST_PROFILE_NAME="$profile_name" SHIMMY_TEST_PROFILE_ACTION="$action" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST="${FAKE_MACHINE_LIST:-}" \
    FAKE_CONNECTION_LIST="${FAKE_CONNECTION_LIST:-}" FAKE_WORKLOADS="${FAKE_WORKLOADS:-}" \
    FAKE_DARWIN_INFO="${FAKE_DARWIN_INFO:-true|true}" FAKE_LINUX_INFO="${FAKE_LINUX_INFO:-true|false}" \
    FAKE_FAIL_ACTION="${FAKE_FAIL_ACTION:-}" FAKE_ROLLBACK_FAIL="${FAKE_ROLLBACK_FAIL:-}" FAKE_PRIOR_MACHINE="${FAKE_PRIOR_MACHINE:-}" \
    FAKE_TARGET_MACHINE="${FAKE_TARGET_MACHINE:-}" FAKE_PRIOR_DEFAULT="${FAKE_PRIOR_DEFAULT:-}" \
    /bin/sh -c '
      set -eu
      . "$1/lib/common/common.sh"
      . "$1/lib/profile/profile.sh"
      . "$1/lib/profile/activation.sh"
      SHIMMY_PROFILE_NAME=$SHIMMY_TEST_PROFILE_NAME
      SHIMMY_CONFIG_ROOT=$XDG_CONFIG_HOME/shimmy
      SHIMMY_PROFILE_ROOT=$SHIMMY_CONFIG_ROOT/profiles/$SHIMMY_PROFILE_NAME
      mkdir -p "$SHIMMY_CONFIG_ROOT"
      SHIMMY_PROFILE_ACTIVATION_LOCK_HELD=0
      trap shimmy_profile_activation_lock_release EXIT
      case "$SHIMMY_TEST_PROFILE_ACTION" in
        status) shimmy_profile_status_print manifest ;;
        activate) shimmy_profile_activate "$2" "$3" "$4" ;;
      esac
    ' sh "$ROOT_DIR" "$@"
}

test_lib_profile_activation_mapping_and_status() {
  setup_scenario
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"

  FAKE_MACHINE_LIST='shimmy-default|false'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  status_output=$(profile_activation_library_run default Darwin status)
  assert_contains "$status_output" 'expected_engine=shimmy-default'
  assert_contains "$status_output" 'activation=stopped'

  FAKE_MACHINE_LIST='shimmy-default|true'
  status_output=$(profile_activation_library_run default Darwin status)
  assert_contains "$status_output" 'activation=active'

  FAKE_FAIL_ACTION=target_validation
  status_output=$(profile_activation_library_run default Darwin status)
  assert_contains "$status_output" 'activation=unreachable'
  FAKE_FAIL_ACTION=

  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
other|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  status_output=$(profile_activation_library_run default Darwin status)
  assert_contains "$status_output" 'activation=mismatched_default'

  FAKE_MACHINE_LIST='shimmy-default|true
other|true'
  status_output=$(profile_activation_library_run default Darwin status)
  assert_contains "$status_output" 'activation=invalid_metadata'

  FAKE_MACHINE_LIST='shimmy-default|false
other|true'
  status_output=$(profile_activation_library_run default Darwin status)
  assert_contains "$status_output" 'alternate_running_machine=other'
  assert_contains "$status_output" 'activation=alternate_running'

  FAKE_MACHINE_LIST='podman-machine-default|true'
  FAKE_CONNECTION_LIST='podman-machine-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  status_output=$(profile_activation_library_run upstream Darwin status)
  assert_contains "$status_output" 'expected_engine=shimmy-upstream'
  assert_contains "$status_output" 'machine_state=missing'
  assert_contains "$status_output" 'activation=unavailable'

  FAKE_LINUX_INFO='true|false'
  status_output=$(profile_activation_library_run default Linux status)
  assert_contains "$status_output" 'engine_type=local_rootless'
  assert_contains "$status_output" 'expected_connection=not_applicable'
  assert_contains "$status_output" 'activation=ready'
  pass "profile state maps only canonical profiles and classifies Darwin missing/stopped plus Linux readiness"
}

test_lib_profile_activation_idempotence_and_rejections() {
  setup_scenario
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  FAKE_MACHINE_LIST='shimmy-default|true'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_WORKLOADS=
  FAKE_PRIOR_MACHINE=shimmy-default
  FAKE_TARGET_MACHINE=shimmy-default
  FAKE_PRIOR_DEFAULT=shimmy-default
  FAKE_FAIL_ACTION=
  FAKE_ROLLBACK_FAIL=

  export CONTAINER_CONNECTION='secret-connection-value'
  set +e
  override_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1)
  override_status=$?
  set -e
  unset CONTAINER_CONNECTION
  [ "$override_status" -ne 0 ] || fail_test "connection override unexpectedly allowed activation"
  assert_contains "$override_output" 'CONTAINER_CONNECTION overrides Podman profile activation'
  assert_not_contains "$override_output" 'secret-connection-value'

  activation_output=$(profile_activation_library_run default Darwin activate 0 0 0)
  assert_contains "$activation_output" 'Activated Shimmy profile default'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop'

  set +e
  irrelevant_output=$(profile_activation_library_run default Darwin activate 0 1 0 2>&1)
  irrelevant_status=$?
  set -e
  [ "$irrelevant_status" -ne 0 ] || fail_test "irrelevant --stop-running unexpectedly succeeded"
  assert_contains "$irrelevant_output" 'valid only when activation will stop'

  FAKE_WORKLOADS='abc123|restart-blocker'
  set +e
  restart_output=$(profile_activation_library_run default Darwin activate 1 0 0 2>&1)
  restart_status=$?
  set -e
  [ "$restart_status" -ne 0 ] || fail_test "restart unexpectedly ignored running workloads"
  assert_contains "$restart_output" 'restart-blocker'

  FAKE_MACHINE_LIST='shimmy-default|false
other|true'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
other|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_WORKLOADS=
  FAKE_FAIL_ACTION=workload
  set +e
  inspection_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1)
  inspection_status=$?
  set -e
  [ "$inspection_status" -ne 0 ] || fail_test "uninspectable running machine unexpectedly stopped"
  assert_contains "$inspection_output" 'unable to inspect running workloads'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop other'
  FAKE_FAIL_ACTION=

  mkdir -p "$XDG_CONFIG_HOME_DIR/shimmy/.profile-activation.lock"
  set +e
  lock_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1)
  lock_status=$?
  set -e
  [ "$lock_status" -ne 0 ] || fail_test "concurrent activation lock unexpectedly succeeded"
  assert_contains "$lock_output" 'another Shimmy profile activation holds'
  rmdir "$XDG_CONFIG_HOME_DIR/shimmy/.profile-activation.lock"

  FAKE_MACHINE_LIST='podman-machine-default|true'
  FAKE_CONNECTION_LIST='podman-machine-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  set +e
  missing_output=$(profile_activation_library_run default Darwin activate 0 0 1 2>&1)
  missing_status=$?
  set -e
  [ "$missing_status" -ne 0 ] || fail_test "missing deterministic machine unexpectedly succeeded"
  assert_contains "$missing_output" 'podman machine init shimmy-default'
  assert_contains "$missing_output" 'does not adopt, rename, migrate, or remove podman-machine-default'

  FAKE_LINUX_INFO='true|true'
  set +e
  linux_output=$(profile_activation_library_run default Linux activate 0 0 0 2>&1)
  linux_status=$?
  set -e
  [ "$linux_status" -ne 0 ] || fail_test "remote Linux engine unexpectedly succeeded"
  assert_contains "$linux_output" 'local rootless Podman engine'
  pass "activation is idempotent and rejects irrelevant acknowledgements, guarded restarts, locks, missing machines, and remote Linux"
}

test_lib_profile_activation_switch_and_guard() {
  setup_scenario
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  FAKE_MACHINE_LIST='shimmy-upstream|true
shimmy-default|false'
  FAKE_CONNECTION_LIST='shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'
  FAKE_WORKLOADS=
  FAKE_PRIOR_MACHINE=shimmy-upstream
  FAKE_TARGET_MACHINE=shimmy-default
  FAKE_PRIOR_DEFAULT=shimmy-upstream
  FAKE_FAIL_ACTION=

  activation_output=$(profile_activation_library_run default Darwin activate 0 0 0)
  assert_contains "$activation_output" 'Stopping Podman machine: shimmy-upstream'
  assert_contains "$activation_output" 'Starting Podman machine: shimmy-default'
  command_log=$(cat "$FAKE_PODMAN_LOG")
  assert_contains "$command_log" 'machine stop shimmy-upstream'
  assert_contains "$command_log" 'machine start shimmy-default'
  assert_contains "$command_log" 'system connection default shimmy-default'
  stop_line=$(sed -n '/^machine stop shimmy-upstream$/=' "$FAKE_PODMAN_LOG")
  start_line=$(sed -n '/^machine start shimmy-default$/=' "$FAKE_PODMAN_LOG")
  validate_line=$(sed -n '/^--connection shimmy-default info /=' "$FAKE_PODMAN_LOG" | tail -n 1)
  default_line=$(sed -n '/^system connection default shimmy-default$/=' "$FAKE_PODMAN_LOG")
  [ "$stop_line" -lt "$start_line" ] && [ "$start_line" -lt "$validate_line" ] && [ "$validate_line" -lt "$default_line" ] ||
    fail_test "activation did not commit the default connection last"

  : > "$FAKE_PODMAN_LOG"
  FAKE_WORKLOADS='abc123|important'
  set +e
  guard_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1)
  guard_status=$?
  set -e
  [ "$guard_status" -ne 0 ] || fail_test "running workload unexpectedly allowed an unacknowledged switch"
  assert_contains "$guard_output" 'abc123|important'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop'

  dry_run_output=$(profile_activation_library_run default Darwin activate 0 1 1)
  assert_contains "$dry_run_output" 'would_stop=shimmy-upstream'
  assert_contains "$dry_run_output" 'would_start=shimmy-default'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop'
  pass "Darwin switching inspects workloads and commits the global default only after target validation"
}

test_lib_profile_activation_rollback() {
  setup_scenario
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  FAKE_MACHINE_LIST='shimmy-upstream|true
shimmy-default|false'
  FAKE_CONNECTION_LIST='shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'
  FAKE_WORKLOADS=
  FAKE_PRIOR_MACHINE=shimmy-upstream
  FAKE_TARGET_MACHINE=shimmy-default
  FAKE_PRIOR_DEFAULT=shimmy-upstream

  FAKE_ROLLBACK_FAIL=
  for failure_action in stop target_start target_validation default_commit; do
    : > "$FAKE_PODMAN_LOG"
    FAKE_FAIL_ACTION=$failure_action
    set +e
    failure_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1)
    failure_status=$?
    set -e
    [ "$failure_status" -ne 0 ] || fail_test "failure injection unexpectedly succeeded: $failure_action"
    assert_contains "$failure_output" 'Rollback:'
    assert_contains "$FAKE_CONNECTION_LIST" shimmy-upstream
  done

  for rollback_failure in target_cleanup prior_restart default_restore; do
    : > "$FAKE_PODMAN_LOG"
    FAKE_FAIL_ACTION=default_commit
    FAKE_ROLLBACK_FAIL=$rollback_failure
    failure_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1 || true)
    assert_contains "$failure_output" 'Rollback result: incomplete'
    assert_contains "$failure_output" 'failed'
  done

  FAKE_FAIL_ACTION=default_commit
  FAKE_ROLLBACK_FAIL=
  FAKE_WORKLOADS='abc123|important'
  failure_output=$(profile_activation_library_run default Darwin activate 0 1 0 2>&1 || true)
  assert_contains "$failure_output" 'acknowledged running workloads may not have resumed'
  assert_contains "$failure_output" 'Rollback result: incomplete'
  pass "activation failure boundaries report target cleanup, prior restart, default restoration, and workload uncertainty"
}

test_lib_profile_activation_run() {
  test_lib_profile_activation_mapping_and_status
  test_lib_profile_activation_idempotence_and_rejections
  test_lib_profile_activation_switch_and_guard
  test_lib_profile_activation_rollback
}
