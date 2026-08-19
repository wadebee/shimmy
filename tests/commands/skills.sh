#!/bin/sh

test_commands_skills_activation_guidance_assert() {
  skills_root=$1

  assert_file_contains "$skills_root/shimmy-init/SKILL.md" '"$profile_root/bin/shimmy" profile activate --dry-run'
  assert_file_contains "$skills_root/shimmy-init/SKILL.md" 'separate explicit user confirmation'
  assert_file_contains "$skills_root/shimmy-init/SKILL.md" 'podman machine init shimmy-<profile>'
  assert_file_contains "$skills_root/shimmy-init/SKILL.md" 'Do not provision, delete, rename, or adopt a machine.'
  assert_file_contains "$skills_root/shimmy-init/SKILL.md" 'require status to report current'
  assert_file_contains "$skills_root/shimmy-init/SKILL.md" 'combined `bootstrap.sh --activate` human convenience'
  assert_file_contains "$skills_root/shimmy-install/SKILL.md" 'exact absolute `bin/shimmy profile activate` command'
  assert_file_contains "$skills_root/shimmy-install/SKILL.md" 'separate explicit confirmation'
  assert_file_contains "$skills_root/shimmy-install/SKILL.md" '`./bootstrap.sh` checkout bootstrap'
  assert_file_contains "$skills_root/shimmy-install/SKILL.md" 'hard compatibility'
  assert_file_contains "$skills_root/shimmy-install/SKILL.md" 'shimmy uninstall --global'
  assert_file_contains "$skills_root/shimmy-install/SKILL.md" '`--activate` is a human checkout-bootstrap convenience'
  assert_file_contains "$skills_root/shimmy-install/SKILL.md" 'does not authorize an AI Agent'
  assert_file_contains "$skills_root/shimmy-install/SKILL.md" 'podman machine init'
  assert_file_contains "$skills_root/shimmy-install/SKILL.md" '`shimmy images verify` mount only a valid current'
  assert_file_contains "$skills_root/shimmy-escalation/SKILL.md" 'unverified from the sandbox'
  assert_file_contains "$skills_root/shimmy-escalation/SKILL.md" 'Retry the same wrapper operation'
  assert_file_contains "$skills_root/shimmy-escalation/SKILL.md" '["rg"]'
  assert_file_contains "$skills_root/shimmy-init/SKILL.md" 'Require a failed wrapper invocation'
  assert_file_contains "$skills_root/shimmy-tool-jq/SKILL.md" '"$profile_root/bin/shimmy" profile activate --dry-run'
  assert_file_contains "$skills_root/shimmy-tool-jq/SKILL.md" 'Running containers'
  assert_file_contains "$skills_root/shimmy-tool-jq/SKILL.md" 'agents never run direct Podman'
  for tool_skill_file in "$skills_root"/shimmy-tool-*/SKILL.md; do
    case "$tool_skill_file" in
      */shimmy-tool-local-build/SKILL.md) continue ;;
    esac
    assert_file_contains "$tool_skill_file" '## AI Agent Evidence Order'
    assert_file_contains "$tool_skill_file" 'unverified from the sandbox'
    assert_file_contains "$tool_skill_file" 'Retry the same wrapper operation'
    assert_file_contains "$tool_skill_file" 'Use `shimmy-init` only if the escalated wrapper still proves'
    assert_file_contains "$tool_skill_file" 'Approval scope:'
  done
}

