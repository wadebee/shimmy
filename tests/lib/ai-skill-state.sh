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
  while IFS= read -r test_control_name; do
    [ -n "$test_control_name" ] || continue
    test_lib_ai_skill_file_write "$test_bundle_root/control/skills/$test_control_name/SKILL.md" \
      "$test_control_name" "$test_control_name fixture."
    test_control_hash=$(shimmy_sha256_fingerprint_file_render "$test_bundle_root/control/skills/$test_control_name/SKILL.md")
    test_control_records=$(shimmy_append_line_list "$test_control_records" \
      "$test_control_name|$test_control_hash|control|$test_control_name|$test_bundle_commit")
  done <<EOF
$(shimmy_ai_skill_control_names_render)
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
  test_lib_ai_skill_profile_consistency
  test_lib_ai_skill_integrity
}
