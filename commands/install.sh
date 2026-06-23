#!/bin/sh
# Install or remove Shimmy profiles and runtime assets.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=core/install/install.sh
. "$ROOT_DIR/core/install/install.sh"

shimmy_install_run "$@"
