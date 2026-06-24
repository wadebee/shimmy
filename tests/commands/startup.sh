#!/bin/sh
# Activation and managed shell-startup tests.

test_commands_startup_activate_idempotent() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null
  activation_code=$(HOME="$HOME_DIR" run_in_repo ./shimmy activate --install-dir "$INSTALL_DIR" --profile default)
  activation_profile=$(
    /bin/sh -c '
      eval "$1"
      eval "$1"
      case ":$PATH:" in
        *":$2:$2:"*) exit 1 ;;
      esac
      [ "$SHIMMY_PROFILE_ACTIVE" = default ] || exit 1
      printf "%s\n" "$SHIMMY_PROFILE_ACTIVE"
    ' sh "$activation_code" "$INSTALL_DIR/bin"
  )

  assert_equals "$activation_profile" default
  pass "activation is idempotent and exports the selected profile"
}

test_commands_startup_install_idempotent() {
  setup_scenario
  startup_file=$HOME_DIR/.zshrc
  printf '# user configuration\n' > "$startup_file"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shell zsh --startup-file "$startup_file" --no-skills >/dev/null
  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shell zsh --startup-file "$startup_file" --no-skills >/dev/null

  assert_file_contains "$startup_file" "# user configuration"
  assert_file_contains "$startup_file" "# >>> shimmy onboarding >>>"
  assert_file_contains "$startup_file" "# <<< shimmy onboarding <<<"
  marker_count=$(grep -F "# >>> shimmy onboarding >>>" "$startup_file" | wc -l | tr -d ' ')
  assert_equals "$marker_count" 1
  pass "install writes one managed startup block to an explicit file"
}

test_commands_startup_update_repair() {
  setup_scenario
  startup_file=$HOME_DIR/.zshrc

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null
  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --repair-startup --shell zsh --startup-file "$startup_file" >/dev/null

  assert_file_contains "$startup_file" "# >>> shimmy onboarding >>>"
  assert_file_contains "$startup_file" "# <<< shimmy onboarding <<<"
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" "startup_file=$startup_file"
  pass "update --repair-startup restores explicit startup integration"
}

test_commands_startup_run() {
  test_commands_startup_activate_idempotent
  test_commands_startup_install_idempotent
  test_commands_startup_update_repair
}
