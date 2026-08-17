#!/bin/sh
# Metadata and source-dispatch behavior tests.

test_lib_catalog_activate() {
  # shellcheck source=lib/catalog/catalog.sh
  . "$ROOT_DIR/lib/catalog/catalog.sh"
  shimmy_catalog_checkout_resolve "$ROOT_DIR" upstream || fail_test "$SHIMMY_CATALOG_ERROR"
}

test_lib_catalog_context_tree() {
  "$ROOT_DIR/tests/context-tree.sh"
  pass "retained CONTEXT tree"
}

test_lib_catalog_context_tree_rejects_prohibited_file() {
  setup_scenario
  prohibited_tree=$SCENARIO_DIR/prohibited-tree
  mkdir -p "$prohibited_tree/nested"
  : > "$prohibited_tree/nested/CONTEXT.md"

  set +e
  output=$("$ROOT_DIR/tests/context-tree.sh" --check-prohibited-tree "$prohibited_tree" 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "prohibited context fixture unexpectedly passed"
  assert_contains "$output" 'prohibited context file:'
  pass "prohibited tool and plugin context files are rejected"
}

test_lib_catalog_contract_fixture_create() {
  catalog_fixture_root=$1
  mkdir -p "$catalog_fixture_root/tools"
  cp "$ROOT_DIR/catalog.conf" "$catalog_fixture_root/catalog.conf"
  test_fixture_tree_copy "$ROOT_DIR/plugins" "$catalog_fixture_root/plugins"
  test_fixture_tree_copy "$ROOT_DIR/tools/jq" "$catalog_fixture_root/tools/jq"
}

test_lib_catalog_contract_rejection() {
  for catalog_mutation in missing-format duplicate-schema unknown-key unsupported-schema missing-skill invalid-skill-name unexpected-management-skill unsafe-link orphan-tool duplicate-version; do
    setup_scenario
    catalog_fixture_root=$SCENARIO_DIR/catalog
    test_lib_catalog_contract_fixture_create "$catalog_fixture_root"
    case "$catalog_mutation" in
      missing-format)
        sed '/^catalog_format=/d' "$catalog_fixture_root/catalog.conf" > "$catalog_fixture_root/catalog.conf.tmp"
        mv "$catalog_fixture_root/catalog.conf.tmp" "$catalog_fixture_root/catalog.conf"
        ;;
      duplicate-schema)
        printf 'catalog_schema=1\n' >> "$catalog_fixture_root/catalog.conf"
        ;;
      unknown-key)
        printf 'catalog_mode=legacy\n' >> "$catalog_fixture_root/catalog.conf"
        ;;
      unsupported-schema)
        printf '%s\n' 'catalog_format=shimmy-catalog' 'catalog_schema=2' > "$catalog_fixture_root/catalog.conf"
        ;;
      missing-skill)
        rm -rf "$catalog_fixture_root/plugins/shimmy/skills/shimmy-init"
        ;;
      invalid-skill-name)
        sed 's/^name: shimmy-tool-jq$/name: shimmy-tool-wrong/' "$catalog_fixture_root/tools/jq/SKILL.md" > "$catalog_fixture_root/tools/jq/SKILL.md.tmp"
        mv "$catalog_fixture_root/tools/jq/SKILL.md.tmp" "$catalog_fixture_root/tools/jq/SKILL.md"
        ;;
      unexpected-management-skill)
        cp -R "$catalog_fixture_root/plugins/shimmy/skills/shimmy-init" "$catalog_fixture_root/plugins/shimmy/skills/shimmy-extra"
        ;;
      unsafe-link)
        ln -s "$SCENARIO_DIR" "$catalog_fixture_root/tools/jq/escape"
        ;;
      orphan-tool)
        cp -R "$catalog_fixture_root/tools/jq" "$catalog_fixture_root/tools/orphan"
        rm "$catalog_fixture_root/tools/orphan/tool.conf"
        ;;
      duplicate-version)
        cp -R "$catalog_fixture_root/tools/jq" "$catalog_fixture_root/tools/other"
        sed 's/^shim_name=jq$/shim_name=other/' "$catalog_fixture_root/tools/other/tool.conf" > "$catalog_fixture_root/tools/other/tool.conf.tmp"
        mv "$catalog_fixture_root/tools/other/tool.conf.tmp" "$catalog_fixture_root/tools/other/tool.conf"
        ;;
    esac

    if shimmy_catalog_checkout_resolve "$catalog_fixture_root" upstream >/dev/null 2>&1; then
      fail_test "invalid schema-1 catalog unexpectedly passed: $catalog_mutation"
    fi
    assert_not_empty "$SHIMMY_CATALOG_ERROR"
  done
  test_lib_catalog_activate
  pass "catalog schema rejects missing, duplicate, unknown, unsafe, incompatible, and duplicate logical data"
}

