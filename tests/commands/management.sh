#!/bin/sh
# Activation, skills, and netinfo command tests.

test_commands_management_activate() {
  activation_output=$(HOME="$HOME_DIR" run_in_repo ./shimmy activate --install-dir "$INSTALL_DIR" --profile default)

  assert_contains "$activation_output" SHIMMY_PROFILE_ACTIVE=
  assert_contains "$activation_output" "$INSTALL_DIR/bin"
  pass "activation renders selected profile shell code"
}

test_commands_management_skills() {
  manifest_file=$INSTALL_DIR/profiles/default/install-manifest.txt
  HOME="$HOME_DIR" run_in_repo ./shimmy skills install --target profile --manifest "$manifest_file" >/dev/null

  skills_root=$HOME_DIR/.agents/skills
  assert_file_exists "$skills_root/.shimmy-skills-manifest.txt"
  assert_file_exists "$skills_root/shimmy-install/SKILL.md"
  assert_file_exists "$skills_root/shimmy-tool-jq/SKILL.md"

  HOME="$HOME_DIR" run_in_repo ./shimmy skills uninstall --target profile >/dev/null
  assert_path_not_exists "$skills_root/.shimmy-skills-manifest.txt"
  assert_path_not_exists "$skills_root/shimmy-tool-jq"
  pass "skills install and uninstall use canonical sources"
}

test_commands_management_netinfo() {
  output=$(run_in_repo ./shimmy netinfo --format manifest --host-ip 192.0.2.10 --host-prefix 24 --target 192.0.2.20)

  assert_contains "$output" host_ipv4=192.0.2.10
  assert_contains "$output" host_lan=192.0.2.0/24
  assert_contains "$output" route_target=
  pass "netinfo renders explicit host network inputs"
}

test_commands_management_argument_errors() {
  set +e
  output=$(run_in_repo ./shimmy update --all --shim jq 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "conflicting update options were accepted"
  assert_contains "$output" "--all cannot be combined with --shim"
  pass "management commands reject conflicting arguments"
}

test_commands_management_run() {
  test_commands_management_activate
  test_commands_management_skills
  test_commands_management_netinfo
  test_commands_management_argument_errors
}
