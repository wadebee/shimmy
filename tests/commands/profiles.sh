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
    version_four)
      sed \
        -e 's/^shimmy_install_manifest_version=.*/shimmy_install_manifest_version=4/' \
        -e 's/^shimmy_profile_manifest_version=.*/shimmy_profile_manifest_version=4/' \
        "$manifest_file" > "$mutation_tmp"
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
    unsafe_tool)
      sed 's/^tool=jq$/tool=..\/escape/' "$manifest_file" > "$mutation_tmp"
      ;;
    duplicate_ownership)
      cp "$manifest_file" "$mutation_tmp"
      printf '%s\n' 'tool=jq' >> "$mutation_tmp"
      ;;
    duplicate_tool_version)
      cp "$manifest_file" "$mutation_tmp"
      sed -n '/^tool_version=/ { p; q; }' "$manifest_file" >> "$mutation_tmp"
      ;;
    contradictory_tool_version)
      sed 's/^tool=jq$/tool=rg/' "$manifest_file" > "$mutation_tmp"
      ;;
    legacy_tool_key)
      cp "$manifest_file" "$mutation_tmp"
      printf '%s\n' 'kind=jq' >> "$mutation_tmp"
      ;;
    legacy_tool_version_key)
      cp "$manifest_file" "$mutation_tmp"
      printf '%s\n' 'kind_version=jq|default|jq_1_8' >> "$mutation_tmp"
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
  setup_scenario_with_profiles default
  manifest_file=$DEFAULT_PROFILE_ROOT/install-manifest.txt
  valid_manifest=$SCENARIO_DIR/valid-manifest.txt
  cp "$manifest_file" "$valid_manifest"
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/unmanaged-manifest-sentinel"
  launcher_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")
  implementation_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/implementations/jq")

  for mutation_name in missing_identity duplicate_identity version_two version_four unknown_version wrong_label wrong_profile unsafe_tool duplicate_ownership duplicate_tool_version contradictory_tool_version legacy_tool_key legacy_tool_version_key malformed_line shell_payload; do
    cp "$valid_manifest" "$manifest_file"
    test_manifest_mutate "$mutation_name" "$manifest_file"
    set +e
    rejection_output=$(default_shimmy status --format manifest 2>&1)
    rejection_status=$?
    set -e
    [ "$rejection_status" -ne 0 ] || fail_test "invalid manifest unexpectedly accepted: $mutation_name"
    assert_contains "$rejection_output" 'invalid or unsupported Shimmy profile manifest'
    if [ "$mutation_name" = version_four ]; then
      assert_contains "$rejection_output" 'expected shimmy_install_manifest_version=1'
      assert_contains "$rejection_output" 'shimmy_profile_manifest_version=1'
    fi
    assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-manifest-sentinel"
    assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")" "$launcher_checksum"
    assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/implementations/jq")" "$implementation_checksum"
    assert_path_not_exists "$SCENARIO_DIR/manifest-payload-ran"
  done

  cp "$valid_manifest" "$manifest_file"
  test_manifest_mutate version_four "$manifest_file"
  set +e
  v4_refresh_output=$(bootstrap_default 2>&1)
  v4_refresh_status=$?
  set -e
  [ "$v4_refresh_status" -ne 0 ] || fail_test "manifest-v4 profile unexpectedly refreshed in place"
  assert_contains "$v4_refresh_output" 'expected shimmy_install_manifest_version=1'
  assert_file_contains "$manifest_file" 'shimmy_install_manifest_version=4'
  assert_file_contains "$manifest_file" 'shimmy_profile_manifest_version=4'
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")" "$launcher_checksum"
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/implementations/jq")" "$implementation_checksum"

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
  setup_scenario_with_profiles upstream
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
  setup_scenario_with_profiles default
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/unmanaged-partial-sentinel"
  rm -rf "$DEFAULT_PROFILE_ROOT/tools"

  partial_status=$(default_shimmy status --format manifest)
  assert_contains "$partial_status" 'shimmy_installed=no'

  set +e
  dispatch_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version 2>&1)
  dispatch_status=$?
  set -e
  [ "$dispatch_status" -ne 0 ] || fail_test "partial profile unexpectedly dispatched"
  assert_contains "$dispatch_output" 'incomplete or damaged Shimmy profile'

  default_shimmy uninstall >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-partial-sentinel"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/commands"
  pass "partial profiles report damaged state and uninstall only their remaining schema-owned assets"
}

test_commands_profiles_shell_init_shape() {
  for shell_init_mutation in missing symlink directory; do
    setup_scenario_with_profiles default
    shell_init_file=$DEFAULT_PROFILE_ROOT/shell-init.sh
    manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
    launcher_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")
    implementation_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/implementations/jq")

    case "$shell_init_mutation" in
      missing)
        rm -f "$shell_init_file"
        ;;
      symlink)
        shell_init_target=$SCENARIO_DIR/shell-init-target
        printf '%s\n' keep > "$shell_init_target"
        rm -f "$shell_init_file"
        ln -s "$shell_init_target" "$shell_init_file"
        ;;
      directory)
        rm -f "$shell_init_file"
        mkdir "$shell_init_file"
        printf '%s\n' keep > "$shell_init_file/sentinel"
        ;;
    esac

    damaged_status=$(default_shimmy status --format manifest)
    assert_contains "$damaged_status" 'shimmy_installed=no'
    set +e
    dispatch_output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version 2>&1)
    dispatch_status=$?
    set -e
    [ "$dispatch_status" -ne 0 ] || fail_test "$shell_init_mutation shell init damage unexpectedly dispatched"
    assert_contains "$dispatch_output" 'incomplete or damaged Shimmy profile'
    assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$manifest_checksum"
    assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")" "$launcher_checksum"
    assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/implementations/jq")" "$implementation_checksum"

    if [ "$shell_init_mutation" != missing ]; then
      set +e
      refresh_output=$(bootstrap_default 2>&1)
      refresh_status=$?
      set -e
      [ "$refresh_status" -ne 0 ] || fail_test "$shell_init_mutation shell init collision unexpectedly refreshed"
      assert_contains "$refresh_output" 'installed shell init must be a regular non-symlink file'
      case "$shell_init_mutation" in
        symlink)
          assert_path_symlink "$shell_init_file"
          assert_file_contains "$shell_init_target" keep
          ;;
        directory)
          assert_file_exists "$shell_init_file/sentinel"
          ;;
      esac
    fi
  done
  pass "missing, symlinked, and non-file shell init assets fail structure checks without mutating owned state"
}

test_commands_profiles_identity() {
  setup_scenario_with_profiles default upstream

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
  relative_output=$(run_in_repo env XDG_CONFIG_HOME=relative HOME="$HOME_DIR" ./install.sh --no-startup 2>&1)
  relative_status=$?
  set -e
  [ "$relative_status" -ne 0 ] || fail_test "relative XDG_CONFIG_HOME unexpectedly succeeded"
  assert_contains "$relative_output" 'unable to resolve canonical Shimmy profile'
  assert_path_not_exists "$ROOT_DIR/relative"
  pass "profile identity is directory-bound and relative XDG roots are rejected"
}

test_commands_profiles_run() {
  test_commands_profiles_identity
  test_commands_profiles_manifest_rejection
  test_commands_profiles_upstream_checkout_rejection
  test_commands_profiles_partial_shape
  test_commands_profiles_shell_init_shape
}
