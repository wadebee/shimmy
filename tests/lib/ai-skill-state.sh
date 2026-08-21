#!/bin/sh

test_lib_target_ai_skill_file_write() {
  target_skill_file=$1
  target_skill_name=$2
  target_skill_description=$3
  mkdir -p "$(dirname -- "$target_skill_file")"
  printf '%s\n' '---' "name: $target_skill_name" "description: $target_skill_description" '---' '' \
    "$SHIMMY_TARGET_AI_SKILL_MANAGED_HEADER" '' "# $target_skill_name" > "$target_skill_file"
}

test_lib_target_ai_skill_bundle_fixture_create() {
  target_bundle_root=$1
  target_bundle_profile=team-one
  target_bundle_commit=1111111111111111111111111111111111111111
  target_bundle_fingerprint=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target_bundle_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  mkdir -p "$target_bundle_root/control/skills" "$target_bundle_root/shims/skills"
  target_control_records=
  while IFS= read -r target_control_name; do
    [ -n "$target_control_name" ] || continue
    test_lib_target_ai_skill_file_write "$target_bundle_root/control/skills/$target_control_name/SKILL.md" \
      "$target_control_name" "$target_control_name fixture."
    target_control_hash=$(shimmy_sha256_fingerprint_file_render "$target_bundle_root/control/skills/$target_control_name/SKILL.md")
    target_control_records=$(shimmy_append_line_list "$target_control_records" \
      "$target_control_name|$target_control_hash|control|$target_control_name|$target_bundle_commit")
  done <<EOF
$(shimmy_target_ai_skill_control_names_render)
EOF
  test_lib_target_ai_skill_file_write "$target_bundle_root/shims/skills/shimmy-tool-alpha/SKILL.md" shimmy-tool-alpha 'Alpha fixture.'
  test_lib_target_ai_skill_file_write "$target_bundle_root/shims/skills/shimmy-tool-beta/SKILL.md" shimmy-tool-beta 'Beta fixture.'
  target_alpha_hash=$(shimmy_sha256_fingerprint_file_render "$target_bundle_root/shims/skills/shimmy-tool-alpha/SKILL.md")
  target_beta_hash=$(shimmy_sha256_fingerprint_file_render "$target_bundle_root/shims/skills/shimmy-tool-beta/SKILL.md")
  target_shim_records="shimmy-tool-alpha|$target_alpha_hash|default|alpha|$target_bundle_generation
shimmy-tool-beta|$target_beta_hash|default|beta|$target_bundle_generation"
  shimmy_target_ai_skill_bundle_render control "$target_bundle_profile" "$target_bundle_commit" "$target_control_records" > "$target_bundle_root/control/bundle.conf"
  shimmy_target_ai_skill_bundle_render shims "$target_bundle_profile" "$target_bundle_generation/$target_bundle_fingerprint" "$target_shim_records" > "$target_bundle_root/shims/bundle.conf"
}

test_lib_target_ai_skill_bundle_round_trip() {
  setup_scenario
  test_lib_target_ai_skill_bundle_fixture_create "$SCENARIO_DIR/bundles"
  shimmy_target_ai_skill_bundle_read "$SCENARIO_DIR/bundles/control" control team-one || fail_test 'valid control bundle rejected'
  shimmy_target_ai_skill_bundle_render "$SHIMMY_TARGET_AI_SKILL_BUNDLE_KIND" "$SHIMMY_TARGET_AI_SKILL_PROFILE_NAME" "$SHIMMY_TARGET_AI_SKILL_SOURCE_REF" "$SHIMMY_TARGET_AI_SKILL_RECORDS" > "$SCENARIO_DIR/bundles/control/bundle.round-trip"
  cmp -s "$SCENARIO_DIR/bundles/control/bundle.conf" "$SCENARIO_DIR/bundles/control/bundle.round-trip" || fail_test 'control bundle round trip changed bytes'
  rm "$SCENARIO_DIR/bundles/control/bundle.round-trip"
  shimmy_target_ai_skill_bundle_read "$SCENARIO_DIR/bundles/shims" shims team-one || fail_test 'valid shims bundle rejected'
  assert_equals "$(shimmy_sha256_fingerprint_file_render "$SCENARIO_DIR/bundles/shims/skills/shimmy-tool-alpha/SKILL.md")" \
    sha256:240a4db8851770e79daaf1724b163cf60a69f59bf5940b7e74b699700461a2d9
  pass 'control and shims bundle fixtures round-trip with fixed SHA-256 skill identity'
}

