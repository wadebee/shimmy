#!/bin/sh

test_commands_activate_run() {
  setup_scenario
  bootstrap_default --shim jq >/dev/null
  bootstrap_upstream --shim rg >/dev/null

  default_activation=$(default_shimmy activate)
  upstream_activation=$(upstream_shimmy activate)
  assert_contains "$default_activation" "$DEFAULT_PROFILE_ROOT/bin"
  assert_contains "$upstream_activation" "$UPSTREAM_PROFILE_ROOT/bin"
  assert_not_contains "$default_activation" SHIMMY_PROFILE_ACTIVE
  assert_not_contains "$upstream_activation" SHIMMY_PROFILE_ACTIVE

  activated_path=$(
    PATH=/usr/bin:/bin
    export PATH
    eval "$default_activation"
    eval "$default_activation"
    printf '%s\n' "$PATH"
  )
  assert_equals "${activated_path%%:*}" "$DEFAULT_PROFILE_ROOT/bin"
  activation_occurrences=$(printf '%s\n' "$activated_path" | awk -F: -v path="$DEFAULT_PROFILE_ROOT/bin" '{ count=0; for (i=1; i<=NF; i++) if ($i == path) count++; print count }')
  assert_equals "$activation_occurrences" 1

  default_bound_status=$(env SHIMMY_PROFILE_ACTIVE=upstream XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/shimmy" status --format manifest)
  upstream_bound_status=$(env SHIMMY_PROFILE_ACTIVE=default XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$UPSTREAM_PROFILE_ROOT/bin/shimmy" status --format manifest)
  assert_contains "$default_bound_status" 'shimmy_profile_name=default'
  assert_contains "$upstream_bound_status" 'shimmy_profile_name=upstream'

  path_selected_status=$(
    PATH="$UPSTREAM_PROFILE_ROOT/bin:$DEFAULT_PROFILE_ROOT/bin:/usr/bin:/bin"
    XDG_CONFIG_HOME=$XDG_CONFIG_HOME_DIR
    HOME=$HOME_DIR
    export PATH XDG_CONFIG_HOME HOME
    shimmy status --format manifest
  )
  assert_contains "$path_selected_status" 'shimmy_profile_name=upstream'
  pass "activation changes PATH only and launchers remain bound to their enclosing profiles"
}
