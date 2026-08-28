#!/bin/sh

test_catalog_checkout_create() {
  test_catalog_checkout=$1
  test_fixture_tree_copy "$ROOT_DIR" "$test_catalog_checkout"
  rm -rf "$test_catalog_checkout/.git"
  git -C "$test_catalog_checkout" init -q
  git -C "$test_catalog_checkout" symbolic-ref HEAD refs/heads/main
  git -C "$test_catalog_checkout" config user.email shimmy-tests@example.invalid
  git -C "$test_catalog_checkout" config user.name 'Shimmy Tests'
  git -C "$test_catalog_checkout" add -A
  git -C "$test_catalog_checkout" commit -qm initial
}

test_catalog_fixture_create() {
  test_catalog_fixture_checkout=$1
  test_catalog_fixture_config=$2
  mkdir -p "$test_catalog_fixture_config"
  test_catalog_checkout_create "$test_catalog_fixture_checkout"
  shimmy_catalog_default_create "$test_catalog_fixture_config" "$test_catalog_fixture_checkout" ||
    fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
}

test_catalog_tool_source_advance() {
  test_catalog_advance_checkout=$1
  test_catalog_advance_marker=$2
  printf '\n%s\n' "$test_catalog_advance_marker" >> "$test_catalog_advance_checkout/tools/jq/SKILL.md"
  git -C "$test_catalog_advance_checkout" add tools/jq/SKILL.md
  git -C "$test_catalog_advance_checkout" commit -qm "$test_catalog_advance_marker"
}

test_catalog_management_source_advance() {
  test_catalog_advance_checkout=$1
  test_catalog_advance_marker=$2
  printf '\n%s\n' "$test_catalog_advance_marker" >> "$test_catalog_advance_checkout/plugins/shimmy/skills/shimmy-catalog/SKILL.md"
  git -C "$test_catalog_advance_checkout" add plugins/shimmy/skills/shimmy-catalog/SKILL.md
  git -C "$test_catalog_advance_checkout" commit -qm "$test_catalog_advance_marker"
}

test_lib_catalog_static_validation() {
  setup_scenario
  test_catalog_payload=$SCENARIO_DIR/payload
  mkdir "$test_catalog_payload"
  cp "$ROOT_DIR/catalog.conf" "$test_catalog_payload/catalog.conf"
  test_fixture_tree_copy "$ROOT_DIR/tools" "$test_catalog_payload/tools"
  shimmy_catalog_authority_payload_validate "$test_catalog_payload" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"

  test_catalog_fingerprint_before=$(shimmy_catalog_content_fingerprint_render "$test_catalog_payload")
  printf '\nTool skill fingerprint fixture.\n' >> "$test_catalog_payload/tools/jq/SKILL.md"
  shimmy_catalog_authority_payload_validate "$test_catalog_payload" || fail_test 'valid tool skill content change was rejected'
  test_catalog_fingerprint_after=$(shimmy_catalog_content_fingerprint_render "$test_catalog_payload")
  [ "$test_catalog_fingerprint_before" != "$test_catalog_fingerprint_after" ] || fail_test 'tool skill bytes did not affect catalog fingerprint'
  chmod 0755 "$test_catalog_payload/tools/jq/SKILL.md"
  test_catalog_fingerprint_mode=$(shimmy_catalog_content_fingerprint_render "$test_catalog_payload")
  [ "$test_catalog_fingerprint_after" != "$test_catalog_fingerprint_mode" ] || fail_test 'tool skill mode did not affect catalog fingerprint'

  sed 's/^name: shimmy-tool-jq$/name: shimmy-tool-wrong/' "$test_catalog_payload/tools/jq/SKILL.md" > "$test_catalog_payload/tools/jq/SKILL.md.tmp"
  mv "$test_catalog_payload/tools/jq/SKILL.md.tmp" "$test_catalog_payload/tools/jq/SKILL.md"
  if shimmy_catalog_authority_payload_validate "$test_catalog_payload" >/dev/null 2>&1; then
    fail_test 'mismatched tool skill mapping was accepted'
  fi
  pass 'catalog validates tool skills, exact mapping, headers, and fingerprint bytes and modes'
}