test_lib_target_ai_skill_profile_consistency() {
  setup_scenario
  test_lib_target_profile_state_fixture_create "$SCENARIO_DIR/state"
  test_lib_target_ai_skill_bundle_fixture_create "$SCENARIO_DIR/state/profile/ai-skills"
  target_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  shimmy_target_profile_state_validate \
    "$SCENARIO_DIR/state/profile/install-manifest.txt" \
    "$SCENARIO_DIR/state/catalogs/default/registry.conf" \
    "$SCENARIO_DIR/state/catalogs/default/generations/$target_generation" \
    "$SCENARIO_DIR/state/profile/ai-skills/control" \
    "$SCENARIO_DIR/state/profile/ai-skills/shims" || fail_test 'consistent complete target profile rejected'
  pass 'profile-wide validation accepts one default pin, tracking/exact coexistence, and consistent bundles'
}

test_lib_target_ai_skill_integrity() {
  setup_scenario
  test_lib_target_profile_state_fixture_create "$SCENARIO_DIR/state"
  test_lib_target_ai_skill_bundle_fixture_create "$SCENARIO_DIR/state/profile/ai-skills"
  target_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target_control=$SCENARIO_DIR/state/profile/ai-skills/control
  target_shims=$SCENARIO_DIR/state/profile/ai-skills/shims
  target_control_saved=$SCENARIO_DIR/control.bundle.saved
  cp "$target_control/bundle.conf" "$target_control_saved"

  printf '%s\n' drift >> "$target_shims/skills/shimmy-tool-alpha/SKILL.md"
  if shimmy_target_ai_skill_bundle_read "$target_shims" shims team-one; then fail_test 'bundle content drift accepted'; fi
  test_lib_target_ai_skill_file_write "$target_shims/skills/shimmy-tool-alpha/SKILL.md" shimmy-tool-alpha 'Alpha fixture.'

  sed 's/1111111111111111111111111111111111111111/3333333333333333333333333333333333333333/g' "$target_control_saved" > "$target_control/bundle.conf"
  if shimmy_target_profile_state_validate "$SCENARIO_DIR/state/profile/install-manifest.txt" "$SCENARIO_DIR/state/catalogs/default/registry.conf" "$SCENARIO_DIR/state/catalogs/default/generations/$target_generation" "$target_control" "$target_shims"; then
    fail_test 'control source mismatch accepted'
  fi
  cp "$target_control_saved" "$target_control/bundle.conf"

  target_generation_file=$SCENARIO_DIR/state/catalogs/default/generations/$target_generation/generation.conf
  target_generation_saved=$SCENARIO_DIR/generation.conf.saved
  cp "$target_generation_file" "$target_generation_saved"
  sed 's/2222222222222222222222222222222222222222/4444444444444444444444444444444444444444/' "$target_generation_saved" > "$target_generation_file"
  if shimmy_target_profile_state_validate "$SCENARIO_DIR/state/profile/install-manifest.txt" "$SCENARIO_DIR/state/catalogs/default/registry.conf" "$SCENARIO_DIR/state/catalogs/default/generations/$target_generation" "$target_control" "$target_shims"; then
    fail_test 'catalog pin provenance mismatch accepted'
  fi
  cp "$target_generation_saved" "$target_generation_file"

  target_collision_file=$target_control/skills/shimmy-tool-alpha/SKILL.md
  test_lib_target_ai_skill_file_write "$target_collision_file" shimmy-tool-alpha 'Collision fixture.'
  target_collision_hash=$(shimmy_sha256_fingerprint_file_render "$target_collision_file")
  target_collision_record="shimmy-tool-alpha|$target_collision_hash|control|shimmy-tool-alpha|1111111111111111111111111111111111111111"
  target_control_records="$(sed -n '5,$s/^skill=//p' "$target_control_saved")
$target_collision_record"
  target_control_records=$(printf '%s\n' "$target_control_records" | LC_ALL=C sort)
  shimmy_target_ai_skill_bundle_render control team-one 1111111111111111111111111111111111111111 "$target_control_records" > "$target_control/bundle.conf"
  if shimmy_target_profile_state_validate "$SCENARIO_DIR/state/profile/install-manifest.txt" "$SCENARIO_DIR/state/catalogs/default/registry.conf" "$SCENARIO_DIR/state/catalogs/default/generations/$target_generation" "$target_control" "$target_shims"; then
    fail_test 'cross-bundle skill collision accepted'
  fi
  pass 'bundle drift, source mismatch, and cross-bundle collision fail closed'
}

test_lib_target_ai_skill_state_run() {
  test_lib_target_ai_skill_bundle_round_trip
  test_lib_target_ai_skill_profile_consistency
  test_lib_target_ai_skill_integrity
}
