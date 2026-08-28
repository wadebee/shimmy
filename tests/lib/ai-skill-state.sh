#!/bin/sh

test_lib_ai_skill_file_write() {
  test_skill_file=$1
  test_skill_name=$2
  test_skill_description=$3
  mkdir -p "$(dirname -- "$test_skill_file")"
  printf '%s\n' '---' "name: $test_skill_name" "description: $test_skill_description" '---' '' \
    "$SHIMMY_AI_SKILL_MANAGED_HEADER" '' "# $test_skill_name" > "$test_skill_file"
}

test_lib_ai_skill_bundle_fixture_create() {
  test_bundle_root=$1
  test_bundle_profile=team-one
  test_bundle_commit=1111111111111111111111111111111111111111
  test_bundle_fingerprint=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  test_bundle_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  mkdir -p "$test_bundle_root/control/skills" "$test_bundle_root/shims/skills"
  test_control_records=
  test_control_names=fixture-control
  while IFS= read -r test_control_name; do
    [ -n "$test_control_name" ] || continue
    test_lib_ai_skill_file_write "$test_bundle_root/control/skills/$test_control_name/SKILL.md" \
      "$test_control_name" "$test_control_name fixture."
    test_control_hash=$(shimmy_sha256_fingerprint_file_render "$test_bundle_root/control/skills/$test_control_name/SKILL.md")
    test_control_records=$(shimmy_append_line_list "$test_control_records" \
      "$test_control_name|$test_control_hash|control|$test_control_name|$test_bundle_commit")
  done <<EOF
$test_control_names
EOF
  test_lib_ai_skill_file_write "$test_bundle_root/shims/skills/shimmy-tool-alpha/SKILL.md" shimmy-tool-alpha 'Alpha fixture.'
  test_lib_ai_skill_file_write "$test_bundle_root/shims/skills/shimmy-tool-beta/SKILL.md" shimmy-tool-beta 'Beta fixture.'
  test_alpha_hash=$(shimmy_sha256_fingerprint_file_render "$test_bundle_root/shims/skills/shimmy-tool-alpha/SKILL.md")
  test_beta_hash=$(shimmy_sha256_fingerprint_file_render "$test_bundle_root/shims/skills/shimmy-tool-beta/SKILL.md")
  test_shim_records="shimmy-tool-alpha|$test_alpha_hash|default|alpha|$test_bundle_generation
shimmy-tool-beta|$test_beta_hash|default|beta|$test_bundle_generation"
  shimmy_ai_skill_bundle_render control "$test_bundle_profile" "$test_bundle_commit" "$test_control_records" > "$test_bundle_root/control/bundle.conf"
  shimmy_ai_skill_bundle_render shims "$test_bundle_profile" "$test_bundle_generation/$test_bundle_fingerprint" "$test_shim_records" > "$test_bundle_root/shims/bundle.conf"
}

test_lib_ai_skill_empty_control_rejection() {
  setup_scenario
  test_empty_control=$SCENARIO_DIR/empty-control
  mkdir -p "$test_empty_control/skills"
  printf '%s\n' \
    'shimmy_ai_skill_bundle_schema=1' \
    'shimmy_ai_skill_bundle_kind=control' \
    'shimmy_profile_name=team-one' \
    'shimmy_ai_skill_source_ref=1111111111111111111111111111111111111111' \
    > "$test_empty_control/bundle.conf"
  if shimmy_ai_skill_bundle_read "$test_empty_control" control team-one; then
    fail_test 'empty control bundle accepted'
  fi
  pass 'empty control bundles fail closed'
}

