#!/bin/sh
# Profile activation state-machine tests using a purpose-built Podman seam.

profile_activation_fake_create() {
  fake_path=$1
  {
    printf '%s\n' '#!/bin/sh' 'set -eu'
    printf '%s\n' 'printf "%s\n" "$*" >> "$FAKE_PODMAN_LOG"'
    printf '%s\n' \
      'fake_fail_requested() {' \
      '  requested_action=$1' \
      '  requested_machine=${2:-}' \
      '  [ "${FAKE_FAIL_ACTION:-}" = "$requested_action" ] || return 1' \
      '  [ -z "${FAKE_FAIL_MACHINE:-}" ] || [ "$FAKE_FAIL_MACHINE" = "$requested_machine" ] || return 1' \
      '  if [ -n "${FAKE_FAIL_ONCE_FILE:-}" ]; then' \
      '    [ ! -e "$FAKE_FAIL_ONCE_FILE" ] || return 1' \
      '    : > "$FAKE_FAIL_ONCE_FILE"' \
      '  fi' \
      '  return 0' \
      '}'
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
      '    if [ -n "${FAKE_FAIL_LINUX_TARGET:-}" ] && [ -L "${FAKE_ACTIVE_LINK:-}" ] && [ "$(readlink "$FAKE_ACTIVE_LINK")" = "$FAKE_FAIL_LINUX_TARGET" ]; then exit 50; fi' \
      '    if [ -n "${FAKE_FAIL_LINUX_CONFIG_PATTERN:-}" ] && [ -f "${FAKE_ACTIVE_CONFIG:-}" ]; then case "$(cat "$FAKE_ACTIVE_CONFIG")" in *"$FAKE_FAIL_LINUX_CONFIG_PATTERN"*) exit 51 ;; esac; fi' \
      "    printf '%s\\n' \"\${FAKE_LINUX_INFO:-true|false}\"" \
      '    ;;' \
      '  "machine ssh "*)' \
      '    if [ "${3:-}" = --username ]; then' \
      '      machine_name=${5:-}' \
      '      action=${9:-}' \
      '      case "$action" in' \
      '        inspect)' \
      '          [ "${FAKE_FAIL_ACTION:-}" != projection_inspect ] || exit 52' \
      "          printf '%s\\n' \"\${FAKE_DARWIN_PROJECTION_STATE:-current}\"" \
      '          ;;' \
      '        apply)' \
      '          fake_fail_requested projection_rollback "$machine_name" && exit 58' \
      '          [ "${FAKE_FAIL_ACTION:-}" != projection_apply ] || exit 53' \
      '          if [ -n "${FAKE_DARWIN_APPLY_RESULT:-}" ]; then printf "%s\n" "$FAKE_DARWIN_APPLY_RESULT"; else case "${FAKE_DARWIN_PROJECTION_STATE:-current}" in absent) printf "%s\n" changed ;; current) printf "%s\n" unchanged ;; *) exit 54 ;; esac; fi' \
      '          ;;' \
      '        detach|rollback)' \
      '          fake_fail_requested projection_detach "$machine_name" && exit 59' \
      '          printf "%s\n" detached' \
      '          ;;' \
      '        *) exit 91 ;;' \
      '      esac' \
      '    else' \
      '      action=${7:-}' \
      '      target=${8:-}' \
      '      case "$action" in' \
      '        source) [ "${FAKE_FAIL_ACTION:-}" != projection_source ] || exit 56 ;;' \
      '        projection) [ "${FAKE_FAIL_ACTION:-}" != projection_validation ] || exit 57 ;;' \
      '        *) exit 92 ;;' \
      '      esac' \
      '      if [ -n "${FAKE_DARWIN_PROJECTION_FINGERPRINT:-}" ]; then' \
      '        printf "%s\n" "$FAKE_DARWIN_PROJECTION_FINGERPRINT"' \
      '      else' \
      '        set -- $(cksum < "$target")' \
      '        printf "%s-%s\n" "$1" "$2"' \
      '      fi' \
      '    fi' \
      '    ;;' \
      '  "machine stop "*)' \
      '    machine_name=${3:-}' \
      '    fake_fail_requested machine_stop "$machine_name" && exit 60' \
      '    if [ "${FAKE_FAIL_ACTION:-}" = stop ] && [ "$machine_name" = "${FAKE_PRIOR_MACHINE:-}" ]; then exit 44; fi' \
      '    if [ "${FAKE_ROLLBACK_FAIL:-}" = target_cleanup ] && [ "$machine_name" = "${FAKE_TARGET_MACHINE:-}" ]; then exit 45; fi' \
      '    ;;' \
      '  "machine start "*)' \
      '    machine_name=${3:-${2:-}}' \
      '    fake_fail_requested machine_start "$machine_name" && exit 61' \
      '    if [ "${FAKE_FAIL_ACTION:-}" = target_start ] && [ "$machine_name" = "${FAKE_TARGET_MACHINE:-}" ]; then exit 46; fi' \
      '    if [ "${FAKE_ROLLBACK_FAIL:-}" = prior_restart ] && [ "$machine_name" = "${FAKE_PRIOR_MACHINE:-}" ]; then exit 47; fi' \
      '    ;;' \
      '  "system connection default "*)' \
      '    connection_name=${4:-${3:-}}' \
      '    fake_fail_requested default_restore "$connection_name" && exit 62' \
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
    FAKE_DARWIN_PROJECTION_STATE="${FAKE_DARWIN_PROJECTION_STATE:-current}" \
    FAKE_DARWIN_PROJECTION_FINGERPRINT="${FAKE_DARWIN_PROJECTION_FINGERPRINT:-}" \
    FAKE_DARWIN_RECORD_STATE="${FAKE_DARWIN_RECORD_STATE:-valid}" \
    FAKE_ACTIVE_LINK="${FAKE_ACTIVE_LINK:-}" FAKE_ACTIVE_CONFIG="${FAKE_ACTIVE_CONFIG:-}" \
    FAKE_FAIL_LINUX_TARGET="${FAKE_FAIL_LINUX_TARGET:-}" FAKE_FAIL_LINUX_CONFIG_PATTERN="${FAKE_FAIL_LINUX_CONFIG_PATTERN:-}" \
    FAKE_FAIL_ACTION="${FAKE_FAIL_ACTION:-}" FAKE_ROLLBACK_FAIL="${FAKE_ROLLBACK_FAIL:-}" FAKE_PRIOR_MACHINE="${FAKE_PRIOR_MACHINE:-}" \
    FAKE_FAIL_MACHINE="${FAKE_FAIL_MACHINE:-}" FAKE_FAIL_ONCE_FILE="${FAKE_FAIL_ONCE_FILE:-}" \
    FAKE_TARGET_MACHINE="${FAKE_TARGET_MACHINE:-}" FAKE_PRIOR_DEFAULT="${FAKE_PRIOR_DEFAULT:-}" \
    /bin/sh -c '
      set -eu
      . "$1/lib/common/common.sh"
      . "$1/lib/profile/profile.sh"
      . "$1/lib/profile/activation.sh"
      . "$1/lib/registries/registries.sh"
      shimmy_profile_paths_resolve "$SHIMMY_TEST_PROFILE_NAME"
      mkdir -p "$SHIMMY_PROFILE_ROOT"
      if [ ! -e "$SHIMMY_PROFILE_REGISTRIES_PATH" ] && [ ! -L "$SHIMMY_PROFILE_REGISTRIES_PATH" ]; then
        shimmy_registries_config_render "$SHIMMY_PROFILE_NAME" "" > "$SHIMMY_PROFILE_REGISTRIES_PATH"
        chmod 0644 "$SHIMMY_PROFILE_REGISTRIES_PATH"
      fi
      if [ "$SHIMMY_TEST_PROFILE_OS" = Darwin ]; then
        projection_fingerprint=$(shimmy_registries_config_fingerprint_render "$SHIMMY_PROFILE_REGISTRIES_PATH")
        case "$FAKE_DARWIN_RECORD_STATE" in
          valid) shimmy_registries_machine_projection_record_render "$SHIMMY_PROFILE_NAME" "$projection_fingerprint" > "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
          stale) shimmy_registries_machine_projection_record_render "$SHIMMY_PROFILE_NAME" 0-0 > "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
          invalid) printf "%s\n" invalid > "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
          absent) rm -f "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
        esac
        [ ! -f "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ] || chmod 0644 "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
      fi
      SHIMMY_PROFILE_ACTIVATION_LOCK_HELD=0
      SHIMMY_REGISTRIES_LOCK_HELD=0
      trap "shimmy_registries_lock_release; shimmy_profile_activation_lock_release" EXIT
      if [ "$FAKE_FAIL_ACTION" = projection_record ]; then
        shimmy_registries_machine_projection_record_apply() { return 1; }
      fi
      case "$SHIMMY_TEST_PROFILE_ACTION" in
        recommendation)
          shimmy_profile_state_read
          shimmy_profile_activation_recommendation_resolve
          printf "activation_label=%s\naction=%s\naction_label=%s\naction_command=%s\n" \
            "$SHIMMY_PROFILE_ACTIVATION_LABEL" "$SHIMMY_PROFILE_RECOMMENDED_ACTION" \
            "$SHIMMY_PROFILE_RECOMMENDED_ACTION_LABEL" "$SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND"
          ;;
        status) shimmy_profile_status_print manifest ;;
        activate) shimmy_profile_activate "$2" "$3" "$4" ;;
      esac
    ' sh "$ROOT_DIR" "$@"
}

