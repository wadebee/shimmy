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
  pass "Skopeo preview preserves image overrides and explicit auth secret handling"
}

test_tools_skopeo_run() {
  test_tools_skopeo_preview_contract
}
