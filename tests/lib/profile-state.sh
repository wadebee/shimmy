#!/bin/sh

test_lib_target_profile_state_fixture_create() {
  target_fixture_root=$1
  target_commit=1111111111111111111111111111111111111111
  target_catalog_commit=2222222222222222222222222222222222222222
  target_fingerprint=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target_shims='alpha|tracking
beta|pinned'
  target_versions='alpha|alpha-1|default
alpha|alpha-legacy|exact
beta|beta-2|default'
  target_startup_files="$target_fixture_root/home/.profile
$target_fixture_root/home/.zprofile"
  mkdir -p "$target_fixture_root/catalogs/default/generations/$target_generation" "$target_fixture_root/profile"
  shimmy_target_catalog_registry_render "$target_generation" '' "$target_catalog_commit" "$target_fingerprint" > "$target_fixture_root/catalogs/default/registry.conf"
  shimmy_target_catalog_generation_metadata_render "$target_catalog_commit" "$target_fingerprint" > "$target_fixture_root/catalogs/default/generations/$target_generation/generation.conf"
  shimmy_target_active_profile_render team-one "$target_fixture_root/home/.agents/skills" > "$target_fixture_root/active-profile.conf"
  shimmy_target_profile_manifest_render team-one https://example.invalid/shimmy.git "$target_commit" \
    "default|$target_generation|$target_catalog_commit|$target_fingerprint" "$target_shims" "$target_versions" zsh "$target_startup_files" \
    > "$target_fixture_root/profile/install-manifest.txt"
}

test_lib_target_profile_state_round_trip() {
  setup_scenario
  test_lib_target_profile_state_fixture_create "$SCENARIO_DIR/state"
  target_root=$SCENARIO_DIR/state
  shimmy_target_active_profile_read "$target_root/active-profile.conf" || fail_test 'valid active record rejected'
  shimmy_target_active_profile_render "$SHIMMY_TARGET_ACTIVE_PROFILE_NAME" "$SHIMMY_TARGET_ACTIVE_AI_SKILL_ROOT" > "$target_root/active-profile.round-trip"
  cmp -s "$target_root/active-profile.conf" "$target_root/active-profile.round-trip" || fail_test 'active record round trip changed bytes'
  shimmy_target_catalog_registry_read "$target_root/catalogs/default/registry.conf" || fail_test 'valid target catalog registry rejected'
  shimmy_target_catalog_registry_render "$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT" "$SHIMMY_TARGET_CATALOG_GENERATION_PREVIOUS" "$SHIMMY_TARGET_CATALOG_SOURCE_COMMIT" "$SHIMMY_TARGET_CATALOG_CONTENT_FINGERPRINT" > "$target_root/catalogs/default/registry.round-trip"
  cmp -s "$target_root/catalogs/default/registry.conf" "$target_root/catalogs/default/registry.round-trip" || fail_test 'catalog registry round trip changed bytes'
  shimmy_target_profile_manifest_read "$target_root/profile/install-manifest.txt" ||
    fail_test 'valid profile manifest rejected'
  shimmy_target_profile_manifest_render "$SHIMMY_TARGET_PROFILE_NAME" "$SHIMMY_TARGET_PROFILE_SOURCE_URL" "$SHIMMY_TARGET_PROFILE_SOURCE_REF" "$SHIMMY_TARGET_PROFILE_CATALOG_RECORD" "$SHIMMY_TARGET_PROFILE_SHIM_RECORDS" "$SHIMMY_TARGET_PROFILE_SHIM_VERSION_RECORDS" "$SHIMMY_TARGET_PROFILE_STARTUP_SHELL" "$SHIMMY_TARGET_PROFILE_STARTUP_FILES" > "$target_root/profile/install-manifest.round-trip"
  cmp -s "$target_root/profile/install-manifest.txt" "$target_root/profile/install-manifest.round-trip" || fail_test 'profile manifest round trip changed bytes'
  assert_equals "$SHIMMY_TARGET_PROFILE_NAME" team-one
  pass 'target active, catalog, generation, and profile fixtures round-trip byte-deterministically'
}