test_lib_catalog_discovery() {
  test_lib_catalog_activate

  tools=$(shimmy_tool_list)
  assert_contains "$tools" jq
  assert_contains "$tools" opnsense-mcp-admin
  assert_equals "$(shimmy_tool_version_default oc)" oc_4_20
  assert_equals "$(shimmy_tool_version_label_resolve oc 4.18)" oc_4_18
  assert_equals "$(shimmy_tool_version_tool rg_15_1)" rg
  assert_equals "$(shimmy_version_label gcloud_573_0)" 573.0
  pass "metadata-driven catalog discovery"
}

test_lib_catalog_image_config_assert_invalid() {
  config_file=$1
  if shimmy_image_config_validate "$config_file" >/dev/null 2>&1; then
    fail_test "invalid image configuration was accepted: $config_file"
  fi
}

test_lib_catalog_image_config_write() {
  config_file=$1
  shift

  : > "$config_file"
  for config_line do
    printf '%s\n' "$config_line" >> "$config_file"
  done
}

test_lib_catalog_image_config_validation() {
  setup_scenario
  SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
  # shellcheck source=lib/runtime/image.sh
  . "$SHIMMY_RUNTIME_DIR/image.sh"
  config_dir=$SCENARIO_DIR/image-configs
  mkdir -p "$config_dir"
  digest_a=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

  valid_external=$config_dir/valid-external.conf
  test_lib_catalog_image_config_write "$valid_external" \
    'shimmy_image_config_version=1' \
    'image_source=external' \
    'image_upstream_ref=registry.example/vendor/tool:1.0' \
    "image_default_ref=registry.example/vendor/tool@sha256:$digest_a" \
    'image_registry_access=public' \
    'image_platform=linux/amd64' \
    'image_platform=linux/arm64'
  shimmy_image_config_validate "$valid_external" || fail_test 'valid external image configuration was rejected'

  test_lib_catalog_image_config_write "$config_dir/missing-key.conf" \
    'shimmy_image_config_version=1' 'image_source=external' \
    'image_upstream_ref=registry.example/vendor/tool:1.0' \
    "image_default_ref=registry.example/vendor/tool@sha256:$digest_a" \
    'image_platform=linux/amd64' 'image_platform=linux/arm64'
  test_lib_catalog_image_config_assert_invalid "$config_dir/missing-key.conf"

  test_lib_catalog_image_config_write "$config_dir/duplicate-key.conf" \
    'shimmy_image_config_version=1' 'image_source=external' 'image_source=external' \
    'image_upstream_ref=registry.example/vendor/tool:1.0' \
    "image_default_ref=registry.example/vendor/tool@sha256:$digest_a" \
    'image_registry_access=public' 'image_platform=linux/amd64' 'image_platform=linux/arm64'
  test_lib_catalog_image_config_assert_invalid "$config_dir/duplicate-key.conf"

  test_lib_catalog_image_config_write "$config_dir/unknown-version.conf" \
    'shimmy_image_config_version=2' 'image_source=external' \
    'image_upstream_ref=registry.example/vendor/tool:1.0' \
    "image_default_ref=registry.example/vendor/tool@sha256:$digest_a" \
    'image_registry_access=public' 'image_platform=linux/amd64' 'image_platform=linux/arm64'
  test_lib_catalog_image_config_assert_invalid "$config_dir/unknown-version.conf"

  test_lib_catalog_image_config_write "$config_dir/tag-default.conf" \
    'shimmy_image_config_version=1' 'image_source=external' \
    'image_upstream_ref=registry.example/vendor/tool:1.0' \
    'image_default_ref=registry.example/vendor/tool:1.0' \
    'image_registry_access=public' 'image_platform=linux/amd64' 'image_platform=linux/arm64'
  test_lib_catalog_image_config_assert_invalid "$config_dir/tag-default.conf"

  test_lib_catalog_image_config_write "$config_dir/malformed-digest.conf" \
    'shimmy_image_config_version=1' 'image_source=external' \
    'image_upstream_ref=registry.example/vendor/tool:1.0' \
    'image_default_ref=registry.example/vendor/tool@sha256:abc123' \
    'image_registry_access=public' 'image_platform=linux/amd64' 'image_platform=linux/arm64'
  test_lib_catalog_image_config_assert_invalid "$config_dir/malformed-digest.conf"

  test_lib_catalog_image_config_write "$config_dir/architecture-specific.conf" \
    'shimmy_image_config_version=1' 'image_source=external' \
    'image_upstream_ref=registry.example/vendor/tool:1.0-amd64' \
    "image_default_ref=registry.example/vendor/tool@sha256:$digest_a" \
    'image_registry_access=public' 'image_platform=linux/amd64'
  test_lib_catalog_image_config_assert_invalid "$config_dir/architecture-specific.conf"

  test_lib_catalog_image_config_write "$config_dir/unknown-key.conf" \
    'shimmy_image_config_version=1' 'image_source=external' \
    'image_upstream_ref=registry.example/vendor/tool:1.0' \
    "image_default_ref=registry.example/vendor/tool@sha256:$digest_a" \
    'image_registry_access=public' 'image_context=container' \
    'image_platform=linux/amd64' 'image_platform=linux/arm64'
  test_lib_catalog_image_config_assert_invalid "$config_dir/unknown-key.conf"

  local_common='shimmy_image_config_version=1 image_source=local-build image_local_repo=localhost/shimmy-fixture image_base_count=1 image_base_1_build_arg=SHIMMY_FIXTURE_BASE_IMAGE image_base_1_upstream_ref=registry.example/base/image:1 image_base_1_registry_access=public image_platform=linux/amd64 image_platform=linux/arm64'
  # shellcheck disable=SC2086
  test_lib_catalog_image_config_write "$config_dir/unsafe-context.conf" $local_common \
    'image_context=../container' "image_base_1_default_ref=registry.example/base/image@sha256:$digest_a"
  test_lib_catalog_image_config_assert_invalid "$config_dir/unsafe-context.conf"

  test_lib_catalog_image_config_write "$config_dir/unsafe-build-arg.conf" \
    'shimmy_image_config_version=1' 'image_source=local-build' 'image_context=container' \
    'image_local_repo=localhost/shimmy-fixture' 'image_base_count=1' \
    'image_base_1_build_arg=FIXTURE_BASE_IMAGE;false' \
    'image_base_1_upstream_ref=registry.example/base/image:1' \
    "image_base_1_default_ref=registry.example/base/image@sha256:$digest_a" \
    'image_base_1_registry_access=public' 'image_platform=linux/amd64' 'image_platform=linux/arm64'
  test_lib_catalog_image_config_assert_invalid "$config_dir/unsafe-build-arg.conf"

  test_lib_catalog_image_config_write "$config_dir/noncontiguous-base.conf" \
    'shimmy_image_config_version=1' 'image_source=local-build' 'image_context=container' \
    'image_local_repo=localhost/shimmy-fixture' 'image_base_count=2' \
    'image_base_1_build_arg=SHIMMY_FIXTURE_BASE_IMAGE' \
    'image_base_1_upstream_ref=registry.example/base/image:1' \
    "image_base_1_default_ref=registry.example/base/image@sha256:$digest_a" \
    'image_base_1_registry_access=public' 'image_platform=linux/amd64' 'image_platform=linux/arm64'
  test_lib_catalog_image_config_assert_invalid "$config_dir/noncontiguous-base.conf"

  scratch_config=$config_dir/scratch.conf
  test_lib_catalog_image_config_write "$scratch_config" \
    'shimmy_image_config_version=1' 'image_source=local-build' 'image_context=container' \
    'image_local_repo=localhost/shimmy-fixture' 'image_base_count=1' \
    'image_base_1_build_arg=SHIMMY_FIXTURE_BASE_IMAGE' 'image_base_1_default_ref=scratch' \
    'image_platform=linux/amd64' 'image_platform=linux/arm64'
  shimmy_image_config_validate "$scratch_config" || fail_test 'valid scratch image configuration was rejected'
  printf '%s\n' 'image_base_1_registry_access=public' >> "$scratch_config"
  test_lib_catalog_image_config_assert_invalid "$scratch_config"

  pass "image configuration validation accepts complete schemas and rejects malformed metadata"
}

