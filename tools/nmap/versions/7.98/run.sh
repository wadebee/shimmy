#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_PODMAN_HELPER_FILE=$ROOT_DIR/lib/runtime/podman.sh

SHIMMY_NMAP_IMAGE=${SHIMMY_NMAP_IMAGE:-docker.io/instrumentisto/nmap:7.98-r2}
SHIMMY_NMAP_IMAGE_PULL=${SHIMMY_NMAP_IMAGE_PULL:-}
SHIMMY_NMAP_LAN_SCAN=${SHIMMY_NMAP_LAN_SCAN:-}
SHIMMY_NMAP_NETWORK=${SHIMMY_NMAP_NETWORK:-}
SHIMMY_NMAP_NET_ADMIN_CAP_ARG=
SHIMMY_NMAP_NET_ADMIN_CAP_VALUE=
SHIMMY_NMAP_NET_RAW_CAP_ARG=
SHIMMY_NMAP_NET_RAW_CAP_VALUE=
SHIMMY_NMAP_NETWORK_ARG=
SHIMMY_NMAP_NETWORK_VALUE=
SHIMMY_NMAP_PRIVILEGED=${SHIMMY_NMAP_PRIVILEGED:-}
SHIMMY_NMAP_PRIVILEGED_ARG=
SHIMMY_NMAP_PULL_ARG=
SHIMMY_NMAP_TTY_ARG=
PODMAN_CONNECTION_ARG=
PODMAN_CONNECTION_VALUE=
PODMAN_PRIVILEGED=${SHIMMY_PODMAN_PRIVILEGED:-}
PODMAN_PRIVILEGED_ARG=

shimmy_nmap_args_include_host_discovery() {
  for arg do
    case "$arg" in
      -sn|-sP)
        return 0
        ;;
    esac
  done

  return 1
}

shimmy_nmap_args_include_unprivileged() {
  for arg do
    case "$arg" in
      --unprivileged)
        return 0
        ;;
    esac
  done

  return 1
}

shimmy_nmap_is_rootless_podman() {
  rootless_value=$("$SHIMMY_PODMAN_BIN" info --format '{{.Host.Security.Rootless}}' 2>/dev/null || printf unknown)

  [ "$rootless_value" = true ]
}

if [ ! -f "$SHIMMY_PODMAN_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_PODMAN_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/podman.sh
. "$SHIMMY_PODMAN_HELPER_FILE"

shimmy_podman_preflight_or_preview_require "the nmap shim" "$@"

if [ "$SHIMMY_NMAP_IMAGE_PULL" = "always" ]; then
  SHIMMY_NMAP_PULL_ARG=--pull=always
fi

case "$SHIMMY_NMAP_LAN_SCAN" in
  ''|0)
    ;;
  1)
    if [ -n "$SHIMMY_NMAP_NETWORK" ] && [ "$SHIMMY_NMAP_NETWORK" != host ]; then
      printf 'ERROR: SHIMMY_NMAP_LAN_SCAN=1 cannot be combined with SHIMMY_NMAP_NETWORK=%s\n' "$SHIMMY_NMAP_NETWORK" >&2
      exit 1
    fi
    SHIMMY_NMAP_NETWORK=host
    SHIMMY_NMAP_NET_RAW_CAP_ARG=--cap-add
    SHIMMY_NMAP_NET_RAW_CAP_VALUE=NET_RAW
    SHIMMY_NMAP_NET_ADMIN_CAP_ARG=--cap-add
    SHIMMY_NMAP_NET_ADMIN_CAP_VALUE=NET_ADMIN
    ;;
  *)
    printf 'ERROR: SHIMMY_NMAP_LAN_SCAN must be 1, 0, or unset\n' >&2
    exit 1
    ;;
esac

case "$SHIMMY_NMAP_PRIVILEGED" in
  '')
    ;;
  1)
    SHIMMY_NMAP_PRIVILEGED_ARG=--privileged
    ;;
  0)
    SHIMMY_NMAP_PRIVILEGED_ARG=--unprivileged
    ;;
  *)
    printf 'ERROR: SHIMMY_NMAP_PRIVILEGED must be 1, 0, or unset\n' >&2
    exit 1
    ;;
esac

case "$PODMAN_PRIVILEGED" in
  ''|0)
    ;;
  1)
    if shimmy_podman_is_preview; then
      if [ -n "${SHIMMY_PODMAN_PRIVILEGED_CONNECTION:-}" ]; then
        PODMAN_CONNECTION_ARG=--connection
        PODMAN_CONNECTION_VALUE=$SHIMMY_PODMAN_PRIVILEGED_CONNECTION
      fi
    else
      shimmy_podman_privileged_connection_require "the nmap shim" || exit 1
      PODMAN_CONNECTION_ARG=--connection
      PODMAN_CONNECTION_VALUE=$SHIMMY_PODMAN_PRIVILEGED_CONNECTION
    fi
    PODMAN_PRIVILEGED_ARG=--privileged
    ;;
  *)
    printf 'ERROR: SHIMMY_PODMAN_PRIVILEGED must be 1, 0, or unset\n' >&2
    exit 1
    ;;
