#!/bin/sh
# Engine schema, ownership, lifecycle, projection, and Podman seam tests.

engine_fake_create() {
  engine_fake_path=$1
  cat > "$engine_fake_path" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$FAKE_ENGINE_LOG"

fake_entries_render() {
  awk '
    /^\[\[registry\]\]$/ {
      if (prefix != "") print prefix "|" location
      prefix = ""; location = ""; next
    }
    /^prefix = "/ { value = $0; sub(/^prefix = "/, "", value); sub(/"$/, "", value); prefix = value; next }
    /^location = "/ { value = $0; sub(/^location = "/, "", value); sub(/"$/, "", value); location = value; next }
    END { if (prefix != "") print prefix "|" location }
  ' "$FAKE_ENGINE_PROJECTION_CONFIG"
}

fake_service_activate() {
  fake_pid=$(cat "$FAKE_ENGINE_SERVICE_PID")
  if [ "$fake_pid" = 0 ]; then
    fake_sequence=$(cat "$FAKE_ENGINE_SERVICE_SEQUENCE")
    fake_sequence=$((fake_sequence + 1))
    printf '%s\n' "$fake_sequence" > "$FAKE_ENGINE_SERVICE_SEQUENCE"
    printf '%s\n' "$fake_sequence" > "$FAKE_ENGINE_SERVICE_PID"
    fake_entries_render > "$FAKE_ENGINE_SERVICE_CACHE"
  fi
}

case "$1|${2:-}" in
  'machine|list')
    fake_state=$(cat "$FAKE_ENGINE_MACHINE_STATE")
    if [ "$fake_state" != absent ]; then
      if [ "$fake_state" = running ]; then fake_running=true; else fake_running=false; fi
      printf '%s|%s|%s\n' "$FAKE_ENGINE_MACHINE_NAME" "$FAKE_ENGINE_PROVIDER" "$fake_running"
    fi
    ;;
  'system|connection')
    case "${3:-}" in
      list)
        fake_default=$(cat "$FAKE_ENGINE_DEFAULT_CONNECTION")
        if [ "$(cat "$FAKE_ENGINE_MACHINE_STATE")" != absent ]; then
          [ "$fake_default" = "$FAKE_ENGINE_CONNECTION" ] && fake_is_default=true || fake_is_default=false
          printf '%s|%s|%s|%s\n' "$FAKE_ENGINE_CONNECTION" "$(cat "$FAKE_ENGINE_CONNECTION_URI")" "$FAKE_ENGINE_IDENTITY_PATH" "$fake_is_default"
          printf '%s-root|ssh://root@127.0.0.1/run/podman/podman.sock|%s|false\n' "$FAKE_ENGINE_CONNECTION" "$FAKE_ENGINE_IDENTITY_PATH"
        fi
        [ "$fake_default" = other ] && fake_other_default=true || fake_other_default=false
        printf 'other|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|%s|%s\n' "$FAKE_ENGINE_IDENTITY_PATH" "$fake_other_default"
        ;;
      default)
        printf '%s\n' "$4" > "$FAKE_ENGINE_DEFAULT_CONNECTION"
        ;;
      *) exit 90 ;;
    esac
    ;;
  'machine|inspect')
    [ "$(cat "$FAKE_ENGINE_MACHINE_STATE")" != absent ]
    printf '%s|%s|%s|%s|%s|core|false\n' "$FAKE_ENGINE_MACHINE_NAME" \
      "$(cat "$FAKE_ENGINE_CREATED")" "$FAKE_ENGINE_CONFIG_DIR" \
      "$FAKE_ENGINE_SOCKET_PATH" "$FAKE_ENGINE_IDENTITY_PATH"
    ;;
  'machine|init')
    [ "${FAKE_ENGINE_FAIL_ACTION:-}" != machine-init ] || exit 51
    [ "$(cat "$FAKE_ENGINE_MACHINE_STATE")" = absent ]
    printf '%s\n' stopped > "$FAKE_ENGINE_MACHINE_STATE"
    if [ "${FAKE_ENGINE_INIT_CHANGES_DEFAULT:-0}" -eq 1 ]; then
      printf '%s\n' "$FAKE_ENGINE_CONNECTION" > "$FAKE_ENGINE_DEFAULT_CONNECTION"
    fi
    ;;
  'machine|start')
    [ "${FAKE_ENGINE_FAIL_ACTION:-}" != machine-start ] || exit 52
    printf '%s\n' running > "$FAKE_ENGINE_MACHINE_STATE"
    ;;
  'machine|stop')
    [ "${FAKE_ENGINE_FAIL_ACTION:-}" != machine-stop ] || exit 53
    printf '%s\n' stopped > "$FAKE_ENGINE_MACHINE_STATE"
    ;;
  'machine|rm')
    [ "${FAKE_ENGINE_FAIL_ACTION:-}" != machine-rm ] || exit 54
    printf '%s\n' absent > "$FAKE_ENGINE_MACHINE_STATE"
    ;;
  'machine|ssh')
    if [ "${4:-}" = /bin/sh ]; then
      fake_action=${7:-}
      fake_engine=${8:-}
      fake_name=${9:-}
      fake_token=${10:-}
      case "$fake_action" in
        write)
          [ "${FAKE_ENGINE_FAIL_ACTION:-}" != marker-write ] || exit 55
          printf '%s|%s|%s\n' "$fake_engine" "$fake_name" "$fake_token" > "$FAKE_ENGINE_GUEST_MARKER"
          printf '%s\n' written
          ;;
        verify)
          [ "${FAKE_ENGINE_FAIL_ACTION:-}" != marker-verify ] || exit 56
          [ -f "$FAKE_ENGINE_GUEST_MARKER" ]
          [ "$(cat "$FAKE_ENGINE_GUEST_MARKER")" = "$fake_engine|$fake_name|$fake_token" ]
          printf '%s\n' matched
          ;;
        remove)
          [ "$(cat "$FAKE_ENGINE_GUEST_MARKER")" = "$fake_engine|$fake_name|$fake_token" ]
          rm -f "$FAKE_ENGINE_GUEST_MARKER"
          printf '%s\n' removed
          ;;
        *) exit 91 ;;
      esac
    else
      case "${4:-}|${5:-}|${6:-}|${7:-}" in
        'systemctl|--user|is-active|podman.socket') printf '%s\n' active ;;
        'systemctl|--user|stop|podman.service')
          [ "${FAKE_ENGINE_FAIL_ACTION:-}" != service-stop ] || exit 57
          printf '%s\n' 0 > "$FAKE_ENGINE_SERVICE_PID"
          ;;
        'systemctl|--user|show|--property') cat "$FAKE_ENGINE_SERVICE_PID" ;;
        *) exit 92 ;;
      esac
    fi
    ;;
  '--connection|'*)
    [ "$2" = "$FAKE_ENGINE_CONNECTION" ]
    if [ "$3" = ps ]; then
      cat "$FAKE_ENGINE_WORKLOADS"
      exit 0
    fi
    [ "$3" = info ]
    fake_service_activate
    fake_template=${5:-}
    case "$fake_template" in
      '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}') printf '%s\n' 'true|true' ;;
      *'index .Registries "'*)
        fake_prefix=${fake_template#*index .Registries \"}
        fake_prefix=${fake_prefix%%\"*}
        awk -F '|' -v prefix="$fake_prefix" '$1 == prefix { print }' "$FAKE_ENGINE_SERVICE_CACHE"
        ;;
      *) exit 93 ;;
    esac
    ;;
  *) exit 94 ;;
