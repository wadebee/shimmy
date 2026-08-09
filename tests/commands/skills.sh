#!/bin/sh

test_commands_skills_manifest_fingerprints() {
  for skills_manifest in \
    "$ROOT_DIR/.agents/skills/.shimmy-skills-manifest.txt" \
    "$ROOT_DIR/plugins/shimmy/skills/.shimmy-skills-manifest.txt"; do
    assert_file_exists "$skills_manifest"
    tracked_skill_count=0

    while IFS= read -r manifest_line; do
      case "$manifest_line" in
        shimmy_skill=*)
          skill_entry=${manifest_line#shimmy_skill=}
          skill_entry=${skill_entry#*|}
          skill_name=${skill_entry%%|*}
          skill_entry=${skill_entry#*|}
          skill_path=${skill_entry%%|*}
          expected_fingerprint=${skill_entry#*|}
          skill_dir=$ROOT_DIR/$skill_path
          assert_dir_exists "$skill_dir"

          fingerprint_output=$(
            (
              cd "$skill_dir"
              find . -type f -print | LC_ALL=C sort | while IFS= read -r skill_file; do
                cksum "$skill_file"
                printf ' %s\n' "$skill_file"
              done
            ) | cksum
          )
          set -- $fingerprint_output
          actual_fingerprint=$1-$2
          [ "$actual_fingerprint" = "$expected_fingerprint" ] ||
            fail_test "stale checked-in fingerprint for $skill_name: expected $expected_fingerprint, got $actual_fingerprint"
          tracked_skill_count=$((tracked_skill_count + 1))
          ;;
      esac
    done < "$skills_manifest"

    [ "$tracked_skill_count" -gt 0 ] || fail_test "expected tracked skills in $skills_manifest"
  done

  pass "checked-in repo and plugin skill manifests match their exported skill trees"
}

test_commands_skills_target_ownership() {
  setup_scenario
  (
    cd "$WORK_DIR"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$ROOT_DIR/install.sh" --profile default --no-startup --skills-target repo >/dev/null
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$ROOT_DIR/install.sh" --profile upstream --no-startup --skills-target repo >/dev/null
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
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$ROOT_DIR/install.sh" --profile default --no-startup --skills-target repo 2>&1
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
  test_commands_skills_manifest_fingerprints
  test_commands_skills_target_ownership
  test_commands_skills_external_failure_retry
}
