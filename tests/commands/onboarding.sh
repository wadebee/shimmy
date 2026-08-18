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

test_commands_onboarding_failure_cleanup() {
  setup_scenario
  failure_output=$(
    env TEST_ROOT_DIR="$ROOT_DIR" XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      PATH=/usr/bin:/bin /bin/sh -c '
        cd "$TEST_ROOT_DIR"
        . ./install.sh --unknown-option >/dev/null 2>&1
        install_status=$?
        printf "status=%s\n" "$install_status"
        printf "after=failure\n"
        command -v shimmy__bootstrap_run >/dev/null 2>&1 && printf "function=leaked\n"
        [ "${shimmy__bootstrap_profile_name+x}" = x ] && printf "variable=leaked\n"
        [ "${shimmy__bootstrap_tool_baseline+x}" = x ] && printf "variable=leaked\n"
        true
      '
  )
  assert_contains "$failure_output" 'status=1'
  assert_contains "$failure_output" 'after=failure'
  assert_not_contains "$failure_output" 'function=leaked'
  assert_not_contains "$failure_output" 'variable=leaked'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"

  conditional_output=$(
    env TEST_ROOT_DIR="$ROOT_DIR" XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      PATH=/usr/bin:/bin /bin/sh -c '
        set -e
        cd "$TEST_ROOT_DIR"
        if . ./install.sh --unknown-option >/dev/null 2>&1; then
          exit 90
        fi
        printf "after=conditional-failure\n"
      '
  )
  assert_contains "$conditional_output" 'after=conditional-failure'

  invalid_checkout_output=$(
    env TEST_INSTALL_FILE="$ROOT_DIR/install.sh" XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      PATH=/usr/bin:/bin /bin/sh -c '
        cd "$HOME"
        . "$TEST_INSTALL_FILE" --no-startup >/dev/null 2>&1
        printf "status=%s\n" "$?"
        printf "after=checkout-failure\n"
      '
  )
  assert_contains "$invalid_checkout_output" 'status=1'
  assert_contains "$invalid_checkout_output" 'after=checkout-failure'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  pass "sourced failures return without exiting or leaking bootstrap state"
}

test_commands_onboarding_help() {
  setup_scenario
  help_output=$(
    env TEST_ROOT_DIR="$ROOT_DIR" XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      PATH=/usr/bin:/bin /bin/sh -c '
        cd "$TEST_ROOT_DIR"
        path_before=$PATH
        . ./install.sh --profile upstream --help
        printf "path_unchanged=%s\n" "$([ "$PATH" = "$path_before" ] && printf yes || printf no)"
        command -v shimmy__bootstrap_run >/dev/null 2>&1 && printf "function=leaked\n"
        true
      '
  )
  assert_contains "$help_output" 'source ./install.sh'
  assert_contains "$help_output" 'Every bootstrap includes jq and rg.'
  assert_contains "$help_output" 'shimmy install --shim <tool>'
  assert_contains "$help_output" 'path_unchanged=yes'
  assert_not_contains "$help_output" 'function=leaked'
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"
  pass "sourced help describes both modes without installing or changing PATH"
}

test_commands_onboarding_bootstrap_documentation() {
  assert_file_exists "$ROOT_DIR/BOOTSTRAP.md"
  assert_file_contains "$ROOT_DIR/AGENTS.md" 'BOOTSTRAP.md'
  assert_file_contains "$ROOT_DIR/README.md" '[BOOTSTRAP.md](BOOTSTRAP.md)'
  assert_file_contains "$ROOT_DIR/BOOTSTRAP.md" 'root `install.sh` checkout bootstrap'
  assert_file_contains "$ROOT_DIR/BOOTSTRAP.md" 'commands/install.sh'
  assert_file_contains "$ROOT_DIR/BOOTSTRAP.md" 'lib/install/install.sh'
  assert_file_contains "$ROOT_DIR/BOOTSTRAP.md" 'Do not execute or source'
  assert_file_contains "$ROOT_DIR/BOOTSTRAP.md" 'Every bootstrap installs jq and rg.'
  assert_file_contains "$ROOT_DIR/BOOTSTRAP.md" 'shimmy skills install --target repo'
  assert_file_contains "$ROOT_DIR/BOOTSTRAP.md" 'shimmy skills install --target profile'
  assert_path_not_exists "$ROOT_DIR/bootstrap.sh"
  assert_path_not_exists "$ROOT_DIR/bootstrap"
  pass "bootstrap discovery documents the supported public chain and adapter workflow"
}