test_lib_catalog_lifecycle() {
  setup_scenario
  test_catalog_checkout=$SCENARIO_DIR/checkout
  test_catalog_config=$SCENARIO_DIR/config/shimmy
  test_catalog_fixture_create "$test_catalog_checkout" "$test_catalog_config"
  test_catalog_registry=$test_catalog_config/catalogs/default/registry.conf
  test_catalog_initial=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_registry")
  test_catalog_generations_root=$test_catalog_config/catalogs/default/generations
  test_catalog_initial_root=$test_catalog_generations_root/$test_catalog_initial
  test_catalog_initial_commit=$(sed -n '1s/^catalog_source_commit=//p' "$test_catalog_initial_root/generation.conf")
  test_catalog_initial_metadata_checksum=$(cksum < "$test_catalog_initial_root/generation.conf")
  test_catalog_generation_layout=$(
    find "$test_catalog_initial_root" -mindepth 1 -maxdepth 1 -exec basename -- {} \; | LC_ALL=C sort
  )
  assert_equals "$test_catalog_generation_layout" 'catalog.conf
generation.conf
tools'
  test_catalog_registry_layout_checksum=$(cksum < "$test_catalog_registry")
  mkdir -p "$test_catalog_initial_root/plugins/shimmy/skills"
  if shimmy_catalog_generation_record_validate \
    "$test_catalog_initial_root" "$test_catalog_initial" >/dev/null 2>&1
  then
    fail_test 'legacy management-skill generation content was accepted'
  fi
  if shimmy_catalog_default_publish "$test_catalog_config" \
    "$test_catalog_checkout" >/dev/null 2>&1
  then
    fail_test 'publication converted legacy management-skill generation state in place'
  fi
  assert_equals "$(cksum < "$test_catalog_registry")" \
    "$test_catalog_registry_layout_checksum"
  rm -rf "$test_catalog_initial_root/plugins"
  shimmy_catalog_generation_record_validate \
    "$test_catalog_initial_root" "$test_catalog_initial" ||
    fail_test 'generation remained invalid after legacy content was removed'

  test_catalog_status_one=$(shimmy_catalog_status_render "$test_catalog_config" manifest)
  test_catalog_status_two=$(shimmy_catalog_status_render "$test_catalog_config" manifest)
  assert_equals "$test_catalog_status_one" "$test_catalog_status_two"
  assert_contains "$test_catalog_status_one" "shimmy_catalog=default|$test_catalog_initial||"
  test_catalog_tools=$(shimmy_catalog_tools_render "$test_catalog_config" '' manifest)
  assert_contains "$test_catalog_tools" "shimmy_catalog_tool=default|$test_catalog_initial|jq|1.8|1.8"
  test_catalog_tools_header=$(shimmy_catalog_tools_render \
    "$test_catalog_config" '' human | sed -n '1p' | awk '{$1=$1; print}')
  assert_equals "$test_catalog_tools_header" 'TOOL DEFAULT VERSIONS'

  test_catalog_registry_checksum=$(cksum < "$test_catalog_registry")
  test_catalog_generation_count=$(find "$test_catalog_generations_root" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  test_catalog_management_source_advance "$test_catalog_checkout" 'Management-only catalog publication.'
  test_catalog_management_head=$(git -C "$test_catalog_checkout" rev-parse HEAD)
  [ "$test_catalog_management_head" != "$test_catalog_initial_commit" ] || fail_test 'management-only source did not advance HEAD'
  shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  assert_equals "$(cksum < "$test_catalog_registry")" "$test_catalog_registry_checksum"
  assert_equals "$(cksum < "$test_catalog_initial_root/generation.conf")" "$test_catalog_initial_metadata_checksum"
  assert_equals "$(find "$test_catalog_generations_root" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "$test_catalog_generation_count"

  test_catalog_tool_source_advance "$test_catalog_checkout" 'Second catalog generation.'
  shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  test_catalog_second=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_registry")
  test_catalog_second_root=$test_catalog_generations_root/$test_catalog_second
  test_catalog_second_commit=$(sed -n '1s/^catalog_source_commit=//p' "$test_catalog_second_root/generation.conf")
  test_catalog_second_metadata_checksum=$(cksum < "$test_catalog_second_root/generation.conf")
  [ "$test_catalog_second" != "$test_catalog_initial" ] || fail_test 'publication did not advance current'
  assert_equals "$(sed -n '4s/^catalog_generation_previous=//p' "$test_catalog_registry")" "$test_catalog_initial"
  test_catalog_registry_checksum=$(cksum < "$test_catalog_registry")
  shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  assert_equals "$(cksum < "$test_catalog_registry")" "$test_catalog_registry_checksum"
  assert_contains "$(shimmy_catalog_tools_render "$test_catalog_config" "$test_catalog_initial" manifest)" "default|$test_catalog_initial|jq"

  shimmy_catalog_default_rollback "$test_catalog_config" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  assert_equals "$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_registry")" "$test_catalog_initial"
  assert_equals "$(sed -n '4s/^catalog_generation_previous=//p' "$test_catalog_registry")" "$test_catalog_second"

  test_catalog_management_source_advance "$test_catalog_checkout" 'Equivalent retained catalog publication.'
  test_catalog_equivalent_head=$(git -C "$test_catalog_checkout" rev-parse HEAD)
  [ "$test_catalog_equivalent_head" != "$test_catalog_second_commit" ] || fail_test 'equivalent source did not advance HEAD'
  shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  assert_equals "$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_registry")" "$test_catalog_second"
  assert_equals "$(sed -n '4s/^catalog_generation_previous=//p' "$test_catalog_registry")" "$test_catalog_initial"
  assert_equals "$(sed -n '5s/^catalog_source_commit=//p' "$test_catalog_registry")" "$test_catalog_second_commit"
  assert_equals "$(cksum < "$test_catalog_registry")" "$test_catalog_registry_checksum"
  assert_equals "$(cksum < "$test_catalog_second_root/generation.conf")" "$test_catalog_second_metadata_checksum"
  assert_equals "$(cksum < "$test_catalog_initial_root/generation.conf")" "$test_catalog_initial_metadata_checksum"
  assert_dir_exists "$test_catalog_initial_root"
  assert_dir_exists "$test_catalog_second_root"
  assert_equals "$(find "$test_catalog_generations_root" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" 2
  pass 'catalog publication preserves exact layout, no-op identity, retained provenance, rollback, and generations'
}