test_lib_ai_skill_control_source_discovery() {
  setup_scenario
  test_control_source=$SCENARIO_DIR/control-source
  test_control_alpha=$test_control_source/plugins/shimmy/skills/fixture-alpha/SKILL.md
  test_control_zulu=$test_control_source/plugins/shimmy/skills/fixture-zulu/SKILL.md
  test_lib_ai_skill_file_write "$test_control_zulu" fixture-zulu \
    'Dynamic zulu control-source fixture.'
  test_lib_ai_skill_file_write "$test_control_alpha" fixture-alpha \
    'Dynamic alpha control-source fixture.'
  git -C "$test_control_source" init -q
  git -C "$test_control_source" config user.email shimmy-tests@example.invalid
  git -C "$test_control_source" config user.name 'Shimmy Tests'
  git -C "$test_control_source" add plugins/shimmy/skills/fixture-alpha/SKILL.md \
    plugins/shimmy/skills/fixture-zulu/SKILL.md
  git -C "$test_control_source" commit -qm valid-control-source
  test_control_source_ref=$(git -C "$test_control_source" rev-parse HEAD)

  printf 'dirty worktree bytes\n' >> "$test_control_alpha"
  test_lib_ai_skill_file_write \
    "$test_control_source/plugins/shimmy/skills/fixture-worktree/SKILL.md" \
    fixture-worktree 'Uncommitted control-source fixture.'
  shimmy_ai_skill_control_bundle_materialize "$test_control_source" \
    "$test_control_source_ref" team-one "$SCENARIO_DIR/control-valid" ||
    fail_test 'valid exact-source control tree was rejected'
  test_control_materialized_names=$(sed -n \
    '5,$s/^skill=\([^|]*\)|.*$/\1/p' \
    "$SCENARIO_DIR/control-valid/bundle.conf")
  assert_equals "$test_control_materialized_names" 'fixture-alpha
fixture-zulu'
  assert_file_not_contains "$SCENARIO_DIR/control-valid/skills/fixture-alpha/SKILL.md" \
    'dirty worktree bytes'
  assert_path_not_exists "$SCENARIO_DIR/control-valid/skills/fixture-worktree"

  git -C "$test_control_source" reset -q --hard HEAD
  git -C "$test_control_source" clean -fdq
  git -C "$test_control_source" rm -qr plugins/shimmy/skills/fixture-alpha \
    plugins/shimmy/skills/fixture-zulu
  git -C "$test_control_source" commit -qm empty-control-source
  test_control_source_ref=$(git -C "$test_control_source" rev-parse HEAD)
  if shimmy_ai_skill_control_bundle_materialize "$test_control_source" \
    "$test_control_source_ref" team-one "$SCENARIO_DIR/control-empty" \
    >/dev/null 2>&1
  then
    fail_test 'empty exact-source control tree was accepted'
  fi

  test_lib_ai_skill_file_write \
    "$test_control_source/plugins/shimmy/skills/unsafe_name/SKILL.md" \
    unsafe_name 'Unsafe-name control-source fixture.'
  git -C "$test_control_source" add plugins/shimmy/skills/unsafe_name/SKILL.md
  git -C "$test_control_source" commit -qm unsafe-control-source
  test_control_source_ref=$(git -C "$test_control_source" rev-parse HEAD)
  if shimmy_ai_skill_control_bundle_materialize "$test_control_source" \
    "$test_control_source_ref" team-one "$SCENARIO_DIR/control-unsafe" \
    >/dev/null 2>&1
  then
    fail_test 'unsafe direct control-source tree name was accepted'
  fi

  git -C "$test_control_source" rm -qr plugins/shimmy/skills/unsafe_name
  mkdir -p "$test_control_source/plugins/shimmy/skills"
  printf 'not a skill tree\n' > \
    "$test_control_source/plugins/shimmy/skills/not-a-tree"
  git -C "$test_control_source" add plugins/shimmy/skills/not-a-tree
  git -C "$test_control_source" commit -qm non-tree-control-source
  test_control_source_ref=$(git -C "$test_control_source" rev-parse HEAD)
  if shimmy_ai_skill_control_bundle_materialize "$test_control_source" \
    "$test_control_source_ref" team-one "$SCENARIO_DIR/control-non-tree" \
    >/dev/null 2>&1
  then
    fail_test 'non-tree direct control-source entry was accepted'
  fi
  pass 'exact-source discovery materializes all sorted committed trees, ignores worktree drift, and rejects empty, unsafe, or non-tree control sets'
}

test_lib_ai_skill_bundle_round_trip() {
  setup_scenario
  test_lib_ai_skill_bundle_fixture_create "$SCENARIO_DIR/bundles"
  shimmy_ai_skill_bundle_read "$SCENARIO_DIR/bundles/control" control team-one || fail_test 'valid control bundle rejected'
  shimmy_ai_skill_bundle_render "$SHIMMY_AI_SKILL_BUNDLE_KIND" "$SHIMMY_AI_SKILL_PROFILE_NAME" "$SHIMMY_AI_SKILL_SOURCE_REF" "$SHIMMY_AI_SKILL_RECORDS" > "$SCENARIO_DIR/bundles/control/bundle.round-trip"
  cmp -s "$SCENARIO_DIR/bundles/control/bundle.conf" "$SCENARIO_DIR/bundles/control/bundle.round-trip" || fail_test 'control bundle round trip changed bytes'
  rm "$SCENARIO_DIR/bundles/control/bundle.round-trip"
  shimmy_ai_skill_bundle_read "$SCENARIO_DIR/bundles/shims" shims team-one || fail_test 'valid shims bundle rejected'
  assert_equals "$(shimmy_sha256_fingerprint_file_render "$SCENARIO_DIR/bundles/shims/skills/shimmy-tool-alpha/SKILL.md")" \
    sha256:240a4db8851770e79daaf1724b163cf60a69f59bf5940b7e74b699700461a2d9
  pass 'control and shims bundle fixtures round-trip with fixed SHA-256 skill identity'
}

