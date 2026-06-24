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

test_tools_oc_run() {
  test_tools_oc_preview_contract
}
