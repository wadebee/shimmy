#!/bin/sh

test_commands_activate_path_assert() {
  activate_file=$1
  path_before=$2
  path_expected=$3

  path_after=$(
    TEST_ACTIVATE_FILE=$activate_file TEST_PATH_BEFORE=$path_before /bin/sh -c '
      PATH=$TEST_PATH_BEFORE
      export PATH
      . "$TEST_ACTIVATE_FILE"
      if [ "${shimmy_activate_bin_dir+x}" = x ] ||
        [ "${shimmy_activate_path_entry+x}" = x ] ||
        [ "${shimmy_activate_path_has_entry+x}" = x ] ||
        [ "${shimmy_activate_path_input+x}" = x ] ||
        [ "${shimmy_activate_path_more+x}" = x ] ||
        [ "${shimmy_activate_path_output+x}" = x ] ||
        [ "${shimmy_activate_podman_dir+x}" = x ]; then
        printf "temporary activation variable leaked\n"
      else
        printf "%s\n" "$PATH"
      fi
    '
  )
  assert_equals "$path_after" "$path_expected"
}

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
  assert_contains "$default_activation" '/opt/podman/bin'

  podman_path_suffix=
  if [ -x /opt/podman/bin/podman ] && ! (PATH=/usr/bin:/bin; export PATH; command -v podman >/dev/null 2>&1); then
    podman_path_suffix=:/opt/podman/bin
  fi
  default_activate_file=$DEFAULT_PROFILE_ROOT/activate.sh
  upstream_activate_file=$UPSTREAM_PROFILE_ROOT/activate.sh
  test_commands_activate_path_assert \
    "$default_activate_file" \
    "/usr/bin:/bin" \
    "$DEFAULT_PROFILE_ROOT/bin:/usr/bin:/bin$podman_path_suffix"
  test_commands_activate_path_assert \
    "$default_activate_file" \
    ":$DEFAULT_PROFILE_ROOT/bin:/usr/bin:$DEFAULT_PROFILE_ROOT/bin::/bin:" \
    "$DEFAULT_PROFILE_ROOT/bin::/usr/bin::/bin:$podman_path_suffix"

  switched_path=$(
    TEST_DEFAULT_ACTIVATE_FILE=$default_activate_file \
      TEST_UPSTREAM_ACTIVATE_FILE=$upstream_activate_file \
      TEST_DEFAULT_BIN=$DEFAULT_PROFILE_ROOT/bin \
      TEST_UPSTREAM_BIN=$UPSTREAM_PROFILE_ROOT/bin \
      /bin/sh -c '
        PATH=$TEST_DEFAULT_BIN:/usr/bin:$TEST_UPSTREAM_BIN:/bin:$TEST_DEFAULT_BIN
        export PATH
        . "$TEST_UPSTREAM_ACTIVATE_FILE"
        . "$TEST_DEFAULT_ACTIVATE_FILE"
        . "$TEST_DEFAULT_ACTIVATE_FILE"
        printf "%s\n" "$PATH"
      '
  )
  assert_equals "$switched_path" "$DEFAULT_PROFILE_ROOT/bin:$UPSTREAM_PROFILE_ROOT/bin:/usr/bin:/bin$podman_path_suffix"

  podman_fixture_dir=$SCENARIO_DIR/podman-bin
  podman_path_dir=$SCENARIO_DIR/path-without-podman
  podman_activate_file=$SCENARIO_DIR/activate-with-podman-fixture.sh
  mkdir -p "$podman_fixture_dir" "$podman_path_dir"
  printf '#!/bin/sh\nexit 0\n' > "$podman_fixture_dir/podman"
  chmod 755 "$podman_fixture_dir/podman"
  printf '%s\n' "$default_activation" | sed "s|'/opt/podman/bin'|'$podman_fixture_dir'|" > "$podman_activate_file"
  test_commands_activate_path_assert \
    "$podman_activate_file" \
    "$podman_path_dir" \
    "$DEFAULT_PROFILE_ROOT/bin:$podman_path_dir:$podman_fixture_dir"

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
