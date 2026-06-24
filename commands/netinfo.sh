#!/bin/sh
# Render host network information for Shimmy tools.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=core/netinfo/netinfo.sh
. "$ROOT_DIR/core/netinfo/netinfo.sh"

shimmy_netinfo_run "$@"
