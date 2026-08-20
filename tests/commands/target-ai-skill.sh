#!/bin/sh

test_target_ai_skill_fixture_setup() {
  test_target_shim_fixture_setup
  TARGET_AI_SKILL_HOME_BASE=$SCENARIO_DIR/home%encoded'|path'
  TARGET_AI_SKILL_HOME_SEQUENCE=0
  TARGET_AI_SKILL_CONTROL_SAVED=$SCENARIO_DIR/control.bundle.pristine
  TARGET_AI_SKILL_SHIMS_SAVED=$SCENARIO_DIR/shims.bundle.pristine
  cp "$TARGET_SHIM_PROFILE_ROOT/ai-skills/control/bundle.conf" "$TARGET_AI_SKILL_CONTROL_SAVED"
  cp "$TARGET_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf" "$TARGET_AI_SKILL_SHIMS_SAVED"
}

test_target_ai_skill_fixture_reset() {
  TARGET_AI_SKILL_HOME_SEQUENCE=$((TARGET_AI_SKILL_HOME_SEQUENCE + 1))
  TARGET_AI_SKILL_HOME=$TARGET_AI_SKILL_HOME_BASE-$TARGET_AI_SKILL_HOME_SEQUENCE
  TARGET_AI_SKILL_USER_ROOT=$TARGET_AI_SKILL_HOME/.agents/skills
  case "$TARGET_AI_SKILL_HOME" in "$SCENARIO_DIR"/*) ;; *) fail_test 'escaped target AI-skill fixture home' ;; esac
  mkdir -p "$TARGET_AI_SKILL_USER_ROOT"
  shimmy_target_active_profile_render default "$TARGET_AI_SKILL_USER_ROOT" > "$TARGET_SHIM_CONFIG/active-profile.conf"
  cp "$TARGET_AI_SKILL_CONTROL_SAVED" "$TARGET_SHIM_PROFILE_ROOT/ai-skills/control/bundle.conf"
  cp "$TARGET_AI_SKILL_SHIMS_SAVED" "$TARGET_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf"
}

test_target_ai_skill_run() {
  env HOME="$TARGET_AI_SKILL_HOME" SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" \
    "$ROOT_DIR/commands/ai-skill-target.sh" "$@"
}

test_commands_target_ai_skill_materialization_and_list() {
  test_target_ai_skill_fixture_reset
  target_ai_commit=$TARGET_SHIM_PINNED_COMMIT
  target_ai_control_copy=$TARGET_SHIM_PROFILE_ROOT/ai-skills/control-copy
  shimmy_target_ai_skill_control_bundle_materialize "$TARGET_SHIM_CHECKOUT" "$target_ai_commit" \
    default "$target_ai_control_copy" || fail_test 'second deterministic control materialization failed'
  diff -r "$TARGET_SHIM_PROFILE_ROOT/ai-skills/control" "$target_ai_control_copy" >/dev/null ||
    fail_test 'same control commit produced different bundle bytes'
  rm -rf "$target_ai_control_copy"

  target_ai_wrong_profile=$TARGET_SHIM_CONFIG/profiles/team-two/ai-skills/control/skills/shimmy-install
  mkdir -p "$target_ai_wrong_profile"
  ln -s "$target_ai_wrong_profile" "$TARGET_AI_SKILL_USER_ROOT/shimmy-install"
  ln -s "$SCENARIO_DIR/missing-foreign" "$TARGET_AI_SKILL_USER_ROOT/shimmy-init"
  target_ai_list=$(test_target_ai_skill_run list --format manifest)
  assert_contains "$target_ai_list" 'shimmy_ai_skill_bundle=control|valid|6|-'
  assert_contains "$target_ai_list" 'shimmy_ai_skill_bundle=shims|empty|0|-'
  assert_contains "$target_ai_list" 'shimmy_ai_skill=control|shimmy-install|shimmy-link-wrong-profile|'
  assert_contains "$target_ai_list" 'shimmy_ai_skill=control|shimmy-init|foreign-link-broken|'
  assert_contains "$target_ai_list" 'home%25encoded%7Cpath'
  assert_file_contains "$TARGET_SHIM_PROFILE_ROOT/ai-skills/control/bundle.conf" \
    "|control|shimmy-catalog|$target_ai_commit"
  pass 'control and empty shim bundles materialize deterministically and list encoded broken and wrong-profile link state'
}

test_commands_target_ai_skill_exact_repair() {
  test_target_ai_skill_fixture_reset
  target_ai_root_marker=$TARGET_AI_SKILL_USER_ROOT/root-marker
  target_ai_sibling=$TARGET_AI_SKILL_USER_ROOT/custom-skill
  mkdir "$target_ai_sibling"
  printf 'root-survives\n' > "$target_ai_root_marker"
  printf 'sibling-survives\n' > "$target_ai_sibling/SKILL.md"
  target_ai_root_before=$(cksum < "$target_ai_root_marker")
  target_ai_sibling_before=$(cksum < "$target_ai_sibling/SKILL.md")

  printf 'foreign-file\n' > "$TARGET_AI_SKILL_USER_ROOT/shimmy-catalog"
  mkdir "$TARGET_AI_SKILL_USER_ROOT/shimmy-create-tool"
  printf 'foreign-directory\n' > "$TARGET_AI_SKILL_USER_ROOT/shimmy-create-tool/payload"
  target_ai_foreign=$SCENARIO_DIR/foreign-link
  printf 'foreign-link\n' > "$target_ai_foreign"
  ln -s "$target_ai_foreign" "$TARGET_AI_SKILL_USER_ROOT/shimmy-escalation"
  ln -s "$SCENARIO_DIR/missing-foreign" "$TARGET_AI_SKILL_USER_ROOT/shimmy-init"
  target_ai_wrong=$TARGET_SHIM_CONFIG/profiles/team-two/ai-skills/control/skills/shimmy-install
  mkdir -p "$target_ai_wrong"
  ln -s "$target_ai_wrong" "$TARGET_AI_SKILL_USER_ROOT/shimmy-install"
  target_ai_stale=$TARGET_SHIM_PROFILE_ROOT/ai-skills/shims/skills/shimmy-tool-stale
  ln -s "$target_ai_stale" "$TARGET_AI_SKILL_USER_ROOT/shimmy-tool-stale"

  target_ai_repair=$(test_target_ai_skill_run repair 2>&1)
  assert_contains "$target_ai_repair" 'not recoverable'
  assert_contains "$target_ai_repair" 'Remove recognized stale Shimmy link'
  for target_ai_name in $(shimmy_target_ai_skill_control_names_render); do
    assert_path_symlink "$TARGET_AI_SKILL_USER_ROOT/$target_ai_name"
    assert_equals "$(readlink "$TARGET_AI_SKILL_USER_ROOT/$target_ai_name")" \
      "$TARGET_SHIM_PROFILE_ROOT/ai-skills/control/skills/$target_ai_name"
  done
  assert_path_not_exists "$TARGET_AI_SKILL_USER_ROOT/shimmy-tool-stale"
  assert_equals "$(cksum < "$target_ai_root_marker")" "$target_ai_root_before"
  assert_equals "$(cksum < "$target_ai_sibling/SKILL.md")" "$target_ai_sibling_before"
  pass 'repair overwrites every exact collision, removes only recognized stale links, and preserves unrelated user content byte-for-byte'
}

test_commands_target_ai_skill_failure_rollback() {
  test_target_ai_skill_fixture_reset
  target_ai_prior=$TARGET_SHIM_CONFIG/profiles/team-two/ai-skills/control/skills/shimmy-catalog
  mkdir -p "$target_ai_prior"
  ln -s "$target_ai_prior" "$TARGET_AI_SKILL_USER_ROOT/shimmy-catalog"
  printf 'foreign-create\n' > "$TARGET_AI_SKILL_USER_ROOT/shimmy-create-tool"

  set +e
  target_ai_failure=$(env HOME="$TARGET_AI_SKILL_HOME" SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" \
    SHIMMY_TARGET_TEST_MODE=1 SHIMMY_TARGET_TEST_AI_SKILL_FAILURE_AFTER=2 \
    "$ROOT_DIR/commands/ai-skill-target.sh" repair 2>&1)
  target_ai_status=$?
  set -e
  [ "$target_ai_status" -ne 0 ] || fail_test 'injected AI-skill repair failure unexpectedly succeeded'
  assert_contains "$target_ai_failure" 'Rollback result: incomplete'
  assert_contains "$target_ai_failure" 'foreign content is not recoverable'
  assert_equals "$(readlink "$TARGET_AI_SKILL_USER_ROOT/shimmy-catalog")" "$target_ai_prior"
  assert_path_not_exists "$TARGET_AI_SKILL_USER_ROOT/shimmy-create-tool"
  assert_path_not_exists "$TARGET_AI_SKILL_USER_ROOT/shimmy-escalation"
  pass 'failure injection restores prior recognized links and reports overwritten foreign content as unrecoverable'
}

test_commands_target_ai_skill_invalid_and_unsupported() {
  test_target_ai_skill_fixture_reset
  target_ai_control_manifest=$TARGET_SHIM_PROFILE_ROOT/ai-skills/control/bundle.conf
  target_ai_control_saved=$SCENARIO_DIR/control.bundle.saved
  cp "$target_ai_control_manifest" "$target_ai_control_saved"
  target_ai_other_commit=9999999999999999999999999999999999999999
  sed "s/$TARGET_SHIM_PINNED_COMMIT/$target_ai_other_commit/g" "$target_ai_control_saved" > "$target_ai_control_manifest"
  printf 'must-survive\n' > "$TARGET_AI_SKILL_USER_ROOT/shimmy-catalog"
  target_ai_invalid_list=$(test_target_ai_skill_run list --format manifest)
  assert_contains "$target_ai_invalid_list" 'shimmy_ai_skill_bundle=control|valid|6|-'
  set +e
  target_ai_invalid_repair=$(test_target_ai_skill_run repair 2>&1)
  target_ai_invalid_status=$?
  set -e
  [ "$target_ai_invalid_status" -ne 0 ] || fail_test 'control source mismatch did not block repair'
  assert_contains "$target_ai_invalid_repair" 'supported AI-skill bundle consistency validation failed'
  assert_equals "$(cat "$TARGET_AI_SKILL_USER_ROOT/shimmy-catalog")" must-survive
  cp "$target_ai_control_saved" "$target_ai_control_manifest"
  printf 'malformed=1\n' >> "$target_ai_control_manifest"
  target_ai_malformed_list=$(test_target_ai_skill_run list --format manifest)
  assert_contains "$target_ai_malformed_list" 'shimmy_ai_skill_bundle=control|invalid|0|malformed-supported-bundle'
  cp "$target_ai_control_saved" "$target_ai_control_manifest"

  target_ai_shims_manifest=$TARGET_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf
  sed 's/^shimmy_ai_skill_bundle_schema=1$/shimmy_ai_skill_bundle_schema=2/' \
    "$target_ai_shims_manifest" > "$target_ai_shims_manifest.tmp"
  mv "$target_ai_shims_manifest.tmp" "$target_ai_shims_manifest"
  rm -f "$TARGET_AI_SKILL_USER_ROOT/shimmy-catalog"
  target_ai_stale=$TARGET_SHIM_PROFILE_ROOT/ai-skills/shims/skills/shimmy-tool-stale
  ln -s "$target_ai_stale" "$TARGET_AI_SKILL_USER_ROOT/shimmy-tool-stale"
  target_ai_unsupported_list=$(test_target_ai_skill_run list --format manifest)
  assert_contains "$target_ai_unsupported_list" 'shimmy_ai_skill_bundle=shims|invalid|0|unsupported-schema-2'
  assert_not_contains "$target_ai_unsupported_list" 'shimmy_ai_skill=shims|'
  set +e
  target_ai_unsupported_repair=$(test_target_ai_skill_run repair 2>&1)
  target_ai_unsupported_status=$?
  set -e
  assert_equals "$target_ai_unsupported_status" 2
  assert_contains "$target_ai_unsupported_repair" 'skipping unsupported shims AI-skill bundle'
  assert_path_not_exists "$TARGET_AI_SKILL_USER_ROOT/shimmy-tool-stale"
  assert_path_symlink "$TARGET_AI_SKILL_USER_ROOT/shimmy-catalog"
  pass 'source mismatch blocks reconciliation while unsupported bundles warn, skip rows, remove recognized prior-kind links, and return nonzero'
}

test_commands_target_ai_skill_run() {
  test_target_ai_skill_fixture_setup
  test_commands_target_ai_skill_materialization_and_list
  test_commands_target_ai_skill_exact_repair
  test_commands_target_ai_skill_failure_rollback
  test_commands_target_ai_skill_invalid_and_unsupported
}
