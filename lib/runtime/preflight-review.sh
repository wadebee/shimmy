#!/bin/sh
# Dormant runtime-preflight extraction seams for call and ownership review.
#
# Production runtimes do not source this module. The source-only benchmark may
# source it to measure an exact split of the current preflight without changing
# the live call graph. Moving either helper into production requires a separate
# reviewed implementation decision.

shimmy_podman_preflight_context_review_require() {
  context_label=${1:-shimmy}

  shimmy_podman_bin_require "$context_label" || return 1
  shimmy_podman_platform_resolve
  shimmy_podman_profile_affinity_require || return 1
}

shimmy_podman_preflight_reachability_review_require() {
  context_label=${1:-shimmy}

  if [ -z "${SHIMMY_PODMAN_BIN:-}" ]; then
    shimmy_podman_bin_require "$context_label" || return 1
  fi

  if ! "$SHIMMY_PODMAN_BIN" info >/dev/null 2>&1; then
    shimmy_podman_failure_print_unreachable "$context_label" "$SHIMMY_PODMAN_BIN"
    return 1
  fi
}