esac
EOF
  chmod 0755 "$engine_fake_path"
}

engine_fake_setup() {
  setup_scenario
  FAKE_ENGINE_ROOT=$SCENARIO_DIR/fake-engine
  mkdir -p "$FAKE_ENGINE_ROOT/config" "$FAKE_ENGINE_ROOT/run" "$FAKE_ENGINE_ROOT/identity"
  FAKE_ENGINE_LOG=$FAKE_ENGINE_ROOT/podman.log
  FAKE_ENGINE_MACHINE_STATE=$FAKE_ENGINE_ROOT/machine-state
  FAKE_ENGINE_DEFAULT_CONNECTION=$FAKE_ENGINE_ROOT/default-connection
  FAKE_ENGINE_CONNECTION_URI=$FAKE_ENGINE_ROOT/connection-uri
  FAKE_ENGINE_CREATED=$FAKE_ENGINE_ROOT/created
  FAKE_ENGINE_GUEST_MARKER=$FAKE_ENGINE_ROOT/guest-marker
  FAKE_ENGINE_SERVICE_PID=$FAKE_ENGINE_ROOT/service-pid
  FAKE_ENGINE_SERVICE_SEQUENCE=$FAKE_ENGINE_ROOT/service-sequence
  FAKE_ENGINE_SERVICE_CACHE=$FAKE_ENGINE_ROOT/service-cache
  FAKE_ENGINE_WORKLOADS=$FAKE_ENGINE_ROOT/workloads
  FAKE_ENGINE_PROJECTION_CONFIG=$FAKE_ENGINE_ROOT/projected-registries.conf
  FAKE_ENGINE_MACHINE_NAME=shimmy-test
  FAKE_ENGINE_CONNECTION=shimmy-test
  FAKE_ENGINE_PROVIDER=applehv
  FAKE_ENGINE_CONFIG_DIR=$FAKE_ENGINE_ROOT/config
  FAKE_ENGINE_SOCKET_PATH=$FAKE_ENGINE_ROOT/run/podman.sock
  FAKE_ENGINE_IDENTITY_PATH=$FAKE_ENGINE_ROOT/identity/machine
  SHIMMY_TEST_ENGINE_PODMAN_BIN=$FAKE_ENGINE_ROOT/podman
  export FAKE_ENGINE_ROOT FAKE_ENGINE_LOG FAKE_ENGINE_MACHINE_STATE
  export FAKE_ENGINE_DEFAULT_CONNECTION FAKE_ENGINE_CONNECTION_URI FAKE_ENGINE_CREATED
  export FAKE_ENGINE_GUEST_MARKER FAKE_ENGINE_SERVICE_PID FAKE_ENGINE_SERVICE_SEQUENCE
  export FAKE_ENGINE_SERVICE_CACHE FAKE_ENGINE_WORKLOADS FAKE_ENGINE_PROJECTION_CONFIG FAKE_ENGINE_MACHINE_NAME
  export FAKE_ENGINE_CONNECTION FAKE_ENGINE_PROVIDER FAKE_ENGINE_CONFIG_DIR
  export FAKE_ENGINE_SOCKET_PATH FAKE_ENGINE_IDENTITY_PATH SHIMMY_TEST_ENGINE_PODMAN_BIN
  : > "$FAKE_ENGINE_LOG"
  : > "$FAKE_ENGINE_SERVICE_CACHE"
  : > "$FAKE_ENGINE_WORKLOADS"
  printf '%s\n' absent > "$FAKE_ENGINE_MACHINE_STATE"
  printf '%s\n' other > "$FAKE_ENGINE_DEFAULT_CONNECTION"
  printf '%s\n' 'ssh://core@127.0.0.1/run/user/1000/podman/podman.sock' > "$FAKE_ENGINE_CONNECTION_URI"
  printf '%s\n' '2026-08-22 12:00:00 +0000 UTC' > "$FAKE_ENGINE_CREATED"
  printf '%s\n' 800 > "$FAKE_ENGINE_SERVICE_PID"
  printf '%s\n' 800 > "$FAKE_ENGINE_SERVICE_SEQUENCE"
  engine_fake_create "$SHIMMY_TEST_ENGINE_PODMAN_BIN"
  shimmy_engine_podman_bin_require
}

