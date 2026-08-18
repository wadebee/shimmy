#!/bin/sh

test_commands_startup_failure_retry() {
  setup_scenario
  mkdir "$HOME_DIR/.zshrc"

  set +e
  failure_output=$(run_in_clean_source env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    ./install.sh --profile default --shell zsh 2>&1)
  failure_status=$?
  set -e
  [ "$failure_status" -ne 0 ] || fail_test "invalid conventional startup target unexpectedly succeeded"
  assert_contains "$failure_output" 'profile installed, but startup integration failed'
  assert_contains "$failure_output" 'shimmy update --repair-startup'
  assert_contains "$(default_shimmy status --format manifest)" 'shimmy_installed=yes'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'startup_shell=zsh'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "startup_file=$HOME_DIR/.zshrc"

  rmdir "$HOME_DIR/.zshrc"
  test_manifest_source_url_replace "$DEFAULT_PROFILE_ROOT/install-manifest.txt" \
    "$SHIMMY_TEST_UPDATE_SOURCE_REPOSITORY"
  default_shimmy update --repair-startup >/dev/null
  assert_file_contains "$HOME_DIR/.zshrc" '# >>> shimmy default profile >>>'
  assert_file_contains "$HOME_DIR/.zshrc" "$DEFAULT_PROFILE_ROOT/shell-init.sh"
  pass "startup failure commits the exact ownership ledger and repair retries it"
}

