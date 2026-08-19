#!/bin/sh

commands_status_default_run() {
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Unsupported "$DEFAULT_PROFILE_ROOT/bin/shimmy" status "$@"
}

test_commands_status_run() {
  setup_scenario_with_profiles default upstream

  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  fake_connections='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'

  default_status=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true
shimmy-upstream|false' FAKE_CONNECTION_LIST="$fake_connections" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" status --format manifest)
  upstream_status=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true
shimmy-upstream|false' FAKE_CONNECTION_LIST="$fake_connections" \
    "$UPSTREAM_PROFILE_ROOT/bin/shimmy" status --format manifest)
  assert_contains "$default_status" "shimmy_profile_root=$DEFAULT_PROFILE_ROOT"
  assert_contains "$default_status" 'shimmy_installed=yes'
  assert_contains "$default_status" 'shimmy_profile_name=default'
  assert_contains "$default_status" 'shimmy_catalog_name=default'
  assert_contains "$default_status" 'shimmy_catalog_health=ok'
  assert_contains "$default_status" 'shimmy_profile_tool=jq'
  assert_contains "$default_status" 'shimmy_profile_tool=rg'
  assert_contains "$default_status" 'shimmy_profile_tool_version=jq|1.8|jq_1_8'
  assert_contains "$default_status" 'shimmy_engine_type=podman_machine'
  assert_contains "$default_status" 'shimmy_engine_name=shimmy-default'
  assert_contains "$default_status" 'shimmy_engine_connection=shimmy-default'
  assert_contains "$default_status" 'shimmy_engine_default_connection=shimmy-default'
  assert_contains "$default_status" 'shimmy_engine_machine_state=running'
  assert_contains "$default_status" 'shimmy_engine_reachable=true'
  assert_contains "$default_status" 'shimmy_engine_activation=registry_restart_required'
  assert_contains "$default_status" 'shimmy_engine_registry_policy=restart-required'
  assert_contains "$default_status" 'shimmy_engine_running_container_count=0'
  assert_contains "$default_status" 'shimmy_engine_recommended_action=profile_activate_restart'
  assert_not_contains "$default_status" 'ssh://core@127.0.0.1'
  assert_contains "$upstream_status" "shimmy_profile_root=$UPSTREAM_PROFILE_ROOT"
  assert_contains "$upstream_status" 'shimmy_installed=yes'
  assert_contains "$upstream_status" 'shimmy_profile_tool=rg'
  assert_contains "$upstream_status" 'shimmy_profile_tool=jq'

  human_status=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST='shimmy-default|true
shimmy-upstream|false' FAKE_CONNECTION_LIST="$fake_connections" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" status)
  assert_contains "$human_status" 'Profile'
  assert_contains "$human_status" 'Podman Engine'
  assert_contains "$human_status" 'Catalog'
  assert_contains "$human_status" 'Tools'
  assert_contains "$human_status" '  type: podman machine'
  assert_contains "$human_status" '  connection: shimmy-default (default)'
  assert_contains "$human_status" '  reachable: yes'
  assert_contains "$human_status" '  activation: registry restart required'
  assert_contains "$human_status" '  registry policy: restart required'
  assert_contains "$human_status" "  action: '$DEFAULT_PROFILE_ROOT/bin/shimmy' profile activate --restart"
  assert_contains "$human_status" 'ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91'
  assert_not_contains "$human_status" 'ssh://core@127.0.0.1'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine start'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'system connection default'

  unavailable_status=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$SCENARIO_DIR/missing-podman" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" status)
  assert_contains "$unavailable_status" '  activation: unavailable'
  assert_contains "$unavailable_status" 'Catalog'
  assert_contains "$unavailable_status" 'Tools'
  assert_contains "$unavailable_status" '- jq'

  unsupported_status=$(commands_status_default_run)
  assert_contains "$unsupported_status" '  type: unsupported'
  assert_contains "$unsupported_status" '  activation: unsupported host'
  assert_not_contains "$unsupported_status" '  action:'
  assert_contains "$unsupported_status" 'Catalog'
  assert_contains "$unsupported_status" 'Tools'

  secret_connection='ssh://secret@example.invalid/run/user/1/podman/podman.sock'
  secret_registries=$SCENARIO_DIR/secret-registries.conf
  overridden_status=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    CONTAINER_HOST="$secret_connection" CONTAINERS_REGISTRIES_CONF="$secret_registries" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" "$DEFAULT_PROFILE_ROOT/bin/shimmy" status)
  assert_contains "$overridden_status" '  activation: overridden'
  assert_contains "$overridden_status" '  action: unset CONTAINER_HOST CONTAINERS_REGISTRIES_CONF'
  assert_not_contains "$overridden_status" "$secret_connection"
  assert_not_contains "$overridden_status" "$secret_registries"

  default_shimmy install --shim netcat >/dev/null
  default_catalog_source=$(commands_status_default_run --format manifest | sed -n 's/^shimmy_catalog_source=//p')
  assert_contains "$(commands_status_default_run)" "local-build:$DEFAULT_PROFILE_ROOT/tools/netcat/versions/7.92/container"

  printf '%s\n' 'shimmy_image_config_version=999' > "$default_catalog_source/tools/jq/versions/1.8/image.conf"
  set +e
  invalid_status=$(commands_status_default_run 2>&1)
  invalid_status_code=$?
  set -e
  [ "$invalid_status_code" -ne 0 ] || fail_test 'status accepted malformed installed image configuration'
  assert_contains "$invalid_status" 'Profile'
  assert_contains "$invalid_status" 'Podman Engine'
  assert_contains "$invalid_status" 'Catalog'
  assert_contains "$invalid_status" '  health: invalid'
  assert_contains "$invalid_status" 'invalid image configuration'

  setup_scenario_with_profiles default
  printf '%s\n' 'shimmy_image_config_version=999' > "$DEFAULT_PROFILE_ROOT/tools/jq/versions/1.8/image.conf"
  set +e
  invalid_materialization_status=$(commands_status_default_run 2>&1)
  invalid_materialization_status_code=$?
  set -e
  [ "$invalid_materialization_status_code" -ne 0 ] || fail_test 'status accepted malformed profile-materialized image configuration'
  assert_contains "$invalid_materialization_status" 'invalid image configuration'
  pass "status reports sectioned read-only engine state and preserves profile, catalog, and version-owned metadata"
}