test_lib_profile_activation_linux_registry_projection() {
  setup_scenario
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  FAKE_LINUX_INFO='true|false'
  FAKE_ACTIVE_LINK=$XDG_CONFIG_HOME_DIR/containers/registries.conf.d/shimmy-active-profile.conf
  FAKE_ACTIVE_CONFIG=$XDG_CONFIG_HOME_DIR/shimmy/profiles/default/registries.conf
  FAKE_FAIL_LINUX_TARGET=
  FAKE_FAIL_LINUX_CONFIG_PATTERN=

  dry_run_output=$(profile_activation_library_run default Linux activate 0 0 1)
  assert_contains "$dry_run_output" "would_link=$FAKE_ACTIVE_LINK"
  assert_path_not_exists "$FAKE_ACTIVE_LINK"

  activation_output=$(profile_activation_library_run default Linux activate 0 0 0)
  assert_contains "$activation_output" 'Activated Shimmy profile default registry policy'
  assert_path_symlink "$FAKE_ACTIVE_LINK"
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$FAKE_ACTIVE_CONFIG"
  profile_activation_library_run default Linux activate 0 0 0 >/dev/null
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$FAKE_ACTIVE_CONFIG"
  status_output=$(profile_activation_library_run default Linux status)
  assert_contains "$status_output" 'activation=active'

  profile_activation_library_run upstream Linux status >/dev/null
  upstream_config=$XDG_CONFIG_HOME_DIR/shimmy/profiles/upstream/registries.conf
  profile_activation_library_run upstream Linux activate 0 0 0 >/dev/null
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$upstream_config"

  FAKE_FAIL_LINUX_TARGET=$FAKE_ACTIVE_CONFIG
  set +e
  rollback_output=$(profile_activation_library_run default Linux activate 0 0 0 2>&1)
  rollback_status=$?
  set -e
  [ "$rollback_status" -ne 0 ] || fail_test 'failed Linux validation unexpectedly committed an active link'
  assert_contains "$rollback_output" 'prior active profile restored'
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$upstream_config"
  FAKE_FAIL_LINUX_TARGET=

  secret_registry_path=$SCENARIO_DIR/secret-registry-path
  export CONTAINERS_REGISTRIES_CONF=$secret_registry_path
  set +e
  override_output=$(profile_activation_library_run default Linux activate 0 0 0 2>&1)
  override_status=$?
  set -e
  unset CONTAINERS_REGISTRIES_CONF
  [ "$override_status" -ne 0 ] || fail_test 'masking registry override unexpectedly allowed Linux activation'
  assert_contains "$override_output" 'CONTAINERS_REGISTRIES_CONF masks Shimmy registry activation'
  assert_not_contains "$override_output" "$secret_registry_path"
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$upstream_config"

  export CONTAINERS_REGISTRIES_CONF_OVERRIDE=$secret_registry_path
  set +e
  override_output=$(profile_activation_library_run default Linux activate 0 0 0 2>&1)
  override_status=$?
  set -e
  unset CONTAINERS_REGISTRIES_CONF_OVERRIDE
  [ "$override_status" -ne 0 ] || fail_test 'masking registry override file unexpectedly allowed Linux activation'
  assert_contains "$override_output" 'CONTAINERS_REGISTRIES_CONF_OVERRIDE masks Shimmy registry activation'
  assert_not_contains "$override_output" "$secret_registry_path"
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$upstream_config"

  rm -f "$FAKE_ACTIVE_LINK"
  printf '%s\n' foreign > "$FAKE_ACTIVE_LINK"
  set +e
  collision_output=$(profile_activation_library_run default Linux activate 0 0 0 2>&1)
  collision_status=$?
  set -e
  [ "$collision_status" -ne 0 ] || fail_test 'foreign Linux activation file unexpectedly replaced'
  assert_contains "$collision_output" 'invalid or foreign registry path'
  assert_file_contains "$FAKE_ACTIVE_LINK" foreign

  rm -f "$FAKE_ACTIVE_LINK"
  mkdir "$FAKE_ACTIVE_LINK"
  if profile_activation_library_run default Linux activate 0 0 0 >/dev/null 2>&1; then
    fail_test 'foreign Linux activation directory unexpectedly replaced'
  fi
  assert_dir_exists "$FAKE_ACTIVE_LINK"
  rmdir "$FAKE_ACTIVE_LINK"

  ln -s "$SCENARIO_DIR/missing-registry-config" "$FAKE_ACTIVE_LINK"
  if profile_activation_library_run default Linux activate 0 0 0 >/dev/null 2>&1; then
    fail_test 'dangling Linux activation link unexpectedly replaced'
  fi
  assert_path_symlink "$FAKE_ACTIVE_LINK"
  rm -f "$FAKE_ACTIVE_LINK"

  printf '%s\n' foreign > "$SCENARIO_DIR/foreign-registry-config"
  ln -s "$SCENARIO_DIR/foreign-registry-config" "$FAKE_ACTIVE_LINK"
  if profile_activation_library_run default Linux activate 0 0 0 >/dev/null 2>&1; then
    fail_test 'unrecognized Linux activation target unexpectedly replaced'
  fi
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$SCENARIO_DIR/foreign-registry-config"
  rm -f "$FAKE_ACTIVE_LINK"

  rmdir "$(dirname "$FAKE_ACTIVE_LINK")"
  mv "$XDG_CONFIG_HOME_DIR/containers" "$XDG_CONFIG_HOME_DIR/containers-real"
  ln -s "$XDG_CONFIG_HOME_DIR/containers-real" "$XDG_CONFIG_HOME_DIR/containers"
  if profile_activation_library_run default Linux activate 0 0 0 >/dev/null 2>&1; then
    fail_test 'symlinked Linux registry parent unexpectedly accepted'
  fi
  assert_path_symlink "$XDG_CONFIG_HOME_DIR/containers"
  pass 'Linux activation creates, switches, validates, rolls back, and refuses masked, foreign, dangling, or unsafe registry state'
}

