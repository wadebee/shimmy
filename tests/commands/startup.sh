#!/bin/sh

test_commands_startup_progressive_success() {
  setup_scenario_with_profiles upstream
  run_in_clean_source env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile default --shell zsh >/dev/null
  assert_file_contains "$HOME_DIR/.zshrc" '# >>> shimmy default profile >>>'
  assert_file_contains "$HOME_DIR/.zshrc" "$DEFAULT_PROFILE_ROOT/shell-init.sh"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "startup_file=$HOME_DIR/.zshrc"
  assert_path_not_exists "$HOME_DIR/.bashrc"
  assert_path_not_exists "$HOME_DIR/.bash_profile"
  pass "default bootstrap configures only the explicitly requested zsh startup file"

  run_in_clean_source env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHELL=/bin/sh ./install.sh --profile default >/dev/null
  for startup_file in "$HOME_DIR/.zshrc" "$HOME_DIR/.bashrc" "$HOME_DIR/.bash_profile"; do
    assert_file_contains "$startup_file" '# >>> shimmy default profile >>>'
    assert_file_contains "$startup_file" "$DEFAULT_PROFILE_ROOT/shell-init.sh"
    assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "startup_file=$startup_file"
  done
  assert_not_contains "$(sed -n 's/^startup_shell=//p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" 'sh'
  pass "repeated default bootstrap adopts automatic multi-shell startup integration"

  startup_file=$HOME_DIR/.zshrc
  default_shimmy install --shim jq --shell zsh --startup-file "$startup_file" >/dev/null
  marker_count=$(grep -Fxc '# >>> shimmy default profile >>>' "$startup_file")
  manifest_entry_count=$(grep -Fxc "startup_file=$startup_file" "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  assert_equals "$marker_count" 1
  assert_equals "$manifest_entry_count" 1
  pass "default startup integration is profile-specific and idempotent"

  upstream_startup_file=$SCENARIO_DIR/upstream-zshrc
  default_manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  upstream_manifest_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")
  startup_zsh_checksum=$(cksum < "$HOME_DIR/.zshrc")
  startup_bash_interactive_checksum=$(cksum < "$HOME_DIR/.bashrc")
  startup_bash_login_checksum=$(cksum < "$HOME_DIR/.bash_profile")

  set +e
  upstream_install_output=$(upstream_shimmy install --shell zsh --startup-file "$upstream_startup_file" 2>&1)
  upstream_install_status=$?
  upstream_update_output=$(upstream_shimmy update --repair-startup --shell zsh --startup-file "$upstream_startup_file" 2>&1)
  upstream_update_status=$?
  set -e
  [ "$upstream_install_status" -ne 0 ] || fail_test "upstream install startup mutation unexpectedly succeeded"
  [ "$upstream_update_status" -ne 0 ] || fail_test "upstream update startup mutation unexpectedly succeeded"
  assert_contains "$upstream_install_output" 'upstream has no persistent startup integration'
  assert_contains "$upstream_install_output" "$UPSTREAM_PROFILE_ROOT/shell-init.sh"
  assert_contains "$upstream_update_output" 'upstream has no persistent startup integration'
  assert_contains "$upstream_update_output" "$UPSTREAM_PROFILE_ROOT/shell-init.sh"
  assert_path_not_exists "$upstream_startup_file"
  assert_equals "$(cksum < "$HOME_DIR/.zshrc")" "$startup_zsh_checksum"
  assert_equals "$(cksum < "$HOME_DIR/.bashrc")" "$startup_bash_interactive_checksum"
  assert_equals "$(cksum < "$HOME_DIR/.bash_profile")" "$startup_bash_login_checksum"
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$default_manifest_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" "$upstream_manifest_checksum"
  pass "upstream rejects all startup mutation without changing either profile or startup file"
}

test_commands_startup_external_failure_retry() {
  setup_scenario
  invalid_startup_file=$SCENARIO_DIR/startup-as-directory
  mkdir -p "$invalid_startup_file"
  set +e
  failure_output=$(run_in_clean_source env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile default --shell zsh --startup-file "$invalid_startup_file" 2>&1)
  failure_status=$?
  set -e
  [ "$failure_status" -ne 0 ] || fail_test "invalid startup target unexpectedly succeeded"
  assert_contains "$failure_output" 'profile installed, but startup integration failed'
  assert_contains "$failure_output" 'retry with'
  assert_contains "$(default_shimmy status --format manifest)" 'shimmy_installed=yes'

  retry_file=$SCENARIO_DIR/retry-zshrc
  default_shimmy install --shim jq --shell zsh --startup-file "$retry_file" >/dev/null
  assert_file_contains "$retry_file" '# >>> shimmy default profile >>>'
  pass "startup integration failure leaves a valid profile and an independently repeatable repair path"
}

test_commands_startup_run() {
  test_commands_startup_progressive_success
  test_commands_startup_external_failure_retry
}