test_lib_engine_records() {
  setup_scenario
  engine_root=$SCENARIO_DIR/config/shimmy/engines/shared
  profile_root=$SCENARIO_DIR/config/shimmy/profiles/default
  mkdir -p "$engine_root" "$profile_root"
  token=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  identity=sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  source_path=$profile_root/registries.conf
  source_fingerprint=sha256:1111111111111111111111111111111111111111111111111111111111111111
  effective_fingerprint=sha256:2222222222222222222222222222222222222222222222222222222222222222

  binding_file=$profile_root/engine-binding.conf
  shimmy_engine_binding_render default shared shared > "$binding_file"
  chmod 0644 "$binding_file"
  shimmy_engine_binding_read "$binding_file" || fail_test 'valid shared engine binding rejected'
  assert_equals "$SHIMMY_ENGINE_BINDING_MODE" shared

  record_file=$engine_root/engine.conf
  shimmy_engine_record_render shared darwin-machine installation shimmy-test shimmy-test \
    applehv shimmy-created "$token" "$identity" > "$record_file"
  chmod 0644 "$record_file"
  shimmy_engine_record_read "$record_file" || fail_test 'valid Darwin engine record rejected'
  assert_equals "$SHIMMY_ENGINE_RECORD_ORIGIN" shimmy-created

  sibling_root=$SCENARIO_DIR/config/shimmy/profiles/team-one
  mkdir -p "$sibling_root"
  shimmy_engine_profile_binding_resolve "$SCENARIO_DIR/config/shimmy" default ||
    fail_test 'published shared binding did not resolve through its engine record'
  assert_equals "$SHIMMY_PROFILE_ENGINE_MIGRATION_STATE" migrated
  assert_equals "$SHIMMY_PROFILE_EXPECTED_MACHINE" shimmy-test
  shimmy_engine_profile_binding_resolve "$SCENARIO_DIR/config/shimmy" team-one ||
    fail_test 'unbound profile did not retain its schema-2 compatibility mapping during publication'
  assert_equals "$SHIMMY_PROFILE_ENGINE_MIGRATION_STATE" unmigrated
  assert_equals "$SHIMMY_PROFILE_EXPECTED_MACHINE" shimmy-team-one
  if shimmy_engine_installation_schema_state_read "$SCENARIO_DIR/config/shimmy"; then
    fail_test 'partially published installation engine schema was accepted as authoritative'
  fi
  shimmy_engine_binding_write "$sibling_root/engine-binding.conf" team-one shared shared
  shimmy_engine_installation_schema_state_read "$SCENARIO_DIR/config/shimmy" ||
    fail_test 'complete engine/binding publication was rejected'
  assert_equals "$SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE" migrated
  SHIMMY_ENGINE_REGISTRY_HOST_OS=darwin
  shimmy_engine_registry_migration_journal_write "$SCENARIO_DIR/config/shimmy" \
    'default
team-one'
  shimmy_engine_registry_migration_journal_read "$SCENARIO_DIR/config/shimmy" ||
    fail_test 'valid durable migration journal was rejected'
  assert_equals "$SHIMMY_ENGINE_REGISTRY_MIGRATION_PROFILES" 'default
team-one'
  rm -f "$SCENARIO_DIR/config/shimmy/.engine-migration.conf"

  projection_file=$engine_root/projection.conf
  shimmy_engine_projection_render shared default "$source_path" "$source_fingerprint" \
    "$effective_fingerprint" none > "$projection_file"
  chmod 0644 "$projection_file"
  shimmy_engine_projection_read "$projection_file" || fail_test 'valid engine projection rejected'

  lifecycle_file=$engine_root/lifecycle.conf
  shimmy_engine_lifecycle_render shared create initialized shimmy-test shimmy-test absent \
    "$token" "$identity" > "$lifecycle_file"
  chmod 0644 "$lifecycle_file"
  shimmy_engine_lifecycle_read "$lifecycle_file" || fail_test 'valid engine lifecycle journal rejected'

  for engine_record_case in unknown-field wrong-version wrong-mode symlink unsafe-source; do
    case "$engine_record_case" in
      unknown-field)
        cp "$record_file" "$engine_root/candidate.conf"
        printf '%s\n' extra=value >> "$engine_root/candidate.conf"
        chmod 0644 "$engine_root/candidate.conf"
        if shimmy_engine_record_read "$engine_root/candidate.conf"; then fail_test 'engine record accepted unknown field'; fi
        ;;
      wrong-version)
        sed 's/shimmy_engine_version=1/shimmy_engine_version=2/' "$record_file" > "$engine_root/candidate.conf"
        chmod 0644 "$engine_root/candidate.conf"
        if shimmy_engine_record_read "$engine_root/candidate.conf"; then fail_test 'engine record accepted wrong version'; fi
        ;;
      wrong-mode)
        cp "$record_file" "$engine_root/candidate.conf"
        chmod 0600 "$engine_root/candidate.conf"
        if shimmy_engine_record_read "$engine_root/candidate.conf"; then fail_test 'engine record accepted wrong mode'; fi
        ;;
      symlink)
        rm -f "$engine_root/candidate.conf"
        ln -s "$record_file" "$engine_root/candidate.conf"
        if shimmy_engine_record_read "$engine_root/candidate.conf"; then fail_test 'engine record accepted symlink'; fi
        ;;
      unsafe-source)
        shimmy_engine_projection_render shared default "$SCENARIO_DIR/other/registries.conf" \
          "$source_fingerprint" "$effective_fingerprint" none >/dev/null 2>&1 &&
          fail_test 'engine projection accepted unsafe source path'
        ;;
    esac
    rm -f "$engine_root/candidate.conf"
  done
  pass 'engine manifests round-trip canonically and reject malformed, unsafe, unknown, symlinked, or wrong-mode state'
}