test_lib_profile_activation_darwin_registry_projection() {
  setup_scenario
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  FAKE_MACHINE_LIST='shimmy-default|false'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_WORKLOADS=
  FAKE_PRIOR_MACHINE=
  FAKE_TARGET_MACHINE=shimmy-default
  FAKE_PRIOR_DEFAULT=shimmy-default
  FAKE_DARWIN_PROJECTION_STATE=absent
  FAKE_DARWIN_PROJECTION_FINGERPRINT=
  FAKE_DARWIN_RECORD_STATE=absent
  FAKE_FAIL_ACTION=
  FAKE_ROLLBACK_FAIL=

  activation_output=$(profile_activation_library_run default Darwin activate 0 0 0)
  assert_contains "$activation_output" 'Activated Shimmy profile default'
  record_path=$XDG_CONFIG_HOME_DIR/shimmy/profiles/default/machine-projection.txt
  assert_regular_file_not_symlink "$record_path"
  assert_file_mode "$record_path" 644
  shimmy_registries_machine_projection_record_validate "$record_path" default ||
    fail_test 'first Darwin activation did not create a valid projection record'
  source_line=$(sed -n '/^machine ssh shimmy-default \/bin\/sh -s -- source /=' "$FAKE_PODMAN_LOG")
  apply_line=$(sed -n '/^machine ssh --username root shimmy-default \/bin\/sh -s -- apply /=' "$FAKE_PODMAN_LOG")
  projection_line=$(sed -n '/^machine ssh shimmy-default \/bin\/sh -s -- projection /=' "$FAKE_PODMAN_LOG")
  info_line=$(sed -n '/^--connection shimmy-default info /=' "$FAKE_PODMAN_LOG" | tail -n 1)
  [ "$source_line" -lt "$apply_line" ] && [ "$apply_line" -lt "$projection_line" ] &&
    [ "$projection_line" -lt "$info_line" ] ||
    fail_test 'Darwin projection did not validate same-path source, root-write the link, rootless-validate it, then validate the engine'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'cp '

  FAKE_MACHINE_LIST='shimmy-default|true'
  FAKE_DARWIN_PROJECTION_STATE=current
  FAKE_DARWIN_RECORD_STATE=stale
  : > "$FAKE_PODMAN_LOG"
  set +e
  stale_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1)
  stale_status=$?
  set -e
  [ "$stale_status" -ne 0 ] || fail_test 'stale running Darwin projection unexpectedly passed ordinary activation'
  assert_contains "$stale_output" "'$XDG_CONFIG_HOME_DIR/shimmy/profiles/default/bin/shimmy' profile activate --restart"
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop'

  : > "$FAKE_PODMAN_LOG"
  profile_activation_library_run default Darwin activate 1 0 0 >/dev/null
  updated_fingerprint=$(sed -n 's/^config_fingerprint=//p' "$record_path")
  expected_fingerprint=$(shimmy_registries_config_fingerprint_render "$XDG_CONFIG_HOME_DIR/shimmy/profiles/default/registries.conf")
  assert_equals "$updated_fingerprint" "$expected_fingerprint"
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop shimmy-default'

  for failure_action in projection_source projection_apply projection_validation projection_record; do
    : > "$FAKE_PODMAN_LOG"
    FAKE_MACHINE_LIST='shimmy-default|false'
    FAKE_DARWIN_PROJECTION_STATE=absent
    FAKE_DARWIN_RECORD_STATE=absent
    FAKE_FAIL_ACTION=$failure_action
    set +e
    failure_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1)
    failure_status=$?
    set -e
    [ "$failure_status" -ne 0 ] || fail_test "Darwin projection failure unexpectedly succeeded: $failure_action"
    case "$failure_action" in
      projection_validation|projection_record)
        assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh --username root shimmy-default /bin/sh -s -- rollback'
        ;;
      *)
        assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh --username root shimmy-default /bin/sh -s -- rollback'
        ;;
    esac
    assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop shimmy-default'
    assert_path_not_exists "$record_path"
  done

  : > "$FAKE_PODMAN_LOG"
  FAKE_MACHINE_LIST='shimmy-default|false'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
