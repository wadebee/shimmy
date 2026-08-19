#!/bin/sh

test_commands_test_live_smoke_run() {
  if command -v podman >/dev/null 2>&1; then
    live_podman=$(command -v podman)
  elif [ -x /opt/podman/bin/podman ]; then
    live_podman=/opt/podman/bin/podman
  else
    fail_test "Podman is required for installed live smoke coverage"
  fi

  if [ "$(uname -s)" = Darwin ]; then
    live_connection=$(
      "$live_podman" system connection list \
        --format '{{range .}}{{if .Default}}{{.URI}}|{{.Identity}}{{"\n"}}{{end}}{{end}}'
    )
    case "$live_connection" in
      *'|'*) ;;
      *) fail_test "unable to resolve the default Podman connection for installed live smoke coverage" ;;
    esac
    live_connection_uri=${live_connection%%|*}
    live_connection_identity=${live_connection#*|}
    [ -n "$live_connection_uri" ] && [ -n "$live_connection_identity" ] ||
      fail_test "default Podman connection is incomplete for installed live smoke coverage"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_TEST_OS=Linux \
      CONTAINER_HOST="$live_connection_uri" CONTAINER_SSHKEY="$live_connection_identity" \
      "$DEFAULT_PROFILE_ROOT/bin/shimmy" test "$@"
    return
  fi

  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" test "$@"
}

test_commands_test_run() {
  setup_scenario_with_profiles default
  help_output=$(default_shimmy test --help)
  assert_contains "$help_output" 'shimmy test [--shim'
  pass "installed test exposes shim selection help"

  test_commands_test_live_smoke_run --shim jq >/dev/null
  test_commands_test_live_smoke_run --shim jq@1.8 >/dev/null
  test_commands_test_live_smoke_run --all >/dev/null
  pass "installed public, exact-version, and all-version smokes succeed through live Podman"

  failing_smoke_dir=$TMP_ROOT/failing-profile-smoke
  mkdir -p "$failing_smoke_dir"
  failing_smoke=$failing_smoke_dir/failing-smoke
  failing_smoke_config=$failing_smoke_dir/failing-smoke.conf
  printf '%s\n' '#!/bin/sh' 'printf "%s\n" intentional-smoke-failure >&2' 'exit 7' > "$failing_smoke"
  chmod +x "$failing_smoke"
  printf '%s\n' 'shim_config_version=1' 'shim_name=failing_smoke' 'smoke_arg=--version' > "$failing_smoke_config"

  set +e
  failing_smoke_output=$(
    exec 2>&1
    test_profile_smoke_command_run \
      "$failing_smoke" default "$failing_smoke_config" \
      "$failing_smoke_config" version failing_smoke
  )
  failing_smoke_status=$?
  set -e
  [ "$failing_smoke_status" -ne 0 ] || fail_test "failing installed smoke unexpectedly passed"
  assert_contains "$failing_smoke_output" 'intentional-smoke-failure'
  assert_contains "$failing_smoke_output" 'version smoke command failed for failing_smoke'
  pass "installed test fails when a version-owned smoke command fails"
}
