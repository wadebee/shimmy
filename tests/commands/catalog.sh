#!/bin/sh

images_fixture_fake_runtimes_write() {
  fixture_root=$1
  jq_run=$fixture_root/tools/jq/versions/1.8/run.sh
  skopeo_run=$fixture_root/tools/skopeo/versions/1.22/run.sh

  cat > "$jq_run" <<'EOF'
#!/bin/sh
payload=$(cat)
case "$payload" in
  *'"_fixture": "oci-valid"'*) printf 'verified\tapplication/vnd.oci.image.index.v1+json\tverified\n' ;;
  *'"_fixture": "docker-valid"'*) printf 'verified\tapplication/vnd.docker.distribution.manifest.list.v2+json\tverified\n' ;;
  *'"_fixture":"single-manifest"'*) printf 'unsupported-media-type\tunsupported\tfailed\n' ;;
  *'"_fixture":"child-digest"'*) printf 'unsupported-media-type\tunsupported\tfailed\n' ;;
  *'"_fixture":"missing-arm64"'*) printf 'missing-required-platform\tapplication/vnd.oci.image.index.v1+json\tfailed\n' ;;
  *'"_fixture":"unsupported-media"'*) printf 'unsupported-media-type\tunsupported\tfailed\n' ;;
  *'"_fixture":"empty-index"'*) printf 'missing-descriptors\tapplication/vnd.oci.image.index.v1+json\tfailed\n' ;;
  *'"_fixture":"absent-manifests"'*) printf 'missing-descriptors\tapplication/vnd.oci.image.index.v1+json\tfailed\n' ;;
  *) exit 4 ;;
esac
EOF

  cat > "$skopeo_run" <<'EOF'
#!/bin/sh
mode=digest
remote_ref=
for inspect_arg in "$@"; do
  [ "$inspect_arg" != --raw ] || mode=raw
  case "$inspect_arg" in docker://*) remote_ref=${inspect_arg#docker://} ;; esac
done
[ -n "$remote_ref" ] || exit 2
cat >/dev/null
printf '%s|%s\n' "$mode" "$remote_ref" >> "$SHIMMY_TEST_IMAGES_CALL_LOG"
while IFS='|' read -r response_mode response_ref response_value response_status; do
  [ "$response_mode" = "$mode" ] || continue
  [ "$response_ref" = "$remote_ref" ] || continue
  [ "$response_status" = ok ] || exit 3
  if [ "$mode" = raw ]; then
    cat "$SHIMMY_TEST_IMAGES_FIXTURE_DIR/$response_value"
  else
    printf '%s\n' "$response_value"
  fi
  exit 0
done < "$SHIMMY_TEST_IMAGES_RESPONSE_FILE"
exit 4
EOF
  chmod 0755 "$jq_run" "$skopeo_run"
}

