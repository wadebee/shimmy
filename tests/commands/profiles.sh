#!/bin/sh

test_manifest_mutate() {
  mutation_name=$1
  manifest_file=$2
  mutation_tmp=$manifest_file.mutation

  case "$mutation_name" in
    missing_identity)
      sed '/^shimmy_install_layout=/d' "$manifest_file" > "$mutation_tmp"
      ;;
    duplicate_identity)
      cp "$manifest_file" "$mutation_tmp"
      printf '%s\n' 'shimmy_install_layout=profile-flat-root' >> "$mutation_tmp"
      ;;
    version_two)
      sed 's/^shimmy_install_manifest_version=.*/shimmy_install_manifest_version=2/' "$manifest_file" > "$mutation_tmp"
      ;;
    unknown_version)
      sed 's/^shimmy_profile_manifest_version=.*/shimmy_profile_manifest_version=99/' "$manifest_file" > "$mutation_tmp"
      ;;
    wrong_label)
      sed 's/^shimmy_install_layout=.*/shimmy_install_layout=shared-core/' "$manifest_file" > "$mutation_tmp"
      ;;
    wrong_profile)
      sed 's/^shimmy_profile_name=.*/shimmy_profile_name=upstream/' "$manifest_file" > "$mutation_tmp"
      ;;
    unsafe_kind)
      sed 's/^kind=jq$/kind=..\/escape/' "$manifest_file" > "$mutation_tmp"
      ;;
    duplicate_ownership)
      cp "$manifest_file" "$mutation_tmp"
      printf '%s\n' 'kind=jq' >> "$mutation_tmp"
      ;;
    duplicate_kind_version)
      cp "$manifest_file" "$mutation_tmp"
      sed -n '/^kind_version=/ { p; q; }' "$manifest_file" >> "$mutation_tmp"
      ;;
    contradictory_kind_version)
      sed 's/^kind=jq$/kind=rg/' "$manifest_file" > "$mutation_tmp"
      ;;
    malformed_line)
      cp "$manifest_file" "$mutation_tmp"
      printf '%s\n' 'this is not a manifest entry' >> "$mutation_tmp"
      ;;
    shell_payload)
      cp "$manifest_file" "$mutation_tmp"
      printf 'payload=$(touch %s)\n' "$SCENARIO_DIR/manifest-payload-ran" >> "$mutation_tmp"
      ;;
    *)
      fail_test "unknown manifest mutation fixture: $mutation_name"
      ;;
  esac
  mv "$mutation_tmp" "$manifest_file"
}

test_commands_profiles_manifest_rejection() {
  setup_scenario
  bootstrap_default --shim jq >/dev/null
  manifest_file=$DEFAULT_PROFILE_ROOT/install-manifest.txt
  valid_manifest=$SCENARIO_DIR/valid-manifest.txt
  cp "$manifest_file" "$valid_manifest"
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/unmanaged-manifest-sentinel"
  launcher_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")
  implementation_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/implementations/jq")

  for mutation_name in missing_identity duplicate_identity version_two unknown_version wrong_label wrong_profile unsafe_kind duplicate_ownership duplicate_kind_version contradictory_kind_version malformed_line shell_payload; do
    cp "$valid_manifest" "$manifest_file"
    test_manifest_mutate "$mutation_name" "$manifest_file"
    set +e
    rejection_output=$(default_shimmy status --format manifest 2>&1)
    rejection_status=$?
    set -e
    [ "$rejection_status" -ne 0 ] || fail_test "invalid manifest unexpectedly accepted: $mutation_name"
    assert_contains "$rejection_output" 'invalid or unsupported Shimmy profile manifest'
    assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-manifest-sentinel"
    assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")" "$launcher_checksum"
    assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/implementations/jq")" "$implementation_checksum"
    assert_path_not_exists "$SCENARIO_DIR/manifest-payload-ran"
  done

  cp "$valid_manifest" "$manifest_file"
  rm -f "$manifest_file"
  set +e
  missing_output=$(default_shimmy status 2>&1)
  missing_status=$?
  set -e
  [ "$missing_status" -ne 0 ] || fail_test "missing manifest unexpectedly accepted"
  assert_contains "$missing_output" 'invalid or unsupported Shimmy profile manifest'

  cp "$valid_manifest" "$SCENARIO_DIR/manifest-target"
  ln -s "$SCENARIO_DIR/manifest-target" "$manifest_file"
  set +e
  symlink_output=$(default_shimmy status 2>&1)
  symlink_status=$?
  set -e
  [ "$symlink_status" -ne 0 ] || fail_test "symlinked manifest unexpectedly accepted"
  assert_contains "$symlink_output" 'invalid or unsupported Shimmy profile manifest'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-manifest-sentinel"
  pass "strict manifest parsing rejects malformed identity and ownership data without evaluating or mutating assets"
}