test_commands_skills_export_inventory() {
  export_inventory_root=$1

  (
    cd "$export_inventory_root"
    find . -type f -print | LC_ALL=C sort | while IFS= read -r export_inventory_path; do
      export_inventory_checksum=$(cksum < "$export_inventory_path")
      set -- $export_inventory_checksum
      printf '%s|%s|%s\n' "${export_inventory_path#./}" "$1" "$2"
    done
  )
}

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
    assert_file_contains "$ROOT_DIR/tools/$tool_name/SKILL.md" '## AI Agent Evidence Order'
    assert_file_contains "$ROOT_DIR/tools/$tool_name/SKILL.md" 'unverified from the sandbox'
    assert_file_contains "$ROOT_DIR/tools/$tool_name/SKILL.md" 'Retry the same wrapper operation'
    assert_file_contains "$ROOT_DIR/tools/$tool_name/SKILL.md" 'Use `shimmy-init` only if the escalated wrapper still proves'
    assert_file_contains "$ROOT_DIR/tools/$tool_name/SKILL.md" 'Approval scope:'
    assert_path_not_exists "$ROOT_DIR/tools/$tool_name/agent"
    tool_skill_count=$((tool_skill_count + 1))
  done
  assert_equals "$tool_skill_count" 20
  assert_file_contains "$ROOT_DIR/.agents/plugins/marketplace.json" '"path": "./plugins/shimmy"'
  assert_file_contains "$ROOT_DIR/docs/templates/generic-shim/SKILL.md" 'tool-specific approval rule'
  assert_file_contains "$ROOT_DIR/docs/templates/generic-shim/SKILL.md" 'unverified from the sandbox'
  assert_file_contains "$ROOT_DIR/docs/templates/generic-shim/SKILL.md" 'Add an `Approval scope:` rule specific to the tool.'
  pass "management plugin and co-located tool skills have the final split ownership"
}