test_lib_catalog_local_image_identity() {
  setup_scenario
  SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
  # shellcheck source=lib/runtime/image.sh
  . "$SHIMMY_RUNTIME_DIR/image.sh"
  version_dir=$SCENARIO_DIR/version
  mkdir -p "$version_dir/container"
  test_lib_catalog_image_config_write "$version_dir/container/Containerfile" 'ARG SHIMMY_FIXTURE_BASE_IMAGE' 'FROM ${SHIMMY_FIXTURE_BASE_IMAGE}'
  digest_a=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  digest_b=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  test_lib_catalog_image_config_write "$version_dir/image.conf" \
    'shimmy_image_config_version=1' 'image_source=local-build' 'image_context=container' \
    'image_local_repo=localhost/shimmy-fixture' 'image_base_count=1' \
    'image_base_1_build_arg=SHIMMY_FIXTURE_BASE_IMAGE' \
    'image_base_1_upstream_ref=registry.example/base/image:1' \
    "image_base_1_default_ref=registry.example/base/image@sha256:$digest_a" \
    'image_base_1_registry_access=public' 'image_platform=linux/amd64' 'image_platform=linux/arm64'

  ref_default=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 shimmy_local_image_ref_render "$version_dir/image.conf")
  ref_identical=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 shimmy_local_image_ref_render "$version_dir/image.conf")
  ref_arm64=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=arm64 shimmy_local_image_ref_render "$version_dir/image.conf")
  ref_value=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 shimmy_local_image_ref_render "$version_dir/image.conf" --build-arg SHIMMY_FIXTURE_VERSION=2)
  ref_order_a=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 shimmy_local_image_ref_render "$version_dir/image.conf" --build-arg SHIMMY_FIXTURE_ONE=1 --build-arg SHIMMY_FIXTURE_TWO=2)
  ref_order_b=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 shimmy_local_image_ref_render "$version_dir/image.conf" --build-arg SHIMMY_FIXTURE_TWO=2 --build-arg SHIMMY_FIXTURE_ONE=1)
  ref_override=$(SHIMMY_FIXTURE_BASE_IMAGE="registry.example/base/image@sha256:$digest_b" SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 shimmy_local_image_ref_render "$version_dir/image.conf")

  assert_equals "$ref_default" "$ref_identical"
  [ "$ref_default" != "$ref_arm64" ] || fail_test 'platform did not change local image identity'
  [ "$ref_default" != "$ref_value" ] || fail_test 'build argument value did not change local image identity'
  [ "$ref_order_a" != "$ref_order_b" ] || fail_test 'build argument order did not change local image identity'
  [ "$ref_default" != "$ref_override" ] || fail_test 'base image override did not change local image identity'
  assert_contains "$ref_default" linux-amd64
  assert_contains "$ref_arm64" linux-arm64

  test_lib_catalog_image_config_write "$version_dir/image.conf" \
    'shimmy_image_config_version=1' 'image_source=local-build' 'image_context=container' \
    'image_local_repo=localhost/shimmy-fixture' 'image_base_count=1' \
    'image_base_1_build_arg=SHIMMY_FIXTURE_BASE_IMAGE' \
    'image_base_1_upstream_ref=registry.example/base/image:2' \
    "image_base_1_default_ref=registry.example/base/image@sha256:$digest_a" \
    'image_base_1_registry_access=public' 'image_platform=linux/amd64' 'image_platform=linux/arm64'
  ref_config_changed=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 shimmy_local_image_ref_render "$version_dir/image.conf")
  [ "$ref_default" != "$ref_config_changed" ] || fail_test 'image configuration did not change local image identity'
  printf '%s\n' '# context change' >> "$version_dir/container/Containerfile"
  ref_context_changed=$(SHIMMY_TEST_OS=Linux SHIMMY_TEST_ARCH=amd64 shimmy_local_image_ref_render "$version_dir/image.conf")
  [ "$ref_config_changed" != "$ref_context_changed" ] || fail_test 'container context did not change local image identity'
  assert_file_contains "$SHIMMY_RUNTIME_DIR/image.sh" 'current_ref=$(shimmy_local_image_ref_render "$config_file" "$@")'
  pass "local image identity covers configuration, ordered build arguments, overrides, and platform"
}