test_commands_profiles_upstream_checkout_rejection() {
  setup_scenario
  bootstrap_upstream --shim jq >/dev/null
  manifest_file=$UPSTREAM_PROFILE_ROOT/install-manifest.txt
  valid_manifest=$SCENARIO_DIR/upstream-manifest.txt
  cp "$manifest_file" "$valid_manifest"
  implementation_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/implementations/jq")

  invalid_checkout=relative/source
  awk -v checkout="$invalid_checkout" '
    /^source_checkout=/ { print "source_checkout=" checkout; next }
    { print }
  ' "$valid_manifest" > "$manifest_file"
  set +e
  relative_output=$(upstream_shimmy test --shim jq 2>&1)
  relative_status=$?
  set -e
  [ "$relative_status" -ne 0 ] || fail_test "relative upstream checkout unexpectedly accepted"
  assert_contains "$relative_output" 'invalid or unsupported Shimmy profile manifest'
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/implementations/jq")" "$implementation_checksum"

  for invalid_checkout in "$SCENARIO_DIR/missing-checkout"; do
    awk -v checkout="$invalid_checkout" '
      /^source_checkout=/ { print "source_checkout=" checkout; next }
      { print }
    ' "$valid_manifest" > "$manifest_file"
    set +e
    checkout_output=$(upstream_shimmy test --shim jq 2>&1)
    checkout_status=$?
    set -e
    [ "$checkout_status" -ne 0 ] || fail_test "invalid upstream checkout unexpectedly accepted: $invalid_checkout"
    assert_contains "$checkout_output" 'invalid upstream Shimmy checkout'
    assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/implementations/jq")" "$implementation_checksum"
  done
  pass "upstream smoke rejects malformed and stale recorded source checkouts without mutation"
}

test_commands_profiles_partial_shape() {
  setup_scenario
  bootstrap_default --shim jq >/dev/null
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/unmanaged-partial-sentinel"
  rm -rf "$DEFAULT_PROFILE_ROOT/tools"

  partial_status=$(default_shimmy status --format manifest)
  assert_contains "$partial_status" 'shimmy_installed=no'

  set +e
  activation_output=$(default_shimmy activate 2>&1)
  activation_status=$?
  dispatch_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version 2>&1)
  dispatch_status=$?
  set -e
  [ "$activation_status" -ne 0 ] || fail_test "partial profile unexpectedly activated"
  [ "$dispatch_status" -ne 0 ] || fail_test "partial profile unexpectedly dispatched"
  assert_contains "$activation_output" 'incomplete or damaged Shimmy profile'
  assert_contains "$dispatch_output" 'incomplete or damaged Shimmy profile'

  default_shimmy uninstall --no-skills >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-partial-sentinel"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/commands"
  pass "partial profiles report damaged state and uninstall only their remaining schema-owned assets"
}

test_commands_profiles_run() {
  setup_scenario
  bootstrap_default --shim jq >/dev/null
  bootstrap_upstream --shim rg >/dev/null

  default_status=$(default_shimmy status --format manifest)
  upstream_status=$(upstream_shimmy status --format manifest)
  assert_contains "$default_status" 'shimmy_profile_name=default'
  assert_contains "$upstream_status" 'shimmy_profile_name=upstream'

  set +e
  copied_output=$(cp "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "$UPSTREAM_PROFILE_ROOT/install-manifest.txt" 2>&1 && upstream_shimmy status 2>&1)
  copied_status=$?
  set -e
  [ "$copied_status" -ne 0 ] || fail_test "copied wrong-profile manifest unexpectedly succeeded"
  assert_contains "$copied_output" 'invalid or unsupported Shimmy profile manifest'

  setup_scenario
  set +e
  relative_output=$(run_in_repo env XDG_CONFIG_HOME=relative HOME="$HOME_DIR" ./install.sh --shim jq --no-startup --no-skills 2>&1)
  relative_status=$?
  set -e
  [ "$relative_status" -ne 0 ] || fail_test "relative XDG_CONFIG_HOME unexpectedly succeeded"
  assert_contains "$relative_output" 'unable to resolve canonical Shimmy profile'
  assert_path_not_exists "$ROOT_DIR/relative"
  pass "profile identity is directory-bound and relative XDG roots are rejected"

  test_commands_profiles_manifest_rejection
  test_commands_profiles_upstream_checkout_rejection
  test_commands_profiles_partial_shape
}