test_lib_engine_podman_and_ownership() {
  engine_fake_setup
  FAKE_ENGINE_INIT_CHANGES_DEFAULT=1
  export FAKE_ENGINE_INIT_CHANGES_DEFAULT
  shimmy_engine_podman_machine_init shimmy-test shimmy-test
  assert_equals "$(cat "$FAKE_ENGINE_MACHINE_STATE")" stopped
  assert_equals "$(cat "$FAKE_ENGINE_DEFAULT_CONNECTION")" other
  assert_contains "$(cat "$FAKE_ENGINE_LOG")" 'machine init --update-connection=false shimmy-test'
  identity=$(shimmy_engine_podman_machine_identity_fingerprint_render shimmy-test shimmy-test)
  token=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  record_file=$FAKE_ENGINE_ROOT/engine.conf
  shimmy_engine_record_render profile-test darwin-machine profile shimmy-test shimmy-test \
    applehv shimmy-created "$token" "$identity" > "$record_file"
  chmod 0644 "$record_file"
  shimmy_engine_podman_machine_start shimmy-test
  shimmy_engine_podman_guest_marker_write shimmy-test profile-test "$token"
  printf '%s\n' 'abcdef012345|sentinel' > "$FAKE_ENGINE_WORKLOADS"
  shimmy_engine_podman_workloads_read shimmy-test
  assert_equals "$SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT" 1
  shimmy_engine_ownership_state_read "$record_file"
  assert_equals "$SHIMMY_ENGINE_OWNERSHIP_STATE" owned

  printf '%s\n' mismatched > "$FAKE_ENGINE_GUEST_MARKER"
  shimmy_engine_ownership_state_read "$record_file"
  assert_equals "$SHIMMY_ENGINE_OWNERSHIP_STATE" ambiguous
  assert_equals "$SHIMMY_ENGINE_OWNERSHIP_REASON" guest-marker-mismatch
  shimmy_engine_podman_guest_marker_write shimmy-test profile-test "$token"
  printf '%s\n' '2026-08-23 12:00:00 +0000 UTC' > "$FAKE_ENGINE_CREATED"
  shimmy_engine_ownership_state_read "$record_file"
  assert_equals "$SHIMMY_ENGINE_OWNERSHIP_REASON" inspect-mismatch
  printf '%s\n' '2026-08-22 12:00:00 +0000 UTC' > "$FAKE_ENGINE_CREATED"
  printf '%s\n' absent > "$FAKE_ENGINE_MACHINE_STATE"
  shimmy_engine_ownership_state_read "$record_file"
  assert_equals "$SHIMMY_ENGINE_OWNERSHIP_STATE" missing
  set +e
  ownership_output=$(shimmy_engine_ownership_destructive_validate "$record_file" 2>&1)
  ownership_status=$?
  set -e
  [ "$ownership_status" -ne 0 ] || fail_test 'missing machine retained destructive authority'
  assert_not_contains "$ownership_output" "$token"
  engine_fake_setup
  printf '%s\n' none > "$FAKE_ENGINE_DEFAULT_CONNECTION"
  FAKE_ENGINE_INIT_CHANGES_DEFAULT=0
  export FAKE_ENGINE_INIT_CHANGES_DEFAULT
  shimmy_engine_podman_machine_init shimmy-test shimmy-test
  assert_equals "$(cat "$FAKE_ENGINE_DEFAULT_CONNECTION")" none
  pass 'exact host, guest, connection, provider, and inspect evidence grants ownership while any mismatch preserves the machine without token disclosure'
}