test_commands_startup_inferred_and_manual_policy() {
  setup_scenario
  printf '%s\n' '# existing login file' > "$HOME_DIR/.bash_login"
  run_in_clean_source env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHELL=/bin/bash ./install.sh --profile default >/dev/null
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'startup_shell=bash'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "startup_file=$HOME_DIR/.bashrc"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "startup_file=$HOME_DIR/.bash_login"
  assert_file_contains "$HOME_DIR/.bashrc" '# >>> shimmy default profile >>>'
  assert_file_contains "$HOME_DIR/.bash_login" '# >>> shimmy default profile >>>'
  assert_path_not_exists "$HOME_DIR/.bash_profile"
  assert_path_not_exists "$HOME_DIR/.zshrc"
  pass "fresh inferred Bash policy records its interactive and selected login targets"

  setup_scenario
  run_in_clean_source env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHELL=/bin/dash ./install.sh --profile default --no-startup >/dev/null
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'startup_shell=sh'
  assert_no_line_with_prefix "$(cat "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" 'startup_file='
  assert_path_not_exists "$HOME_DIR/.profile"
  policy_before=$(sed -n '/^startup_/p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")

  default_shimmy install --shim task >/dev/null
  assert_equals "$(sed -n '/^startup_/p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$policy_before"
  test_manifest_source_url_replace "$DEFAULT_PROFILE_ROOT/install-manifest.txt" \
    "$SHIMMY_TEST_UPDATE_SOURCE_REPOSITORY"
  default_shimmy update >/dev/null
  repair_output=$(default_shimmy update --repair-startup 2>&1)
  assert_contains "$repair_output" 'profile has no managed startup files to repair'
  assert_equals "$(sed -n '/^startup_/p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$policy_before"
  assert_path_not_exists "$HOME_DIR/.profile"
  pass "manual policy records a normalized shell and stays a policy-preserving repair no-op"
}

test_commands_startup_managed_policy_lifecycle() {
  setup_scenario_with_profiles upstream
  run_in_clean_source env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHELL=/bin/bash ./install.sh --profile default --shell zsh >/dev/null
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'startup_shell=zsh'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "startup_file=$HOME_DIR/.zshrc"
  assert_file_contains "$HOME_DIR/.zshrc" '# >>> shimmy default profile >>>'
  assert_path_not_exists "$HOME_DIR/.bashrc"
  assert_path_not_exists "$HOME_DIR/.bash_profile"
  policy_before=$(sed -n '/^startup_/p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")

  printf '%s\n' '# user zsh configuration' > "$HOME_DIR/.zshrc"
  default_shimmy install --shim task >/dev/null
  assert_file_not_contains "$HOME_DIR/.zshrc" '# >>> shimmy default profile >>>'
  assert_equals "$(sed -n '/^startup_/p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$policy_before"

  test_manifest_source_url_replace "$DEFAULT_PROFILE_ROOT/install-manifest.txt" \
    "$SHIMMY_TEST_UPDATE_SOURCE_REPOSITORY"
  default_shimmy update >/dev/null
  assert_file_not_contains "$HOME_DIR/.zshrc" '# >>> shimmy default profile >>>'
  assert_equals "$(sed -n '/^startup_/p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$policy_before"

  alternate_home=$SCENARIO_DIR/alternate-home
  mkdir "$alternate_home"
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$alternate_home" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" update --repair-startup >/dev/null
  assert_file_contains "$HOME_DIR/.zshrc" '# >>> shimmy default profile >>>'
  assert_path_not_exists "$alternate_home/.zshrc"

  printf '%s\n' '# user zsh configuration' > "$HOME_DIR/.zshrc"
  run_in_clean_source env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHELL=/bin/bash ./install.sh --profile default >/dev/null
  assert_file_contains "$HOME_DIR/.zshrc" '# >>> shimmy default profile >>>'
  assert_path_not_exists "$HOME_DIR/.bashrc"
  assert_equals "$(sed -n '/^startup_/p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$policy_before"

  manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  startup_checksum=$(cksum < "$HOME_DIR/.zshrc")
  set +e
  immutable_output=$(run_in_clean_source env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    ./install.sh --profile default --shell bash 2>&1)
  immutable_status=$?
  set -e
  [ "$immutable_status" -ne 0 ] || fail_test "existing default profile unexpectedly accepted a startup policy selector"
  assert_contains "$immutable_output" 'startup policy is fixed when the default profile is created'
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$manifest_checksum"
  assert_equals "$(cksum < "$HOME_DIR/.zshrc")" "$startup_checksum"

  upstream_shimmy install --shim task >/dev/null
  assert_no_line_with_prefix "$(cat "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" 'startup_shell='
  assert_no_line_with_prefix "$(cat "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" 'startup_file='

  cp "$HOME_DIR/.zshrc" "$HOME_DIR/.bashrc"
  default_shimmy uninstall >/dev/null
  assert_file_not_contains "$HOME_DIR/.zshrc" '# >>> shimmy default profile >>>'
  assert_file_contains "$HOME_DIR/.bashrc" '# >>> shimmy default profile >>>'
  pass "managed policy is inherited exactly by install, update, repair, repeat bootstrap, upstream work, and uninstall"
}

test_commands_startup_shell_mismatch_confirmation() {
  [ -x /bin/bash ] || {
    pass "startup shell mismatch confirmation requires Bash when available"
    return 0
  }
  setup_scenario

  set +e
  mismatch_denied_output=$(
    printf '\n' | env TEST_ROOT_DIR="$SHIMMY_TEST_CLEAN_SOURCE_ROOT" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHELL=/bin/zsh \
      PATH=/usr/bin:/bin /bin/bash -c '
        cd "$TEST_ROOT_DIR"
        source ./install.sh
      ' 2>&1
  )
  mismatch_denied_status=$?
  set -e
  [ "$mismatch_denied_status" -ne 0 ] || fail_test "shell mismatch unexpectedly proceeded without permission"
  assert_contains "$mismatch_denied_output" 'startup shell discrepancy: configured=/bin/zsh running=/bin/bash'
  assert_contains "$mismatch_denied_output" 'source ./install.sh --shell bash'
  assert_contains "$mismatch_denied_output" 'Proceed with zsh startup integration? [y/N]'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"

  mismatch_allowed_output=$(
    printf 'yes\n' | env TEST_ROOT_DIR="$SHIMMY_TEST_CLEAN_SOURCE_ROOT" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHELL=/bin/zsh \
      PATH=/usr/bin:/bin /bin/bash -c '
        cd "$TEST_ROOT_DIR"
        source ./install.sh
      ' 2>&1
  )
  assert_contains "$mismatch_allowed_output" 'startup shell discrepancy: configured=/bin/zsh running=/bin/bash'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'startup_shell=zsh'
  assert_file_contains "$HOME_DIR/.zshrc" '# >>> shimmy default profile >>>'
  pass "startup shell discrepancy requires consent before managed installation"
}

test_commands_startup_run() {
  test_commands_startup_inferred_and_manual_policy
  test_commands_startup_managed_policy_lifecycle
  test_commands_startup_shell_mismatch_confirmation
  test_commands_startup_failure_retry
}