test_lib_ai_skill_profile_consistency() {
  setup_scenario
  test_lib_profile_state_fixture_create "$SCENARIO_DIR/state"
  test_lib_ai_skill_bundle_fixture_create "$SCENARIO_DIR/state/profile/ai-skills"
  test_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  shimmy_profile_state_validate \
    "$SCENARIO_DIR/state/profile/install-manifest.txt" \
    "$SCENARIO_DIR/state/catalogs/default/registry.conf" \
    "$SCENARIO_DIR/state/catalogs/default/generations/$test_generation" \
    "$SCENARIO_DIR/state/profile/ai-skills/control" \
    "$SCENARIO_DIR/state/profile/ai-skills/shims" || fail_test 'consistent complete profile rejected'
  pass 'profile-wide validation accepts one default pin, tracking/exact coexistence, and consistent bundles'
}

test_lib_ai_skill_integrity() {
  setup_scenario
  test_lib_profile_state_fixture_create "$SCENARIO_DIR/state"
  test_lib_ai_skill_bundle_fixture_create "$SCENARIO_DIR/state/profile/ai-skills"
  test_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  test_control=$SCENARIO_DIR/state/profile/ai-skills/control
  test_shims=$SCENARIO_DIR/state/profile/ai-skills/shims
  test_control_saved=$SCENARIO_DIR/control.bundle.saved
  cp "$test_control/bundle.conf" "$test_control_saved"

  printf '%s\n' drift >> "$test_shims/skills/shimmy-tool-alpha/SKILL.md"
  if shimmy_ai_skill_bundle_read "$test_shims" shims team-one; then fail_test 'bundle content drift accepted'; fi
  test_lib_ai_skill_file_write "$test_shims/skills/shimmy-tool-alpha/SKILL.md" shimmy-tool-alpha 'Alpha fixture.'

  sed 's/1111111111111111111111111111111111111111/3333333333333333333333333333333333333333/g' "$test_control_saved" > "$test_control/bundle.conf"
  if shimmy_profile_state_validate "$SCENARIO_DIR/state/profile/install-manifest.txt" "$SCENARIO_DIR/state/catalogs/default/registry.conf" "$SCENARIO_DIR/state/catalogs/default/generations/$test_generation" "$test_control" "$test_shims"; then
    fail_test 'control source mismatch accepted'
  fi
  cp "$test_control_saved" "$test_control/bundle.conf"

  test_generation_file=$SCENARIO_DIR/state/catalogs/default/generations/$test_generation/generation.conf
  test_generation_saved=$SCENARIO_DIR/generation.conf.saved
  cp "$test_generation_file" "$test_generation_saved"
  sed 's/2222222222222222222222222222222222222222/4444444444444444444444444444444444444444/' "$test_generation_saved" > "$test_generation_file"
  if shimmy_profile_state_validate "$SCENARIO_DIR/state/profile/install-manifest.txt" "$SCENARIO_DIR/state/catalogs/default/registry.conf" "$SCENARIO_DIR/state/catalogs/default/generations/$test_generation" "$test_control" "$test_shims"; then
    fail_test 'catalog pin provenance mismatch accepted'
  fi
  cp "$test_generation_saved" "$test_generation_file"

  test_collision_file=$test_control/skills/shimmy-tool-alpha/SKILL.md
  test_lib_ai_skill_file_write "$test_collision_file" shimmy-tool-alpha 'Collision fixture.'
  test_collision_hash=$(shimmy_sha256_fingerprint_file_render "$test_collision_file")
  test_collision_record="shimmy-tool-alpha|$test_collision_hash|control|shimmy-tool-alpha|1111111111111111111111111111111111111111"
  test_control_records="$(sed -n '5,$s/^skill=//p' "$test_control_saved")
$test_collision_record"
  test_control_records=$(printf '%s\n' "$test_control_records" | LC_ALL=C sort)
  shimmy_ai_skill_bundle_render control team-one 1111111111111111111111111111111111111111 "$test_control_records" > "$test_control/bundle.conf"
  if shimmy_profile_state_validate "$SCENARIO_DIR/state/profile/install-manifest.txt" "$SCENARIO_DIR/state/catalogs/default/registry.conf" "$SCENARIO_DIR/state/catalogs/default/generations/$test_generation" "$test_control" "$test_shims"; then
    fail_test 'cross-bundle skill collision accepted'
  fi
  pass 'bundle drift, source mismatch, and cross-bundle collision fail closed'
}

test_lib_ai_skill_state_run() {
  test_lib_ai_skill_bundle_round_trip
  test_lib_ai_skill_empty_control_rejection
  test_lib_ai_skill_control_source_discovery
  test_lib_ai_skill_profile_consistency
  test_lib_ai_skill_integrity
}