test_lib_engine_lifecycle_journal() {
  engine_fake_setup
  engine_root=$SCENARIO_DIR/config/shimmy/engines/profile-test
  mkdir -p "$engine_root"
  journal=$engine_root/lifecycle.conf
  record=$engine_root/engine.conf
  shimmy_engine_machine_create_prepare profile-test shimmy-test shimmy-test "$journal"
  assert_file_contains "$journal" 'phase=planned'
  shimmy_engine_machine_create_initialize "$journal"
  assert_file_contains "$journal" 'phase=initialized'
  shimmy_engine_machine_create_record "$journal" "$record" profile
  assert_file_contains "$journal" 'phase=recorded'
  shimmy_engine_machine_create_start "$journal"
  FAKE_ENGINE_FAIL_ACTION=marker-write
  export FAKE_ENGINE_FAIL_ACTION
  set +e
  shimmy_engine_machine_create_guest_mark "$journal" >/dev/null 2>&1
  marker_status=$?
  set -e
  [ "$marker_status" -ne 0 ] || fail_test 'injected guest-marker failure unexpectedly succeeded'
  assert_file_contains "$journal" 'phase=guest-marking'
  FAKE_ENGINE_FAIL_ACTION=
  export FAKE_ENGINE_FAIL_ACTION
  shimmy_engine_machine_create_guest_mark "$journal"
  shimmy_engine_machine_create_commit "$journal"
  assert_path_not_exists "$journal"

  shimmy_engine_podman_machine_stop shimmy-test
  shimmy_engine_machine_remove_prepare "$record" "$journal"
  FAKE_ENGINE_FAIL_ACTION=machine-rm
  export FAKE_ENGINE_FAIL_ACTION
  set +e
  shimmy_engine_machine_remove_apply "$record" "$journal" >/dev/null 2>&1
  remove_status=$?
  set -e
  [ "$remove_status" -ne 0 ] || fail_test 'injected machine removal failure unexpectedly succeeded'
  assert_file_contains "$journal" 'phase=removing'
  FAKE_ENGINE_FAIL_ACTION=
  export FAKE_ENGINE_FAIL_ACTION
  shimmy_engine_machine_remove_apply "$record" "$journal"
  assert_file_contains "$journal" 'phase=removed'
  shimmy_engine_machine_remove_commit "$journal"
  assert_path_not_exists "$journal"
  assert_equals "$(cat "$FAKE_ENGINE_MACHINE_STATE")" absent
  pass 'journal transitions precede external lifecycle mutations and retain exact retry state across interrupted create and remove'
}

