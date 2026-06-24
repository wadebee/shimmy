#!/bin/sh
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
TMP_PARENT=${TMPDIR:-/tmp}

case "$TMP_PARENT" in
  ''|/) TMP_PARENT=/tmp ;;
  */) TMP_PARENT=${TMP_PARENT%/} ;;
esac

TMP_ROOT=$(mktemp -d "$TMP_PARENT/shimmy-test.XXXXXX")
TEST_COUNT=0

# shellcheck source=tests/support.sh
. "$SCRIPT_DIR/support.sh"
# shellcheck source=tests/core/catalog.sh
. "$SCRIPT_DIR/core/catalog.sh"
# shellcheck source=tests/core/runtime.sh
. "$SCRIPT_DIR/core/runtime.sh"
# shellcheck source=tests/commands/lifecycle.sh
. "$SCRIPT_DIR/commands/lifecycle.sh"
# shellcheck source=tests/commands/management.sh
. "$SCRIPT_DIR/commands/management.sh"
# shellcheck source=tests/commands/profiles.sh
. "$SCRIPT_DIR/commands/profiles.sh"
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
# shellcheck source=tools/nmap/tests/nmap.sh
. "$ROOT_DIR/tools/nmap/tests/nmap.sh"
# shellcheck source=tools/opnsense-mcp-admin/tests/opnsense-mcp-admin.sh
. "$ROOT_DIR/tools/opnsense-mcp-admin/tests/opnsense-mcp-admin.sh"
# shellcheck source=tools/opnsense-mcp-read-only/tests/opnsense-mcp-read-only.sh
. "$ROOT_DIR/tools/opnsense-mcp-read-only/tests/opnsense-mcp-read-only.sh"
# shellcheck source=tests/commands/install.sh
. "$SCRIPT_DIR/commands/install.sh"

trap shimmy_test_cleanup EXIT HUP INT TERM

main() {
  test_core_catalog_run
  test_core_runtime_run
  test_commands_lifecycle_prepare
  test_commands_management_run
  test_commands_lifecycle_complete
  test_commands_profiles_run
  test_commands_update_run
  test_commands_startup_run
  test_commands_skills_run
  test_commands_dispatcher_run
  test_commands_netinfo_run
  test_tools_nmap_run
  test_tools_opnsense_mcp_read_only_run
  test_tools_opnsense_mcp_admin_run
  test_commands_install_run
  printf 'All %s Shimmy tests passed.\n' "$TEST_COUNT"
}

main "$@"