test_lib_target_profile_state_integrity() {
  setup_scenario
  test_lib_target_profile_state_fixture_create "$SCENARIO_DIR/state"
  target_manifest=$SCENARIO_DIR/state/profile/install-manifest.txt
  target_saved=$SCENARIO_DIR/saved-manifest
  cp "$target_manifest" "$target_saved"

  sed 's#refs/heads/main#refs/heads/release#' "$target_saved" > "$target_manifest"
  if shimmy_target_profile_manifest_read "$target_manifest"; then fail_test 'non-main tracking ref accepted'; fi
  sed 's#shim=alpha|tracking#shim=alpha|alpha-1|tracking#' "$target_saved" > "$target_manifest"
  if shimmy_target_profile_manifest_read "$target_manifest"; then fail_test 'redundant shim version field accepted'; fi
  sed 's#alpha|alpha-1|default#alpha|alpha-1|exact#' "$target_saved" > "$target_manifest"
  if shimmy_target_profile_manifest_read "$target_manifest"; then fail_test 'shim with no default version accepted'; fi
  sed 's#alpha|alpha-legacy|exact#alpha|alpha-legacy|default#' "$target_saved" > "$target_manifest"
  if shimmy_target_profile_manifest_read "$target_manifest"; then fail_test 'shim with multiple default versions accepted'; fi
  awk '{ print; if ($0 == "shim_version=alpha|alpha-1|default") print "shim_version=alpha|alpha-1|exact" }' "$target_saved" > "$target_manifest"
  if shimmy_target_profile_manifest_read "$target_manifest"; then fail_test 'one version in default and exact roles accepted'; fi
  awk '{ print; if ($0 == "shim=beta|pinned") print }' "$target_saved" > "$target_manifest"
  if shimmy_target_profile_manifest_read "$target_manifest"; then fail_test 'duplicate shim accepted'; fi
  sed "s#startup_file=.*#startup_file=$SCENARIO_DIR/state/home/../escape#" "$target_saved" > "$target_manifest"
  if shimmy_target_profile_manifest_read "$target_manifest"; then fail_test 'unsafe startup path accepted'; fi
  cp "$target_saved" "$target_manifest"
  printf '\000' >> "$target_manifest"
  if shimmy_target_profile_manifest_read "$target_manifest"; then fail_test 'NUL-bearing manifest accepted'; fi
  printf '%s' "$(cat "$target_saved")" > "$target_manifest"
  if shimmy_target_profile_manifest_read "$target_manifest"; then fail_test 'unterminated manifest accepted'; fi

  target_fingerprint=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  target_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  if shimmy_target_catalog_registry_render "$target_generation" "$target_generation" 2222222222222222222222222222222222222222 "$target_fingerprint" >/dev/null; then
    fail_test 'duplicate current/previous catalog generations accepted'
  fi
  pass 'target state rejects unsafe paths, duplicates, fixed-ref drift, redundant policy fields, and invalid default roles'
}

test_lib_target_profile_state_roots() {
  setup_scenario
  shimmy_target_profile_paths_resolve "$SCENARIO_DIR/disposable-shimmy" arbitrary-safe || fail_test 'disposable target roots rejected'
  assert_equals "$SHIMMY_TARGET_PROFILE_ROOT" "$SCENARIO_DIR/disposable-shimmy/profiles/arbitrary-safe"
  if shimmy_target_profile_paths_resolve relative/root valid-name; then fail_test 'relative target root accepted'; fi
  if shimmy_target_profile_paths_resolve "$SCENARIO_DIR/disposable-shimmy" invalid_name; then fail_test 'unsafe profile name accepted'; fi
  pass 'target roots are parameterized and profile names are arbitrary within the safe grammar'
}

test_lib_target_profile_state_run() {
  test_lib_target_profile_state_round_trip
  test_lib_target_profile_state_integrity
  test_lib_target_profile_state_roots
}
