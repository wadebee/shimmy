#!/usr/bin/env bash

SHIMMY_REPO_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/repo/shimmy-log.sh
source "$SHIMMY_REPO_LIB_DIR/shimmy-log.sh"
# shellcheck source=lib/repo/shimmy-paths.sh
source "$SHIMMY_REPO_LIB_DIR/shimmy-paths.sh"
# shellcheck source=lib/repo/shimmy-install-paths.sh
source "$SHIMMY_REPO_LIB_DIR/shimmy-install-paths.sh"
# shellcheck source=lib/repo/shimmy-manifest.sh
source "$SHIMMY_REPO_LIB_DIR/shimmy-manifest.sh"
# shellcheck source=lib/repo/shimmy-shell-blocks.sh
source "$SHIMMY_REPO_LIB_DIR/shimmy-shell-blocks.sh"
