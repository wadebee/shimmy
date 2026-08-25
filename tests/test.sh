#!/bin/sh
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_CONTROL_ROOT=$ROOT_DIR
TMP_PARENT=${TMPDIR:-/tmp}

case "$TMP_PARENT" in
  ''|/) TMP_PARENT=/tmp ;;
  */) TMP_PARENT=${TMP_PARENT%/} ;;
esac

TEST_COUNT=0

# shellcheck source=tests/support.sh
. "$SCRIPT_DIR/support.sh"
# shellcheck source=lib/common/common.sh
. "$ROOT_DIR/lib/common/common.sh"
# shellcheck source=lib/common/lock.sh
. "$ROOT_DIR/lib/common/lock.sh"
# shellcheck source=lib/catalog/catalog.sh
. "$ROOT_DIR/lib/catalog/catalog.sh"
# shellcheck source=lib/profile/profile.sh
. "$ROOT_DIR/lib/profile/profile.sh"
# shellcheck source=lib/catalog/state.sh
. "$ROOT_DIR/lib/catalog/state.sh"
# shellcheck source=lib/catalog/authority.sh
. "$ROOT_DIR/lib/catalog/authority.sh"
# shellcheck source=lib/shim/state.sh
. "$ROOT_DIR/lib/shim/state.sh"
# shellcheck source=lib/shim/shim.sh
. "$ROOT_DIR/lib/shim/shim.sh"
# shellcheck source=lib/ai-skill/bundle.sh
. "$ROOT_DIR/lib/ai-skill/bundle.sh"
# shellcheck source=lib/profile/transaction.sh
. "$ROOT_DIR/lib/profile/transaction.sh"
# shellcheck source=lib/ai-skill/link.sh
. "$ROOT_DIR/lib/ai-skill/link.sh"
# shellcheck source=lib/ai-skill/ai-skill.sh
. "$ROOT_DIR/lib/ai-skill/ai-skill.sh"
# shellcheck source=lib/profile/state.sh
. "$ROOT_DIR/lib/profile/state.sh"
# shellcheck source=lib/install/manifest.sh
. "$ROOT_DIR/lib/install/manifest.sh"
# shellcheck source=lib/install/transaction.sh
. "$ROOT_DIR/lib/install/transaction.sh"
# shellcheck source=lib/install/catalog.sh
. "$ROOT_DIR/lib/install/catalog.sh"
# shellcheck source=lib/install/profile.sh
. "$ROOT_DIR/lib/install/profile.sh"
# shellcheck source=lib/engine/state.sh
. "$ROOT_DIR/lib/engine/state.sh"
# shellcheck source=lib/engine/podman.sh
. "$ROOT_DIR/lib/engine/podman.sh"
# shellcheck source=lib/engine/ownership.sh
. "$ROOT_DIR/lib/engine/ownership.sh"
# shellcheck source=lib/engine/lifecycle.sh
. "$ROOT_DIR/lib/engine/lifecycle.sh"
# shellcheck source=lib/engine/projection.sh
. "$ROOT_DIR/lib/engine/projection.sh"
# shellcheck source=lib/startup/startup.sh
. "$ROOT_DIR/lib/startup/startup.sh"
# shellcheck source=lib/install/lifecycle.sh
. "$ROOT_DIR/lib/install/lifecycle.sh"
# shellcheck source=lib/install/uninstall.sh
. "$ROOT_DIR/lib/install/uninstall.sh"
# shellcheck source=lib/update/profile.sh
. "$ROOT_DIR/lib/update/profile.sh"
# shellcheck source=lib/registries/registries.sh
. "$ROOT_DIR/lib/registries/registries.sh"
# shellcheck source=lib/engine/registry.sh
. "$ROOT_DIR/lib/engine/registry.sh"
# shellcheck source=lib/profile/management.sh
. "$ROOT_DIR/lib/profile/management.sh"
# shellcheck source=lib/images/images.sh
. "$ROOT_DIR/lib/images/images.sh"
# shellcheck source=lib/images/catalog.sh
. "$ROOT_DIR/lib/images/catalog.sh"