test_commands_onboarding_progression() {
  setup_scenario

  set +e
  bootstrap_selection_output=$(bootstrap_default --shim task 2>&1)
  bootstrap_selection_status=$?
  set -e
  [ "$bootstrap_selection_status" -ne 0 ] || fail_test "repository installer unexpectedly accepted --shim"
  assert_contains "$bootstrap_selection_output" 'repository installation includes jq and rg'
  assert_contains "$bootstrap_selection_output" 'shimmy install --shim <tool>'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"

  absolute_output=$(
    cd "$WORK_DIR"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      "$ROOT_DIR/install.sh" --profile upstream 2>&1
  )
  assert_contains "$absolute_output" "Installed Shimmy upstream profile at $UPSTREAM_PROFILE_ROOT"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/install-manifest.txt"
  assert_file_contains "$UPSTREAM_PROFILE_ROOT/install-manifest.txt" 'shimmy_profile_name=upstream'
  absolute_upstream_selection=$(sed -n '/^tool=/p; /^tool_version=/p' \
    "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")
  pass "repository installer executes by absolute path outside the checkout"

  progression_output=$(
    env TEST_ROOT_DIR="$SHIMMY_TEST_CLEAN_SOURCE_ROOT" TEST_REPO_ROOT="$ROOT_DIR" \
      TEST_DEFAULT_PROFILE_ROOT="$DEFAULT_PROFILE_ROOT" \
      TEST_UPSTREAM_PROFILE_ROOT="$UPSTREAM_PROFILE_ROOT" TEST_WORK_DIR="$WORK_DIR" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      PATH=/usr/bin:/bin /bin/sh -c '
        cd "$TEST_ROOT_DIR"
        set -- first "second value"
        cwd_before=$(pwd -P)
        flags_before=$-
        unrelated_value=preserved
        caller_function() { printf preserved; }
        trap "trap_preserved=yes" USR1
        . ./install.sh --no-startup >/dev/null || exit 91
        install_status=$?
        kill -USR1 $$
        printf "status=%s\n" "$install_status"
        printf "shimmy=%s\n" "$(command -v shimmy)"
        printf "jq=%s\n" "$(command -v jq)"
        printf "rg=%s\n" "$(command -v rg)"
        printf "profile=%s\n" "$(shimmy status --format manifest | sed -n "s/^shimmy_profile_name=//p")"
        printf "cwd_unchanged=%s\n" "$([ "$(pwd -P)" = "$cwd_before" ] && printf yes || printf no)"
        printf "flags_unchanged=%s\n" "$([ "$-" = "$flags_before" ] && printf yes || printf no)"
        printf "parameters_unchanged=%s\n" "$([ "$#" -eq 2 ] && [ "$1" = first ] && [ "$2" = "second value" ] && printf yes || printf no)"
        printf "function_unchanged=%s\n" "$(caller_function)"
        printf "unrelated=%s\n" "$unrelated_value"
        printf "trap=%s\n" "${trap_preserved:-no}"
        command -v shimmy__bootstrap_run >/dev/null 2>&1 && printf "function=leaked\n"
        [ "${shimmy__bootstrap_source_root+x}" = x ] && printf "variable=leaked\n"
        [ "${shimmy__bootstrap_tool_baseline+x}" = x ] && printf "variable=leaked\n"
        [ "${SHIMMY_BOOTSTRAP_PROFILE+x}" = x ] && printf "profile_selector=leaked\n"

        sed -n "/^tool=/p; /^tool_version=/p" \
          "$TEST_DEFAULT_PROFILE_ROOT/install-manifest.txt" \
          > "$TEST_WORK_DIR/default-baseline-selection"

        manifest_checksum=$(cksum < "$TEST_DEFAULT_PROFILE_ROOT/install-manifest.txt")
        if "$TEST_DEFAULT_PROFILE_ROOT/bin/shimmy" install \
          > "$TEST_WORK_DIR/empty-install-output" 2>&1; then
          exit 92
        fi
        printf "empty_manifest_unchanged=%s\n" \
          "$([ "$(cksum < "$TEST_DEFAULT_PROFILE_ROOT/install-manifest.txt")" = "$manifest_checksum" ] && printf yes || printf no)"

        "$TEST_DEFAULT_PROFILE_ROOT/bin/shimmy" install \
          --shim task --shim oc@4.18 >/dev/null || exit 93
        additive_selection=$(sed -n "/^tool=/p; /^tool_version=/p" \
          "$TEST_DEFAULT_PROFILE_ROOT/install-manifest.txt")
        printf "%s\n" "$additive_selection" > "$TEST_WORK_DIR/additive-selection"

        . ./install.sh --profile default >/dev/null || exit 94
        refreshed_selection=$(sed -n "/^tool=/p; /^tool_version=/p" \
          "$TEST_DEFAULT_PROFILE_ROOT/install-manifest.txt")
        printf "%s\n" "$refreshed_selection" > "$TEST_WORK_DIR/refreshed-selection"
        printf "refresh_selection_unchanged=%s\n" \
          "$([ "$refreshed_selection" = "$additive_selection" ] && printf yes || printf no)"
        printf "default_first=%s\n" "$(command -v shimmy)"

        cd "$TEST_REPO_ROOT"
        . ./install.sh --profile upstream >/dev/null || exit 95
        printf "upstream=%s\n" "$(command -v shimmy)"
        cd "$TEST_ROOT_DIR"
        . ./install.sh --profile default >/dev/null || exit 96
        printf "default_again=%s\n" "$(command -v shimmy)"
      '
  )

  assert_contains "$progression_output" 'status=0'
  assert_contains "$progression_output" "shimmy=$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_contains "$progression_output" "jq=$DEFAULT_PROFILE_ROOT/bin/jq"
  assert_contains "$progression_output" "rg=$DEFAULT_PROFILE_ROOT/bin/rg"
  assert_contains "$progression_output" 'profile=default'
  assert_contains "$progression_output" 'cwd_unchanged=yes'
  assert_contains "$progression_output" 'flags_unchanged=yes'
  assert_contains "$progression_output" 'parameters_unchanged=yes'
  assert_contains "$progression_output" 'function_unchanged=preserved'
  assert_contains "$progression_output" 'unrelated=preserved'
  assert_contains "$progression_output" 'trap=yes'
  assert_not_contains "$progression_output" 'function=leaked'
  assert_not_contains "$progression_output" 'variable=leaked'
  assert_not_contains "$progression_output" 'profile_selector=leaked'
  assert_path_not_exists "$HOME_DIR/.profile"
  pass "sourced onboarding initializes the current shell without changing caller state"

  default_fixture_selection=$(sed -n '/^tool=/p; /^tool_version=/p' \
    "$SHIMMY_TEST_PROFILE_FIXTURES_ROOT/default/install-manifest.txt")
  upstream_fixture_selection=$(sed -n '/^tool=/p; /^tool_version=/p' \
    "$SHIMMY_TEST_PROFILE_FIXTURES_ROOT/upstream/install-manifest.txt")
  default_baseline_selection=$(cat "$WORK_DIR/default-baseline-selection")
  assert_equals "$default_baseline_selection" "$default_fixture_selection"
  assert_equals "$absolute_upstream_selection" "$upstream_fixture_selection"
  assert_equals "$upstream_fixture_selection" "$default_fixture_selection"
  assert_file_contains "$WORK_DIR/empty-install-output" 'install requires at least one --shim <tool>'
  assert_contains "$progression_output" 'empty_manifest_unchanged=yes'
  additive_selection=$(cat "$WORK_DIR/additive-selection")
  refreshed_selection=$(cat "$WORK_DIR/refreshed-selection")
  assert_contains "$additive_selection" 'tool=jq'
  assert_contains "$additive_selection" 'tool=rg'
  assert_contains "$additive_selection" 'tool=task'
  assert_contains "$additive_selection" 'tool=oc'
  assert_contains "$additive_selection" 'tool_version=oc|4.18|oc_4_18'
  assert_equals "$refreshed_selection" "$additive_selection"
  assert_contains "$progression_output" 'refresh_selection_unchanged=yes'
  pass "bootstrap owns the fixed jq/rg baseline while installed additions stay explicit and additive"

  assert_contains "$progression_output" "default_first=$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_contains "$progression_output" "upstream=$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_contains "$progression_output" "default_again=$DEFAULT_PROFILE_ROOT/bin/shimmy"
  pass "repeated sourced installs switch profile PATH precedence deterministically"
}

