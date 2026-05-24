#!/bin/sh
set -eu

OUTPUT_FORMAT=human
REQUESTED_HOST_IP=
REQUESTED_HOST_LAN=
REQUESTED_HOST_NAME=
REQUESTED_HOST_PREFIX=
ROUTE_TARGETS=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

shimmy_command_output() {
  "$@" 2>/dev/null || true
}

shimmy_environment_detect() {
  shell_hostname=$1
  interface_lines=$2
  default_route_lines=$3
  virtual_kind=$4

  if [ -e /dev/.cros_milestone ]; then
    printf '%s\n' crostini
    return 0
  fi

  environment_probe=$shell_hostname'
'$interface_lines'
'$default_route_lines

  case "$environment_probe" in
    *penguin*100.115.92.*|*penguin*/mnt/chromeos*)
      printf '%s\n' crostini_probable
      return 0
      ;;
  esac

  if [ "$shell_hostname" = penguin ] && [ "$virtual_kind" = lxc ]; then
    printf '%s\n' crostini_probable
    return 0
  fi

  if [ "$shell_hostname" = penguin ] && [ -d /mnt/chromeos ]; then
    printf '%s\n' crostini_probable
    return 0
  fi

  case "$shell_hostname" in
    podman*|*podman*)
      printf '%s\n' podman_vm_probable
      return 0
      ;;
  esac

  case "$virtual_kind" in
    kvm|qemu|oracle|vmware|microsoft|parallels|bhyve)
      printf '%s\n' vm_probable
      return 0
      ;;
  esac

  printf '%s\n' linux
}

shimmy_host_ipv4_resolve() {
  if [ -n "$REQUESTED_HOST_IP" ]; then
    HOST_IPV4=$REQUESTED_HOST_IP
    HOST_IPV4_SOURCE=explicit
    if [ -n "$REQUESTED_HOST_NAME" ]; then
      HOST_NAME_RESOLUTION=skipped_explicit_host_ip
    else
      HOST_NAME_RESOLUTION=not_requested
    fi
    return 0
  fi

  if [ -z "$REQUESTED_HOST_NAME" ]; then
    HOST_IPV4=unknown
    HOST_IPV4_SOURCE=unknown
    HOST_NAME_RESOLUTION=not_requested
    return 0
  fi

  if ! command -v getent >/dev/null 2>&1; then
    HOST_IPV4=unknown
    HOST_IPV4_SOURCE=unknown
    HOST_NAME_RESOLUTION=getent_missing
    return 0
  fi

  host_ipv4=$(
    getent ahostsv4 "$REQUESTED_HOST_NAME" 2>/dev/null |
      sed -n '1{s/[[:space:]].*//;p;}'
  )

  if [ -n "$host_ipv4" ]; then
    HOST_IPV4=$host_ipv4
    HOST_IPV4_SOURCE=getent_ahostsv4
    HOST_NAME_RESOLUTION=resolved
    return 0
  fi

  HOST_IPV4=unknown
  HOST_IPV4_SOURCE=unknown
  HOST_NAME_RESOLUTION=failed
}

shimmy_host_lan_resolve() {
  if [ -n "$REQUESTED_HOST_LAN" ]; then
    HOST_LAN=$REQUESTED_HOST_LAN
    HOST_LAN_SOURCE=explicit
    return 0
  fi

  if [ "$HOST_IPV4" != unknown ] && [ -n "$REQUESTED_HOST_PREFIX" ]; then
    HOST_LAN=$(shimmy_ipv4_cidr_network_render "$HOST_IPV4" "$REQUESTED_HOST_PREFIX")
    HOST_LAN_SOURCE=host_prefix
    return 0
  fi

  HOST_LAN=unknown
  HOST_LAN_SOURCE=unknown
}