esac

if [ "$SHIMMY_NMAP_PRIVILEGED_ARG" != "--unprivileged" ] &&
  [ "$PODMAN_PRIVILEGED_ARG" != "--privileged" ] &&
  ! shimmy_podman_is_preview &&
  ! shimmy_nmap_args_include_unprivileged "$@" &&
  shimmy_nmap_args_include_host_discovery "$@" &&
  shimmy_nmap_is_rootless_podman; then
  printf '%s\n' 'ERROR: nmap host discovery (-sn/-sP) needs raw socket access, but this Podman connection is rootless.' >&2
  printf '%s\n' 'This scan requires explicit Podman privileged escalation approval.' >&2
  printf '%s\n' 'Do not make SHIMMY_PODMAN_PRIVILEGED=1 a default.' >&2
  printf '%s\n' 'When Podman provides a <default-connection>-root connection, Shimmy uses it only for the approved privileged run.' >&2
  printf '%s\n' 'Set SHIMMY_PODMAN_PRIVILEGED_CONNECTION to override that rootful connection.' >&2
  printf '%s\n' 'Request approval for the exact wrapper prefix before retrying, for example:' >&2
  printf '%s\n' '  ["env","SHIMMY_NMAP_LAN_SCAN=1","SHIMMY_PODMAN_PRIVILEGED=1","./commands/run-tool.sh","nmap"]' >&2
  printf '%s\n' '  ["env","SHIMMY_NMAP_LAN_SCAN=1","SHIMMY_PODMAN_PRIVILEGED=1","nmap"]' >&2
  printf '%s\n' 'After approval, retry with:' >&2
  printf '%s\n' '  SHIMMY_NMAP_LAN_SCAN=1 SHIMMY_PODMAN_PRIVILEGED=1 nmap -sn <target>' >&2
  printf '%s\n' 'If the approved privileged run still cannot open raw sockets, use a rootful Podman connection for raw LAN discovery.' >&2
  printf '%s\n' 'For TCP reachability from rootless Podman, use a non-discovery scan such as: nmap -sT -Pn -p <ports> <target>' >&2
  exit 1
fi

if [ -n "$SHIMMY_NMAP_NETWORK" ]; then
  SHIMMY_NMAP_NETWORK_ARG=--network
  SHIMMY_NMAP_NETWORK_VALUE=$SHIMMY_NMAP_NETWORK
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_NMAP_TTY_ARG=-it
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" \
  ${PODMAN_CONNECTION_ARG:+"$PODMAN_CONNECTION_ARG"} \
  ${PODMAN_CONNECTION_VALUE:+"$PODMAN_CONNECTION_VALUE"} \
  run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_NMAP_PULL_ARG:+"$SHIMMY_NMAP_PULL_ARG"} \
  ${SHIMMY_NMAP_TTY_ARG:+"$SHIMMY_NMAP_TTY_ARG"} \
  ${SHIMMY_NMAP_NETWORK_ARG:+"$SHIMMY_NMAP_NETWORK_ARG"} \
  ${SHIMMY_NMAP_NETWORK_VALUE:+"$SHIMMY_NMAP_NETWORK_VALUE"} \
  ${SHIMMY_NMAP_NET_RAW_CAP_ARG:+"$SHIMMY_NMAP_NET_RAW_CAP_ARG"} \
  ${SHIMMY_NMAP_NET_RAW_CAP_VALUE:+"$SHIMMY_NMAP_NET_RAW_CAP_VALUE"} \
  ${SHIMMY_NMAP_NET_ADMIN_CAP_ARG:+"$SHIMMY_NMAP_NET_ADMIN_CAP_ARG"} \
  ${SHIMMY_NMAP_NET_ADMIN_CAP_VALUE:+"$SHIMMY_NMAP_NET_ADMIN_CAP_VALUE"} \
  ${PODMAN_PRIVILEGED_ARG:+"$PODMAN_PRIVILEGED_ARG"} \
  -v "$PWD:/work" \
  -w /work \
  "$SHIMMY_NMAP_IMAGE" \
  ${SHIMMY_NMAP_PRIVILEGED_ARG:+"$SHIMMY_NMAP_PRIVILEGED_ARG"} \
  "$@"
