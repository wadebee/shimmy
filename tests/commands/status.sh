#!/bin/sh

test_commands_status_run() {
  setup_scenario_with_profiles default upstream

  default_status=$(default_shimmy status --format manifest)
  upstream_status=$(upstream_shimmy status --format manifest)
  assert_contains "$default_status" "shimmy_profile_root=$DEFAULT_PROFILE_ROOT"
  assert_contains "$default_status" 'shimmy_installed=yes'
  assert_contains "$default_status" 'shimmy_profile_tool=jq'
  assert_contains "$default_status" 'shimmy_profile_tool=rg'
  assert_not_contains "$default_status" 'shimmy_profile_kind='
  assert_not_contains "$default_status" 'shimmy_profile_kind_version='
  assert_contains "$upstream_status" "shimmy_profile_root=$UPSTREAM_PROFILE_ROOT"
  assert_contains "$upstream_status" 'shimmy_installed=yes'
  assert_contains "$upstream_status" 'shimmy_profile_tool=rg'
  assert_contains "$upstream_status" 'shimmy_profile_tool=jq'

  assert_contains "$(default_shimmy status)" 'ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91'

  default_shimmy install --shim netcat >/dev/null
  default_catalog_source=$(default_shimmy status --format manifest | sed -n 's/^shimmy_catalog_source=//p')
  assert_contains "$(default_shimmy status)" "local-build:$DEFAULT_PROFILE_ROOT/tools/netcat/versions/7.92/container"

  printf '%s\n' 'shimmy_image_config_version=999' > "$default_catalog_source/tools/jq/versions/1.8/image.conf"
  set +e
  invalid_status=$(default_shimmy status 2>&1)
  invalid_status_code=$?
  set -e
  [ "$invalid_status_code" -ne 0 ] || fail_test 'status accepted malformed installed image configuration'
  assert_contains "$invalid_status" 'invalid image configuration'

  setup_scenario_with_profiles default
  printf '%s\n' 'shimmy_image_config_version=999' > "$DEFAULT_PROFILE_ROOT/tools/jq/versions/1.8/image.conf"
  set +e
  invalid_materialization_status=$(default_shimmy status 2>&1)
  invalid_materialization_status_code=$?
  set -e
  [ "$invalid_materialization_status_code" -ne 0 ] || fail_test 'status accepted malformed profile-materialized image configuration'
  assert_contains "$invalid_materialization_status" 'invalid image configuration'
  pass "status reports only the invoking profile and version-owned metadata"
}
