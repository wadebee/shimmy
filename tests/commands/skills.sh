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

test_commands_skills_semantic_parity() {
  for target_name in repo plugin; do
    case "$target_name" in
      repo) skills_root=$ROOT_DIR/.agents/skills ;;
      plugin) skills_root=$ROOT_DIR/plugins/shimmy/skills ;;
    esac
    skills_manifest=$skills_root/.shimmy-skills-manifest.txt

    while IFS= read -r manifest_line; do
      case "$manifest_line" in
        shimmy_skill=*)
          skill_entry=${manifest_line#shimmy_skill=}
          skill_entry=${skill_entry#*|}
          skill_name=${skill_entry%%|*}
          if [ -d "$ROOT_DIR/agent/core/$skill_name" ]; then
            source_dir=$ROOT_DIR/agent/core/$skill_name
          else
            source_dir=$ROOT_DIR/tools/${skill_name#shimmy-tool-}/agent
          fi
          assert_dir_exists "$source_dir"
          case "$target_name" in
            repo)
              generated_file_count=$(find "$skills_root/$skill_name" -type f | wc -l | tr -d ' ')
              assert_equals "$generated_file_count" 1
              assert_file_exists "$skills_root/$skill_name/SKILL.md"
              cmp -s "$source_dir/SKILL.md" "$skills_root/$skill_name/SKILL.md" ||
                fail_test "generated repo adapter differs from canonical SKILL.md: $skill_name"
              ;;
            plugin)
              diff -qr "$source_dir" "$skills_root/$skill_name" >/dev/null 2>&1 ||
                fail_test "generated plugin skill differs from canonical source: $skill_name"
              ;;
          esac
          ;;
      esac
    done < "$skills_manifest"
  done

  pass "repo adapters preserve canonical SKILL.md only and plugin skills preserve complete canonical content"
}

test_commands_skills_target_ownership() {
  setup_scenario_with_profiles default upstream

  repo_skills_root=$WORK_DIR/.agents/skills
  repo_skills_manifest=$repo_skills_root/.shimmy-skills-manifest.txt
  profile_skills_root=$HOME_DIR/.agents/skills
  profile_skills_manifest=$profile_skills_root/.shimmy-skills-manifest.txt
  assert_path_not_exists "$repo_skills_root"
  assert_path_not_exists "$profile_skills_root"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/agent/core/shimmy-install/SKILL.md"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/shimmy-install/SKILL.md"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/agent/core/shimmy-install/SKILL.md"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/plugins/shimmy/skills/shimmy-install/SKILL.md"

  (
    cd "$WORK_DIR"
    default_shimmy skills install --target repo >/dev/null
    upstream_shimmy skills update --target repo >/dev/null
  )
  default_shimmy skills install --target profile >/dev/null
  upstream_shimmy skills update --target profile >/dev/null
  default_shimmy skills update --target plugin >/dev/null

  for skills_root in "$repo_skills_root" "$profile_skills_root"; do
    assert_file_exists "$skills_root/.shimmy-skills-manifest.txt"
    assert_file_exists "$skills_root/shimmy-install/SKILL.md"
    assert_file_exists "$skills_root/shimmy-tool-jq/SKILL.md"
    assert_file_exists "$skills_root/shimmy-tool-rg/SKILL.md"
    assert_path_not_exists "$skills_root/shimmy-install/CONTEXT.md"
    printf '%s\n' keep > "$skills_root/unknown-sibling"
  done
  assert_file_contains "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/.shimmy-skills-manifest.txt" 'shimmy_skills_target=plugin'
  repo_skills_manifest_checksum=$(cksum < "$repo_skills_manifest")
  profile_skills_manifest_checksum=$(cksum < "$profile_skills_manifest")

  (
    cd "$WORK_DIR"
    default_shimmy install --shim jq --no-startup >/dev/null
  )
  assert_equals "$(cksum < "$repo_skills_manifest")" "$repo_skills_manifest_checksum"
  assert_equals "$(cksum < "$profile_skills_manifest")" "$profile_skills_manifest_checksum"

  update_source=$SHIMMY_TEST_UPDATE_SOURCE_REPOSITORY
  test_manifest_source_url_replace "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "$update_source"
  (
    cd "$WORK_DIR"
    default_shimmy update --shim jq >/dev/null
  )
  assert_equals "$(cksum < "$repo_skills_manifest")" "$repo_skills_manifest_checksum"
  assert_equals "$(cksum < "$profile_skills_manifest")" "$profile_skills_manifest_checksum"

  (
    cd "$WORK_DIR"
    default_shimmy uninstall >/dev/null
  )
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/plugins"
  assert_file_exists "$repo_skills_root/shimmy-install/SKILL.md"
  assert_file_exists "$repo_skills_root/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$repo_skills_root/shimmy-tool-rg/SKILL.md"
  assert_file_exists "$profile_skills_root/shimmy-install/SKILL.md"
  assert_file_exists "$profile_skills_root/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$profile_skills_root/shimmy-tool-rg/SKILL.md"

  (
    cd "$WORK_DIR"
    upstream_shimmy skills uninstall --target repo >/dev/null
  )
  upstream_shimmy skills uninstall --target profile >/dev/null
  for skills_root in "$repo_skills_root" "$profile_skills_root"; do
    assert_path_not_exists "$skills_root/shimmy-install"
    assert_path_not_exists "$skills_root/shimmy-tool-jq"
    assert_path_not_exists "$skills_root/shimmy-tool-rg"
    assert_path_not_exists "$skills_root/.shimmy-skills-manifest.txt"
    assert_file_exists "$skills_root/unknown-sibling"
  done
  pass "profile lifecycle preserves explicit repository and home skill targets until standalone uninstall"
}

test_commands_skills_external_failure_retry() {
  setup_scenario_with_profiles default
  manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  mkdir -p "$WORK_DIR/.agents"
  printf '%s\n' collision > "$WORK_DIR/.agents/skills"
  set +e
  failure_output=$(
    cd "$WORK_DIR"
    default_shimmy skills install --target repo 2>&1
  )
  failure_status=$?
  set -e
  [ "$failure_status" -ne 0 ] || fail_test "skills target collision unexpectedly succeeded"
  assert_not_empty "$failure_output"
  assert_contains "$(default_shimmy status --format manifest)" 'shimmy_installed=yes'
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$manifest_checksum"

  rm -f "$WORK_DIR/.agents/skills"
  (
    cd "$WORK_DIR"
    default_shimmy skills install --target repo >/dev/null
  )
  assert_file_exists "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt"
  pass "standalone skills failure leaves the installed profile unchanged and can be retried directly"
}

test_commands_skills_run() {
  test_commands_skills_manifest_fingerprints
  test_commands_skills_semantic_parity
  test_commands_skills_target_ownership
  test_commands_skills_external_failure_retry
}
