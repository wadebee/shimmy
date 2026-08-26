#!/bin/sh
# OpenShift CLI preview-contract tests.

test_tools_oc_preview_contract() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output_4_18=$(SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_OC_VERSION=4.18 SHIMMY_OC_4_18_IMAGE=example.invalid/shimmy/oc:4.18 SHIMMY_OC_4_18_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh oc --preview-shim version)
  output_4_20=$(SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_OC_VERSION=4.20 SHIMMY_OC_4_20_IMAGE=example.invalid/shimmy/oc:4.20 SHIMMY_OC_4_20_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh oc --preview-shim version)
  output_4_22=$(SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_OC_VERSION=4.22 SHIMMY_OC_4_22_IMAGE=example.invalid/shimmy/oc:4.22 SHIMMY_OC_4_22_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh oc --preview-shim version)
  ca_mount="'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  ca_environment="'-e' 'SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem'"

  assert_contains "$output_4_18" "'example.invalid/shimmy/oc:4.18'"
  assert_contains "$output_4_20" "'example.invalid/shimmy/oc:4.20'"
  assert_contains "$output_4_22" "'example.invalid/shimmy/oc:4.22'"
  assert_contains "$output_4_18" "'--pull=always'"
  assert_contains "$output_4_20" "'--pull=always'"
  assert_contains "$output_4_22" "'--pull=always'"
  assert_contains "$output_4_18" "$ca_mount"
  assert_contains "$output_4_20" "$ca_mount"
  assert_contains "$output_4_22" "$ca_mount"
  assert_contains "$output_4_18" "$ca_environment"
  assert_contains "$output_4_20" "$ca_environment"
  assert_contains "$output_4_22" "$ca_environment"
  pass "oc preview dispatches each supported concrete version with the host CA bundle mapping"
}

test_tools_oc_authenticated_image_config() {
  base_image_4_18=registry.redhat.io/openshift4/ose-cli-rhel9@sha256:16c25aadbd5f564a7c5f1508470f734d676a411b89bd98b307001619d1a5338f
  base_image_4_20=registry.redhat.io/openshift4/ose-cli-rhel9@sha256:61136a31003a378aae4039be61cfe10f3d2b60399f08a5325233826deb569383
  base_image_4_22=registry.redhat.io/openshift4/ose-cli-rhel9@sha256:83541f26b665963dea277a7f893725f4a1812b0550d07404f1429ed8da6b3bb2

  assert_file_contains "$ROOT_DIR/tools/oc/versions/4.18/image.conf" "image_base_1_default_ref=$base_image_4_18"
  assert_file_contains "$ROOT_DIR/tools/oc/versions/4.20/image.conf" "image_base_1_default_ref=$base_image_4_20"
  assert_file_contains "$ROOT_DIR/tools/oc/versions/4.22/image.conf" "image_base_1_default_ref=$base_image_4_22"
  for image_config_file in "$ROOT_DIR"/tools/oc/versions/*/image.conf; do
    assert_file_contains "$image_config_file" 'image_base_1_registry_access=authenticated'
  done
  pass "oc image metadata records the authenticated Red Hat manifest-list defaults"
}

test_tools_oc_smoke_help() {
  for smoke_file in "$ROOT_DIR"/tools/oc/versions/*/smoke.conf; do
    assert_file_contains "$smoke_file" 'smoke_arg=--help'
  done
  pass "oc smoke metadata avoids cluster network access"
}

test_tools_oc_run() {
  test_tools_oc_authenticated_image_config
  test_tools_oc_preview_contract
  test_tools_oc_smoke_help
}
