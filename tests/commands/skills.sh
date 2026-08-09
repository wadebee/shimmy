#!/bin/sh

test_commands_skills_target_ownership() {
  setup_scenario
  (
    cd "$WORK_DIR"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$ROOT_DIR/install.sh" --profile default --shim jq --no-startup --skills-target repo >/dev/null
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$ROOT_DIR/install.sh" --profile upstream --shim rg --no-startup --skills-target repo >/dev/null
  )
  skills_root=$WORK_DIR/.agents/skills
  skills_manifest=$skills_root/.shimmy-skills-manifest.txt
  assert_file_exists "$skills_manifest"
  assert_file_exists "$skills_root/shimmy-install/SKILL.md"
  assert_file_exists "$skills_root/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$skills_root/shimmy-tool-rg/SKILL.md"
  printf '%s\n' keep > "$skills_root/unknown-sibling"
  skills_manifest_checksum=$(cksum < "$skills_manifest")

  default_shimmy install --refresh-shims --shim jq --no-startup --no-skills >/dev/null
  assert_equals "$(cksum < "$skills_manifest")" "$skills_manifest_checksum"

  update_source=$SCENARIO_DIR/update-source
  test_update_source_repository_create "$update_source"
  test_manifest_source_url_replace "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "$update_source"
  default_shimmy update --shim jq >/dev/null
  assert_equals "$(cksum < "$skills_manifest")" "$skills_manifest_checksum"

  default_shimmy uninstall --no-skills >/dev/null
  assert_file_exists "$skills_root/shimmy-install/SKILL.md"
  assert_file_exists "$skills_root/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$skills_root/shimmy-tool-rg/SKILL.md"

  (
    cd "$WORK_DIR"
    upstream_shimmy skills uninstall --target repo >/dev/null
  )
  assert_path_not_exists "$skills_root/shimmy-install"
  assert_path_not_exists "$skills_root/shimmy-tool-jq"
  assert_path_not_exists "$skills_root/shimmy-tool-rg"
  assert_path_not_exists "$skills_manifest"
  assert_file_exists "$skills_root/unknown-sibling"
  pass "combined profiles share idempotent target-manifest-owned skills that only explicit uninstall removes"
}

test_commands_skills_external_failure_retry() {
  setup_scenario
  mkdir -p "$WORK_DIR/.agents"
  printf '%s\n' collision > "$WORK_DIR/.agents/skills"
  set +e
  failure_output=$(
    cd "$WORK_DIR"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$ROOT_DIR/install.sh" --profile default --shim jq --no-startup --skills-target repo 2>&1
  )
  failure_status=$?
  set -e
  [ "$failure_status" -ne 0 ] || fail_test "skills target collision unexpectedly succeeded"
  assert_contains "$failure_output" 'profile installed, but skills integration failed'
  assert_contains "$failure_output" 'retry with'
  assert_contains "$(default_shimmy status --format manifest)" 'shimmy_installed=yes'

  rm -f "$WORK_DIR/.agents/skills"
  (
    cd "$WORK_DIR"
    default_shimmy skills install --target repo >/dev/null
  )
  assert_file_exists "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt"
  pass "skills integration failure leaves a valid profile and an independently repeatable repair path"
}

test_commands_skills_run() {
  test_commands_skills_target_ownership
  test_commands_skills_external_failure_retry
}
