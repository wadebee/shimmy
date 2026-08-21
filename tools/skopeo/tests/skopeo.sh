#!/bin/sh
# Skopeo preview-contract tests.

test_tools_skopeo_preview_contract() {
  output=$(SHIMMY_SKOPEO_IMAGE=example.invalid/shimmy/skopeo:test SHIMMY_SKOPEO_IMAGE_PULL=always SHIMMY_SKOPEO_AUTH_SECRET=registry-example-auth run_in_repo ./commands/run-tool.sh skopeo --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'run' '--rm'"
  assert_contains "$output" "'-i'"
  assert_contains "$output" "'--secret' 'registry-example-auth,target=skopeo-auth.json'"
  assert_contains "$output" "'REGISTRY_AUTH_FILE=/run/secrets/skopeo-auth.json'"
  assert_contains "$output" "'example.invalid/shimmy/skopeo:test'"
  assert_not_contains "$output" 'shimmy-profile.conf'
  pass "Skopeo preview preserves image overrides and explicit auth secret handling"
}

test_tools_skopeo_registry_client_mount() {
  setup_scenario
  sibling_profile_root=$XDG_CONFIG_HOME_DIR/shimmy/profiles/team-one
  mkdir -p "$DEFAULT_PROFILE_ROOT/tools/skopeo/versions" "$sibling_profile_root" \
    "$HOME_DIR/.agents/skills"
  test_fixture_tree_copy "$ROOT_DIR/lib" "$DEFAULT_PROFILE_ROOT/lib"
  test_fixture_tree_copy "$ROOT_DIR/tools/skopeo/versions/1.22" \
    "$DEFAULT_PROFILE_ROOT/tools/skopeo/versions/1.22"
  printf '%s\n' \
    'shimmy_install_manifest_version=2' \
    'shimmy_install_layout=profile-materialized-root' \
    'shimmy_profile_manifest_version=2' \
    'shimmy_profile_name=default' \
    > "$DEFAULT_PROFILE_ROOT/install-manifest.txt"
  shimmy_registries_config_render default '' > "$DEFAULT_PROFILE_ROOT/registries.conf"
  shimmy_registries_config_render team-one '' > "$sibling_profile_root/registries.conf"
  shimmy_target_active_profile_render default "$HOME_DIR/.agents/skills" \
    > "$XDG_CONFIG_HOME_DIR/shimmy/active-profile.conf"
  chmod 0644 "$DEFAULT_PROFILE_ROOT/install-manifest.txt" \
    "$DEFAULT_PROFILE_ROOT/registries.conf" "$sibling_profile_root/registries.conf" \
    "$XDG_CONFIG_HOME_DIR/shimmy/active-profile.conf"
  skopeo_run=$DEFAULT_PROFILE_ROOT/tools/skopeo/versions/1.22/run.sh
  active_link=$XDG_CONFIG_HOME_DIR/containers/registries.conf.d/shimmy-active-profile.conf
  expected_mount=$DEFAULT_PROFILE_ROOT/registries.conf:/etc/containers/registries.conf.d/shimmy-profile.conf:ro

  inactive_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_OS=Linux SHIMMY_TEST_PROFILE_OS=Linux \
    "$skopeo_run" --preview-shim --version)
  assert_not_contains "$inactive_output" 'shimmy-profile.conf'

  mkdir -p "$(dirname -- "$active_link")"
  ln -s "$DEFAULT_PROFILE_ROOT/registries.conf" "$active_link"
  current_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_OS=Linux SHIMMY_TEST_PROFILE_OS=Linux \
    "$skopeo_run" --preview-shim --version)
  assert_contains "$current_output" "'-v' '$expected_mount'"
  assert_contains "$current_output" "'-v' '$PWD:/work' '-w' '/work'"

  set +e
  override_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_OS=Linux SHIMMY_TEST_PROFILE_OS=Linux \
    CONTAINERS_REGISTRIES_CONF=secret-value \
    "$skopeo_run" --preview-shim --version 2>&1)
  override_status=$?
  set -e
  [ "$override_status" -ne 0 ] || fail_test 'registry-overridden Skopeo preview unexpectedly succeeded'
  assert_contains "$override_output" 'CONTAINERS_REGISTRIES_CONF masks registry client policy (value hidden)'
  assert_not_contains "$override_output" 'secret-value'

  set +e
  connection_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_OS=Linux SHIMMY_TEST_PROFILE_OS=Linux \
    CONTAINER_HOST=secret-remote-endpoint \
    "$skopeo_run" --preview-shim --version 2>&1)
  connection_status=$?
  set -e
  [ "$connection_status" -ne 0 ] || fail_test 'connection-overridden Skopeo preview unexpectedly succeeded'
  assert_contains "$connection_output" 'CONTAINER_HOST masks the active profile engine (value hidden)'
  assert_not_contains "$connection_output" 'secret-remote-endpoint'

  rm -f "$active_link"
  ln -s "$sibling_profile_root/registries.conf" "$active_link"
  set +e
  sibling_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_OS=Linux SHIMMY_TEST_PROFILE_OS=Linux \
    "$skopeo_run" --preview-shim --version 2>&1)
  sibling_status=$?
  set -e
  [ "$sibling_status" -ne 0 ] || fail_test 'Skopeo preview unexpectedly accepted a sibling profile policy'
  assert_contains "$sibling_output" 'active registry policy belongs to profile team-one'

  rm -f "$active_link"
  rmdir "$(dirname -- "$active_link")"
  mkdir "$SCENARIO_DIR/foreign-dropins"
  ln -s "$SCENARIO_DIR/foreign-dropins" "$(dirname -- "$active_link")"
  set +e
  unsafe_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_OS=Linux SHIMMY_TEST_PROFILE_OS=Linux \
    "$skopeo_run" --preview-shim --version 2>&1)
  unsafe_status=$?
  set -e
  [ "$unsafe_status" -ne 0 ] || fail_test 'Skopeo preview unexpectedly accepted an unsafe activation path'
  assert_contains "$unsafe_output" 'active registry policy path is invalid or unsafe'

  rm -f "$(dirname -- "$active_link")"
  mkdir "$(dirname -- "$active_link")"
  ln -s "$DEFAULT_PROFILE_ROOT/registries.conf" "$active_link"
  printf '%s\n' damaged > "$DEFAULT_PROFILE_ROOT/registries.conf"
  set +e
  damaged_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_OS=Linux SHIMMY_TEST_PROFILE_OS=Linux \
    "$skopeo_run" --preview-shim --version 2>&1)
  damaged_status=$?
  set -e
  [ "$damaged_status" -ne 0 ] || fail_test 'Skopeo preview unexpectedly accepted a damaged registry policy'
  assert_contains "$damaged_output" 'registry configuration is invalid'
  pass 'Skopeo mounts only the active invoking profile registry policy and fails closed on masking, mismatch, unsafe paths, or damage'
}

test_tools_skopeo_run() {
  test_tools_skopeo_preview_contract
  test_tools_skopeo_registry_client_mount
}
