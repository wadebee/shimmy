#!/bin/sh

test_commands_status_run() {
  setup_scenario
  bootstrap_default >/dev/null
  bootstrap_upstream >/dev/null

  default_status=$(default_shimmy status --format manifest)
  upstream_status=$(upstream_shimmy status --format manifest)
  assert_contains "$default_status" "shimmy_profile_root=$DEFAULT_PROFILE_ROOT"
  assert_contains "$default_status" 'shimmy_installed=yes'
  assert_contains "$default_status" 'shimmy_profile_kind=jq'
  assert_contains "$default_status" 'shimmy_profile_kind=rg'
  assert_contains "$upstream_status" "shimmy_profile_root=$UPSTREAM_PROFILE_ROOT"
  assert_contains "$upstream_status" 'shimmy_installed=yes'
  assert_contains "$upstream_status" 'shimmy_profile_kind=rg'
  assert_contains "$upstream_status" 'shimmy_profile_kind=jq'

  available_status=$(default_shimmy status --available --format manifest)
  assert_contains "$available_status" 'shimmy_available_kind=task'
  assert_not_contains "$available_status" 'shimmy_available_kind=rg'
  assert_contains "$(default_shimmy status)" 'ghcr.io/jqlang/jq:1.8.1'
  pass "status reports only the invoking profile and version-owned metadata"
}
