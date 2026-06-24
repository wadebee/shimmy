#!/bin/sh
# Public test-command request validation.

test_commands_test_fake_wrapper_write() {
  wrapper_path=$1
  marker_text=$2
  marker_quoted=$(shimmy_quote_shell_word "$marker_text")

  {
    printf '%s\n' '#!/bin/sh' 'set -eu'
    printf 'marker=%s\n' "$marker_quoted"
    printf '%s\n' 'printf "%s|%s|%s|%s\\n" "$marker" "${SHIMMY_PROFILE_ACTIVE:-}" "${SHIMMY_OC_VERSION:-}" "$*" >> "${SHIMMY_TEST_RECORD:?}"'
  } > "$wrapper_path"
  chmod 755 "$wrapper_path"
}

test_commands_test_profile_config_validation() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null
  rm -f "$INSTALL_DIR/profiles/default/config/shims/jq.conf"

  set +e
  output=$(HOME="$HOME_DIR" "$INSTALL_DIR/bin/shimmy" test --profile default --shim jq 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "test accepted a missing installed shim config"
  assert_contains "$output" "missing installed shim config:"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --refresh-shims --shim jq --no-startup --no-skills >/dev/null
  printf '%s\n' 'shim_config_version=1' 'shim_name=jq' > "$INSTALL_DIR/profiles/default/config/shims/jq_1_8.conf"

  set +e
  output=$(HOME="$HOME_DIR" "$INSTALL_DIR/bin/shimmy" test --profile default --shim jq 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "test accepted a missing smoke argument"
  assert_contains "$output" "missing smoke_arg in"
  pass "test validates installed smoke metadata before execution"
}

test_commands_test_profile_default_dispatch() {
  setup_scenario
  smoke_record=$WORK_DIR/smoke-record.txt

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null
  test_commands_test_fake_wrapper_write "$INSTALL_DIR/profiles/default/bin/jq" default-jq

  output=$(SHIMMY_TEST_RECORD="$smoke_record" HOME="$HOME_DIR" "$INSTALL_DIR/bin/shimmy" test --profile default --shim jq)

  assert_contains "$output" "Selected Shimmy profile: default"
  assert_contains "$output" "public smoke command succeeds for jq in profile default"
  assert_equals "$(cat "$smoke_record")" "default-jq|default||--version"
  pass "test runs installed public dispatchers with version smoke metadata"
}

test_commands_test_profile_precedence() {
  setup_scenario
  smoke_record=$WORK_DIR/smoke-record.txt
  checkout_dir=$(cd -- "$ROOT_DIR" && pwd -P)

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile default --shim jq --no-startup --no-skills >/dev/null
  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null
  test_commands_test_fake_wrapper_write "$INSTALL_DIR/profiles/default/bin/jq" default-jq
  test_commands_test_fake_wrapper_write "$INSTALL_DIR/profiles/upstream/bin/jq" upstream-jq

  SHIMMY_TEST_RECORD="$smoke_record" SHIMMY_PROFILE_ACTIVE=upstream HOME="$HOME_DIR" "$INSTALL_DIR/bin/shimmy" test --shim jq >/dev/null
  assert_equals "$(cat "$smoke_record")" "upstream-jq|upstream||--version"

  : > "$smoke_record"
  SHIMMY_TEST_RECORD="$smoke_record" SHIMMY_PROFILE_ACTIVE=upstream HOME="$HOME_DIR" "$INSTALL_DIR/bin/shimmy" test --profile default --shim jq >/dev/null
  assert_equals "$(cat "$smoke_record")" "default-jq|default||--version"

  set +e
  output=$(SHIMMY_PROFILE_ACTIVE=unsupported HOME="$HOME_DIR" "$INSTALL_DIR/bin/shimmy" test --shim jq 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "test accepted an unsupported active profile"
  assert_contains "$output" "unsupported Shimmy profile: unsupported"
  pass "test uses active-profile fallback and explicit-profile precedence"
}

test_commands_test_profile_request_validation() {
  setup_scenario

  set +e
  output=$(HOME="$HOME_DIR" run_in_repo ./shimmy test --all --shim jq 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "test accepted --all with --shim"
  assert_contains "$output" "--all cannot be combined with --shim"

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --no-startup --no-skills >/dev/null

  set +e
  output=$(HOME="$HOME_DIR" run_in_repo ./shimmy test --install-dir "$INSTALL_DIR" --profile default --shim rg 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "test accepted an uninstalled requested kind"
  assert_contains "$output" "kind rg is not recorded in the selected Shimmy profile"
  pass "test validates installed profile shim requests before smoke execution"
}

test_commands_test_profile_versions_all() {
  setup_scenario
  smoke_record=$WORK_DIR/smoke-record.txt

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim oc@4.18 --no-startup --no-skills >/dev/null
  test_commands_test_fake_wrapper_write "$INSTALL_DIR/profiles/default/bin/oc_4_18" oc-4-18
  test_commands_test_fake_wrapper_write "$INSTALL_DIR/profiles/default/bin/oc_4_20" oc-default

  output=$(SHIMMY_TEST_RECORD="$smoke_record" HOME="$HOME_DIR" "$INSTALL_DIR/bin/shimmy" test --profile default --all)

  assert_contains "$output" "public smoke command succeeds for oc in profile default"
  assert_contains "$output" "version smoke command succeeds for oc_4_18 in profile default"
  assert_contains "$output" "version smoke command succeeds for oc_4_20 in profile default"
  smoke_records=$(cat "$smoke_record")
  assert_contains "$smoke_records" "oc-default|default|4.20|version"
  assert_contains "$smoke_records" "oc-default|default||version"
  assert_contains "$smoke_records" "oc-4-18|default||version"

  : > "$smoke_record"
  SHIMMY_TEST_RECORD="$smoke_record" HOME="$HOME_DIR" "$INSTALL_DIR/bin/shimmy" test --profile default --shim oc@4.18 >/dev/null
  assert_equals "$(cat "$smoke_record")" "oc-4-18|default||version"
  pass "test --all runs installed public and concrete version wrappers"
}

test_commands_test_usage() {
  output=$(run_in_repo ./shimmy test --help)

  assert_contains "$output" "Run Shimmy tests."
  assert_contains "$output" "--profile default|upstream"
  assert_contains "$output" "--shim <name>"
  pass "test documents installed-profile smoke mode"
}

test_commands_test_run() {
  test_commands_test_profile_config_validation
  test_commands_test_profile_default_dispatch
  test_commands_test_profile_precedence
  test_commands_test_profile_request_validation
  test_commands_test_profile_versions_all
  test_commands_test_usage
}