test_lib_catalog_preview_dispatch() {
  jq_preview=$("$ROOT_DIR/commands/run-tool.sh" jq --preview-shim --version)
  assert_contains "$jq_preview" 'ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91'

  oc_preview=$(SHIMMY_OC_VERSION=4.18 "$ROOT_DIR/commands/run-tool.sh" oc --preview-shim version)
  assert_contains "$oc_preview" shimmy-oc-4_18
  pass "generic tool dispatch and version selection"
}

test_lib_catalog_all_previews() {
  test_lib_catalog_activate

  for tool_name in $(shimmy_tool_list); do
    case "$tool_name" in
      gdrive|opnsense-mcp-admin|opnsense-mcp-read-only)
        output=$("$ROOT_DIR/commands/run-tool.sh" "$tool_name" --preview-shim 2>&1)
        ;;
      *)
        output=$("$ROOT_DIR/commands/run-tool.sh" "$tool_name" --preview-shim --help 2>&1)
        ;;
    esac
    assert_not_empty "$output"
  done
  pass "all tool preview paths"
}

test_lib_catalog_concrete_version_previews() {
  test_lib_catalog_activate

  for tool_name in $(shimmy_tool_list); do
    default_label=$(sed -n 's/^tool_default_version=//p' "$ROOT_DIR/tools/$tool_name/tool.conf" | sed -n '1p')
    selector_env=$(shimmy_tool_selector_env "$tool_name")

    for version_label in $(shimmy_tool_version_label_list "$tool_name"); do
      version_dir=$ROOT_DIR/tools/$tool_name/versions/$version_label
      smoke_file=$version_dir/smoke.conf
      version_name=$(shimmy_tool_version_label_resolve "$tool_name" "$version_label")
      smoke_name=$(sed -n 's/^shim_name=//p' "$smoke_file" | sed -n '1p')
      smoke_arg=$(sed -n 's/^smoke_arg=//p' "$smoke_file" | sed -n '1p')
      image_source=$(sed -n 's/^image_source=//p' "$version_dir/image.conf" | sed -n '1p')
      image_default_ref=$(sed -n 's/^image_default_ref=//p' "$version_dir/image.conf" | sed -n '1p')

      assert_equals "$smoke_name" "$version_name"
      assert_not_empty "$smoke_arg"

      for platform_case in \
        'Linux amd64 linux/amd64' \
        'Linux arm64 linux/arm64' \
        'Darwin amd64 linux/amd64' \
        'Darwin arm64 linux/arm64'; do
        set -- $platform_case
        runtime_output=$(env SHIMMY_TEST_OS="$1" SHIMMY_TEST_ARCH="$2" "$version_dir/run.sh" --preview-shim "$smoke_arg" 2>&1)
        assert_not_empty "$runtime_output"
        assert_contains "$runtime_output" "'--platform' '$3'"
        if [ "$image_source" = external ]; then
          assert_contains "$runtime_output" "'$image_default_ref'"
        fi
      done

      if [ -n "$selector_env" ]; then
        dispatch_output=$(env "$selector_env=$version_label" "$ROOT_DIR/commands/run-tool.sh" "$tool_name" --preview-shim "$smoke_arg" 2>&1)
      elif [ "$version_label" = "$default_label" ]; then
        dispatch_output=$("$ROOT_DIR/commands/run-tool.sh" "$tool_name" --preview-shim "$smoke_arg" 2>&1)
      else
        continue
      fi
      assert_not_empty "$dispatch_output"
    done
  done
  pass "all concrete runtimes honor declared smoke previews"
}

