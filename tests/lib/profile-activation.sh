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
      '  "machine list --format {{.Name}}|{{.Running}}")' \
      '    printf "%s\n" "${FAKE_MACHINE_LIST:-}"' \
      '    if [ -n "${FAKE_MACHINE_STATE_DIR:-}" ] && [ -d "$FAKE_MACHINE_STATE_DIR" ]; then for state_file in "$FAKE_MACHINE_STATE_DIR"/*; do [ -f "$state_file" ] || continue; state=$(cat "$state_file"); [ "$state" = absent ] || { [ "$state" = running ] && running=true || running=false; printf "%s|%s\n" "$(basename "$state_file")" "$running"; }; done; fi' \
      '    if [ -n "${FAKE_CREATED_MACHINE_STATE_FILE:-}" ] && [ -f "$FAKE_CREATED_MACHINE_STATE_FILE" ]; then state=$(cat "$FAKE_CREATED_MACHINE_STATE_FILE"); [ "$state" = absent ] || { [ "$state" = running ] && running=true || running=false; printf "%s|%s\n" "${FAKE_CREATED_MACHINE_NAME:-shimmy}" "$running"; }; fi' \
      '    ;;' \
      '  "machine list --format {{.Name}}|{{.VMType}}|{{.Running}}")' \
      '    printf "%s\n" "${FAKE_MACHINE_LIST:-}" | awk -F "|" '\''NF == 2 { print $1 "|applehv|" $2 } NF == 3 { print }'\''' \
      '    if [ -n "${FAKE_MACHINE_STATE_DIR:-}" ] && [ -d "$FAKE_MACHINE_STATE_DIR" ]; then for state_file in "$FAKE_MACHINE_STATE_DIR"/*; do [ -f "$state_file" ] || continue; state=$(cat "$state_file"); [ "$state" = absent ] || { [ "$state" = running ] && running=true || running=false; printf "%s|applehv|%s\n" "$(basename "$state_file")" "$running"; }; done; fi' \
      '    if [ -n "${FAKE_CREATED_MACHINE_STATE_FILE:-}" ] && [ -f "$FAKE_CREATED_MACHINE_STATE_FILE" ]; then state=$(cat "$FAKE_CREATED_MACHINE_STATE_FILE"); [ "$state" = absent ] || { [ "$state" = running ] && running=true || running=false; printf "%s|applehv|%s\n" "${FAKE_CREATED_MACHINE_NAME:-shimmy}" "$running"; }; fi' \
      '    ;;' \
      '  "system connection list --format {{.Name}}|{{.URI}}|{{.Default}}")' \
      '    printf "%s\n" "${FAKE_CONNECTION_LIST:-}"' \
      '    if [ -n "${FAKE_MACHINE_STATE_DIR:-}" ] && [ -d "$FAKE_MACHINE_STATE_DIR" ]; then for state_file in "$FAKE_MACHINE_STATE_DIR"/*; do [ -f "$state_file" ] || continue; [ "$(cat "$state_file")" = absent ] || printf "%s|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false\n" "$(basename "$state_file")"; done; fi' \
      '    if [ -n "${FAKE_CREATED_MACHINE_STATE_FILE:-}" ] && [ -f "$FAKE_CREATED_MACHINE_STATE_FILE" ] && [ "$(cat "$FAKE_CREATED_MACHINE_STATE_FILE")" != absent ]; then printf "%s|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false\n" "${FAKE_CREATED_MACHINE_NAME:-shimmy}"; fi' \
      '    ;;' \
      '  "system connection list --format {{.Name}}|{{.URI}}|{{.Identity}}|{{.Default}}")' \
      '    printf "%s\n" "${FAKE_CONNECTION_LIST:-}" | awk -F "|" -v identity="${FAKE_ENGINE_IDENTITY_PATH:-/tmp/shimmy-fake-identity}" '\''NF == 3 { print $1 "|" $2 "|" identity "|" $3 } NF == 4 { print }'\''' \
      '    if [ -n "${FAKE_MACHINE_STATE_DIR:-}" ] && [ -d "$FAKE_MACHINE_STATE_DIR" ]; then for state_file in "$FAKE_MACHINE_STATE_DIR"/*; do [ -f "$state_file" ] || continue; [ "$(cat "$state_file")" = absent ] || { machine_name=$(basename "$state_file"); identity=${FAKE_ENGINE_IDENTITY_PATH:-/tmp/shimmy-fake-identity}; [ -z "${FAKE_MACHINE_METADATA_DIR:-}" ] || [ ! -f "$FAKE_MACHINE_METADATA_DIR/$machine_name" ] || identity=$(sed -n "3p" "$FAKE_MACHINE_METADATA_DIR/$machine_name"); printf "%s|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|%s|false\n" "$machine_name" "$identity"; }; done; fi' \
      '    if [ -n "${FAKE_CREATED_MACHINE_STATE_FILE:-}" ] && [ -f "$FAKE_CREATED_MACHINE_STATE_FILE" ] && [ "$(cat "$FAKE_CREATED_MACHINE_STATE_FILE")" != absent ]; then printf "%s|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|%s|false\n" "${FAKE_CREATED_MACHINE_NAME:-shimmy}" "${FAKE_ENGINE_IDENTITY_PATH:-/tmp/shimmy-fake-identity}"; fi' \
      '    ;;' \
      '  "machine init "*)' \
      '    [ -n "${FAKE_CREATED_MACHINE_STATE_FILE:-}" ] || exit 95' \
      '    fake_fail_requested machine_init "${FAKE_CREATED_MACHINE_NAME:-shimmy}" && exit 65' \
      '    printf "%s\n" stopped > "$FAKE_CREATED_MACHINE_STATE_FILE"' \
      '    fake_fail_requested machine_init_after_create "${FAKE_CREATED_MACHINE_NAME:-shimmy}" && exit 65' \
      '    :' \
      '    ;;' \
      '  "machine inspect --format "*)' \
      '    name=${6:-${5:-shimmy}}' \
      '    config_dir=${FAKE_ENGINE_CONFIG_DIR:-/tmp/shimmy-fake-config}; socket_path=${FAKE_ENGINE_SOCKET_PATH:-/tmp/shimmy-fake-socket}; identity_path=${FAKE_ENGINE_IDENTITY_PATH:-/tmp/shimmy-fake-identity}' \
      '    if [ -n "${FAKE_MACHINE_METADATA_DIR:-}" ] && [ -f "$FAKE_MACHINE_METADATA_DIR/$name" ]; then config_dir=$(sed -n "1p" "$FAKE_MACHINE_METADATA_DIR/$name"); socket_path=$(sed -n "2p" "$FAKE_MACHINE_METADATA_DIR/$name"); identity_path=$(sed -n "3p" "$FAKE_MACHINE_METADATA_DIR/$name"); fi' \
      '    printf "%s|2026-08-23 00:00:00 +0000 UTC|%s|%s|%s|core|false\n" "$name" "$config_dir" "$socket_path" "$identity_path"' \
      '    ;;' \
      '  "--connection "*" ps --format {{.ID}}|{{.Names}}")' \
      '    [ "${FAKE_FAIL_ACTION:-}" != workload ] || exit 42' \
      "    printf '%s\\n' \"\${FAKE_WORKLOADS:-}\"" \
      '    ;;' \
      '  "--connection "*" info --format {{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}")' \
      '    [ "${FAKE_FAIL_ACTION:-}" != test_validation ] || exit 43' \
      "    printf '%s\\n' \"\${FAKE_DARWIN_INFO:-true|true}\"" \
      '    ;;' \
      '  "--connection "*" info --format "*"index .Registries"*)' \
      '    template=${5:-}' \
      '    prefix=${template#*index .Registries \"}' \
      '    prefix=${prefix%%\"*}' \
      '    awk '\''/^\[\[registry\]\]$/ { if (p != "") print p "|" l; p=""; l=""; next } /^prefix = "/ { v=$0; sub(/^prefix = "/,"",v); sub(/"$/,"",v); p=v; next } /^location = "/ { v=$0; sub(/^location = "/,"",v); sub(/"$/,"",v); l=v; next } END { if (p != "") print p "|" l }'\'' "${FAKE_ENGINE_PROJECTION_CONFIG:?}" | awk -F "|" -v prefix="$prefix" '\''$1 == prefix { print }'\''' \
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
      '      if [ "${4:-}" = systemctl ]; then' \
      '        case "$*" in *" show --property MainPID --value podman.service") if [ -n "${FAKE_SERVICE_PID_FILE:-}" ]; then cat "$FAKE_SERVICE_PID_FILE"; else printf "%s\n" "${FAKE_SERVICE_PID:-800}"; fi ;; *" is-active podman.socket") printf "%s\n" active ;; *" stop podman.service") if [ -n "${FAKE_SERVICE_PID_FILE:-}" ]; then pid=$(cat "$FAKE_SERVICE_PID_FILE"); printf "%s\n" "$((pid + 1))" > "$FAKE_SERVICE_PID_FILE"; fi ;; *) exit 96 ;; esac' \
      '        exit 0' \
      '      fi' \
      '      action=${7:-}' \
      '      target=${8:-}' \
      '      case "$action" in' \
      '        write) printf "%s\n" written; exit 0 ;;' \
      '        verify) case "$target" in shared|profile-*) printf "%s\n" matched ;; *) printf "%s\n" current ;; esac; exit 0 ;;' \
      '        install) printf "%s\n" installed; exit 0 ;;' \
      '        remove) printf "%s\n" removed; exit 0 ;;' \
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
      '    if [ "${FAKE_ROLLBACK_FAIL:-}" = test_cleanup ] && [ "$machine_name" = "${FAKE_TARGET_MACHINE:-}" ]; then exit 45; fi' \
      '    if [ -n "${FAKE_CREATED_MACHINE_STATE_FILE:-}" ] && [ "$machine_name" = "${FAKE_CREATED_MACHINE_NAME:-shimmy}" ]; then printf "%s\n" stopped > "$FAKE_CREATED_MACHINE_STATE_FILE"; fi' \
      '    if [ -n "${FAKE_MACHINE_STATE_DIR:-}" ] && [ -f "$FAKE_MACHINE_STATE_DIR/$machine_name" ]; then printf "%s\n" stopped > "$FAKE_MACHINE_STATE_DIR/$machine_name"; fi' \
      '    ;;' \
      '  "machine start "*)' \
      '    machine_name=${3:-${2:-}}' \
      '    fake_fail_requested machine_start "$machine_name" && exit 61' \
      '    if [ "${FAKE_FAIL_ACTION:-}" = test_start ] && [ "$machine_name" = "${FAKE_TARGET_MACHINE:-}" ]; then exit 46; fi' \
      '    if [ "${FAKE_ROLLBACK_FAIL:-}" = prior_restart ] && [ "$machine_name" = "${FAKE_PRIOR_MACHINE:-}" ]; then exit 47; fi' \
      '    if [ -n "${FAKE_CREATED_MACHINE_STATE_FILE:-}" ] && [ "$machine_name" = "${FAKE_CREATED_MACHINE_NAME:-shimmy}" ]; then printf "%s\n" running > "$FAKE_CREATED_MACHINE_STATE_FILE"; fi' \
      '    if [ -n "${FAKE_MACHINE_STATE_DIR:-}" ] && [ -f "$FAKE_MACHINE_STATE_DIR/$machine_name" ]; then printf "%s\n" running > "$FAKE_MACHINE_STATE_DIR/$machine_name"; fi' \
      '    ;;' \
      '  "machine rm --force "*)' \
      '    machine_name=${4:-}' \
      '    fake_fail_requested machine_rm "$machine_name" && exit 63' \
      '    [ "${FAKE_ROLLBACK_FAIL:-}" != machine_rm ] || exit 64' \
      '    if [ -n "${FAKE_CREATED_MACHINE_STATE_FILE:-}" ] && [ "$machine_name" = "${FAKE_CREATED_MACHINE_NAME:-shimmy}" ]; then printf "%s\n" absent > "$FAKE_CREATED_MACHINE_STATE_FILE"; fi' \
      '    if [ -n "${FAKE_MACHINE_STATE_DIR:-}" ] && [ -f "$FAKE_MACHINE_STATE_DIR/$machine_name" ]; then printf "%s\n" absent > "$FAKE_MACHINE_STATE_DIR/$machine_name"; fi' \
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

test_lib_profile_activation_fake_machine_init_contract() {
  setup_scenario
  fake_podman=$SCENARIO_DIR/podman
  fake_log=$SCENARIO_DIR/podman.log
  fake_state=$SCENARIO_DIR/machine-state
  profile_activation_fake_create "$fake_podman"
  : > "$fake_log"

  printf '%s\n' absent > "$fake_state"
  env FAKE_PODMAN_LOG="$fake_log" FAKE_CREATED_MACHINE_STATE_FILE="$fake_state" \
    FAKE_CREATED_MACHINE_NAME=shimmy-contract "$fake_podman" machine init shimmy-contract
  assert_equals "$(cat "$fake_state")" stopped

  printf '%s\n' absent > "$fake_state"
  set +e
  env FAKE_PODMAN_LOG="$fake_log" FAKE_CREATED_MACHINE_STATE_FILE="$fake_state" \
    FAKE_CREATED_MACHINE_NAME=shimmy-contract FAKE_FAIL_ACTION=machine_init \
    "$fake_podman" machine init shimmy-contract
  fake_pre_status=$?
  set -e
  assert_equals "$fake_pre_status" 65
  assert_equals "$(cat "$fake_state")" absent

  set +e
  env FAKE_PODMAN_LOG="$fake_log" FAKE_CREATED_MACHINE_STATE_FILE="$fake_state" \
    FAKE_CREATED_MACHINE_NAME=shimmy-contract FAKE_FAIL_ACTION=machine_init_after_create \
    "$fake_podman" machine init shimmy-contract
  fake_post_status=$?
  set -e
  assert_equals "$fake_post_status" 65
  assert_equals "$(cat "$fake_state")" stopped

  pass 'generated fake Podman init distinguishes success, pre-mutation failure, and post-create failure'
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
    FAKE_SERVICE_PID_FILE="${FAKE_SERVICE_PID_FILE:-}" \
    FAKE_ENGINE_PROJECTION_CONFIG="${FAKE_ENGINE_PROJECTION_CONFIG:-}" \
    FAKE_ENGINE_CONFIG_DIR="${FAKE_ENGINE_CONFIG_DIR:-}" \
    FAKE_ENGINE_SOCKET_PATH="${FAKE_ENGINE_SOCKET_PATH:-}" \
    FAKE_ENGINE_IDENTITY_PATH="${FAKE_ENGINE_IDENTITY_PATH:-}" \
    FAKE_DARWIN_RECORD_STATE="${FAKE_DARWIN_RECORD_STATE:-valid}" \
    FAKE_ACTIVE_LINK="${FAKE_ACTIVE_LINK:-}" FAKE_ACTIVE_CONFIG="${FAKE_ACTIVE_CONFIG:-}" \
    FAKE_FAIL_LINUX_TARGET="${FAKE_FAIL_LINUX_TARGET:-}" FAKE_FAIL_LINUX_CONFIG_PATTERN="${FAKE_FAIL_LINUX_CONFIG_PATTERN:-}" \
    FAKE_FAIL_ACTION="${FAKE_FAIL_ACTION:-}" FAKE_ROLLBACK_FAIL="${FAKE_ROLLBACK_FAIL:-}" FAKE_PRIOR_MACHINE="${FAKE_PRIOR_MACHINE:-}" \
    FAKE_FAIL_MACHINE="${FAKE_FAIL_MACHINE:-}" FAKE_FAIL_ONCE_FILE="${FAKE_FAIL_ONCE_FILE:-}" \
    FAKE_TARGET_MACHINE="${FAKE_TARGET_MACHINE:-}" FAKE_PRIOR_DEFAULT="${FAKE_PRIOR_DEFAULT:-}" \
    /bin/sh -c '
      set -eu
      . "$1/lib/common/common.sh"
      . "$1/lib/engine/state.sh"
      . "$1/lib/engine/podman.sh"
      . "$1/lib/engine/ownership.sh"
      . "$1/lib/engine/lifecycle.sh"
      . "$1/lib/engine/projection.sh"
      . "$1/lib/engine/registry.sh"
      . "$1/lib/profile/profile.sh"
      . "$1/lib/profile/activation.sh"
      . "$1/lib/registries/registries.sh"
      shimmy_profile_paths_resolve "$SHIMMY_TEST_PROFILE_NAME"
      mkdir -p "$SHIMMY_PROFILE_ROOT"
      if [ "$SHIMMY_TEST_PROFILE_OS" = Linux ]; then
        shimmy_engine_paths_resolve "$SHIMMY_CONFIG_ROOT" shared
        mkdir -p "$SHIMMY_ENGINE_ROOT"
        if [ ! -e "$SHIMMY_ENGINE_RECORD_PATH" ]; then
          shimmy_engine_record_write "$SHIMMY_ENGINE_RECORD_PATH" shared linux-rootless \
            installation local local none host-local "" ""
        fi
        shimmy_engine_binding_write "$SHIMMY_PROFILE_ENGINE_BINDING_PATH" \
          "$SHIMMY_PROFILE_NAME" shared shared
      fi
      if [ ! -e "$SHIMMY_PROFILE_REGISTRIES_PATH" ] && [ ! -L "$SHIMMY_PROFILE_REGISTRIES_PATH" ]; then
        shimmy_registries_config_render "$SHIMMY_PROFILE_NAME" "" > "$SHIMMY_PROFILE_REGISTRIES_PATH"
        chmod 0644 "$SHIMMY_PROFILE_REGISTRIES_PATH"
      fi
      SHIMMY_PROFILE_ACTIVATION_LOCK_HELD=0
      SHIMMY_REGISTRIES_LOCK_HELD=0
      trap "shimmy_registries_lock_release; shimmy_profile_activation_lock_release" EXIT
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

  profile_activation_library_run team-one Linux status >/dev/null
  sibling_config=$XDG_CONFIG_HOME_DIR/shimmy/profiles/team-one/registries.conf
  profile_activation_library_run team-one Linux activate 0 0 0 >/dev/null
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$sibling_config"

  FAKE_FAIL_LINUX_TARGET=$FAKE_ACTIVE_CONFIG
  set +e
  rollback_output=$(profile_activation_library_run default Linux activate 0 0 0 2>&1)
  rollback_status=$?
  set -e
  [ "$rollback_status" -ne 0 ] || fail_test 'failed Linux validation unexpectedly committed an active link'
  assert_contains "$rollback_output" 'prior active profile restored'
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$sibling_config"
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
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$sibling_config"

  export CONTAINERS_REGISTRIES_CONF_OVERRIDE=$secret_registry_path
  set +e
  override_output=$(profile_activation_library_run default Linux activate 0 0 0 2>&1)
  override_status=$?
  set -e
  unset CONTAINERS_REGISTRIES_CONF_OVERRIDE
  [ "$override_status" -ne 0 ] || fail_test 'masking registry override file unexpectedly allowed Linux activation'
  assert_contains "$override_output" 'CONTAINERS_REGISTRIES_CONF_OVERRIDE masks Shimmy registry activation'
  assert_not_contains "$override_output" "$secret_registry_path"
  assert_equals "$(readlink "$FAKE_ACTIVE_LINK")" "$sibling_config"

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

test_lib_profile_activation_shared_engine() {
  setup_scenario
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  FAKE_MACHINE_LIST='shimmy-default|true'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_WORKLOADS='sentinel|shared-sentinel'
  FAKE_DARWIN_INFO='true|true'
  FAKE_DARWIN_PROJECTION_STATE=current
  FAKE_ENGINE_CONFIG_DIR=/tmp/shimmy-fake-config
  FAKE_ENGINE_SOCKET_PATH=/tmp/shimmy-fake-socket
  FAKE_ENGINE_IDENTITY_PATH=/tmp/shimmy-fake-identity
  FAKE_SERVICE_PID_FILE=$SCENARIO_DIR/service-pid
  FAKE_ENGINE_PROJECTION_CONFIG=$XDG_CONFIG_HOME_DIR/shimmy/engines/shared/registries.conf
  export FAKE_PODMAN_LOG FAKE_MACHINE_LIST FAKE_CONNECTION_LIST
  export FAKE_ENGINE_CONFIG_DIR FAKE_ENGINE_SOCKET_PATH FAKE_ENGINE_IDENTITY_PATH
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  printf '%s\n' 800 > "$FAKE_SERVICE_PID_FILE"

  shared_config=$XDG_CONFIG_HOME_DIR/shimmy
  shared_engine_root=$shared_config/engines/shared
  mkdir -p "$shared_engine_root" "$shared_config/profiles/default" \
    "$shared_config/profiles/team-one"
  shimmy_registries_config_render default '' > "$shared_config/profiles/default/registries.conf"
  shimmy_registries_config_render team-one '' > "$shared_config/profiles/team-one/registries.conf"
  chmod 0644 "$shared_config/profiles/default/registries.conf" \
    "$shared_config/profiles/team-one/registries.conf"
  shimmy_engine_binding_write "$shared_config/profiles/default/engine-binding.conf" \
    default shared shared
  shimmy_engine_binding_write "$shared_config/profiles/team-one/engine-binding.conf" \
    team-one shared shared
  SHIMMY_TEST_ENGINE_PODMAN_BIN=$FAKE_PODMAN_BIN
  shimmy_engine_podman_bin_require
  shared_identity=$(shimmy_engine_podman_machine_identity_fingerprint_render shimmy-default shimmy-default)
  shared_token=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  shimmy_engine_record_write "$shared_engine_root/engine.conf" shared darwin-machine \
    installation shimmy-default shimmy-default applehv shimmy-created "$shared_token" "$shared_identity"
  cp "$shared_config/profiles/default/registries.conf" "$shared_engine_root/registries.conf"
  chmod 0644 "$shared_engine_root/registries.conf"
  shared_source_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$shared_config/profiles/default/registries.conf")
  shared_effective_fingerprint=$(shimmy_engine_projection_effective_fingerprint_render '')
  shimmy_engine_projection_render shared default \
    "$shared_config/profiles/default/registries.conf" "$shared_source_fingerprint" \
    "$shared_effective_fingerprint" "$shared_effective_fingerprint" > \
    "$shared_engine_root/projection.conf"
  chmod 0644 "$shared_engine_root/projection.conf"

  profile_activation_library_run team-one Darwin activate 0 0 0 >/dev/null
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop '
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine start '
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'stop podman.service'

  shimmy_registries_config_render team-one \
    'docker.io|registry.example.invalid/docker' > \
    "$shared_config/profiles/team-one/registries.conf"
  chmod 0644 "$shared_config/profiles/team-one/registries.conf"
  : > "$FAKE_PODMAN_LOG"
  profile_activation_library_run team-one Darwin activate 0 0 0 >/dev/null
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh shimmy-default systemctl --user stop podman.service'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop '
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine start '
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" '--connection shimmy-default info '
  assert_equals "$(cat "$FAKE_SERVICE_PID_FILE")" 801
  pass 'shared activation reuses the VM, skips equal-policy recycle, and applies changed policy through podman.service only'
}

test_lib_profile_activation_run() {
  test_lib_profile_activation_fake_machine_init_contract
  test_lib_profile_activation_linux_registry_projection
  test_lib_profile_activation_shared_engine
}
