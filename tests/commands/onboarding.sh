#!/bin/sh

test_commands_onboarding_shell_init_path_assert() {
  shell_init_file=$1
  path_before=$2
  path_expected=$3

  path_after=$(
    TEST_SHELL_INIT_FILE=$shell_init_file TEST_PATH_BEFORE=$path_before /bin/sh -c '
      PATH=$TEST_PATH_BEFORE
      export PATH
      . "$TEST_SHELL_INIT_FILE"
      if [ "${shimmy_shell_init_bin_dir+x}" = x ] ||
        [ "${shimmy_shell_init_path_entry+x}" = x ] ||
        [ "${shimmy_shell_init_path_has_entry+x}" = x ] ||
        [ "${shimmy_shell_init_path_input+x}" = x ] ||
        [ "${shimmy_shell_init_path_more+x}" = x ] ||
        [ "${shimmy_shell_init_path_output+x}" = x ] ||
        [ "${shimmy_shell_init_podman_dir+x}" = x ]; then
        printf "temporary shell init variable leaked\n"
      else
        printf "%s\n" "$PATH"
      fi
    '
  )
  assert_equals "$path_after" "$path_expected"
}

test_commands_onboarding_run() {
  setup_scenario
  bootstrap_default --shim jq >/dev/null
  bootstrap_upstream --shim rg >/dev/null

  default_shell_init_file=$DEFAULT_PROFILE_ROOT/shell-init.sh
  upstream_shell_init_file=$UPSTREAM_PROFILE_ROOT/shell-init.sh
  assert_file_contains "$default_shell_init_file" "$DEFAULT_PROFILE_ROOT/bin"
  assert_file_contains "$upstream_shell_init_file" "$UPSTREAM_PROFILE_ROOT/bin"
  assert_file_not_contains "$default_shell_init_file" SHIMMY_PROFILE_ACTIVE
  assert_file_not_contains "$upstream_shell_init_file" SHIMMY_PROFILE_ACTIVE
  assert_file_contains "$default_shell_init_file" '/opt/podman/bin'

  podman_path_suffix=
  if [ -x /opt/podman/bin/podman ] && ! (PATH=/usr/bin:/bin; export PATH; command -v podman >/dev/null 2>&1); then
    podman_path_suffix=:/opt/podman/bin
  fi
  test_commands_onboarding_shell_init_path_assert \
    "$default_shell_init_file" \
    "/usr/bin:/bin" \
    "$DEFAULT_PROFILE_ROOT/bin:/usr/bin:/bin$podman_path_suffix"
  test_commands_onboarding_shell_init_path_assert \
    "$default_shell_init_file" \
    ":$DEFAULT_PROFILE_ROOT/bin:/usr/bin:$DEFAULT_PROFILE_ROOT/bin::/bin:" \
    "$DEFAULT_PROFILE_ROOT/bin::/usr/bin::/bin:$podman_path_suffix"

  switched_path=$(
    TEST_DEFAULT_SHELL_INIT_FILE=$default_shell_init_file \
      TEST_UPSTREAM_SHELL_INIT_FILE=$upstream_shell_init_file \
      TEST_DEFAULT_BIN=$DEFAULT_PROFILE_ROOT/bin \
      TEST_UPSTREAM_BIN=$UPSTREAM_PROFILE_ROOT/bin \
      /bin/sh -c '
        PATH=$TEST_DEFAULT_BIN:/usr/bin:$TEST_UPSTREAM_BIN:/bin:$TEST_DEFAULT_BIN
        export PATH
        . "$TEST_UPSTREAM_SHELL_INIT_FILE"
        . "$TEST_DEFAULT_SHELL_INIT_FILE"
        . "$TEST_DEFAULT_SHELL_INIT_FILE"
        printf "%s\n" "$PATH"
      '
  )
  assert_equals "$switched_path" "$DEFAULT_PROFILE_ROOT/bin:$UPSTREAM_PROFILE_ROOT/bin:/usr/bin:/bin$podman_path_suffix"

  podman_fixture_dir=$SCENARIO_DIR/podman-bin
  podman_path_dir=$SCENARIO_DIR/path-without-podman
  podman_shell_init_file=$SCENARIO_DIR/shell-init-with-podman-fixture.sh
  mkdir -p "$podman_fixture_dir" "$podman_path_dir"
  printf '#!/bin/sh\nexit 0\n' > "$podman_fixture_dir/podman"
  chmod 755 "$podman_fixture_dir/podman"
  sed "s|'/opt/podman/bin'|'$podman_fixture_dir'|" "$default_shell_init_file" > "$podman_shell_init_file"
  test_commands_onboarding_shell_init_path_assert \
    "$podman_shell_init_file" \
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
  pass "shell initialization changes PATH only and launchers remain bound to their enclosing profiles"
}