test_commands_onboarding_shell_sources() {
  for source_shell in /bin/bash /bin/zsh; do
    [ -x "$source_shell" ] || continue
    setup_scenario
    source_output=$(
      env TEST_ROOT_DIR="$SHIMMY_TEST_CLEAN_SOURCE_ROOT" XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
        PATH=/usr/bin:/bin "$source_shell" -c '
          cd "$TEST_ROOT_DIR"
          source ./install.sh --profile default --no-startup >/dev/null
          command -v shimmy
        '
    )
    assert_equals "$source_output" "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  done
  pass "available Bash and Zsh shells support the documented source form"
}

test_commands_onboarding_shell_init_rejection() {
  for shell_init_shape in missing symlink directory unreadable; do
    setup_scenario
    fixture_root=$SCENARIO_DIR/source
    mkdir -p "$fixture_root/commands" "$fixture_root/lib/common" \
      "$fixture_root/lib/install" "$fixture_root/lib/profile" "$fixture_root/tools"
    cp "$ROOT_DIR/install.sh" "$fixture_root/install.sh"
    cp "$ROOT_DIR/lib/common/common.sh" "$fixture_root/lib/common/common.sh"
    cp "$ROOT_DIR/lib/install/launcher-template.sh" "$fixture_root/lib/install/launcher-template.sh"
    cp "$ROOT_DIR/lib/profile/profile.sh" "$fixture_root/lib/profile/profile.sh"
    printf '%s\n' \
      '#!/bin/sh' \
      'set -eu' \
      'profile_root=$XDG_CONFIG_HOME/shimmy/profiles/$SHIMMY_BOOTSTRAP_PROFILE' \
      'mkdir -p "$profile_root/bin"' \
      'case "$TEST_SHELL_INIT_SHAPE" in' \
      '  missing) ;;' \
      '  symlink) ln -s "$TEST_SHELL_INIT_TARGET" "$profile_root/shell-init.sh" ;;' \
      '  directory) mkdir "$profile_root/shell-init.sh" ;;' \
      '  unreadable) printf "%s\\n" true > "$profile_root/shell-init.sh"; chmod 000 "$profile_root/shell-init.sh" ;;' \
      'esac' \
      > "$fixture_root/commands/install.sh"
    chmod 755 "$fixture_root/install.sh" "$fixture_root/commands/install.sh"
    printf '%s\n' true > "$SCENARIO_DIR/shell-init-target"

    rejection_output=$(
      env TEST_FIXTURE_ROOT="$fixture_root" TEST_SHELL_INIT_SHAPE="$shell_init_shape" \
        TEST_SHELL_INIT_TARGET="$SCENARIO_DIR/shell-init-target" \
        XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" PATH=/usr/bin:/bin /bin/sh -c '
          cd "$TEST_FIXTURE_ROOT"
          path_before=$PATH
          . ./install.sh --no-startup >/dev/null 2>&1
          printf "status=%s\n" "$?"
          printf "path_unchanged=%s\n" "$([ "$PATH" = "$path_before" ] && printf yes || printf no)"
          printf "after=shell-init-rejection\n"
        '
    )
    assert_contains "$rejection_output" 'status=1'
    assert_contains "$rejection_output" 'path_unchanged=yes'
    assert_contains "$rejection_output" 'after=shell-init-rejection'
    if [ "$shell_init_shape" = symlink ]; then
      assert_file_contains "$SCENARIO_DIR/shell-init-target" true
    fi
  done
  pass "missing, symlinked, non-file, and unreadable shell init assets are not sourced"
}