shimmy_inputs_validate() {
  if [ -n "$REQUESTED_HOST_IP" ] && ! shimmy_is_ipv4 "$REQUESTED_HOST_IP"; then
    fail "invalid --host-ip value: $REQUESTED_HOST_IP"
  fi

  if [ -n "$REQUESTED_HOST_PREFIX" ] && ! shimmy_is_prefix "$REQUESTED_HOST_PREFIX"; then
    fail "invalid --host-prefix value: $REQUESTED_HOST_PREFIX"
  fi

  if [ -n "$REQUESTED_HOST_LAN" ]; then
    host_lan_ip=${REQUESTED_HOST_LAN%/*}
    host_lan_prefix=${REQUESTED_HOST_LAN#*/}
    if [ "$host_lan_ip" = "$REQUESTED_HOST_LAN" ] ||
      ! shimmy_is_ipv4 "$host_lan_ip" ||
      ! shimmy_is_prefix "$host_lan_prefix"; then
      fail "invalid --host-lan value: $REQUESTED_HOST_LAN"
    fi
  fi
}

shimmy_ipv4_cidr_network_render() {
  ip_value=$1
  prefix_value=$2

  old_ifs=$IFS
  IFS=.
  set -- $ip_value
  IFS=$old_ifs

  [ "$#" -eq 4 ] || fail "invalid IPv4 value: $ip_value"

  octet_a=$1
  octet_b=$2
  octet_c=$3
  octet_d=$4

  ip_int=$(((((octet_a * 256) + octet_b) * 256 + octet_c) * 256 + octet_d))
  if [ "$prefix_value" -eq 0 ]; then
    mask_int=0
  else
    mask_int=$(((4294967295 << (32 - prefix_value)) & 4294967295))
  fi

  network_int=$((ip_int & mask_int))
  network_a=$(((network_int >> 24) & 255))
  network_b=$(((network_int >> 16) & 255))
  network_c=$(((network_int >> 8) & 255))
  network_d=$((network_int & 255))

  printf '%s.%s.%s.%s/%s\n' "$network_a" "$network_b" "$network_c" "$network_d" "$prefix_value"
}

shimmy_is_ipv4() {
  ip_value=$1

  old_ifs=$IFS
  IFS=.
  set -- $ip_value
  IFS=$old_ifs

  [ "$#" -eq 4 ] || return 1

  for octet_value do
    case "$octet_value" in
      ''|*[!0-9]*)
        return 1
        ;;
    esac
    [ "$octet_value" -ge 0 ] 2>/dev/null || return 1
    [ "$octet_value" -le 255 ] 2>/dev/null || return 1
  done

  return 0
}

shimmy_is_prefix() {
  prefix_value=$1

  case "$prefix_value" in
    ''|*[!0-9]*)
      return 1
      ;;
  esac

  [ "$prefix_value" -ge 0 ] 2>/dev/null || return 1
  [ "$prefix_value" -le 32 ] 2>/dev/null || return 1
}

shimmy_line_list_append() {
  list_value=${1:-}
  line_value=$2

  if [ -n "$list_value" ]; then
    printf '%s\n%s\n' "$list_value" "$line_value"
  else
    printf '%s\n' "$line_value"
  fi
}

shimmy_manifest_line_print() {
  key_name=$1
  line_list=${2:-}

  while IFS= read -r line_value; do
    [ -n "$line_value" ] || continue
    printf '%s=%s\n' "$key_name" "$line_value"
  done <<EOF
$line_list
EOF
}

shimmy_nameservers_read() {
  if [ ! -f /etc/resolv.conf ]; then
    return 0
  fi

  sed -n 's/^[[:space:]]*nameserver[[:space:]][[:space:]]*\([^[:space:]#][^[:space:]#]*\).*$/\1/p' /etc/resolv.conf
}

shimmy_require_ip() {
  command -v ip >/dev/null 2>&1 || fail "iproute2 is required; install the ip command or run from a Linux shell that provides it"
}

shimmy_route_targets_read() {
  target_route_lines=

  while IFS= read -r route_target; do
    [ -n "$route_target" ] || continue
    route_result=$(shimmy_command_output ip -4 route get "$route_target")
    if [ -n "$route_result" ]; then
      target_route_lines=$(shimmy_line_list_append "$target_route_lines" "$route_result")
    else
      target_route_lines=$(shimmy_line_list_append "$target_route_lines" "$route_target unresolved")
    fi
  done <<EOF
$ROUTE_TARGETS
EOF

  printf '%s\n' "$target_route_lines"
}

