#!/bin/sh
# Netinfo request parsing and explicit host-input validation.

shimmy_inputs_validate() {
  if [ -n "$REQUESTED_HOST_IP" ] && ! shimmy_is_ipv4 "$REQUESTED_HOST_IP"; then
    shimmy_netinfo_fail "invalid --host-ip value: $REQUESTED_HOST_IP"
  fi

  if [ -n "$REQUESTED_HOST_PREFIX" ] && ! shimmy_is_prefix "$REQUESTED_HOST_PREFIX"; then
    shimmy_netinfo_fail "invalid --host-prefix value: $REQUESTED_HOST_PREFIX"
  fi

  if [ -n "$REQUESTED_HOST_LAN" ]; then
    host_lan_ip=${REQUESTED_HOST_LAN%/*}
    host_lan_prefix=${REQUESTED_HOST_LAN#*/}
    if [ "$host_lan_ip" = "$REQUESTED_HOST_LAN" ] ||
      ! shimmy_is_ipv4 "$host_lan_ip" ||
      ! shimmy_is_prefix "$host_lan_prefix"; then
      shimmy_netinfo_fail "invalid --host-lan value: $REQUESTED_HOST_LAN"
    fi
  fi
}

shimmy_netinfo_request_parse() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --format)
        [ "$#" -ge 2 ] || shimmy_netinfo_fail "missing value for --format"
        case "$2" in
          human|manifest)
            OUTPUT_FORMAT=$2
            ;;
          *)
            shimmy_netinfo_fail "unsupported netinfo format: $2"
            ;;
        esac
        shift 2
        ;;
      --host-ip)
        [ "$#" -ge 2 ] || shimmy_netinfo_fail "missing value for --host-ip"
        REQUESTED_HOST_IP=$2
        shift 2
        ;;
      --host-lan)
        [ "$#" -ge 2 ] || shimmy_netinfo_fail "missing value for --host-lan"
        REQUESTED_HOST_LAN=$2
        shift 2
        ;;
      --host-name)
        [ "$#" -ge 2 ] || shimmy_netinfo_fail "missing value for --host-name"
        REQUESTED_HOST_NAME=$2
        shift 2
        ;;
      --host-prefix)
        [ "$#" -ge 2 ] || shimmy_netinfo_fail "missing value for --host-prefix"
        REQUESTED_HOST_PREFIX=$2
        shift 2
        ;;
      --target)
        [ "$#" -ge 2 ] || shimmy_netinfo_fail "missing value for --target"
        ROUTE_TARGETS=$(shimmy_line_list_append "$ROUTE_TARGETS" "$2")
        shift 2
        ;;
      -h|--help)
        shimmy_usage_print
        exit 0
        ;;
      *)
        shimmy_netinfo_fail "unknown argument: $1"
        ;;
    esac
  done
}

shimmy_netinfo_request_reset() {
  AUTO_HOST_PREFIX=
  HOST_RESOLUTION_CONFIDENCE=unknown
  OUTPUT_FORMAT=human
  REQUESTED_HOST_IP=
  REQUESTED_HOST_LAN=
  REQUESTED_HOST_NAME=
  REQUESTED_HOST_PREFIX=
  ROUTE_TARGETS=
}