test_commands_onboarding_startup_failure() {
  setup_scenario
  mkdir "$HOME_DIR/.zshrc"
  failure_output=$(
    printf 'yes\n' | env TEST_ROOT_DIR="$SHIMMY_TEST_CLEAN_SOURCE_ROOT" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" PATH=/usr/bin:/bin /bin/sh -c '
          cd "$TEST_ROOT_DIR"
          path_before=$PATH
          . ./install.sh --shell zsh >/dev/null 2>&1
          printf "status=%s\n" "$?"
          printf "path_unchanged=%s\n" "$([ "$PATH" = "$path_before" ] && printf yes || printf no)"
          command -v shimmy >/dev/null 2>&1 && printf "shimmy=selected\n"
          printf "after=startup-failure\n"
        '
  )
  assert_contains "$failure_output" 'status=1'
  assert_contains "$failure_output" 'path_unchanged=yes'
  assert_contains "$failure_output" 'after=startup-failure'
  assert_not_contains "$failure_output" 'shimmy=selected'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/install-manifest.txt"
  pass "startup integration failure commits the profile but does not initialize PATH"
}

test_commands_onboarding_shell_init_path_behavior() {
  setup_scenario_with_profiles default upstream

  default_shell_init_file=$DEFAULT_PROFILE_ROOT/shell-init.sh
  upstream_shell_init_file=$UPSTREAM_PROFILE_ROOT/shell-init.sh
  assert_file_contains "$default_shell_init_file" "$DEFAULT_PROFILE_ROOT/bin"
  assert_file_contains "$upstream_shell_init_file" "$UPSTREAM_PROFILE_ROOT/bin"
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

  path_selected_status=$(
    PATH="$UPSTREAM_PROFILE_ROOT/bin:$DEFAULT_PROFILE_ROOT/bin:/usr/bin:/bin"
    XDG_CONFIG_HOME=$XDG_CONFIG_HOME_DIR
    HOME=$HOME_DIR
    export PATH XDG_CONFIG_HOME HOME
    shimmy status --format manifest
  )
  assert_contains "$path_selected_status" 'shimmy_profile_name=upstream'
  pass "shell initialization changes PATH only and PATH precedence selects the active profile"
}

test_commands_onboarding_run() {
  test_commands_onboarding_progression
  test_commands_onboarding_bootstrap_documentation
  test_commands_onboarding_help
  test_commands_onboarding_failure_cleanup
  test_commands_onboarding_startup_failure
  test_commands_onboarding_shell_sources
  test_commands_onboarding_shell_init_rejection
  test_commands_onboarding_shell_init_path_behavior
}