test_lib_catalog_pristine_baseline() {
  setup_scenario
  test_catalog_checkout=$SCENARIO_DIR/checkout
  test_catalog_config=$SCENARIO_DIR/config/shimmy
  test_catalog_fixture_create "$test_catalog_checkout" "$test_catalog_config"
  test_catalog_generation=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_config/catalogs/default/registry.conf")
  test_catalog_generation_root=$test_catalog_config/catalogs/default/generations/$test_catalog_generation

  test_catalog_baseline=$(shimmy_profile_baseline_render "$test_catalog_generation_root") ||
    fail_test 'private pristine-profile baseline could not be rendered'
  assert_equals "$test_catalog_baseline" 'jq|1.8
rg|15.1
skopeo|1.22'
  pass 'private pristine bootstrap and create candidates select catalog-default jq, rg, and Skopeo'
}

test_lib_catalog_control_validation_boundary() {
  setup_scenario
  test_catalog_checkout=$SCENARIO_DIR/checkout
  test_catalog_config=$SCENARIO_DIR/config/shimmy
  test_catalog_fixture_create "$test_catalog_checkout" "$test_catalog_config"
  test_catalog_registry=$test_catalog_config/catalogs/default/registry.conf
  test_catalog_registry_checksum=$(cksum < "$test_catalog_registry")
  test_catalog_control_file=$test_catalog_checkout/plugins/shimmy/skills/shimmy-catalog/SKILL.md

  sed 's/^> Shimmy active-profile reconciliation.*/> malformed/' \
    "$test_catalog_control_file" > "$test_catalog_control_file.tmp"
  mv "$test_catalog_control_file.tmp" "$test_catalog_control_file"
  git -C "$test_catalog_checkout" add plugins/shimmy/skills/shimmy-catalog/SKILL.md
  git -C "$test_catalog_checkout" commit -qm malformed-management-skill

  shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" ||
    fail_test 'catalog publication inspected malformed control-plane skill content'
  assert_equals "$(cksum < "$test_catalog_registry")" "$test_catalog_registry_checksum"
  test_catalog_control_ref=$(git -C "$test_catalog_checkout" rev-parse HEAD)
  if shimmy_ai_skill_control_bundle_materialize "$test_catalog_checkout" \
    "$test_catalog_control_ref" default "$SCENARIO_DIR/control-bundle" \
    >/dev/null 2>&1
  then
    fail_test 'control materialization accepted malformed management skill content'
  fi
  pass 'malformed management skills bypass catalog publication and fail at control materialization'
}

test_lib_catalog_invalid_current_recovery() {
  setup_scenario
  test_catalog_checkout=$SCENARIO_DIR/checkout
  test_catalog_config=$SCENARIO_DIR/config/shimmy
  test_catalog_fixture_create "$test_catalog_checkout" "$test_catalog_config"
  test_catalog_registry=$test_catalog_config/catalogs/default/registry.conf
  test_catalog_initial=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_registry")
  test_catalog_tool_source_advance "$test_catalog_checkout" 'Recovery generation two.'
  shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  test_catalog_corrupt=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_registry")
  printf 'catalog_corruption=1\n' >> "$test_catalog_config/catalogs/default/generations/$test_catalog_corrupt/catalog.conf"

  shimmy_catalog_default_rollback "$test_catalog_config" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  assert_equals "$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_registry")" "$test_catalog_initial"
  assert_equals "$(sed -n '4s/^catalog_generation_previous=//p' "$test_catalog_registry")" ''
  assert_dir_exists "$test_catalog_config/catalogs/default/generations/$test_catalog_corrupt"

  test_catalog_tool_source_advance "$test_catalog_checkout" 'Recovery generation three.'
  shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  test_catalog_recovered=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_registry")
  assert_equals "$(sed -n '4s/^catalog_generation_previous=//p' "$test_catalog_registry")" "$test_catalog_initial"
  [ "$test_catalog_recovered" != "$test_catalog_corrupt" ] || fail_test 'publication retained corrupt current authority'
  assert_dir_exists "$test_catalog_config/catalogs/default/generations/$test_catalog_corrupt"
  pass 'catalog rollback and publication recover invalid current authority without deleting retained generations'
}

