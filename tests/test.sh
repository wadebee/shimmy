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
# shellcheck source=lib/catalog/catalog.sh
. "$ROOT_DIR/lib/catalog/catalog.sh"
# shellcheck source=lib/profile/profile.sh
. "$ROOT_DIR/lib/profile/profile.sh"
# shellcheck source=lib/catalog/state.sh
. "$ROOT_DIR/lib/catalog/state.sh"
# shellcheck source=lib/shim/state.sh
. "$ROOT_DIR/lib/shim/state.sh"
# shellcheck source=lib/ai-skill/bundle.sh
. "$ROOT_DIR/lib/ai-skill/bundle.sh"
# shellcheck source=lib/profile/state.sh
. "$ROOT_DIR/lib/profile/state.sh"
# shellcheck source=lib/install/manifest.sh
. "$ROOT_DIR/lib/install/manifest.sh"
# shellcheck source=lib/registries/registries.sh
. "$ROOT_DIR/lib/registries/registries.sh"
# shellcheck source=lib/images/images.sh
. "$ROOT_DIR/lib/images/images.sh"
# shellcheck source=tests/profile-smoke.sh
. "$SCRIPT_DIR/profile-smoke.sh"
if [ ! -f "$ROOT_DIR/install-manifest.txt" ]; then
# shellcheck source=tests/runner.sh
. "$SCRIPT_DIR/runner.sh"
# shellcheck source=tests/lib/runner.sh
. "$SCRIPT_DIR/lib/runner.sh"
# shellcheck source=tests/lib/catalog.sh
. "$SCRIPT_DIR/lib/catalog.sh"
# shellcheck source=tests/lib/target-codec.sh
. "$SCRIPT_DIR/lib/target-codec.sh"
# shellcheck source=tests/lib/target-profile-state.sh
. "$SCRIPT_DIR/lib/target-profile-state.sh"
# shellcheck source=tests/lib/target-ai-skill-state.sh
. "$SCRIPT_DIR/lib/target-ai-skill-state.sh"
# shellcheck source=tests/lib/runtime.sh
. "$SCRIPT_DIR/lib/runtime.sh"
# shellcheck source=tests/lib/profile-activation.sh
. "$SCRIPT_DIR/lib/profile-activation.sh"
# shellcheck source=tests/lib/registries.sh
. "$SCRIPT_DIR/lib/registries.sh"
# shellcheck source=tests/lib/update.sh
. "$SCRIPT_DIR/lib/update.sh"
# shellcheck source=tests/commands/agent-preflight.sh
. "$SCRIPT_DIR/commands/agent-preflight.sh"
# shellcheck source=tests/commands/catalog.sh
. "$SCRIPT_DIR/commands/catalog.sh"
# shellcheck source=tests/commands/images.sh
. "$SCRIPT_DIR/commands/images.sh"
# shellcheck source=tests/commands/lifecycle.sh
. "$SCRIPT_DIR/commands/lifecycle.sh"
# shellcheck source=tests/commands/management.sh
. "$SCRIPT_DIR/commands/management.sh"
# shellcheck source=tests/commands/onboarding.sh
. "$SCRIPT_DIR/commands/onboarding.sh"
# shellcheck source=tests/commands/profiles.sh
. "$SCRIPT_DIR/commands/profiles.sh"
# shellcheck source=tests/commands/profile.sh
. "$SCRIPT_DIR/commands/profile.sh"
# shellcheck source=tests/commands/status.sh
. "$SCRIPT_DIR/commands/status.sh"
# shellcheck source=tests/commands/update.sh
. "$SCRIPT_DIR/commands/update.sh"
# shellcheck source=tests/commands/startup.sh
. "$SCRIPT_DIR/commands/startup.sh"
# shellcheck source=tests/commands/skills.sh
. "$SCRIPT_DIR/commands/skills.sh"
# shellcheck source=tests/commands/dispatcher.sh
. "$SCRIPT_DIR/commands/dispatcher.sh"
# shellcheck source=tests/commands/netinfo.sh
. "$SCRIPT_DIR/commands/netinfo.sh"
# shellcheck source=tools/aws/tests/aws.sh
. "$ROOT_DIR/tools/aws/tests/aws.sh"
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
# shellcheck source=tests/commands/install.sh
. "$SCRIPT_DIR/commands/install.sh"
# shellcheck source=tests/commands/test.sh
. "$SCRIPT_DIR/commands/test.sh"
fi

main() {
  if [ -f "$ROOT_DIR/install-manifest.txt" ]; then
    test_profile_mode_parse "$@"
    test_profile_smoke_run
    printf 'All %s Shimmy tests passed.\n' "$TEST_COUNT"
    return 0
  fi

  test_runner_options_parse "$@"
  if [ "$TEST_RUNNER_LIST_GROUPS" -eq 1 ]; then
    test_runner_group_list
    return 0
  fi

  shimmy_catalog_checkout_resolve "$ROOT_DIR" upstream || fail_test "$SHIMMY_CATALOG_ERROR"
  test_runner_total_started=$(test_runner_now)
  TMP_ROOT=$(mktemp -d "$TMP_PARENT/shimmy-test.XXXXXX")
  TEST_RUNNER_WORKER_PIDS=
  trap shimmy_test_cleanup EXIT
  trap 'test_runner_signal_handle HUP 129' HUP
  trap 'test_runner_signal_handle INT 130' INT
  trap 'test_runner_signal_handle TERM 143' TERM
  TMP_ROOT=$(cd -- "$TMP_ROOT" && pwd -P)

  test_runner_setup_started=$(test_runner_now)
  setup_session_profile_fixtures
  setup_session_update_source_fixture
  test_runner_setup_finished=$(test_runner_now)
  test_runner_timing_record setup session-fixtures \
    "$((test_runner_setup_finished - test_runner_setup_started))"

  test_runner_groups_run
  test_runner_total_finished=$(test_runner_now)
  test_runner_timing_record total suite \
    "$((test_runner_total_finished - test_runner_total_started))"
  printf 'All %s Shimmy tests passed.\n' "$TEST_COUNT"
}

main "$@"