# shellcheck source=tests/runner.sh
. "$SCRIPT_DIR/runner.sh"
# shellcheck source=tests/lib/runner.sh
. "$SCRIPT_DIR/lib/runner.sh"
# shellcheck source=tests/lib/catalog.sh
. "$SCRIPT_DIR/lib/catalog.sh"
# shellcheck source=tests/lib/codec.sh
. "$SCRIPT_DIR/lib/codec.sh"
# shellcheck source=tests/lib/profile-state.sh
. "$SCRIPT_DIR/lib/profile-state.sh"
# shellcheck source=tests/lib/ai-skill-state.sh
. "$SCRIPT_DIR/lib/ai-skill-state.sh"
# shellcheck source=tests/lib/lock.sh
. "$SCRIPT_DIR/lib/lock.sh"
# shellcheck source=tests/lib/transaction.sh
. "$SCRIPT_DIR/lib/transaction.sh"
# shellcheck source=tests/lib/ai-skill-link.sh
. "$SCRIPT_DIR/lib/ai-skill-link.sh"
# shellcheck source=tests/lib/runtime.sh
. "$SCRIPT_DIR/lib/runtime.sh"
# shellcheck source=tests/lib/engine.sh
. "$SCRIPT_DIR/lib/engine.sh"
# shellcheck source=tests/lib/profile-activation.sh
. "$SCRIPT_DIR/lib/profile-activation.sh"
# shellcheck source=tests/lib/registries.sh
. "$SCRIPT_DIR/lib/registries.sh"
# shellcheck source=tests/commands/agent-preflight.sh
. "$SCRIPT_DIR/commands/agent-preflight.sh"
# shellcheck source=tests/commands/catalog.sh
. "$SCRIPT_DIR/commands/catalog.sh"
# shellcheck source=tests/commands/shim.sh
. "$SCRIPT_DIR/commands/shim.sh"
# shellcheck source=tests/commands/ai-skill.sh
. "$SCRIPT_DIR/commands/ai-skill.sh"
# shellcheck source=tests/commands/profile.sh
. "$SCRIPT_DIR/commands/profile.sh"
# shellcheck source=tests/commands/surface.sh
. "$SCRIPT_DIR/commands/surface.sh"
# shellcheck source=tests/commands/lifecycle.sh
. "$SCRIPT_DIR/commands/lifecycle.sh"

# shellcheck source=tools/aws/tests/aws.sh
. "$ROOT_DIR/tools/aws/tests/aws.sh"
# shellcheck source=tools/bats/tests/bats.sh
. "$ROOT_DIR/tools/bats/tests/bats.sh"
# shellcheck source=tools/community-ansible-dev-tools/tests/community-ansible-dev-tools.sh
. "$ROOT_DIR/tools/community-ansible-dev-tools/tests/community-ansible-dev-tools.sh"
# shellcheck source=tools/gcloud/tests/gcloud.sh
. "$ROOT_DIR/tools/gcloud/tests/gcloud.sh"
# shellcheck source=tools/gdrive/tests/gdrive.sh
. "$ROOT_DIR/tools/gdrive/tests/gdrive.sh"
# shellcheck source=tools/gh/tests/gh.sh
. "$ROOT_DIR/tools/gh/tests/gh.sh"
# shellcheck source=tools/go/tests/go.sh
. "$ROOT_DIR/tools/go/tests/go.sh"
# shellcheck source=tools/jq/tests/jq.sh
. "$ROOT_DIR/tools/jq/tests/jq.sh"
# shellcheck source=tools/netcat/tests/netcat.sh
. "$ROOT_DIR/tools/netcat/tests/netcat.sh"
# shellcheck source=tools/nmap/tests/nmap.sh
. "$ROOT_DIR/tools/nmap/tests/nmap.sh"
# shellcheck source=tools/npx/tests/npx.sh
. "$ROOT_DIR/tools/npx/tests/npx.sh"
# shellcheck source=tools/oc/tests/oc.sh
. "$ROOT_DIR/tools/oc/tests/oc.sh"
# shellcheck source=tools/opnsense-mcp-admin/tests/opnsense-mcp-admin.sh
. "$ROOT_DIR/tools/opnsense-mcp-admin/tests/opnsense-mcp-admin.sh"
# shellcheck source=tools/opnsense-mcp-read-only/tests/opnsense-mcp-read-only.sh
. "$ROOT_DIR/tools/opnsense-mcp-read-only/tests/opnsense-mcp-read-only.sh"
# shellcheck source=tools/rg/tests/rg.sh
. "$ROOT_DIR/tools/rg/tests/rg.sh"
# shellcheck source=tools/skopeo/tests/skopeo.sh
. "$ROOT_DIR/tools/skopeo/tests/skopeo.sh"
# shellcheck source=tools/task/tests/task.sh
. "$ROOT_DIR/tools/task/tests/task.sh"
# shellcheck source=tools/terraform/tests/terraform.sh
. "$ROOT_DIR/tools/terraform/tests/terraform.sh"
# shellcheck source=tools/tessl/tests/tessl.sh
. "$ROOT_DIR/tools/tessl/tests/tessl.sh"
# shellcheck source=tools/textual/tests/textual.sh
. "$ROOT_DIR/tools/textual/tests/textual.sh"

