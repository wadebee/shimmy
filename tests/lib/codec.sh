#!/bin/sh

test_lib_codec_tokens() {
  for valid_name in default a alpha-1 team-one-two; do
    shimmy_name_component_validate "$valid_name" || fail_test "valid name rejected: $valid_name"
  done
  for invalid_name in '' -alpha alpha- alpha--beta alpha.beta alpha_beta Alpha 'alpha beta' 'alpha/beta'; do
    if shimmy_name_component_validate "$invalid_name"; then
      fail_test "unsafe name accepted: $invalid_name"
    fi
  done
  [ refs/heads/main = refs/heads/main ]
  shimmy_git_commit_validate 1111111111111111111111111111111111111111 || fail_test 'valid fixed commit rejected'
  if shimmy_git_commit_validate 111111111111111111111111111111111111111g; then fail_test 'invalid fixed commit accepted'; fi
  pass 'name and commit algorithms enforce fixed grammars'
}

test_lib_codec_hash_vectors() {
  setup_scenario
  printf 'Shimmy fixture content\n' > "$SCENARIO_DIR/content"
  assert_equals "$(shimmy_sha256_fingerprint_file_render "$SCENARIO_DIR/content")" \
    sha256:9425f85b0576f11feacc8d2c76cf65518c8a52fe3e6f2baf17124c9b9a74d018
  vector_fingerprint=sha256:584a0bb2995f58fa4150c3662f3a8c5cfe89dc9f4b5da6790bd9641d2c7e3bc9
  assert_equals "$(shimmy_catalog_generation_render "$vector_fingerprint")" \
    sha256-584a0bb2995f58fa4150c3662f3a8c5cfe89dc9f4b5da6790bd9641d2c7e3bc9
  mkdir -p "$SCENARIO_DIR/catalog/tools/alpha" "$SCENARIO_DIR/catalog/plugins/shimmy/skills/shimmy-install"
  printf 'catalog_schema=1\n' > "$SCENARIO_DIR/catalog/catalog.conf"
  printf 'alpha\n' > "$SCENARIO_DIR/catalog/tools/alpha/tool.conf"
  printf 'skill\n' > "$SCENARIO_DIR/catalog/plugins/shimmy/skills/shimmy-install/SKILL.md"
  assert_equals "$(shimmy_catalog_content_fingerprint_render "$SCENARIO_DIR/catalog")" \
    sha256:62326a559f21a14bb843554bcbc2be2a49cb0c6ecbdff515bfca4952679454dd
  pass 'fixed file, path-sorted catalog content, and generation SHA-256 vectors'
}

test_lib_codec_manifest_vectors() {
  codec_value=$(printf '/tmp/profile path|warning=100%%\r\nnested=key|value')
  codec_encoded=$(shimmy_manifest_value_encode "$codec_value")
  assert_equals "$codec_encoded" '/tmp/profile path%7Cwarning=100%25%0D%0Anested=key%7Cvalue'
  assert_equals "$(shimmy_manifest_value_encode '%7C')" %257C
  codec_decoded=$(shimmy_manifest_value_decode "$codec_encoded")
  assert_equals "$codec_decoded" "$codec_value"

  codec_diagnostic=$(shimmy_manifest_diagnostic_encode 'warning|path=/tmp/one; token=s3cr%t' 's3cr%t')
  assert_equals "$codec_diagnostic" 'warning%7Cpath=/tmp/one; token=[redacted]'
  assert_not_contains "$codec_diagnostic" 's3cr'
  pass 'manifest codec covers percent, pipe, CR, LF, paths, warnings, nested values, and redaction'
}

test_lib_codec_run() {
  test_lib_codec_tokens
  test_lib_codec_hash_vectors
  test_lib_codec_manifest_vectors
}