shimmy_section_print() {
  section_name=$1
  line_list=${2:-}

  printf '%s:\n' "$section_name"
  if [ -z "$line_list" ]; then
    printf '%s\n' '- none'
    return 0
  fi

  while IFS= read -r line_value; do
    [ -n "$line_value" ] || continue
    printf -- '- %s\n' "$line_value"
  done <<EOF
$line_list
EOF
}

shimmy_usage_print() {
  cat <<'EOF'
Print shell network perspective for VM and container-heavy workstations.

Usage:
  shimmy netinfo [options]

Options:
  --target <host-or-ip>    Add an IPv4 route perspective target. Repeatable.
                           Default: 1.1.1.1
  --host-name <name>       Resolve a host-side DHCP/DNS name with getent ahostsv4.
  --host-ip <ipv4>         Provide the host-side IPv4 address explicitly.
  --host-prefix <bits>     Pair with --host-ip or --host-name to derive host LAN CIDR.
  --host-lan <cidr>        Provide the host-side LAN CIDR explicitly.
  --format human|manifest  Output format. Default: human.
  -h, --help               Show help.

Notes:
  Crostini shells commonly report hostname "penguin". That is the Linux shell
  hostname, not the Chromebook DHCP/DNS name. Use --host-name with the name your
  router or local DNS resolves for the Chromebook.
EOF
}

shimmy_virtual_kind_read() {
  command -v systemd-detect-virt >/dev/null 2>&1 || return 0

  systemd-detect-virt 2>/dev/null || true
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --format)
      [ "$#" -ge 2 ] || fail "missing value for --format"
      case "$2" in
        human|manifest)
          OUTPUT_FORMAT=$2
          ;;
        *)
          fail "unsupported netinfo format: $2"
          ;;
      esac
      shift 2
      ;;
    --host-ip)
      [ "$#" -ge 2 ] || fail "missing value for --host-ip"
      REQUESTED_HOST_IP=$2
      shift 2
      ;;
    --host-lan)
      [ "$#" -ge 2 ] || fail "missing value for --host-lan"
      REQUESTED_HOST_LAN=$2
      shift 2
      ;;
    --host-name)
      [ "$#" -ge 2 ] || fail "missing value for --host-name"
      REQUESTED_HOST_NAME=$2
      shift 2
      ;;
    --host-prefix)
      [ "$#" -ge 2 ] || fail "missing value for --host-prefix"
      REQUESTED_HOST_PREFIX=$2
      shift 2
      ;;
    --target)
      [ "$#" -ge 2 ] || fail "missing value for --target"
      ROUTE_TARGETS=$(shimmy_line_list_append "$ROUTE_TARGETS" "$2")
      shift 2
      ;;
    -h|--help)
      shimmy_usage_print
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

shimmy_inputs_validate
shimmy_require_ip

if [ -z "$ROUTE_TARGETS" ]; then
  ROUTE_TARGETS=1.1.1.1
fi

shell_hostname=$(hostname 2>/dev/null || printf unknown)
kernel_name=$(uname -s 2>/dev/null || printf unknown)
interface_lines=$(shimmy_command_output ip -br -4 addr show)
default_route_lines=$(shimmy_command_output ip -4 route show default)
link_route_lines=$(shimmy_command_output ip -4 route show scope link)
neighbor_lines=$(shimmy_command_output ip -4 neigh show)
nameserver_lines=$(shimmy_nameservers_read)
target_route_lines=$(shimmy_route_targets_read)
virtual_kind=$(shimmy_virtual_kind_read)
environment_name=$(shimmy_environment_detect "$shell_hostname" "$interface_lines" "$default_route_lines" "$virtual_kind")

shimmy_host_ipv4_resolve
shimmy_host_lan_resolve

