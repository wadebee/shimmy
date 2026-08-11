#!/bin/sh

test_commands_skills_source_file_resolve() {
  skill_name=$1

  case "$skill_name" in
    shimmy-install|shimmy-init|shimmy-create-tool|shimmy-escalation|shimmy-tool-local-build)
      printf '%s/plugins/shimmy/skills/%s/SKILL.md\n' "$ROOT_DIR" "$skill_name"
      ;;
    shimmy-tool-*)
      printf '%s/tools/%s/SKILL.md\n' "$ROOT_DIR" "${skill_name#shimmy-tool-}"
      ;;
    *)
      fail_test "unknown canonical skill in test inventory: $skill_name"
      ;;
  esac
}

test_commands_skills_manifest_fingerprints() {
  skills_manifest=$ROOT_DIR/.agents/skills/.shimmy-skills-manifest.txt
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
  pass "checked-in repository skill manifest matches its one-file adapters"
}

test_commands_skills_plugin_and_tool_inventory() {
  control_skills='shimmy-install
shimmy-init
shimmy-create-tool
shimmy-escalation
shimmy-tool-local-build'
  plugin_skill_count=0

  assert_path_not_exists "$ROOT_DIR/plugins/shimmy/skills/.shimmy-skills-manifest.txt"
  for plugin_skill_dir in "$ROOT_DIR"/plugins/shimmy/skills/*; do
    [ -d "$plugin_skill_dir" ] || continue
    skill_name=$(basename "$plugin_skill_dir")
    shimmy_contains_line_list "$control_skills" "$skill_name" ||
      fail_test "unexpected skill in management plugin: $skill_name"
    assert_file_exists "$plugin_skill_dir/SKILL.md"
    assert_file_contains "$plugin_skill_dir/SKILL.md" "name: $skill_name"
    assert_path_not_exists "$plugin_skill_dir/CONTEXT.md"
    plugin_skill_count=$((plugin_skill_count + 1))
  done
  assert_equals "$plugin_skill_count" 5

  tool_skill_count=0
  for tool_name in $(shimmy_tool_list); do
    assert_file_exists "$ROOT_DIR/tools/$tool_name/SKILL.md"
    assert_file_contains "$ROOT_DIR/tools/$tool_name/SKILL.md" "name: shimmy-tool-$tool_name"
    assert_path_not_exists "$ROOT_DIR/tools/$tool_name/agent"
    tool_skill_count=$((tool_skill_count + 1))
  done
  assert_equals "$tool_skill_count" 18
  assert_file_contains "$ROOT_DIR/.agents/plugins/marketplace.json" '"path": "./plugins/shimmy"'
  pass "management plugin and co-located tool skills have the final split ownership"
}

test_commands_skills_profile_payload_semantic_parity() {
  for skill_name in shimmy-install shimmy-init shimmy-create-tool shimmy-escalation shimmy-tool-local-build; do
    source_file=$(test_commands_skills_source_file_resolve "$skill_name")
    installed_file=$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/$skill_name/SKILL.md
    cmp -s "$source_file" "$installed_file" ||
      fail_test "installed management skill differs from canonical SKILL.md: $skill_name"
  done

  for tool_name in $(shimmy_tool_list); do
    cmp -s "$ROOT_DIR/tools/$tool_name/SKILL.md" "$DEFAULT_PROFILE_ROOT/tools/$tool_name/SKILL.md" ||
      fail_test "installed tool skill differs from canonical SKILL.md: shimmy-tool-$tool_name"
  done

  pass "profile payload preserves semantic parity with split canonical skill sources"
}

test_commands_skills_portable_exports() {
  setup_scenario_with_profiles default
  control_skills='shimmy-install
shimmy-init
shimmy-create-tool
shimmy-escalation
shimmy-tool-local-build'
  all_skills=$control_skills
  for tool_name in $(shimmy_tool_list); do
    all_skills=$(shimmy_append_line_list "$all_skills" "shimmy-tool-$tool_name")
  done

  default_export_root=$SCENARIO_DIR/default-skills
  default_shimmy skills install --export "$default_export_root" >/dev/null
  assert_file_exists "$default_export_root/shimmy-install/SKILL.md"
  assert_file_exists "$default_export_root/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$default_export_root/shimmy-tool-rg/SKILL.md"
  assert_path_not_exists "$default_export_root/shimmy-tool-local-build"
  assert_path_not_exists "$default_export_root/shimmy-tool-task"
  default_shimmy install --shim task --no-startup >/dev/null
  installed_export_root=$SCENARIO_DIR/installed-skills
  default_shimmy skills install --export "$installed_export_root" >/dev/null
  assert_file_exists "$installed_export_root/shimmy-tool-task/SKILL.md"

  export_root=$SCENARIO_DIR/exported-skills
  default_shimmy skills install --export "$export_root" $all_skills >/dev/null
  assert_file_exists "$export_root/.shimmy-skills-manifest.txt"
  for skill_name in $all_skills; do
    assert_file_exists "$export_root/$skill_name/SKILL.md"
    exported_file_count=$(find "$export_root/$skill_name" -type f | wc -l | tr -d ' ')
    assert_equals "$exported_file_count" 1
  done
  assert_path_not_exists "$export_root/shimmy-tool-task/guide.md"
  assert_path_not_exists "$export_root/shimmy-tool-task/tool.conf"
  assert_path_not_exists "$export_root/shimmy-tool-task/tests"
  assert_path_not_exists "$export_root/shimmy-tool-task/versions"

  export_archive=$SCENARIO_DIR/exported-skills.zip
  archive_extract_root=$SCENARIO_DIR/archive
  default_shimmy skills install --export "$export_archive" $all_skills >/dev/null
  mkdir -p "$archive_extract_root"
  if command -v unzip >/dev/null 2>&1; then
    unzip -qq "$export_archive" -d "$archive_extract_root"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m zipfile -e "$export_archive" "$archive_extract_root"
  else
    fail_test "portable archive test requires unzip or python3"
  fi
  for skill_name in $all_skills; do
    archived_skill_dir=$archive_extract_root/shimmy-skills/$skill_name
    assert_file_exists "$archived_skill_dir/SKILL.md"
    archived_file_count=$(find "$archived_skill_dir" -type f | wc -l | tr -d ' ')
    assert_equals "$archived_file_count" 1
  done
  assert_path_not_exists "$archive_extract_root/shimmy-skills/shimmy-tool-task/guide.md"
  pass "portable directory and archive exports contain one SKILL.md per selected skill"
}

test_commands_skills_stale_manifest_filtering() {
  setup_scenario_with_profiles default
  repo_skills_root=$WORK_DIR/.agents/skills
  mkdir -p "$repo_skills_root/shimmy-install" "$repo_skills_root/shimmy-tool-retired"
  cp "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/shimmy-install/SKILL.md" \
    "$repo_skills_root/shimmy-install/SKILL.md"
  printf '%s\n' stale > "$repo_skills_root/shimmy-tool-retired/SKILL.md"
  printf '%s\n' \
    'shimmy_skills_manifest_version=1' \
    'shimmy_skills_target=repo' \
    'shimmy_skills_root=.agents/skills' \
    'shimmy_skill=repo|shimmy-install|.agents/skills/shimmy-install|stale-fingerprint' \
    'shimmy_skill=repo|shimmy-tool-retired|.agents/skills/shimmy-tool-retired|stale-fingerprint' \
    > "$repo_skills_root/.shimmy-skills-manifest.txt"

  (
    cd "$WORK_DIR"
    default_shimmy skills update --target repo >/dev/null
  )

  assert_file_exists "$repo_skills_root/shimmy-install/SKILL.md"
  assert_file_exists "$repo_skills_root/shimmy-tool-retired/SKILL.md"
  assert_file_not_contains "$repo_skills_root/.shimmy-skills-manifest.txt" 'shimmy-tool-retired'
  pass "skill update filters stale manifest entries without deleting untracked siblings"
}

test_commands_skills_removed_plugin_target() {
  setup_scenario_with_profiles default
  plugin_sentinel=$DEFAULT_PROFILE_ROOT/plugins/shimmy/plugin-sentinel
  override_root=$SCENARIO_DIR/plugin-override
  printf '%s\n' keep > "$plugin_sentinel"
  mkdir -p "$override_root"
  printf '%s\n' keep > "$override_root/sentinel"
  plugin_sentinel_checksum=$(cksum < "$plugin_sentinel")
  profile_manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")

  help_output=$(default_shimmy skills --help)
  assert_not_contains "$help_output" '--target plugin'
  for action_name in install update uninstall; do
    set +e
    rejection_output=$(default_shimmy skills "$action_name" --target plugin 2>&1)
    rejection_status=$?
    set -e
    [ "$rejection_status" -ne 0 ] || fail_test "removed plugin target unexpectedly accepted: $action_name"
    assert_contains "$rejection_output" 'unsupported skills target: plugin'
    assert_equals "$(cksum < "$plugin_sentinel")" "$plugin_sentinel_checksum"
    assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$profile_manifest_checksum"
    assert_path_not_exists "$WORK_DIR/.agents"
    assert_path_not_exists "$HOME_DIR/.agents"
  done

  set +e
  unknown_output=$(
    cd "$WORK_DIR"
    default_shimmy skills install shimmy-tool-unknown 2>&1
  )
  unknown_status=$?
  set -e
  [ "$unknown_status" -ne 0 ] || fail_test "unknown canonical skill unexpectedly accepted"
  assert_contains "$unknown_output" 'missing canonical source skill: shimmy-tool-unknown'
  assert_path_not_exists "$WORK_DIR/.agents"

  (
    cd "$WORK_DIR"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      SHIMMY_SKILLS_PLUGIN_DIR="$override_root" \
      "$DEFAULT_PROFILE_ROOT/bin/shimmy" skills install --target repo >/dev/null
  )
  assert_file_contains "$override_root/sentinel" keep
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-install/SKILL.md"
  pass "removed plugin target rejects before mutation and its former environment override is inert"
}

test_commands_skills_target_ownership() {
  setup_scenario_with_profiles default upstream

  repo_skills_root=$WORK_DIR/.agents/skills
  repo_skills_manifest=$repo_skills_root/.shimmy-skills-manifest.txt
  profile_skills_root=$HOME_DIR/.agents/skills
  profile_skills_manifest=$profile_skills_root/.shimmy-skills-manifest.txt
  assert_path_not_exists "$repo_skills_root"
  assert_path_not_exists "$profile_skills_root"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/agent"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/agent"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/shimmy-install/SKILL.md"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/plugins/shimmy/skills/shimmy-install/SKILL.md"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/tools/jq/SKILL.md"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/tools/rg/SKILL.md"

  (
    cd "$WORK_DIR"
    default_shimmy skills install --target repo >/dev/null
    upstream_shimmy skills update --target repo >/dev/null
  )
  default_shimmy skills install --target profile >/dev/null
  upstream_shimmy skills update --target profile >/dev/null

  for skills_root in "$repo_skills_root" "$profile_skills_root"; do
    assert_file_exists "$skills_root/.shimmy-skills-manifest.txt"
    assert_file_exists "$skills_root/shimmy-install/SKILL.md"
    assert_file_exists "$skills_root/shimmy-tool-jq/SKILL.md"
    assert_file_exists "$skills_root/shimmy-tool-rg/SKILL.md"
    generated_file_count=$(find "$skills_root/shimmy-tool-jq" -type f | wc -l | tr -d ' ')
    assert_equals "$generated_file_count" 1
    printf '%s\n' keep > "$skills_root/unknown-sibling"
  done
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
  test_commands_skills_plugin_and_tool_inventory
  test_commands_skills_profile_payload_semantic_parity
  test_commands_skills_portable_exports
  test_commands_skills_stale_manifest_filtering
  test_commands_skills_removed_plugin_target
  test_commands_skills_target_ownership
  test_commands_skills_external_failure_retry
}