test_lib_catalog_metadata_complete() {
  SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
  # shellcheck source=lib/runtime/image.sh
  . "$SHIMMY_RUNTIME_DIR/image.sh"

  for tool_file in "$ROOT_DIR"/tools/*/tool.conf; do
    [ -f "$tool_file" ] || continue
    tool_dir=$(dirname "$tool_file")
    assert_file_contains "$tool_file" tool_default_version=

    for version_dir in "$tool_dir"/versions/*; do
      [ -d "$version_dir" ] || continue
      assert_file_exists "$version_dir/smoke.conf"
      assert_file_exists "$version_dir/image.conf"
      assert_file_executable "$version_dir/run.sh"
      assert_file_contains "$version_dir/smoke.conf" shim_name=
      shimmy_image_config_validate "$version_dir/image.conf" || fail_test "invalid image configuration: $version_dir/image.conf"
      assert_equals "$(sed -n 's/^image_platform=//p' "$version_dir/image.conf")" 'linux/amd64
linux/arm64'
      image_source=$(shimmy_image_config_scalar_read "$version_dir/image.conf" image_source)
      if [ "$image_source" = external ]; then
        image_default_ref=$(shimmy_image_config_scalar_read "$version_dir/image.conf" image_default_ref)
        assert_contains "$image_default_ref" '@sha256:'
      else
        image_base_count=$(shimmy_image_config_scalar_read "$version_dir/image.conf" image_base_count)
        image_base_index=1
        while [ "$image_base_index" -le "$image_base_count" ]; do
          image_default_ref=$(shimmy_image_config_scalar_read "$version_dir/image.conf" "image_base_${image_base_index}_default_ref")
          if [ "$image_default_ref" != scratch ]; then
            assert_contains "$image_default_ref" '@sha256:'
          fi
          image_base_index=$((image_base_index + 1))
        done
      fi
      assert_path_not_exists "$version_dir/status.conf"
    done
  done
  pass "tool image metadata and concrete runtimes are complete"
}

test_lib_catalog_run() {
  test_lib_catalog_context_tree
  test_lib_catalog_context_tree_rejects_prohibited_file
  test_lib_catalog_contract_rejection
  test_lib_catalog_discovery
  test_lib_catalog_image_config_validation
  test_lib_catalog_local_image_identity
  test_lib_catalog_preview_dispatch
  test_lib_catalog_all_previews
  test_lib_catalog_concrete_version_previews
  test_lib_catalog_metadata_complete
}