if [ "$OUTPUT_FORMAT" = manifest ]; then
  printf 'perspective=shell\n'
  printf 'environment=%s\n' "$environment_name"
  printf 'virtualization=%s\n' "${virtual_kind:-unknown}"
  printf 'kernel=%s\n' "$kernel_name"
  printf 'shell_hostname=%s\n' "$shell_hostname"
  printf 'host_name=%s\n' "${REQUESTED_HOST_NAME:-unknown}"
  printf 'host_name_resolution=%s\n' "$HOST_NAME_RESOLUTION"
  printf 'host_ipv4=%s\n' "$HOST_IPV4"
  printf 'host_ipv4_source=%s\n' "$HOST_IPV4_SOURCE"
  printf 'host_lan=%s\n' "$HOST_LAN"
  printf 'host_lan_source=%s\n' "$HOST_LAN_SOURCE"
  shimmy_manifest_line_print interface_ipv4 "$interface_lines"
  shimmy_manifest_line_print default_route "$default_route_lines"
  shimmy_manifest_line_print link_route "$link_route_lines"
  shimmy_manifest_line_print route_target "$target_route_lines"
  shimmy_manifest_line_print nameserver "$nameserver_lines"
  shimmy_manifest_line_print neighbor_ipv4 "$neighbor_lines"
  if [ "$HOST_LAN" = unknown ]; then
    printf 'action_needed=provide_host_name_host_ip_prefix_or_host_lan\n'
  fi
  if [ "$HOST_NAME_RESOLUTION" = failed ]; then
    printf 'action_needed=verify_host_name_dns_registration\n'
  fi
  exit 0
fi

printf 'Shimmy Netinfo\n'
printf 'perspective: shell\n'
printf 'environment: %s\n' "$environment_name"
printf 'virtualization: %s\n' "${virtual_kind:-unknown}"
printf 'kernel: %s\n' "$kernel_name"
printf 'shell_hostname: %s\n' "$shell_hostname"
printf 'host_name: %s\n' "${REQUESTED_HOST_NAME:-unknown}"
printf 'host_name_resolution: %s\n' "$HOST_NAME_RESOLUTION"
printf 'host_ipv4: %s\n' "$HOST_IPV4"
printf 'host_lan: %s\n' "$HOST_LAN"
printf '\n'

shimmy_section_print interfaces "$interface_lines"
printf '\n'
shimmy_section_print default_routes "$default_route_lines"
printf '\n'
shimmy_section_print link_routes "$link_route_lines"
printf '\n'
shimmy_section_print route_to_targets "$target_route_lines"
printf '\n'
shimmy_section_print dns_nameservers "$nameserver_lines"
printf '\n'
shimmy_section_print neighbors "$neighbor_lines"
printf '\n'

printf 'notes:\n'
if [ "$environment_name" = crostini ] || [ "$environment_name" = crostini_probable ]; then
  printf '%s\n' '- Crostini shell IPs are VM/container-side addresses, not the Chromebook LAN address.'
  if [ "$shell_hostname" = penguin ]; then
    printf '%s\n' '- shell_hostname penguin is the Crostini container name; do not use it as the Chromebook DHCP/DNS name.'
  fi
fi
if [ "$HOST_NAME_RESOLUTION" = failed ]; then
  printf -- '- getent ahostsv4 did not return an IPv4 address for host_name %s.\n' "$REQUESTED_HOST_NAME"
fi
if [ "$HOST_NAME_RESOLUTION" = getent_missing ]; then
  printf '%s\n' '- getent is not available, so host_name could not be resolved from this shell.'
fi
if [ "$HOST_IPV4" != unknown ] && [ "$HOST_LAN" = unknown ]; then
  printf '%s\n' '- host_ipv4 is known, but host_lan still needs --host-prefix or --host-lan.'
fi
if [ "$HOST_LAN" = unknown ]; then
  printf '%s\n' '- To identify the host-side LAN, rerun with --host-name <router-dns-name>, --host-ip <ipv4> --host-prefix <bits>, or --host-lan <cidr>.'
fi