test_target_images_fixture_setup() {
  test_target_images_access=${1:-public}
  setup_scenario
  TARGET_IMAGES_CHECKOUT=$SCENARIO_DIR/checkout
  TARGET_IMAGES_CONFIG=$SCENARIO_DIR/config/shimmy
  TARGET_IMAGES_CALL_LOG=$SCENARIO_DIR/image-calls
  TARGET_IMAGES_RESPONSES=$SCENARIO_DIR/image-responses

  test_target_catalog_checkout_create "$TARGET_IMAGES_CHECKOUT"
  for test_target_images_tool_dir in "$TARGET_IMAGES_CHECKOUT"/tools/*; do
    [ -d "$test_target_images_tool_dir" ] || continue
    test_target_images_tool_name=$(basename -- "$test_target_images_tool_dir")
    case "$test_target_images_tool_name" in jq|rg|skopeo) continue ;; esac
    git -C "$TARGET_IMAGES_CHECKOUT" rm -qr "tools/$test_target_images_tool_name"
  done
  if [ "$test_target_images_access" = authenticated ]; then
    sed 's/^image_registry_access=public$/image_registry_access=authenticated/' \
      "$TARGET_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf" \
      > "$TARGET_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf.tmp"
    mv "$TARGET_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf.tmp" \
      "$TARGET_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf"
    git -C "$TARGET_IMAGES_CHECKOUT" add tools/jq/versions/1.8/image.conf
  fi
  git -C "$TARGET_IMAGES_CHECKOUT" commit -qm target-images-fixture
  mkdir -p "$TARGET_IMAGES_CONFIG"
  shimmy_target_catalog_default_create "$TARGET_IMAGES_CONFIG" "$TARGET_IMAGES_CHECKOUT" ||
    fail_test "$SHIMMY_TARGET_CATALOG_ERROR"

  TARGET_IMAGES_GENERATION=$(sed -n '3s/^catalog_generation_current=//p' \
    "$TARGET_IMAGES_CONFIG/catalogs/default/registry.conf")
  TARGET_IMAGES_GENERATION_ROOT=$TARGET_IMAGES_CONFIG/catalogs/default/generations/$TARGET_IMAGES_GENERATION
  TARGET_IMAGES_COMMIT=$(sed -n '1s/^catalog_source_commit=//p' "$TARGET_IMAGES_GENERATION_ROOT/generation.conf")
  TARGET_IMAGES_FINGERPRINT=$(sed -n '2s/^catalog_content_fingerprint=//p' "$TARGET_IMAGES_GENERATION_ROOT/generation.conf")
  TARGET_IMAGES_PROFILE_ROOT=$TARGET_IMAGES_CONFIG/profiles/default
  mkdir -p "$TARGET_IMAGES_PROFILE_ROOT/tools" "$SCENARIO_DIR/home/.agents/skills"
  for test_target_images_tool_name in jq rg skopeo; do
    test_fixture_tree_copy "$TARGET_IMAGES_GENERATION_ROOT/tools/$test_target_images_tool_name" \
      "$TARGET_IMAGES_PROFILE_ROOT/tools/$test_target_images_tool_name"
  done
  images_fixture_fake_runtimes_write "$TARGET_IMAGES_PROFILE_ROOT"
  shimmy_target_active_profile_render default "$SCENARIO_DIR/home/.agents/skills" \
    > "$TARGET_IMAGES_CONFIG/active-profile.conf"
  shimmy_target_profile_manifest_render default https://example.invalid/shimmy.git "$TARGET_IMAGES_COMMIT" \
    "default|$TARGET_IMAGES_GENERATION|$TARGET_IMAGES_COMMIT|$TARGET_IMAGES_FINGERPRINT" \
    'jq|tracking
rg|tracking
skopeo|tracking' \
    'jq|1.8|default
rg|15.1|default
skopeo|1.22|default' > "$TARGET_IMAGES_PROFILE_ROOT/install-manifest.txt"

  : > "$TARGET_IMAGES_CALL_LOG"
  test_target_images_responses_write oci-index.json \
    sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91
}

test_target_images_fixture_run() {
  env \
    SHIMMY_TEST_IMAGES_CALL_LOG="$TARGET_IMAGES_CALL_LOG" \
    SHIMMY_TEST_IMAGES_FIXTURE_DIR="$ROOT_DIR/tests/commands/image-fixtures" \
    SHIMMY_TEST_IMAGES_RESPONSE_FILE="$TARGET_IMAGES_RESPONSES" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_IMAGES_CONFIG" \
    "$ROOT_DIR/commands/catalog.sh" verify "$@"
}

test_target_images_responses_write() {
  test_target_images_jq_fixture=$1
  test_target_images_jq_digest=$2
  : > "$TARGET_IMAGES_RESPONSES"
  for test_target_images_tool_name in jq rg skopeo; do
    test_target_images_tool_file=$TARGET_IMAGES_GENERATION_ROOT/tools/$test_target_images_tool_name/tool.conf
    test_target_images_version=$(sed -n 's/^tool_default_version=//p' "$test_target_images_tool_file")
    test_target_images_config_file=$TARGET_IMAGES_GENERATION_ROOT/tools/$test_target_images_tool_name/versions/$test_target_images_version/image.conf
    test_target_images_default_ref=$(sed -n 's/^image_default_ref=//p' "$test_target_images_config_file")
    test_target_images_upstream_ref=$(sed -n 's/^image_upstream_ref=//p' "$test_target_images_config_file")
    test_target_images_digest=$(shimmy_images_digest_read "$test_target_images_default_ref")
    test_target_images_fixture=oci-index.json
    [ "$test_target_images_tool_name" != skopeo ] || test_target_images_fixture=docker-list.json
    [ "$test_target_images_tool_name" != jq ] || {
      test_target_images_fixture=$test_target_images_jq_fixture
      test_target_images_digest=$test_target_images_jq_digest
    }
    printf 'raw|%s|%s|ok\n' "$test_target_images_default_ref" "$test_target_images_fixture" \
      >> "$TARGET_IMAGES_RESPONSES"
    printf 'digest|%s|%s|ok\n' "$test_target_images_upstream_ref" "$test_target_images_digest" \
      >> "$TARGET_IMAGES_RESPONSES"
  done
}

test_commands_target_catalog_inspection() {
  setup_scenario
  target_catalog_checkout=$SCENARIO_DIR/checkout
  target_catalog_config=$SCENARIO_DIR/config/shimmy
  test_target_catalog_fixture_create "$target_catalog_checkout" "$target_catalog_config"
  target_catalog_generation=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_config/catalogs/default/registry.conf")

  target_catalog_status=$(env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" "$ROOT_DIR/commands/catalog.sh" status --format manifest)
  target_catalog_tools=$(env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" "$ROOT_DIR/commands/catalog.sh" tools --format manifest)
  target_catalog_retained=$(env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" "$ROOT_DIR/commands/catalog.sh" tools --generation "$target_catalog_generation" --format manifest)
  assert_contains "$target_catalog_status" "shimmy_catalog=default|$target_catalog_generation||"
  assert_equals "$target_catalog_tools" "$target_catalog_retained"
  assert_contains "$target_catalog_tools" "default|$target_catalog_generation|rg|"
  pass 'catalog command renders deterministic local status and retained tools'
}

test_commands_target_catalog_mutation() {
  setup_scenario
  target_catalog_checkout=$SCENARIO_DIR/checkout
  target_catalog_config=$SCENARIO_DIR/config/shimmy
  test_target_catalog_fixture_create "$target_catalog_checkout" "$target_catalog_config"
  target_catalog_initial=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_config/catalogs/default/registry.conf")
  test_target_catalog_source_advance "$target_catalog_checkout" 'Command publication.'
  target_catalog_publish_output=$(cd "$target_catalog_checkout" && env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" ./commands/catalog.sh publish)
  target_catalog_published=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_config/catalogs/default/registry.conf")
  assert_contains "$target_catalog_publish_output" "shimmy_catalog=default|$target_catalog_published|$target_catalog_initial|"
  target_catalog_rollback_output=$(env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" "$ROOT_DIR/commands/catalog.sh" rollback)
  assert_contains "$target_catalog_rollback_output" "shimmy_catalog=default|$target_catalog_initial|$target_catalog_published|"
  pass 'catalog command publishes clean main and rolls back'
}

test_commands_target_catalog_verify_dependencies() {
  test_target_images_fixture_setup

  for test_target_images_dependency in jq skopeo; do
    case "$test_target_images_dependency" in
      jq) test_target_images_dependency_version=1.8 ;;
      skopeo) test_target_images_dependency_version=1.22 ;;
    esac
    test_target_images_runtime=$TARGET_IMAGES_PROFILE_ROOT/tools/$test_target_images_dependency/versions/$test_target_images_dependency_version/run.sh
    mv "$test_target_images_runtime" "$test_target_images_runtime.missing"
    : > "$TARGET_IMAGES_CALL_LOG"
    set +e
    test_target_images_missing_output=$(test_target_images_fixture_run --tool jq --format manifest 2>&1)
    test_target_images_missing_status=$?
    set -e
    [ "$test_target_images_missing_status" -ne 0 ] ||
      fail_test "target catalog verification accepted missing $test_target_images_dependency runtime"
    assert_contains "$test_target_images_missing_output" \
      "shimmy shim add $test_target_images_dependency@$test_target_images_dependency_version"
    assert_equals "$(cat "$TARGET_IMAGES_CALL_LOG")" ''
    mv "$test_target_images_runtime.missing" "$test_target_images_runtime"
  done

  cp "$TARGET_IMAGES_PROFILE_ROOT/install-manifest.txt" "$SCENARIO_DIR/install-manifest.saved"
  sed '/^shim=jq|/d; /^shim_version=jq|/d' "$SCENARIO_DIR/install-manifest.saved" \
    > "$TARGET_IMAGES_PROFILE_ROOT/install-manifest.txt"
  : > "$TARGET_IMAGES_CALL_LOG"
  set +e
  test_target_images_missing_output=$(test_target_images_fixture_run --tool jq --format manifest 2>&1)
  test_target_images_missing_status=$?
  set -e
  [ "$test_target_images_missing_status" -ne 0 ] ||
    fail_test 'target catalog verification accepted a stray jq runtime without manifest authority'
  assert_contains "$test_target_images_missing_output" 'shimmy shim add jq@1.8'
  assert_equals "$(cat "$TARGET_IMAGES_CALL_LOG")" ''
  mv "$SCENARIO_DIR/install-manifest.saved" "$TARGET_IMAGES_PROFILE_ROOT/install-manifest.txt"
  pass 'target catalog verification resolves jq and Skopeo only from active materialization with exact add remediation'
}

test_commands_target_catalog_verify_fixtures() {
  test_target_images_fixture_setup

  test_target_images_all_output=$(test_target_images_fixture_run --format manifest)
  assert_equals "$(printf '%s\n' "$test_target_images_all_output" | awk '/^image_verify=/ { count++ } END { print count + 0 }')" 3
  assert_contains "$test_target_images_all_output" 'image_verify=jq|1.8|runtime|'
  assert_contains "$test_target_images_all_output" 'image_verify=skopeo|1.22|runtime|'

  : > "$TARGET_IMAGES_CALL_LOG"
  test_target_images_repeated_output=$(test_target_images_fixture_run \
    --tool jq --tool skopeo --tool jq --format manifest)
  assert_equals "$(printf '%s\n' "$test_target_images_repeated_output" | awk '/^image_verify=/ { count++ } END { print count + 0 }')" 2
  assert_equals "$(awk -F '|' '$1 == "raw" { count++ } END { print count + 0 }' "$TARGET_IMAGES_CALL_LOG")" 2
  assert_equals "$(awk -F '|' '$1 == "digest" { count++ } END { print count + 0 }' "$TARGET_IMAGES_CALL_LOG")" 2

  for test_target_images_fixture_case in \
    'single-manifest.json|unsupported-media-type' \
    'malformed.json|malformed-json' \
    'missing-arm64.json|missing-required-platform' \
    'empty-index.json|missing-descriptors'
  do
    test_target_images_fixture_file=${test_target_images_fixture_case%%|*}
    test_target_images_fixture_error=${test_target_images_fixture_case#*|}
    test_target_images_responses_write "$test_target_images_fixture_file" \
      sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91
    set +e
    test_target_images_fixture_output=$(test_target_images_fixture_run --tool jq --format manifest 2>&1)
    test_target_images_fixture_status=$?
    set -e
    [ "$test_target_images_fixture_status" -ne 0 ] ||
      fail_test "$test_target_images_fixture_file unexpectedly passed target catalog verification"
    assert_contains "$test_target_images_fixture_output" "|fail|$test_target_images_fixture_error"
  done

  test_target_images_responses_write oci-index.json \
    sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
  test_target_images_drift_output=$(test_target_images_fixture_run --tool jq --format manifest)
  assert_contains "$test_target_images_drift_output" '|moved|warning|none'
  set +e
  test_target_images_strict_output=$(test_target_images_fixture_run \
    --tool jq --require-current-upstream --format manifest 2>&1)
  test_target_images_strict_status=$?
  set -e
  [ "$test_target_images_strict_status" -ne 0 ] || fail_test 'strict target upstream drift unexpectedly passed'
  assert_contains "$test_target_images_strict_output" '|moved|fail|upstream-drift'

  test_target_images_fixture_setup authenticated
  set +e
  test_target_images_auth_output=$(test_target_images_fixture_run --tool jq --format manifest 2>&1)
  test_target_images_auth_status=$?
  set -e
  [ "$test_target_images_auth_status" -ne 0 ] || fail_test 'authenticated target verification passed without a secret'
  assert_contains "$test_target_images_auth_output" '|missing|not-checked|fail|authentication-required'
  test_target_images_public_output=$(test_target_images_fixture_run --tool jq --public-only --format manifest)
  assert_contains "$test_target_images_public_output" '|skipped|not-checked|skip|none'
  test_target_images_secret_output=$(SHIMMY_SKOPEO_AUTH_SECRET='secret|value' \
    test_target_images_fixture_run --tool jq --format manifest)
  assert_contains "$test_target_images_secret_output" '|authenticated|current|pass|none'
  assert_not_contains "$test_target_images_secret_output" 'secret|value'
  pass 'target catalog verify preserves selection, cache, index, authentication, encoding, and drift semantics'
}

test_commands_target_catalog_run() {
  test_commands_target_catalog_inspection
  test_commands_target_catalog_mutation
  test_commands_target_catalog_verify_fixtures
  test_commands_target_catalog_verify_dependencies
}
