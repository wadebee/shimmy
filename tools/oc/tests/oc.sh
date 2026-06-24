#!/bin/sh
# OpenShift CLI preview-contract tests.

test_tools_oc_preview_contract() {
  output_4_18=$(SHIMMY_OC_VERSION=4.18 SHIMMY_OC_4_18_IMAGE=example.invalid/shimmy/oc:4.18 SHIMMY_OC_4_18_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh oc --preview-shim version)
  output_4_20=$(SHIMMY_OC_VERSION=4.20 SHIMMY_OC_4_20_IMAGE=example.invalid/shimmy/oc:4.20 SHIMMY_OC_4_20_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh oc --preview-shim version)
  output_4_22=$(SHIMMY_OC_VERSION=4.22 SHIMMY_OC_4_22_IMAGE=example.invalid/shimmy/oc:4.22 SHIMMY_OC_4_22_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh oc --preview-shim version)

  assert_contains "$output_4_18" "'example.invalid/shimmy/oc:4.18'"
  assert_contains "$output_4_20" "'example.invalid/shimmy/oc:4.20'"
  assert_contains "$output_4_22" "'example.invalid/shimmy/oc:4.22'"
  assert_contains "$output_4_18" "'--pull=always'"
  assert_contains "$output_4_20" "'--pull=always'"
  assert_contains "$output_4_22" "'--pull=always'"
  pass "oc preview dispatches each supported concrete version"
}

test_tools_oc_manifest_list_default() {
  base_image=registry.redhat.io/openshift4/ose-cli-rhel9@sha256:61136a31003a378aae4039be61cfe10f3d2b60399f08a5325233826deb569383

  assert_file_contains "$ROOT_DIR/tools/oc/versions/4.20/container/Containerfile" "$base_image"
  assert_not_contains "$base_image" x86_64
  assert_not_contains "$base_image" aarch64
  pass "oc 4.20 defaults to the Red Hat multi-architecture manifest list"
}

test_tools_oc_smoke_client_only() {
  for smoke_file in "$ROOT_DIR"/tools/oc/versions/*/smoke.conf; do
    assert_file_contains "$smoke_file" 'smoke_arg=version'
    assert_file_contains "$smoke_file" 'smoke_arg=--client'
  done
  pass "oc smoke metadata avoids cluster network access"
}

test_tools_oc_run() {
  test_tools_oc_manifest_list_default
  test_tools_oc_preview_contract
  test_tools_oc_smoke_client_only
}