test_catalog_move_head() {
  test_catalog_move_checkout=$1
  printf 'moved\n' > "$test_catalog_move_checkout/moved-head"
  git -C "$test_catalog_move_checkout" add moved-head
  git -C "$test_catalog_move_checkout" commit -qm moved-head
}

test_lib_catalog_publication_rejections() {
  setup_scenario
  test_catalog_checkout=$SCENARIO_DIR/checkout
  test_catalog_config=$SCENARIO_DIR/config/shimmy
  test_catalog_fixture_create "$test_catalog_checkout" "$test_catalog_config"
  test_catalog_registry=$test_catalog_config/catalogs/default/registry.conf
  test_catalog_registry_checksum=$(cksum < "$test_catalog_registry")

  printf 'dirty\n' > "$test_catalog_checkout/dirty"
  if shimmy_catalog_checkout_validate "$test_catalog_checkout" >/dev/null 2>&1; then fail_test 'dirty publication source was accepted'; fi
  rm "$test_catalog_checkout/dirty"
  git -C "$test_catalog_checkout" checkout -qb topic
  if shimmy_catalog_checkout_validate "$test_catalog_checkout" >/dev/null 2>&1; then fail_test 'non-main publication source was accepted'; fi
  git -C "$test_catalog_checkout" checkout -q main
  git -C "$test_catalog_checkout" checkout -q --detach
  if shimmy_catalog_checkout_validate "$test_catalog_checkout" >/dev/null 2>&1; then fail_test 'detached publication source was accepted'; fi
  git -C "$test_catalog_checkout" checkout -q main

  sed 's/^> Shimmy active-profile reconciliation.*/> malformed/' "$test_catalog_checkout/tools/jq/SKILL.md" > "$test_catalog_checkout/tools/jq/SKILL.md.tmp"
  mv "$test_catalog_checkout/tools/jq/SKILL.md.tmp" "$test_catalog_checkout/tools/jq/SKILL.md"
  git -C "$test_catalog_checkout" add tools/jq/SKILL.md
  git -C "$test_catalog_checkout" commit -qm malformed-skill
  if shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" >/dev/null 2>&1; then fail_test 'malformed catalog skill was published'; fi
  shimmy_catalog_lifecycle_cleanup || true
  shimmy_locks_release_all || true
  git -C "$test_catalog_checkout" reset -q --hard HEAD^

  test_catalog_tool_source_advance "$test_catalog_checkout" 'Moved HEAD publication.'
  SHIMMY_TEST_MODE=1
  SHIMMY_TEST_CATALOG_BEFORE_COMMIT_FUNCTION=test_catalog_move_head
  if shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" >/dev/null 2>&1; then fail_test 'moved HEAD publication was accepted'; fi
  SHIMMY_TEST_MODE=0
  SHIMMY_TEST_CATALOG_BEFORE_COMMIT_FUNCTION=
  shimmy_filesystem_transaction_cleanup || true
  shimmy_catalog_lifecycle_cleanup || true
  shimmy_locks_release_all || true
  assert_equals "$(cksum < "$test_catalog_registry")" "$test_catalog_registry_checksum"

  test_catalog_current=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_registry")
  printf 'catalog_collision=1\n' >> "$test_catalog_config/catalogs/default/generations/$test_catalog_current/catalog.conf"
  git -C "$test_catalog_checkout" reset -q --hard HEAD^^
  if shimmy_catalog_default_publish "$test_catalog_config" "$test_catalog_checkout" >/dev/null 2>&1; then fail_test 'catalog fingerprint collision was accepted'; fi
  shimmy_catalog_lifecycle_cleanup || true
  shimmy_locks_release_all || true
  assert_equals "$(cksum < "$test_catalog_registry")" "$test_catalog_registry_checksum"

  mkdir "$test_catalog_config/catalogs/default/generations/UNSAFE"
  if shimmy_catalog_status_render "$test_catalog_config" manifest >/dev/null 2>&1; then fail_test 'unsafe retained generation state was accepted'; fi
  pass 'publication rejects dirty, detached, non-main, moved-HEAD, malformed-skill, collision, and unsafe state'
}

test_lib_catalog_run() {
  test_lib_catalog_static_validation
  test_lib_catalog_lifecycle
  test_lib_catalog_pristine_baseline
  test_lib_catalog_control_validation_boundary
  test_lib_catalog_invalid_current_recovery
  test_lib_catalog_publication_rejections
}
