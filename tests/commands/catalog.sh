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

test_images_fixture_setup() {
  test_images_access=${1:-public}
  setup_scenario
  TEST_IMAGES_CHECKOUT=$SCENARIO_DIR/checkout
  TEST_IMAGES_CONFIG=$SCENARIO_DIR/config/shimmy
  TEST_IMAGES_CALL_LOG=$SCENARIO_DIR/image-calls
  TEST_IMAGES_RESPONSES=$SCENARIO_DIR/image-responses

  test_catalog_checkout_create "$TEST_IMAGES_CHECKOUT"
  for test_images_tool_dir in "$TEST_IMAGES_CHECKOUT"/tools/*; do
    [ -d "$test_images_tool_dir" ] || continue
    test_images_tool_name=$(basename -- "$test_images_tool_dir")
    case "$test_images_tool_name" in jq|rg|skopeo) continue ;; esac
    git -C "$TEST_IMAGES_CHECKOUT" rm -qr "tools/$test_images_tool_name"
  done
  if [ "$test_images_access" = authenticated ]; then
    sed 's/^image_registry_access=public$/image_registry_access=authenticated/' \
      "$TEST_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf" \
      > "$TEST_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf.tmp"
    mv "$TEST_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf.tmp" \
      "$TEST_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf"
    git -C "$TEST_IMAGES_CHECKOUT" add tools/jq/versions/1.8/image.conf
  fi
  git -C "$TEST_IMAGES_CHECKOUT" commit -qm catalog-images-fixture
  mkdir -p "$TEST_IMAGES_CONFIG"
  shimmy_catalog_default_create "$TEST_IMAGES_CONFIG" "$TEST_IMAGES_CHECKOUT" ||
    fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"

  TEST_IMAGES_GENERATION=$(sed -n '3s/^catalog_generation_current=//p' \
    "$TEST_IMAGES_CONFIG/catalogs/default/registry.conf")
  TEST_IMAGES_GENERATION_ROOT=$TEST_IMAGES_CONFIG/catalogs/default/generations/$TEST_IMAGES_GENERATION
  TEST_IMAGES_COMMIT=$(sed -n '1s/^catalog_source_commit=//p' "$TEST_IMAGES_GENERATION_ROOT/generation.conf")
  TEST_IMAGES_FINGERPRINT=$(sed -n '2s/^catalog_content_fingerprint=//p' "$TEST_IMAGES_GENERATION_ROOT/generation.conf")
  TEST_IMAGES_PROFILE_ROOT=$TEST_IMAGES_CONFIG/profiles/default
  mkdir -p "$TEST_IMAGES_PROFILE_ROOT/tools" "$SCENARIO_DIR/home/.agents/skills"
  for test_images_tool_name in jq rg skopeo; do
    test_fixture_tree_copy "$TEST_IMAGES_GENERATION_ROOT/tools/$test_images_tool_name" \
      "$TEST_IMAGES_PROFILE_ROOT/tools/$test_images_tool_name"
  done
  images_fixture_fake_runtimes_write "$TEST_IMAGES_PROFILE_ROOT"
  shimmy_active_profile_render default "$SCENARIO_DIR/home/.agents/skills" \
    > "$TEST_IMAGES_CONFIG/active-profile.conf"
  shimmy_profile_manifest_render default https://example.invalid/shimmy.git "$TEST_IMAGES_COMMIT" \
    "default|$TEST_IMAGES_GENERATION|$TEST_IMAGES_COMMIT|$TEST_IMAGES_FINGERPRINT" \
    'jq|tracking
rg|tracking
skopeo|tracking' \
    'jq|1.8|default
rg|15.1|default
skopeo|1.22|default' > "$TEST_IMAGES_PROFILE_ROOT/install-manifest.txt"

  : > "$TEST_IMAGES_CALL_LOG"
  test_images_responses_write oci-index.json \
    sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91
}

test_images_fixture_run() {
  env \
    SHIMMY_TEST_IMAGES_CALL_LOG="$TEST_IMAGES_CALL_LOG" \
    SHIMMY_TEST_IMAGES_FIXTURE_DIR="$ROOT_DIR/tests/commands/image-fixtures" \
    SHIMMY_TEST_IMAGES_RESPONSE_FILE="$TEST_IMAGES_RESPONSES" \
    SHIMMY_CONFIG_ROOT="$TEST_IMAGES_CONFIG" \
    "$ROOT_DIR/commands/catalog.sh" verify "$@"
}

test_images_responses_write() {
  test_images_jq_fixture=$1
  test_images_jq_digest=$2
  : > "$TEST_IMAGES_RESPONSES"
  for test_images_tool_name in jq rg skopeo; do
    test_images_tool_file=$TEST_IMAGES_GENERATION_ROOT/tools/$test_images_tool_name/tool.conf
    test_images_version=$(sed -n 's/^tool_default_version=//p' "$test_images_tool_file")
    test_images_config_file=$TEST_IMAGES_GENERATION_ROOT/tools/$test_images_tool_name/versions/$test_images_version/image.conf
    test_images_default_ref=$(sed -n 's/^image_default_ref=//p' "$test_images_config_file")
    test_images_upstream_ref=$(sed -n 's/^image_upstream_ref=//p' "$test_images_config_file")
    test_images_digest=$(shimmy_images_digest_read "$test_images_default_ref")
    test_images_fixture=oci-index.json
    [ "$test_images_tool_name" != skopeo ] || test_images_fixture=docker-list.json
    [ "$test_images_tool_name" != jq ] || {
      test_images_fixture=$test_images_jq_fixture
      test_images_digest=$test_images_jq_digest
    }
    printf 'raw|%s|%s|ok\n' "$test_images_default_ref" "$test_images_fixture" \
      >> "$TEST_IMAGES_RESPONSES"
    printf 'digest|%s|%s|ok\n' "$test_images_upstream_ref" "$test_images_digest" \
      >> "$TEST_IMAGES_RESPONSES"
  done
}

test_commands_catalog_inspection() {
  setup_scenario
  test_catalog_checkout=$SCENARIO_DIR/checkout
  test_catalog_config=$SCENARIO_DIR/config/shimmy
  test_catalog_fixture_create "$test_catalog_checkout" "$test_catalog_config"
  test_catalog_generation=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_config/catalogs/default/registry.conf")

  test_catalog_status=$(env SHIMMY_CONFIG_ROOT="$test_catalog_config" "$ROOT_DIR/commands/catalog.sh" status --format manifest)
  test_catalog_tools=$(env SHIMMY_CONFIG_ROOT="$test_catalog_config" "$ROOT_DIR/commands/catalog.sh" tools --format manifest)
  test_catalog_retained=$(env SHIMMY_CONFIG_ROOT="$test_catalog_config" "$ROOT_DIR/commands/catalog.sh" tools --generation "$test_catalog_generation" --format manifest)
  assert_contains "$test_catalog_status" "shimmy_catalog=default|$test_catalog_generation||"
  assert_equals "$test_catalog_tools" "$test_catalog_retained"
  assert_contains "$test_catalog_tools" "default|$test_catalog_generation|rg|"
  pass 'catalog command renders deterministic local status and retained tools'
}

test_commands_catalog_mutation() {
  setup_scenario
  test_catalog_checkout=$SCENARIO_DIR/checkout
  test_catalog_config=$SCENARIO_DIR/config/shimmy
  test_catalog_fixture_create "$test_catalog_checkout" "$test_catalog_config"
  test_catalog_initial=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_config/catalogs/default/registry.conf")
  test_catalog_source_advance "$test_catalog_checkout" 'Command publication.'
  test_catalog_publish_output=$(cd "$test_catalog_checkout" && env SHIMMY_CONFIG_ROOT="$test_catalog_config" ./commands/catalog.sh publish)
  test_catalog_published=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_config/catalogs/default/registry.conf")
  assert_contains "$test_catalog_publish_output" "shimmy_catalog=default|$test_catalog_published|$test_catalog_initial|"
  test_catalog_rollback_output=$(env SHIMMY_CONFIG_ROOT="$test_catalog_config" "$ROOT_DIR/commands/catalog.sh" rollback)
  assert_contains "$test_catalog_rollback_output" "shimmy_catalog=default|$test_catalog_initial|$test_catalog_published|"
  pass 'catalog command publishes clean main and rolls back'
}

test_commands_catalog_verify_dependencies() {
  test_images_fixture_setup

  for test_images_dependency in jq skopeo; do
    case "$test_images_dependency" in
      jq) test_images_dependency_version=1.8 ;;
      skopeo) test_images_dependency_version=1.22 ;;
    esac
    test_images_runtime=$TEST_IMAGES_PROFILE_ROOT/tools/$test_images_dependency/versions/$test_images_dependency_version/run.sh
    mv "$test_images_runtime" "$test_images_runtime.missing"
    : > "$TEST_IMAGES_CALL_LOG"
    set +e
    test_images_missing_output=$(test_images_fixture_run --tool jq --format manifest 2>&1)
    test_images_missing_status=$?
    set -e
    [ "$test_images_missing_status" -ne 0 ] ||
      fail_test "catalog verification accepted missing $test_images_dependency runtime"
    assert_contains "$test_images_missing_output" \
      "shimmy shim add $test_images_dependency@$test_images_dependency_version"
    assert_equals "$(cat "$TEST_IMAGES_CALL_LOG")" ''
    mv "$test_images_runtime.missing" "$test_images_runtime"
  done

  cp "$TEST_IMAGES_PROFILE_ROOT/install-manifest.txt" "$SCENARIO_DIR/install-manifest.saved"
  sed '/^shim=jq|/d; /^shim_version=jq|/d' "$SCENARIO_DIR/install-manifest.saved" \
    > "$TEST_IMAGES_PROFILE_ROOT/install-manifest.txt"
  : > "$TEST_IMAGES_CALL_LOG"
  set +e
  test_images_missing_output=$(test_images_fixture_run --tool jq --format manifest 2>&1)
  test_images_missing_status=$?
  set -e
  [ "$test_images_missing_status" -ne 0 ] ||
    fail_test 'catalog verification accepted a stray jq runtime without manifest authority'
  assert_contains "$test_images_missing_output" 'shimmy shim add jq@1.8'
  assert_equals "$(cat "$TEST_IMAGES_CALL_LOG")" ''
  mv "$SCENARIO_DIR/install-manifest.saved" "$TEST_IMAGES_PROFILE_ROOT/install-manifest.txt"
  pass 'catalog verification resolves jq and Skopeo only from active materialization with exact add remediation'
}

test_commands_catalog_verify_fixtures() {
  test_images_fixture_setup

  test_images_all_output=$(test_images_fixture_run --format manifest)
  assert_equals "$(printf '%s\n' "$test_images_all_output" | awk '/^image_verify=/ { count++ } END { print count + 0 }')" 3
  assert_contains "$test_images_all_output" 'image_verify=jq|1.8|runtime|'
  assert_contains "$test_images_all_output" 'image_verify=skopeo|1.22|runtime|'

  : > "$TEST_IMAGES_CALL_LOG"
  test_images_repeated_output=$(test_images_fixture_run \
    --tool jq --tool skopeo --tool jq --format manifest)
  assert_equals "$(printf '%s\n' "$test_images_repeated_output" | awk '/^image_verify=/ { count++ } END { print count + 0 }')" 2
  assert_equals "$(awk -F '|' '$1 == "raw" { count++ } END { print count + 0 }' "$TEST_IMAGES_CALL_LOG")" 2
  assert_equals "$(awk -F '|' '$1 == "digest" { count++ } END { print count + 0 }' "$TEST_IMAGES_CALL_LOG")" 2

  for test_images_fixture_case in \
    'single-manifest.json|unsupported-media-type' \
    'malformed.json|malformed-json' \
    'missing-arm64.json|missing-required-platform' \
    'empty-index.json|missing-descriptors'
  do
    test_images_fixture_file=${test_images_fixture_case%%|*}
    test_images_fixture_error=${test_images_fixture_case#*|}
    test_images_responses_write "$test_images_fixture_file" \
      sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91
    set +e
    test_images_fixture_output=$(test_images_fixture_run --tool jq --format manifest 2>&1)
    test_images_fixture_status=$?
    set -e
    [ "$test_images_fixture_status" -ne 0 ] ||
      fail_test "$test_images_fixture_file unexpectedly passed catalog verification"
    assert_contains "$test_images_fixture_output" "|fail|$test_images_fixture_error"
  done

  test_images_responses_write oci-index.json \
    sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
  test_images_drift_output=$(test_images_fixture_run --tool jq --format manifest)
  assert_contains "$test_images_drift_output" '|moved|warning|none'
  set +e
  test_images_strict_output=$(test_images_fixture_run \
    --tool jq --require-current-upstream --format manifest 2>&1)
  test_images_strict_status=$?
  set -e
  [ "$test_images_strict_status" -ne 0 ] || fail_test 'strict catalog upstream drift unexpectedly passed'
  assert_contains "$test_images_strict_output" '|moved|fail|upstream-drift'

  test_images_fixture_setup authenticated
  set +e
  test_images_auth_output=$(test_images_fixture_run --tool jq --format manifest 2>&1)
  test_images_auth_status=$?
  set -e
  [ "$test_images_auth_status" -ne 0 ] || fail_test 'authenticated catalog verification passed without a secret'
  assert_contains "$test_images_auth_output" '|missing|not-checked|fail|authentication-required'
  test_images_public_output=$(test_images_fixture_run --tool jq --public-only --format manifest)
  assert_contains "$test_images_public_output" '|skipped|not-checked|skip|none'
  test_images_secret_output=$(SHIMMY_SKOPEO_AUTH_SECRET='secret|value' \
    test_images_fixture_run --tool jq --format manifest)
  assert_contains "$test_images_secret_output" '|authenticated|current|pass|none'
  assert_not_contains "$test_images_secret_output" 'secret|value'
  pass 'catalog verify preserves selection, cache, index, authentication, encoding, and drift semantics'
}

test_commands_catalog_run() {
  test_commands_catalog_inspection
  test_commands_catalog_mutation
  test_commands_catalog_verify_fixtures
  test_commands_catalog_verify_dependencies
}