test_runner_session_validate() {
  test_lifecycle_checkout_template_validate
}

main() {
  test_runner_options_parse "$@"
  if [ "$TEST_RUNNER_LIST_GROUPS" -eq 1 ]; then
    test_runner_group_list
    return 0
  fi

  shimmy_catalog_payload_validate "$ROOT_DIR" default || fail_test "$SHIMMY_CATALOG_ERROR"
  test_runner_total_started=$(test_runner_now)
  TMP_ROOT=$(mktemp -d "$TMP_PARENT/shimmy-test.XXXXXX")
  TEST_RUNNER_SETUP_PID=
  TEST_RUNNER_SETUP_NAME=
  TEST_RUNNER_SETUP_STARTED=
  TEST_RUNNER_WORKER_PIDS=
  TEST_RUNNER_LOGS_REPLAYED=0
  trap shimmy_test_cleanup EXIT
  trap 'test_runner_signal_handle HUP 129' HUP
  trap 'test_runner_signal_handle INT 130' INT
  trap 'test_runner_signal_handle TERM 143' TERM
  TMP_ROOT=$(cd -- "$TMP_ROOT" && pwd -P)

  test_runner_setup_started=$(test_runner_now)
  test_runner_progress_record setup copy-on-write-probe
  test_fixture_copy_on_write_detect
  test_runner_setup_finished=$(test_runner_now)
  test_runner_timing_record setup copy-on-write-probe \
    "$((test_runner_setup_finished - test_runner_setup_started))"

  TEST_LIFECYCLE_CHECKOUT_TEMPLATE=
  TEST_LIFECYCLE_CHECKOUT_TEMPLATE_HEAD=
  if test_lifecycle_checkout_template_required; then
    TEST_LIFECYCLE_CHECKOUT_TEMPLATE=$TMP_ROOT/lifecycle-checkout-template
    set +e
    test_runner_setup_run lifecycle-checkout-template \
      test_lifecycle_checkout_template_prepare
    test_runner_setup_status=$?
    set -e
    if [ "$test_runner_setup_status" -ne 0 ]; then
      test_runner_total_finished=$(test_runner_now)
      test_runner_timing_record total suite \
        "$((test_runner_total_finished - test_runner_total_started))"
      return "$test_runner_setup_status"
    fi
    TEST_LIFECYCLE_CHECKOUT_TEMPLATE_HEAD=$(git -C \
      "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" rev-parse HEAD)
  fi

  set +e
  test_runner_suite_run
  test_runner_suite_status=$?
  set -e
  [ "$test_runner_suite_status" -eq 0 ] || return "$test_runner_suite_status"
  printf 'All %s Shimmy tests passed.\n' "$TEST_COUNT"
}

main "$@"