test_commands_skills_profile_payload_absence() {
  for skill_name in shimmy-install shimmy-init shimmy-create-tool shimmy-escalation shimmy-tool-local-build; do
    assert_path_not_exists "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/$skill_name/SKILL.md"
  done

  for tool_name in $(shimmy_tool_list); do
    assert_path_not_exists "$DEFAULT_PROFILE_ROOT/tools/$tool_name/SKILL.md"
  done

  pass "profile payload excludes catalog-owned management and tool skill sources"
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
  default_shimmy install --shim task >/dev/null
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
  test_commands_skills_activation_guidance_assert "$export_root"
  assert_file_contains "$export_root/shimmy-tool-skopeo/SKILL.md" 'strict redirect policy read-only'
  assert_file_contains "$export_root/shimmy-tool-oc/SKILL.md" 'replacement location has no configured upstream fallback'
  assert_file_contains "$export_root/shimmy-tool-task/SKILL.md" 'never print its value'
  directory_export_inventory=$(test_commands_skills_export_inventory "$export_root")

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
  archive_top_level_count=0
  for archive_top_level_path in \
    "$archive_extract_root"/* \
    "$archive_extract_root"/.[!.]* \
    "$archive_extract_root"/..?*
  do
    [ -e "$archive_top_level_path" ] || [ -L "$archive_top_level_path" ] || continue
    assert_equals "$(basename "$archive_top_level_path")" shimmy-skills
    archive_top_level_count=$((archive_top_level_count + 1))
  done
  assert_equals "$archive_top_level_count" 1
  archive_skills_root=$archive_extract_root/shimmy-skills
  assert_dir_exists "$archive_skills_root"
  assert_file_exists "$archive_skills_root/.shimmy-skills-manifest.txt"
  assert_file_exists "$archive_skills_root/shimmy-install/SKILL.md"
  assert_file_exists "$archive_skills_root/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$archive_skills_root/shimmy-tool-rg/SKILL.md"
  assert_file_exists "$archive_skills_root/shimmy-tool-task/SKILL.md"
  archive_export_inventory=$(test_commands_skills_export_inventory "$archive_skills_root")
  assert_equals "$archive_export_inventory" "$directory_export_inventory"
  pass "portable directory and archive exports have identical complete inventories"
}

test_commands_skills_stale_manifest_filtering() {
  stale_manifest_work_dir=$WORK_DIR/stale-manifest
  repo_skills_root=$stale_manifest_work_dir/.agents/skills
  mkdir -p "$stale_manifest_work_dir"
  mkdir -p "$repo_skills_root/shimmy-install" "$repo_skills_root/shimmy-tool-retired"
  cp "$ROOT_DIR/plugins/shimmy/skills/shimmy-install/SKILL.md" \
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
    cd "$stale_manifest_work_dir"
    default_shimmy skills update --target repo >/dev/null
  )

  assert_file_exists "$repo_skills_root/shimmy-install/SKILL.md"
  assert_file_exists "$repo_skills_root/shimmy-tool-retired/SKILL.md"
  assert_file_not_contains "$repo_skills_root/.shimmy-skills-manifest.txt" 'shimmy-tool-retired'
  pass "skill update filters stale manifest entries without deleting untracked siblings"
}

test_commands_skills_removed_plugin_target() {
  removed_target_work_dir=$WORK_DIR/removed-target
  plugin_sentinel=$DEFAULT_PROFILE_ROOT/unmanaged-plugin-sentinel
  override_root=$SCENARIO_DIR/plugin-override
  mkdir -p "$removed_target_work_dir"
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
    assert_path_not_exists "$removed_target_work_dir/.agents"
    assert_path_not_exists "$HOME_DIR/.agents"
  done

  set +e
  unknown_output=$(
    cd "$removed_target_work_dir"
    default_shimmy skills install shimmy-tool-unknown 2>&1
  )
  unknown_status=$?
  set -e
  [ "$unknown_status" -ne 0 ] || fail_test "unknown canonical skill unexpectedly accepted"
  assert_contains "$unknown_output" 'missing canonical source skill: shimmy-tool-unknown'
  assert_path_not_exists "$removed_target_work_dir/.agents"

  (
    cd "$removed_target_work_dir"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
      SHIMMY_SKILLS_PLUGIN_DIR="$override_root" \
      "$DEFAULT_PROFILE_ROOT/bin/shimmy" skills install --target repo >/dev/null
  )
  assert_file_contains "$override_root/sentinel" keep
  assert_file_exists "$removed_target_work_dir/.agents/skills/shimmy-install/SKILL.md"
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
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/plugins"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/plugins"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/tools/jq/SKILL.md"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/tools/rg/SKILL.md"

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
    test_commands_skills_activation_guidance_assert "$skills_root"
    printf '%s\n' keep > "$skills_root/unknown-sibling"
  done
  repo_skills_manifest_checksum=$(cksum < "$repo_skills_manifest")
  profile_skills_manifest_checksum=$(cksum < "$profile_skills_manifest")

  (
    cd "$WORK_DIR"
    default_shimmy install --shim jq >/dev/null
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
  external_failure_work_dir=$WORK_DIR/external-failure
  manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  mkdir -p "$external_failure_work_dir/.agents"
  printf '%s\n' collision > "$external_failure_work_dir/.agents/skills"
  set +e
  failure_output=$(
    cd "$external_failure_work_dir"
    default_shimmy skills install --target repo 2>&1
  )
  failure_status=$?
  set -e
  [ "$failure_status" -ne 0 ] || fail_test "skills target collision unexpectedly succeeded"
  assert_not_empty "$failure_output"
  assert_contains "$(default_shimmy status --format manifest)" 'shimmy_installed=yes'
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$manifest_checksum"

  rm -f "$external_failure_work_dir/.agents/skills"
  (
    cd "$external_failure_work_dir"
    default_shimmy skills install --target repo >/dev/null
  )
  assert_file_exists "$external_failure_work_dir/.agents/skills/.shimmy-skills-manifest.txt"
  pass "standalone skills failure leaves the installed profile unchanged and can be retried directly"
}

test_commands_skills_catalog_authority() {
  setup_scenario_with_profiles default upstream
  live_checkout=$SCENARIO_DIR/live-checkout
  test_fixture_tree_copy "$SHIMMY_TEST_CLEAN_SOURCE_ROOT" "$live_checkout"
  upstream_shimmy catalog rebind --checkout "$live_checkout" >/dev/null
  default_manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  upstream_manifest_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")

  test_catalog_tool_create "$live_checkout" instant
  printf '%s\n' 'Live upstream skill marker.' >> "$live_checkout/tools/instant/SKILL.md"
  upstream_export=$SCENARIO_DIR/upstream-instant
  upstream_shimmy skills install --export "$upstream_export" shimmy-tool-instant >/dev/null
  assert_file_contains "$upstream_export/shimmy-tool-instant/SKILL.md" 'Live upstream skill marker.'

  default_unpublished_export=$SCENARIO_DIR/default-unpublished
  set +e
  default_unpublished_output=$(default_shimmy skills install --export "$default_unpublished_export" shimmy-tool-instant 2>&1)
  default_unpublished_status=$?
  set -e
  [ "$default_unpublished_status" -ne 0 ] || fail_test 'default catalog exported an unpublished upstream skill'
  assert_contains "$default_unpublished_output" 'missing canonical source skill: shimmy-tool-instant'
  assert_path_not_exists "$default_unpublished_export"

  git -C "$live_checkout" add tools/instant
  git -C "$live_checkout" commit -qm 'add instant tool skill'
  upstream_shimmy catalog publish >/dev/null

  default_export=$SCENARIO_DIR/default-instant
  default_shimmy skills install --export "$default_export" shimmy-tool-instant >/dev/null
  assert_file_contains "$default_export/shimmy-tool-instant/SKILL.md" 'Live upstream skill marker.'
  default_selection_export=$SCENARIO_DIR/default-selection
  default_shimmy skills install --export "$default_selection_export" >/dev/null
  assert_file_exists "$default_selection_export/shimmy-install/SKILL.md"
  assert_file_exists "$default_selection_export/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$default_selection_export/shimmy-tool-rg/SKILL.md"
  assert_path_not_exists "$default_selection_export/shimmy-tool-instant"
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$default_manifest_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" "$upstream_manifest_checksum"
  pass "skills resolve live upstream additions immediately and immutable default additions only after publication"
}

test_commands_skills_catalog_failure_boundaries() {
  catalog_failure_work_dir=$WORK_DIR/catalog-failure
  repo_skills_root=$catalog_failure_work_dir/.agents/skills
  mkdir -p "$catalog_failure_work_dir"
  (
    cd "$catalog_failure_work_dir"
    default_shimmy skills install --target repo >/dev/null
  )
  skills_manifest_checksum=$(cksum < "$repo_skills_root/.shimmy-skills-manifest.txt")
  install_skill_checksum=$(cksum < "$repo_skills_root/shimmy-install/SKILL.md")
  default_registry=$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf
  default_generation=$(profile_manifest_value "$default_registry" catalog_generation_current)
  default_catalog_file=$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/generations/$default_generation/catalog.conf
  cp "$default_catalog_file" "$SCENARIO_DIR/catalog.conf.valid"
  printf '%s\n' 'catalog_format=shimmy-catalog' 'catalog_schema=2' > "$default_catalog_file"

  set +e
  schema_output=$(
    cd "$catalog_failure_work_dir"
    default_shimmy skills update --target repo 2>&1
  )
  schema_status=$?
  set -e
  [ "$schema_status" -ne 0 ] || fail_test 'schema-incompatible catalog unexpectedly updated a skills target'
  assert_contains "$schema_output" "accepted schema: 1"
  assert_equals "$(cksum < "$repo_skills_root/.shimmy-skills-manifest.txt")" "$skills_manifest_checksum"
  assert_equals "$(cksum < "$repo_skills_root/shimmy-install/SKILL.md")" "$install_skill_checksum"

  (
    cd "$catalog_failure_work_dir"
    default_shimmy skills uninstall --target repo >/dev/null
  )
  assert_path_not_exists "$repo_skills_root/.shimmy-skills-manifest.txt"
  assert_path_not_exists "$repo_skills_root/shimmy-install"
  cp "$SCENARIO_DIR/catalog.conf.valid" "$default_catalog_file"

  mv "$default_registry" "$SCENARIO_DIR/default-registry.conf"
  unavailable_export=$SCENARIO_DIR/unavailable-export
  set +e
  unavailable_output=$(default_shimmy skills install --export "$unavailable_export" 2>&1)
  unavailable_status=$?
  set -e
  [ "$unavailable_status" -ne 0 ] || fail_test 'missing catalog registry unexpectedly allowed a skills export'
  assert_contains "$unavailable_output" 'missing catalog registry entry'
  assert_path_not_exists "$unavailable_export"
  mv "$SCENARIO_DIR/default-registry.conf" "$default_registry"
  pass "catalog loss and schema mismatch fail before mutation while manifest-owned uninstall remains available"
}

test_commands_skills_default_profile_progression() {
  setup_scenario_with_profiles default
  test_commands_skills_stale_manifest_filtering
  test_commands_skills_removed_plugin_target
  test_commands_skills_external_failure_retry
  test_commands_skills_catalog_failure_boundaries
}

test_commands_skills_run() {
  test_commands_skills_manifest_fingerprints
  test_commands_skills_plugin_and_tool_inventory
  test_commands_skills_profile_payload_absence
  test_commands_skills_portable_exports
  test_commands_skills_default_profile_progression
  test_commands_skills_target_ownership
  test_commands_skills_catalog_authority
}
