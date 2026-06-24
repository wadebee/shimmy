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
  base_image_4_18=registry.redhat.io/openshift4/ose-cli-rhel9@sha256:16c25aadbd5f564a7c5f1508470f734d676a411b89bd98b307001619d1a5338f
  base_image_4_20=registry.redhat.io/openshift4/ose-cli-rhel9@sha256:61136a31003a378aae4039be61cfe10f3d2b60399f08a5325233826deb569383
  base_image_4_22=registry.redhat.io/openshift4/ose-cli-rhel9@sha256:83541f26b665963dea277a7f893725f4a1812b0550d07404f1429ed8da6b3bb2

  assert_file_contains "$ROOT_DIR/tools/oc/versions/4.18/container/Containerfile" "$base_image_4_18"
  assert_file_contains "$ROOT_DIR/tools/oc/versions/4.20/container/Containerfile" "$base_image_4_20"
  assert_file_contains "$ROOT_DIR/tools/oc/versions/4.22/container/Containerfile" "$base_image_4_22"
  assert_not_contains "$base_image_4_18$base_image_4_20$base_image_4_22" x86_64
  assert_not_contains "$base_image_4_18$base_image_4_20$base_image_4_22" aarch64
  pass "oc defaults to Red Hat multi-architecture manifest lists"
}

test_tools_oc_smoke_help() {
  for smoke_file in "$ROOT_DIR"/tools/oc/versions/*/smoke.conf; do
    assert_file_contains "$smoke_file" 'smoke_arg=--help'
  done
  pass "oc smoke metadata avoids cluster network access"
}

test_tools_oc_run() {
  test_tools_oc_manifest_list_default
  test_tools_oc_preview_contract
  test_tools_oc_smoke_help
}
