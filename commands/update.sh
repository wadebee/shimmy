#!/bin/sh
# Refresh Shimmy management and runtime assets.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=core/update/update.sh
. "$ROOT_DIR/core/update/update.sh"

shimmy_update_run "$@"
