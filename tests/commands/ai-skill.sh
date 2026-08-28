#!/bin/sh

test_ai_skill_fixture_setup() {
  test_shim_fixture_setup
  TEST_AI_SKILL_HOME_BASE=$SCENARIO_DIR/home%encoded'|path'
  TEST_AI_SKILL_HOME_SEQUENCE=0
  TEST_AI_SKILL_CONTROL_SAVED=$SCENARIO_DIR/control.bundle.pristine
  TEST_AI_SKILL_SHIMS_SAVED=$SCENARIO_DIR/shims.bundle.pristine
  cp "$TEST_SHIM_PROFILE_ROOT/ai-skills/control/bundle.conf" "$TEST_AI_SKILL_CONTROL_SAVED"
  cp "$TEST_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf" "$TEST_AI_SKILL_SHIMS_SAVED"
}

test_ai_skill_fixture_reset() {
  TEST_AI_SKILL_HOME_SEQUENCE=$((TEST_AI_SKILL_HOME_SEQUENCE + 1))
  TEST_AI_SKILL_HOME=$TEST_AI_SKILL_HOME_BASE-$TEST_AI_SKILL_HOME_SEQUENCE
  TEST_AI_SKILL_USER_ROOT=$TEST_AI_SKILL_HOME/.agents/skills
  case "$TEST_AI_SKILL_HOME" in "$SCENARIO_DIR"/*) ;; *) fail_test 'escaped AI-skill fixture home' ;; esac
  mkdir -p "$TEST_AI_SKILL_USER_ROOT"
  shimmy_active_profile_render default "$TEST_AI_SKILL_USER_ROOT" > "$TEST_SHIM_CONFIG/active-profile.conf"
  cp "$TEST_AI_SKILL_CONTROL_SAVED" "$TEST_SHIM_PROFILE_ROOT/ai-skills/control/bundle.conf"
  cp "$TEST_AI_SKILL_SHIMS_SAVED" "$TEST_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf"
}

test_ai_skill_run() {
  env HOME="$TEST_AI_SKILL_HOME" SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    "$ROOT_DIR/commands/ai-skill.sh" "$@"
}

test_ai_skill_control_links_assert() {
  while IFS= read -r test_ai_link_name; do
    [ -n "$test_ai_link_name" ] || continue
    assert_path_symlink "$TEST_AI_SKILL_USER_ROOT/$test_ai_link_name"
    assert_equals "$(readlink "$TEST_AI_SKILL_USER_ROOT/$test_ai_link_name")" \
      "$TEST_SHIM_PROFILE_ROOT/ai-skills/control/skills/$test_ai_link_name"
  done <<EOF
$TEST_SHIM_CONTROL_NAMES
EOF
}

test_commands_ai_skill_materialization_and_list() {
  test_ai_skill_fixture_reset
  test_ai_commit=$TEST_SHIM_PINNED_COMMIT
  test_ai_control_copy=$TEST_SHIM_PROFILE_ROOT/ai-skills/control-copy
  shimmy_ai_skill_control_bundle_materialize "$TEST_SHIM_CHECKOUT" "$test_ai_commit" \
    default "$test_ai_control_copy" || fail_test 'second deterministic control materialization failed'
  diff -r "$TEST_SHIM_PROFILE_ROOT/ai-skills/control" "$test_ai_control_copy" >/dev/null ||
    fail_test 'same control commit produced different bundle bytes'
  rm -rf "$test_ai_control_copy"

  test_ai_control_name=$TEST_SHIM_CONTROL_NAME
  test_ai_wrong_profile=$TEST_SHIM_CONFIG/profiles/team-two/ai-skills/control/skills/$test_ai_control_name
  mkdir -p "$test_ai_wrong_profile"
  ln -s "$test_ai_wrong_profile" "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name"
  test_ai_list=$(test_ai_skill_run list --format manifest)
  assert_contains "$test_ai_list" "shimmy_ai_skill_bundle=control|valid|$TEST_SHIM_CONTROL_COUNT|-"
  assert_contains "$test_ai_list" 'shimmy_ai_skill_bundle=shims|empty|0|-'
  assert_contains "$test_ai_list" "shimmy_ai_skill=control|$test_ai_control_name|shimmy-link-wrong-profile|"
  assert_contains "$test_ai_list" 'home%25encoded%7Cpath'
  assert_file_contains "$TEST_SHIM_PROFILE_ROOT/ai-skills/control/bundle.conf" \
    "|control|$test_ai_control_name|$test_ai_commit"

  test_ai_skill_fixture_reset
  ln -s "$SCENARIO_DIR/missing-foreign" "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name"
  test_ai_list=$(test_ai_skill_run list --format manifest)
  assert_contains "$test_ai_list" "shimmy_ai_skill=control|$test_ai_control_name|foreign-link-broken|"
  pass 'control and empty shim bundles materialize deterministically and list encoded broken and wrong-profile link state'
}

test_commands_ai_skill_exact_repair() {
  test_ai_skill_fixture_reset
  test_ai_root_marker=$TEST_AI_SKILL_USER_ROOT/root-marker
  test_ai_sibling=$TEST_AI_SKILL_USER_ROOT/custom-skill
  mkdir "$test_ai_sibling"
  printf 'root-survives\n' > "$test_ai_root_marker"
  printf 'sibling-survives\n' > "$test_ai_sibling/SKILL.md"
  test_ai_root_before=$(cksum < "$test_ai_root_marker")
  test_ai_sibling_before=$(cksum < "$test_ai_sibling/SKILL.md")

  test_ai_control_name=$TEST_SHIM_CONTROL_NAME
  printf 'foreign-file\n' > "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name"
  test_ai_stale=$TEST_SHIM_PROFILE_ROOT/ai-skills/shims/skills/shimmy-tool-stale
  ln -s "$test_ai_stale" "$TEST_AI_SKILL_USER_ROOT/shimmy-tool-stale"

  test_ai_repair=$(test_ai_skill_run repair 2>&1)
  assert_contains "$test_ai_repair" 'not recoverable'
  assert_contains "$test_ai_repair" 'Remove recognized stale Shimmy link'
  test_ai_skill_control_links_assert
  assert_path_not_exists "$TEST_AI_SKILL_USER_ROOT/shimmy-tool-stale"
  assert_equals "$(cksum < "$test_ai_root_marker")" "$test_ai_root_before"
  assert_equals "$(cksum < "$test_ai_sibling/SKILL.md")" "$test_ai_sibling_before"

  for test_ai_collision in directory foreign-link foreign-link-broken wrong-profile; do
    test_ai_skill_fixture_reset
    test_ai_collision_destination=$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name
    case "$test_ai_collision" in
      directory)
        mkdir "$test_ai_collision_destination"
        printf 'foreign-directory\n' > "$test_ai_collision_destination/payload"
        ;;
      foreign-link)
        test_ai_collision_target=$SCENARIO_DIR/foreign-link-target
        printf 'foreign-link\n' > "$test_ai_collision_target"
        ln -s "$test_ai_collision_target" "$test_ai_collision_destination"
        ;;
      foreign-link-broken)
        ln -s "$SCENARIO_DIR/missing-foreign" "$test_ai_collision_destination"
        ;;
      wrong-profile)
        test_ai_collision_target=$TEST_SHIM_CONFIG/profiles/team-two/ai-skills/control/skills/$test_ai_control_name
        mkdir -p "$test_ai_collision_target"
        ln -s "$test_ai_collision_target" "$test_ai_collision_destination"
        ;;
    esac
    test_ai_skill_run repair >/dev/null 2>&1
    assert_equals "$(readlink "$test_ai_collision_destination")" \
      "$TEST_SHIM_PROFILE_ROOT/ai-skills/control/skills/$test_ai_control_name"
  done
  pass 'repair overwrites every exact collision, removes only recognized stale links, and preserves unrelated user content byte-for-byte'
}

test_commands_ai_skill_failure_rollback() {
  test_ai_skill_fixture_reset
  test_ai_control_name=$TEST_SHIM_CONTROL_NAME
  printf 'foreign-control\n' > "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name"

  set +e
  test_ai_failure=$(env HOME="$TEST_AI_SKILL_HOME" SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    SHIMMY_TEST_MODE=1 SHIMMY_TEST_AI_SKILL_FAILURE_AFTER=1 \
    "$ROOT_DIR/commands/ai-skill.sh" repair 2>&1)
  test_ai_status=$?
  set -e
  [ "$test_ai_status" -ne 0 ] || fail_test 'injected AI-skill repair failure unexpectedly succeeded'
  assert_contains "$test_ai_failure" 'Rollback result: incomplete'
  assert_contains "$test_ai_failure" 'foreign content is not recoverable'
  while IFS= read -r test_ai_name; do
    [ -n "$test_ai_name" ] || continue
    assert_path_not_exists "$TEST_AI_SKILL_USER_ROOT/$test_ai_name"
  done <<EOF
$TEST_SHIM_CONTROL_NAMES
EOF

  test_ai_skill_fixture_reset
  test_ai_prior=$TEST_SHIM_CONFIG/profiles/team-two/ai-skills/control/skills/$test_ai_control_name
  mkdir -p "$test_ai_prior"
  ln -s "$test_ai_prior" "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name"
  set +e
  test_ai_failure=$(env HOME="$TEST_AI_SKILL_HOME" SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    SHIMMY_TEST_MODE=1 SHIMMY_TEST_AI_SKILL_FAILURE_AFTER=1 \
    "$ROOT_DIR/commands/ai-skill.sh" repair 2>&1)
  test_ai_status=$?
  set -e
  [ "$test_ai_status" -ne 0 ] || fail_test 'recognized-link failure injection unexpectedly succeeded'
  assert_contains "$test_ai_failure" 'Rollback result: complete'
  assert_equals "$(readlink "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name")" "$test_ai_prior"
  while IFS= read -r test_ai_name; do
    [ -n "$test_ai_name" ] || continue
    [ "$test_ai_name" = "$test_ai_control_name" ] || \
      assert_path_not_exists "$TEST_AI_SKILL_USER_ROOT/$test_ai_name"
  done <<EOF
$TEST_SHIM_CONTROL_NAMES
EOF
  pass 'failure injection restores prior recognized links and reports overwritten foreign content as unrecoverable'
}

test_commands_ai_skill_invalid_and_unsupported() {
  test_ai_skill_fixture_reset
  test_ai_control_manifest=$TEST_SHIM_PROFILE_ROOT/ai-skills/control/bundle.conf
  test_ai_control_saved=$SCENARIO_DIR/control.bundle.saved
  cp "$test_ai_control_manifest" "$test_ai_control_saved"
  test_ai_other_commit=9999999999999999999999999999999999999999
  sed "s/$TEST_SHIM_PINNED_COMMIT/$test_ai_other_commit/g" "$test_ai_control_saved" > "$test_ai_control_manifest"
  test_ai_control_name=$TEST_SHIM_CONTROL_NAME
  printf 'must-survive\n' > "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name"
  test_ai_invalid_list=$(test_ai_skill_run list --format manifest)
  assert_contains "$test_ai_invalid_list" "shimmy_ai_skill_bundle=control|valid|$TEST_SHIM_CONTROL_COUNT|-"
  set +e
  test_ai_invalid_repair=$(test_ai_skill_run repair 2>&1)
  test_ai_invalid_status=$?
  set -e
  [ "$test_ai_invalid_status" -ne 0 ] || fail_test 'control source mismatch did not block repair'
  assert_contains "$test_ai_invalid_repair" 'supported AI-skill bundle consistency validation failed'
  assert_equals "$(cat "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name")" must-survive
  cp "$test_ai_control_saved" "$test_ai_control_manifest"
  printf 'malformed=1\n' >> "$test_ai_control_manifest"
  test_ai_malformed_list=$(test_ai_skill_run list --format manifest)
  assert_contains "$test_ai_malformed_list" 'shimmy_ai_skill_bundle=control|invalid|0|malformed-supported-bundle'
  cp "$test_ai_control_saved" "$test_ai_control_manifest"

  test_ai_shims_manifest=$TEST_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf
  sed 's/^shimmy_ai_skill_bundle_schema=1$/shimmy_ai_skill_bundle_schema=2/' \
    "$test_ai_shims_manifest" > "$test_ai_shims_manifest.tmp"
  mv "$test_ai_shims_manifest.tmp" "$test_ai_shims_manifest"
  rm -f "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name"
  test_ai_stale=$TEST_SHIM_PROFILE_ROOT/ai-skills/shims/skills/shimmy-tool-stale
  ln -s "$test_ai_stale" "$TEST_AI_SKILL_USER_ROOT/shimmy-tool-stale"
  test_ai_unsupported_list=$(test_ai_skill_run list --format manifest)
  assert_contains "$test_ai_unsupported_list" 'shimmy_ai_skill_bundle=shims|invalid|0|unsupported-schema-2'
  assert_not_contains "$test_ai_unsupported_list" 'shimmy_ai_skill=shims|'
  set +e
  test_ai_unsupported_repair=$(test_ai_skill_run repair 2>&1)
  test_ai_unsupported_status=$?
  set -e
  assert_equals "$test_ai_unsupported_status" 2
  assert_contains "$test_ai_unsupported_repair" 'skipping unsupported shims AI-skill bundle'
  assert_path_not_exists "$TEST_AI_SKILL_USER_ROOT/shimmy-tool-stale"
  assert_path_symlink "$TEST_AI_SKILL_USER_ROOT/$test_ai_control_name"
  pass 'source mismatch blocks reconciliation while unsupported bundles warn, skip rows, remove recognized prior-kind links, and return nonzero'
}

test_commands_ai_skill_run() {
  test_ai_skill_fixture_setup
  test_commands_ai_skill_materialization_and_list
  test_commands_ai_skill_exact_repair
  test_commands_ai_skill_failure_rollback
  test_commands_ai_skill_invalid_and_unsupported
}
