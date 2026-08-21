#!/bin/sh

test_lib_profile_state_fixture_create() {
  test_fixture_root=$1
  test_commit=1111111111111111111111111111111111111111
  test_catalog_commit=2222222222222222222222222222222222222222
  test_fingerprint=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  test_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  test_shims='alpha|tracking
beta|pinned'
  test_versions='alpha|alpha-1|default
alpha|alpha-legacy|exact
beta|beta-2|default'
  test_startup_files="$test_fixture_root/home/.profile
$test_fixture_root/home/.zprofile"
  mkdir -p "$test_fixture_root/catalogs/default/generations/$test_generation" "$test_fixture_root/profile"
  shimmy_catalog_registry_render "$test_generation" '' "$test_catalog_commit" "$test_fingerprint" > "$test_fixture_root/catalogs/default/registry.conf"
  shimmy_catalog_generation_metadata_render "$test_catalog_commit" "$test_fingerprint" > "$test_fixture_root/catalogs/default/generations/$test_generation/generation.conf"
  shimmy_active_profile_render team-one "$test_fixture_root/home/.agents/skills" > "$test_fixture_root/active-profile.conf"
  shimmy_profile_manifest_render team-one https://example.invalid/shimmy.git "$test_commit" \
    "default|$test_generation|$test_catalog_commit|$test_fingerprint" "$test_shims" "$test_versions" zsh "$test_startup_files" \
    > "$test_fixture_root/profile/install-manifest.txt"
}

test_lib_profile_state_round_trip() {
  setup_scenario
  test_lib_profile_state_fixture_create "$SCENARIO_DIR/state"
  test_root=$SCENARIO_DIR/state
  shimmy_active_profile_read "$test_root/active-profile.conf" || fail_test 'valid active record rejected'
  shimmy_active_profile_render "$SHIMMY_ACTIVE_PROFILE_NAME" "$SHIMMY_ACTIVE_AI_SKILL_ROOT" > "$test_root/active-profile.round-trip"
  cmp -s "$test_root/active-profile.conf" "$test_root/active-profile.round-trip" || fail_test 'active record round trip changed bytes'
  shimmy_catalog_registry_read "$test_root/catalogs/default/registry.conf" || fail_test 'valid catalog registry rejected'
  shimmy_catalog_registry_render "$SHIMMY_CATALOG_GENERATION_CURRENT" "$SHIMMY_CATALOG_GENERATION_PREVIOUS" "$SHIMMY_CATALOG_SOURCE_COMMIT" "$SHIMMY_CATALOG_CONTENT_FINGERPRINT" > "$test_root/catalogs/default/registry.round-trip"
  cmp -s "$test_root/catalogs/default/registry.conf" "$test_root/catalogs/default/registry.round-trip" || fail_test 'catalog registry round trip changed bytes'
  shimmy_profile_manifest_read "$test_root/profile/install-manifest.txt" ||
    fail_test 'valid profile manifest rejected'
  shimmy_profile_manifest_render "$SHIMMY_PROFILE_NAME" "$SHIMMY_PROFILE_SOURCE_URL" "$SHIMMY_PROFILE_SOURCE_REF" "$SHIMMY_PROFILE_CATALOG_RECORD" "$SHIMMY_PROFILE_SHIM_RECORDS" "$SHIMMY_PROFILE_SHIM_VERSION_RECORDS" "$SHIMMY_PROFILE_STARTUP_SHELL" "$SHIMMY_PROFILE_STARTUP_FILES" > "$test_root/profile/install-manifest.round-trip"
  cmp -s "$test_root/profile/install-manifest.txt" "$test_root/profile/install-manifest.round-trip" || fail_test 'profile manifest round trip changed bytes'
  assert_equals "$SHIMMY_PROFILE_NAME" team-one
  pass 'active, catalog, generation, and profile fixtures round-trip byte-deterministically'
}

test_lib_profile_state_integrity() {
  setup_scenario
  test_lib_profile_state_fixture_create "$SCENARIO_DIR/state"
  test_manifest=$SCENARIO_DIR/state/profile/install-manifest.txt
  test_saved=$SCENARIO_DIR/saved-manifest
  cp "$test_manifest" "$test_saved"

  sed 's#refs/heads/main#refs/heads/release#' "$test_saved" > "$test_manifest"
  if shimmy_profile_manifest_read "$test_manifest"; then fail_test 'non-main tracking ref accepted'; fi
  sed 's#shim=alpha|tracking#shim=alpha|alpha-1|tracking#' "$test_saved" > "$test_manifest"
  if shimmy_profile_manifest_read "$test_manifest"; then fail_test 'redundant shim version field accepted'; fi
  sed 's#alpha|alpha-1|default#alpha|alpha-1|exact#' "$test_saved" > "$test_manifest"
  if shimmy_profile_manifest_read "$test_manifest"; then fail_test 'shim with no default version accepted'; fi
  sed 's#alpha|alpha-legacy|exact#alpha|alpha-legacy|default#' "$test_saved" > "$test_manifest"
  if shimmy_profile_manifest_read "$test_manifest"; then fail_test 'shim with multiple default versions accepted'; fi
  awk '{ print; if ($0 == "shim_version=alpha|alpha-1|default") print "shim_version=alpha|alpha-1|exact" }' "$test_saved" > "$test_manifest"
  if shimmy_profile_manifest_read "$test_manifest"; then fail_test 'one version in default and exact roles accepted'; fi
  awk '{ print; if ($0 == "shim=beta|pinned") print }' "$test_saved" > "$test_manifest"
  if shimmy_profile_manifest_read "$test_manifest"; then fail_test 'duplicate shim accepted'; fi
  sed "s#startup_file=.*#startup_file=$SCENARIO_DIR/state/home/../escape#" "$test_saved" > "$test_manifest"
  if shimmy_profile_manifest_read "$test_manifest"; then fail_test 'unsafe startup path accepted'; fi
  cp "$test_saved" "$test_manifest"
  printf '\000' >> "$test_manifest"
  if shimmy_profile_manifest_read "$test_manifest"; then fail_test 'NUL-bearing manifest accepted'; fi
  printf '%s' "$(cat "$test_saved")" > "$test_manifest"
  if shimmy_profile_manifest_read "$test_manifest"; then fail_test 'unterminated manifest accepted'; fi

  test_fingerprint=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  test_generation=sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  if shimmy_catalog_registry_render "$test_generation" "$test_generation" 2222222222222222222222222222222222222222 "$test_fingerprint" >/dev/null; then
    fail_test 'duplicate current/previous catalog generations accepted'
  fi
  pass 'state rejects unsafe paths, duplicates, fixed-ref drift, redundant policy fields, and invalid default roles'
}

test_lib_profile_state_roots() {
  setup_scenario
  shimmy_profile_state_paths_resolve "$SCENARIO_DIR/disposable-shimmy" arbitrary-safe || fail_test 'disposable profile roots rejected'
  assert_equals "$SHIMMY_PROFILE_ROOT" "$SCENARIO_DIR/disposable-shimmy/profiles/arbitrary-safe"
  if shimmy_profile_state_paths_resolve relative/root valid-name; then fail_test 'relative root accepted'; fi
  if shimmy_profile_state_paths_resolve "$SCENARIO_DIR/disposable-shimmy" invalid_name; then fail_test 'unsafe profile name accepted'; fi
  pass 'profile roots are parameterized and profile names are arbitrary within the safe grammar'
}

test_lib_profile_state_run() {
  test_lib_profile_state_round_trip
  test_lib_profile_state_integrity
  test_lib_profile_state_roots
}