test_lib_engine_projection_transaction() {
  engine_fake_setup
  printf '%s\n' running > "$FAKE_ENGINE_MACHINE_STATE"
  engine_root=$SCENARIO_DIR/config/shimmy/engines/shared
  default_root=$SCENARIO_DIR/config/shimmy/profiles/default
  sibling_root=$SCENARIO_DIR/config/shimmy/profiles/sibling
  changed_root=$SCENARIO_DIR/config/shimmy/profiles/changed
  mkdir -p "$engine_root" "$default_root" "$sibling_root" "$changed_root"
  source_a=$default_root/registries.conf
  source_equal=$sibling_root/registries.conf
  source_b=$changed_root/registries.conf
  shimmy_registries_config_render default 'docker.io|registry-a.example/docker' > "$source_a"
  shimmy_registries_config_render sibling 'docker.io|registry-a.example/docker' > "$source_equal"
  shimmy_registries_config_render changed 'docker.io|registry-b.example/docker' > "$source_b"
  chmod 0644 "$source_a" "$source_equal" "$source_b"
  FAKE_ENGINE_PROJECTION_CONFIG=$engine_root/registries.conf
  export FAKE_ENGINE_PROJECTION_CONFIG

  shimmy_engine_projection_prepare shared "$engine_root" default "$source_a" shimmy-test
  assert_equals "$SHIMMY_ENGINE_PROJECTION_ACTION" recycle-podman-service
  shimmy_engine_projection_apply shimmy-test
  first_pid=$(cat "$FAKE_ENGINE_SERVICE_PID")
  assert_equals "$(cat "$FAKE_ENGINE_SERVICE_CACHE")" 'docker.io|registry-a.example/docker'
  shimmy_engine_projection_commit

  shimmy_engine_projection_prepare shared "$engine_root" sibling "$source_equal" shimmy-test
  assert_equals "$SHIMMY_ENGINE_PROJECTION_ACTION" none
  shimmy_engine_projection_apply shimmy-test
  assert_equals "$(cat "$FAKE_ENGINE_SERVICE_PID")" "$first_pid"
  shimmy_engine_projection_commit

  prior_config=$SCENARIO_DIR/prior-engine-registries.conf
  prior_record=$SCENARIO_DIR/prior-projection.conf
  cp "$engine_root/registries.conf" "$prior_config"
  cp "$engine_root/projection.conf" "$prior_record"
  shimmy_engine_projection_prepare shared "$engine_root" changed "$source_b" shimmy-test
  assert_equals "$SHIMMY_ENGINE_PROJECTION_ACTION" recycle-podman-service
  shimmy_engine_projection_apply shimmy-test
  changed_pid=$(cat "$FAKE_ENGINE_SERVICE_PID")
  [ "$changed_pid" != "$first_pid" ] || fail_test 'changed registry policy did not recycle service'
  assert_equals "$(cat "$FAKE_ENGINE_SERVICE_CACHE")" 'docker.io|registry-b.example/docker'
  shimmy_engine_projection_rollback shimmy-test
  cmp -s "$prior_config" "$engine_root/registries.conf" || fail_test 'projection rollback did not restore exact config bytes'
  cmp -s "$prior_record" "$engine_root/projection.conf" || fail_test 'projection rollback did not restore exact state bytes'
  assert_equals "$(cat "$FAKE_ENGINE_SERVICE_CACHE")" 'docker.io|registry-a.example/docker'
  assert_path_not_exists "$engine_root/.registries.rollback.$$"
  assert_path_not_exists "$engine_root/.projection.rollback.$$"
  assert_not_contains "$(cat "$FAKE_ENGINE_LOG")" 'machine stop'
  assert_not_contains "$(cat "$FAKE_ENGINE_LOG")" 'SIGHUP'
  assert_not_contains "$(cat "$FAKE_ENGINE_LOG")" 'daemon-reload'
  pass 'engine projection is atomic, equal policy is a no-op, changed policy recycles only the rootless service, and rollback restores and reloads prior policy'
}

test_lib_engine_service_recycle() {
  engine_fake_setup
  printf '%s\n' running > "$FAKE_ENGINE_MACHINE_STATE"
  shimmy_registries_config_render default '' > "$FAKE_ENGINE_PROJECTION_CONFIG"
  chmod 0644 "$FAKE_ENGINE_PROJECTION_CONFIG"
  shimmy_engine_podman_service_recycle shimmy-test shimmy-test
  assert_equals "$SHIMMY_ENGINE_SERVICE_PRIOR_PID" 800
  assert_equals "$SHIMMY_ENGINE_SERVICE_NEW_PID" 801
  service_log=$(cat "$FAKE_ENGINE_LOG")
  assert_contains "$service_log" 'systemctl --user stop podman.service'
  assert_contains "$service_log" '--connection shimmy-test info'
  assert_not_contains "$service_log" 'machine stop'
  pass 'service recycle retains podman.socket, forces exact-connection activation, and observes a new service PID without a VM operation'
}

test_lib_engine_run() {
  test_lib_engine_records
  test_lib_engine_podman_and_ownership
  test_lib_engine_lifecycle_journal
  test_lib_engine_projection_transaction
  test_lib_engine_service_recycle
}