other|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_PRIOR_DEFAULT=other
  FAKE_FAIL_ACTION=default_commit
  FAKE_DARWIN_PROJECTION_STATE=absent
  FAKE_DARWIN_RECORD_STATE=absent
  set +e
  commit_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1)
  commit_status=$?
  set -e
  [ "$commit_status" -ne 0 ] || fail_test 'Darwin default-connection failure unexpectedly retained projection state'
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh --username root shimmy-default /bin/sh -s -- rollback'
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'system connection default other'
  assert_path_not_exists "$record_path"

  : > "$FAKE_PODMAN_LOG"
  FAKE_FAIL_ACTION=
  FAKE_PRIOR_DEFAULT=shimmy-default
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_DARWIN_PROJECTION_STATE=foreign
  FAKE_DARWIN_RECORD_STATE=absent
  set +e
  collision_output=$(profile_activation_library_run default Darwin activate 0 0 0 2>&1)
  collision_status=$?
  set -e
  [ "$collision_status" -ne 0 ] || fail_test 'foreign Darwin projection unexpectedly replaced'
  assert_contains "$collision_output" 'foreign or invalid Darwin registry projection'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" ' /bin/sh -s -- apply '
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop shimmy-default'
  pass 'Darwin activation projects before engine validation, records freshness, requires restart, and rolls back every projection boundary'
}

test_lib_profile_activation_mapping_and_status() {
  setup_scenario
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  FAKE_DARWIN_PROJECTION_STATE=current
  FAKE_DARWIN_PROJECTION_FINGERPRINT=
  FAKE_DARWIN_RECORD_STATE=valid

  FAKE_MACHINE_LIST='shimmy-default|false'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  status_output=$(profile_activation_library_run default Darwin status)
  assert_contains "$status_output" 'expected_engine=shimmy-default'
  assert_contains "$status_output" 'activation=stopped'

  FAKE_MACHINE_LIST='shimmy-default|true'
  status_output=$(profile_activation_library_run default Darwin status)
  assert_contains "$status_output" 'activation=active'

  FAKE_DARWIN_PROJECTION_FINGERPRINT=0-0
  status_output=$(profile_activation_library_run default Darwin status)
  assert_contains "$status_output" 'activation=registry_restart_required'
  FAKE_DARWIN_PROJECTION_FINGERPRINT=

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

test_lib_profile_activation_recommendations() {
  setup_scenario
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_DARWIN_PROJECTION_STATE=current
  FAKE_DARWIN_PROJECTION_FINGERPRINT=
  FAKE_DARWIN_RECORD_STATE=valid
  FAKE_FAIL_ACTION=

  FAKE_MACHINE_LIST='shimmy-default|true'
  recommendation_output=$(profile_activation_library_run default Darwin recommendation)
  assert_contains "$recommendation_output" 'activation_label=active'
  assert_contains "$recommendation_output" 'action=none'

  FAKE_MACHINE_LIST='shimmy-default|false'
  recommendation_output=$(profile_activation_library_run default Darwin recommendation)
  assert_contains "$recommendation_output" 'action=profile_activate'
  assert_contains "$recommendation_output" "action_command='$XDG_CONFIG_HOME_DIR/shimmy/profiles/default/bin/shimmy' profile activate"

  FAKE_MACHINE_LIST='shimmy-default|true'
  FAKE_DARWIN_PROJECTION_FINGERPRINT=0-0
  recommendation_output=$(profile_activation_library_run default Darwin recommendation)
  assert_contains "$recommendation_output" 'activation_label=registry restart required'
  assert_contains "$recommendation_output" 'action=profile_activate_restart'
  assert_contains "$recommendation_output" "action_command='$XDG_CONFIG_HOME_DIR/shimmy/profiles/default/bin/shimmy' profile activate --restart"
  FAKE_DARWIN_PROJECTION_FINGERPRINT=

  FAKE_MACHINE_LIST='podman-machine-default|true'
  FAKE_CONNECTION_LIST='podman-machine-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  recommendation_output=$(profile_activation_library_run default Darwin recommendation)
  assert_contains "$recommendation_output" 'action=podman_machine_init'
  assert_contains "$recommendation_output" 'action_command=podman machine init shimmy-default'

  export CONTAINER_HOST='ssh://secret@example.invalid/run/user/1/podman/podman.sock'
  recommendation_output=$(profile_activation_library_run default Darwin recommendation)
  unset CONTAINER_HOST
  assert_contains "$recommendation_output" 'action=unset_override'
  assert_contains "$recommendation_output" 'action_command=unset CONTAINER_HOST'
  assert_not_contains "$recommendation_output" 'secret@example.invalid'

  export CONTAINERS_REGISTRIES_CONF="$SCENARIO_DIR/secret-registries.conf"
  recommendation_output=$(profile_activation_library_run default Darwin recommendation)
  unset CONTAINERS_REGISTRIES_CONF
  assert_contains "$recommendation_output" 'action=unset_override'
  assert_contains "$recommendation_output" 'action_command=unset CONTAINERS_REGISTRIES_CONF'
  assert_not_contains "$recommendation_output" "$SCENARIO_DIR/secret-registries.conf"

  FAKE_MACHINE_LIST='shimmy-default|true'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_FAIL_ACTION=target_validation
  recommendation_output=$(profile_activation_library_run default Darwin recommendation)
  assert_contains "$recommendation_output" 'action=investigate'
  assert_contains "$recommendation_output" 'action_command='

  recommendation_log=$(cat "$FAKE_PODMAN_LOG")
  assert_not_contains "$recommendation_log" 'machine stop '
  assert_not_contains "$recommendation_log" 'machine start '
  assert_not_contains "$recommendation_log" 'system connection default '
  assert_not_contains "$recommendation_log" ' /bin/sh -s -- apply '
  pass 'profile activation recommendations map resolved states conservatively without Podman mutation'
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
  FAKE_DARWIN_PROJECTION_STATE=current
  FAKE_DARWIN_PROJECTION_FINGERPRINT=
  FAKE_DARWIN_RECORD_STATE=valid

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
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/containers/registries.conf.d/shimmy-active-profile.conf"
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
  FAKE_DARWIN_PROJECTION_STATE=current
  FAKE_DARWIN_PROJECTION_FINGERPRINT=
  FAKE_DARWIN_RECORD_STATE=valid

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
  projection_line=$(sed -n '/^machine ssh shimmy-default \/bin\/sh -s -- projection /=' "$FAKE_PODMAN_LOG" | tail -n 1)
  default_line=$(sed -n '/^system connection default shimmy-default$/=' "$FAKE_PODMAN_LOG")
  [ "$stop_line" -lt "$start_line" ] && [ "$start_line" -lt "$projection_line" ] &&
    [ "$projection_line" -lt "$validate_line" ] && [ "$validate_line" -lt "$default_line" ] ||
    fail_test "activation did not project policy before engine validation and commit the default connection last"

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
  FAKE_DARWIN_PROJECTION_STATE=current
  FAKE_DARWIN_PROJECTION_FINGERPRINT=
  FAKE_DARWIN_RECORD_STATE=valid

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
  test_lib_profile_activation_recommendations
  test_lib_profile_activation_linux_registry_projection
  test_lib_profile_activation_darwin_registry_projection
  test_lib_profile_activation_idempotence_and_rejections
  test_lib_profile_activation_switch_and_guard
  test_lib_profile_activation_rollback
}
