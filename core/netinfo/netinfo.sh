#!/bin/sh
# Render host network information for Shimmy tools.
set -eu

OUTPUT_FORMAT=human
AUTO_HOST_PREFIX=
HOST_RESOLUTION_CONFIDENCE=unknown
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
  kernel_name=$5

  case "$kernel_name" in
    Darwin)
      printf '%s\n' darwin
      return 0
      ;;
  esac

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
    docker|podman|lxc|lxc-libvirt|systemd-nspawn|container-other|wsl)
      printf '%s\n' container_probable
      return 0
      ;;
  esac

  case "$virtual_kind" in
    kvm|qemu|oracle|vmware|microsoft|parallels|bhyve)
      printf '%s\n' vm_probable
      return 0
      ;;
  esac

  case "$kernel_name" in
    Linux)
      printf '%s\n' linux
      ;;
    *)
      printf '%s\n' unknown
      ;;
  esac
}

shimmy_default_interface_name_resolve() {
  default_route_lines=$1

  while IFS= read -r default_route_line; do
    [ -n "$default_route_line" ] || continue
    set -- $default_route_line
    while [ "$#" -gt 0 ]; do
      if [ "$1" = dev ] && [ "$#" -ge 2 ]; then
        printf '%s\n' "$2"
        return 0
      fi
      shift
    done
  done <<EOF
$default_route_lines
EOF
}

shimmy_host_default_interface_ipv4_resolve() {
  default_route_lines=$1
  interface_lines=$2

  default_interface_name=$(shimmy_default_interface_name_resolve "$default_route_lines" || true)
  [ -n "$default_interface_name" ] || return 1

  while IFS= read -r interface_line; do
    [ -n "$interface_line" ] || continue
    set -- $interface_line
    [ "$#" -ge 3 ] || continue
    [ "$1" = "$default_interface_name" ] || continue
    case "$2" in
      UP|UNKNOWN)
        ;;
      *)
        continue
        ;;
    esac

    interface_ipv4=${3%/*}
    interface_prefix=
    case "$3" in
      */*)
        interface_prefix=${3#*/}
        ;;
    esac

    if [ -z "$interface_prefix" ] && [ "$KERNEL_NAME" = Darwin ]; then
      interface_prefix=$(shimmy_shell_interface_prefix_read_darwin "$default_interface_name" || true)
    fi

    shimmy_is_ipv4 "$interface_ipv4" || continue
    if [ -n "$interface_prefix" ] && ! shimmy_is_prefix "$interface_prefix"; then
      interface_prefix=
    fi

    AUTO_HOST_PREFIX=$interface_prefix
    HOST_AUTO_IPV4=$interface_ipv4
    return 0
  done <<EOF
$interface_lines
EOF

  return 1
}

shimmy_host_name_ipv4_lookup() {
  host_name_value=$1

  HOST_IPV4_LOOKUP=unknown
  HOST_IPV4_LOOKUP_SOURCE=unknown
  HOST_NAME_LOOKUP_RESOLUTION=failed
  resolver_available=0

  if command -v getent >/dev/null 2>&1; then
    resolver_available=1
    host_ipv4=$(
      getent ahostsv4 "$host_name_value" 2>/dev/null |
        sed -n '1{s/[[:space:]].*//;p;}'
    )

    if [ -n "$host_ipv4" ]; then
      HOST_IPV4_LOOKUP=$host_ipv4
      HOST_IPV4_LOOKUP_SOURCE=getent_ahostsv4
      HOST_NAME_LOOKUP_RESOLUTION=resolved
      return 0
    fi
  fi

  if command -v dscacheutil >/dev/null 2>&1; then
    resolver_available=1
    host_ipv4=$(
      dscacheutil -q host -a name "$host_name_value" 2>/dev/null |
        sed -n 's/^[[:space:]]*ip_address:[[:space:]]*//p' |
        sed -n '1p'
    )

    if [ -n "$host_ipv4" ]; then
      HOST_IPV4_LOOKUP=$host_ipv4
      HOST_IPV4_LOOKUP_SOURCE=dscacheutil_host
      HOST_NAME_LOOKUP_RESOLUTION=resolved
      return 0
    fi
  fi

  if [ "$resolver_available" -eq 0 ]; then
    HOST_NAME_LOOKUP_RESOLUTION=resolver_missing
  fi

  return 1
}

shimmy_host_name_auto_candidates_read() {
  if [ "$shell_hostname" != unknown ]; then
    printf '%s\n' "$shell_hostname"
    case "$shell_hostname" in
      *.local)
        ;;
      *)
        printf '%s.local\n' "$shell_hostname"
        ;;
    esac
  fi

  if [ "$KERNEL_NAME" = Darwin ] && command -v scutil >/dev/null 2>&1; then
    local_host_name=$(scutil --get LocalHostName 2>/dev/null || true)
    if [ -n "$local_host_name" ]; then
      printf '%s\n' "$local_host_name"
      case "$local_host_name" in
        *.local)
          ;;
        *)
          printf '%s.local\n' "$local_host_name"
          ;;
      esac
    fi
  fi
}

shimmy_host_ipv4_resolve() {
  HOST_NAME=${REQUESTED_HOST_NAME:-unknown}

  if [ -n "$REQUESTED_HOST_IP" ]; then
    HOST_IPV4=$REQUESTED_HOST_IP
    HOST_IPV4_SOURCE=explicit
    HOST_RESOLUTION_CONFIDENCE=high
    if [ -n "$REQUESTED_HOST_NAME" ]; then
      HOST_NAME_RESOLUTION=skipped_explicit_host_ip
    else
      HOST_NAME_RESOLUTION=not_requested
    fi
    return 0
  fi

  if [ -n "$REQUESTED_HOST_NAME" ]; then
    if shimmy_host_name_ipv4_lookup "$REQUESTED_HOST_NAME"; then
      HOST_IPV4=$HOST_IPV4_LOOKUP
      HOST_IPV4_SOURCE=$HOST_IPV4_LOOKUP_SOURCE
      HOST_NAME_RESOLUTION=$HOST_NAME_LOOKUP_RESOLUTION
      HOST_RESOLUTION_CONFIDENCE=high
      return 0
    fi

    HOST_IPV4=unknown
    HOST_IPV4_SOURCE=unknown
    HOST_NAME_RESOLUTION=$HOST_NAME_LOOKUP_RESOLUTION
    return 0
  fi

  if shimmy_is_environment_host_authoritative "$environment_name"; then
    if shimmy_host_default_interface_ipv4_resolve "$default_route_lines" "$interface_lines"; then
      HOST_IPV4=$HOST_AUTO_IPV4
      HOST_IPV4_SOURCE=auto_default_interface
      HOST_RESOLUTION_CONFIDENCE=high
      if [ "$shell_hostname" != unknown ]; then
        HOST_NAME=$shell_hostname
        HOST_NAME_RESOLUTION=auto_shell_hostname
      else
        HOST_NAME_RESOLUTION=not_requested
      fi
      return 0
    fi

    host_name_candidate_lines=$(shimmy_host_name_auto_candidates_read || true)
    while IFS= read -r host_name_candidate; do
      [ -n "$host_name_candidate" ] || continue
      if shimmy_host_name_ipv4_lookup "$host_name_candidate"; then
        HOST_NAME=$host_name_candidate
        HOST_IPV4=$HOST_IPV4_LOOKUP
        HOST_IPV4_SOURCE=auto_$HOST_IPV4_LOOKUP_SOURCE
        HOST_NAME_RESOLUTION=auto_resolved
        HOST_RESOLUTION_CONFIDENCE=high
        return 0
      fi
    done <<EOF
$host_name_candidate_lines
EOF
  fi

  HOST_IPV4=unknown
  HOST_IPV4_SOURCE=unknown
  HOST_NAME_RESOLUTION=not_requested
  if shimmy_is_environment_host_authoritative "$environment_name"; then
    HOST_RESOLUTION_CONFIDENCE=unknown
  else
    HOST_RESOLUTION_CONFIDENCE=low
  fi
}

shimmy_host_lan_resolve() {
  if [ -n "$REQUESTED_HOST_LAN" ]; then
    HOST_LAN=$REQUESTED_HOST_LAN
    HOST_LAN_SOURCE=explicit
    HOST_RESOLUTION_CONFIDENCE=high
    return 0
  fi

  if [ "$HOST_IPV4" != unknown ] && [ -n "$REQUESTED_HOST_PREFIX" ]; then
    HOST_LAN=$(shimmy_ipv4_cidr_network_render "$HOST_IPV4" "$REQUESTED_HOST_PREFIX")
    HOST_LAN_SOURCE=host_prefix
    return 0
  fi

  if [ "$HOST_IPV4" != unknown ] &&
    [ "$HOST_IPV4_SOURCE" = auto_default_interface ] &&
    [ -n "$AUTO_HOST_PREFIX" ]; then
    HOST_LAN=$(shimmy_ipv4_cidr_network_render "$HOST_IPV4" "$AUTO_HOST_PREFIX")
    HOST_LAN_SOURCE=auto_interface_prefix
    return 0
  fi

  HOST_LAN=unknown
  HOST_LAN_SOURCE=unknown
}

shimmy_is_environment_host_authoritative() {
  environment_value=$1

  case "$environment_value" in
    darwin|linux)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
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

shimmy_netmask_octet_prefix_resolve() {
  octet_value=$1

  case "$octet_value" in
    255)
      printf '%s\n' 8
      ;;
    254)
      printf '%s\n' 7
      ;;
    252)
      printf '%s\n' 6
      ;;
    248)
      printf '%s\n' 5
      ;;
    240)
      printf '%s\n' 4
      ;;
    224)
      printf '%s\n' 3
      ;;
    192)
      printf '%s\n' 2
      ;;
    128)
      printf '%s\n' 1
      ;;
    0)
      printf '%s\n' 0
      ;;
    *)
      return 1
      ;;
  esac
}

shimmy_netmask_prefix_resolve() {
  netmask_value=$1

  case "$netmask_value" in
    0x*)
      netmask_hex=${netmask_value#0x}
      netmask_prefix=0
      for netmask_nibble in $(printf '%s\n' "$netmask_hex" | sed 's/./& /g'); do
        case "$netmask_nibble" in
          f|F)
            netmask_prefix=$((netmask_prefix + 4))
            ;;
          e|E)
            netmask_prefix=$((netmask_prefix + 3))
            ;;
          c|C)
            netmask_prefix=$((netmask_prefix + 2))
            ;;
          8)
            netmask_prefix=$((netmask_prefix + 1))
            ;;
          0)
            ;;
          *)
            return 1
            ;;
        esac
      done
      printf '%s\n' "$netmask_prefix"
      ;;
    *.*.*.*)
      old_ifs=$IFS
      IFS=.
      set -- $netmask_value
      IFS=$old_ifs

      [ "$#" -eq 4 ] || return 1
      netmask_prefix=0
      for netmask_octet do
        octet_prefix=$(shimmy_netmask_octet_prefix_resolve "$netmask_octet") || return 1
        netmask_prefix=$((netmask_prefix + octet_prefix))
      done
      printf '%s\n' "$netmask_prefix"
      ;;
    *)
      return 1
      ;;
  esac
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

shimmy_kernel_name_read() {
  if [ -n "${SHIMMY_TEST_OS:-}" ]; then
    printf '%s\n' "$SHIMMY_TEST_OS"
    return 0
  fi

  uname -s 2>/dev/null || printf unknown
}

shimmy_nameservers_read() {
  resolv_nameservers=

  if [ -f /etc/resolv.conf ]; then
    resolv_nameservers=$(
      sed -n 's/^[[:space:]]*nameserver[[:space:]][[:space:]]*\([^[:space:]#][^[:space:]#]*\).*$/\1/p' /etc/resolv.conf
    )
  fi

  if [ -n "$resolv_nameservers" ]; then
    printf '%s\n' "$resolv_nameservers"
    return 0
  fi

  command -v scutil >/dev/null 2>&1 || return 0

  scutil --dns 2>/dev/null |
    sed -n 's/^[[:space:]]*nameserver\[[0-9][0-9]*\][[:space:]]*:[[:space:]]*//p'
}

shimmy_network_tools_require() {
  case "$KERNEL_NAME" in
    Linux)
      shimmy_network_tools_require_linux
      ;;
    Darwin)
      shimmy_network_tools_require_darwin
      ;;
    *)
      fail "unsupported netinfo platform: $KERNEL_NAME"
      ;;
  esac
}

shimmy_network_tools_require_darwin() {
  command -v ifconfig >/dev/null 2>&1 || fail "ifconfig is required for netinfo on macOS"
  command -v netstat >/dev/null 2>&1 || fail "netstat is required for netinfo on macOS"
  command -v route >/dev/null 2>&1 || fail "route is required for netinfo on macOS"
}

shimmy_network_tools_require_linux() {
  command -v ip >/dev/null 2>&1 || fail "iproute2 is required; install the ip command or run from a Linux shell that provides it"
}

shimmy_route_targets_read() {
  case "$KERNEL_NAME" in
    Linux)
      shimmy_route_targets_read_linux
      ;;
    Darwin)
      shimmy_route_targets_read_darwin
      ;;
  esac
}

shimmy_route_targets_read_darwin() {
  target_route_lines=

  while IFS= read -r route_target; do
    [ -n "$route_target" ] || continue
    route_result=$(shimmy_command_output route -n get "$route_target")
    if [ -n "$route_result" ]; then
      route_gateway=$(
        printf '%s\n' "$route_result" |
          sed -n 's/^[[:space:]]*gateway:[[:space:]]*//p' |
          sed -n '1p'
      )
      route_interface=$(
        printf '%s\n' "$route_result" |
          sed -n 's/^[[:space:]]*interface:[[:space:]]*//p' |
          sed -n '1p'
      )
      route_source=$(
        printf '%s\n' "$route_result" |
          sed -n 's/^[[:space:]]*local addr:[[:space:]]*//p; s/^[[:space:]]*source:[[:space:]]*//p' |
          sed -n '1p'
      )
      if [ -z "$route_source" ] && [ -n "$route_interface" ]; then
        route_source=$(shimmy_shell_interface_ipv4_read_darwin "$route_interface")
      fi
      route_line=$route_target
      [ -z "$route_gateway" ] || route_line="$route_line via $route_gateway"
      [ -z "$route_interface" ] || route_line="$route_line dev $route_interface"
      [ -z "$route_source" ] || route_line="$route_line src $route_source"
      target_route_lines=$(shimmy_line_list_append "$target_route_lines" "$route_line")
    else
      target_route_lines=$(shimmy_line_list_append "$target_route_lines" "$route_target unresolved")
    fi
  done <<EOF
$ROUTE_TARGETS
EOF

  printf '%s\n' "$target_route_lines"
}

shimmy_shell_interface_ipv4_read_darwin() {
  interface_name=$1

  ifconfig "$interface_name" 2>/dev/null |
    sed -n 's/^[[:space:]]*inet[[:space:]][[:space:]]*\([^[:space:]]*\).*$/\1/p' |
    sed -n '1p'
}

shimmy_shell_interface_prefix_read_darwin() {
  interface_name=$1

  interface_netmask=$(
    ifconfig "$interface_name" 2>/dev/null |
      sed -n 's/^[[:space:]]*inet[[:space:]][[:space:]]*[^[:space:]][^[:space:]]*[[:space:]][[:space:]]*netmask[[:space:]][[:space:]]*\([^[:space:]]*\).*$/\1/p' |
      sed -n '1p'
  )
  [ -n "$interface_netmask" ] || return 1

  shimmy_netmask_prefix_resolve "$interface_netmask"
}

shimmy_route_targets_read_linux() {
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

shimmy_shell_default_routes_read() {
  case "$KERNEL_NAME" in
    Linux)
      shimmy_command_output ip -4 route show default
      ;;
    Darwin)
      netstat -rn -f inet 2>/dev/null |
        awk '$1 == "default" { print "default via " $2 " dev " $4 }'
      ;;
  esac
}

shimmy_shell_interfaces_read() {
  case "$KERNEL_NAME" in
    Linux)
      shimmy_command_output ip -br -4 addr show
      ;;
    Darwin)
      ifconfig 2>/dev/null |
        awk '
          /^[^[:space:]:][^:]*:/ {
            interface_name = $1
            sub(":", "", interface_name)
            interface_state = "DOWN"
            if ($0 ~ /<[^>]*UP[^>]*>/) {
              interface_state = "UP"
            }
            next
          }
          /^[[:space:]]*inet / {
            print interface_name " " interface_state " " $2
          }
        '
      ;;
  esac
}

shimmy_shell_link_routes_read() {
  case "$KERNEL_NAME" in
    Linux)
      shimmy_command_output ip -4 route show scope link
      ;;
    Darwin)
      netstat -rn -f inet 2>/dev/null |
        awk 'NR > 4 && $1 != "default" && $1 != "" { print }'
      ;;
  esac
}

shimmy_shell_neighbors_read() {
  case "$KERNEL_NAME" in
    Linux)
      shimmy_command_output ip -4 neigh show
      ;;
    Darwin)
      command -v arp >/dev/null 2>&1 || return 0
      shimmy_command_output arp -an
      ;;
  esac
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
  --host-name <name>       Resolve a host-side DHCP/DNS name with the system resolver.
  --host-ip <ipv4>         Provide the host-side IPv4 address explicitly.
  --host-prefix <bits>     Pair with --host-ip or --host-name to derive host LAN CIDR.
  --host-lan <cidr>        Provide the host-side LAN CIDR explicitly.
  --format human|manifest  Output format. Default: human.
  -h, --help               Show help.

Notes:
  When the shell appears to be the real host, netinfo can infer host IPv4 and
  LAN values from the default route interface.
  Crostini shells commonly report hostname "penguin". That is the Linux shell
  hostname, not the Chromebook DHCP/DNS name. Use --host-name with the name your
  router or local DNS resolves for the Chromebook.
EOF
}

shimmy_virtual_kind_read() {
  command -v systemd-detect-virt >/dev/null 2>&1 || return 0

  systemd-detect-virt 2>/dev/null || true
}

shimmy_netinfo_run() {
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
KERNEL_NAME=$(shimmy_kernel_name_read)
shimmy_network_tools_require

if [ -z "$ROUTE_TARGETS" ]; then
  ROUTE_TARGETS=1.1.1.1
fi

shell_hostname=$(hostname 2>/dev/null || printf unknown)
kernel_name=$KERNEL_NAME
interface_lines=$(shimmy_shell_interfaces_read)
default_route_lines=$(shimmy_shell_default_routes_read)
link_route_lines=$(shimmy_shell_link_routes_read)
neighbor_lines=$(shimmy_shell_neighbors_read)
nameserver_lines=$(shimmy_nameservers_read)
target_route_lines=$(shimmy_route_targets_read)
virtual_kind=$(shimmy_virtual_kind_read)
environment_name=$(shimmy_environment_detect "$shell_hostname" "$interface_lines" "$default_route_lines" "$virtual_kind" "$kernel_name")

shimmy_host_ipv4_resolve
shimmy_host_lan_resolve

if [ "$OUTPUT_FORMAT" = manifest ]; then
  printf 'perspective=shell\n'
  printf 'environment=%s\n' "$environment_name"
  printf 'virtualization=%s\n' "${virtual_kind:-unknown}"
  printf 'kernel=%s\n' "$kernel_name"
  printf 'shell_hostname=%s\n' "$shell_hostname"
  printf 'host_name=%s\n' "$HOST_NAME"
  printf 'host_name_resolution=%s\n' "$HOST_NAME_RESOLUTION"
  printf 'host_ipv4=%s\n' "$HOST_IPV4"
  printf 'host_ipv4_source=%s\n' "$HOST_IPV4_SOURCE"
  printf 'host_lan=%s\n' "$HOST_LAN"
  printf 'host_lan_source=%s\n' "$HOST_LAN_SOURCE"
  printf 'host_resolution_confidence=%s\n' "$HOST_RESOLUTION_CONFIDENCE"
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
printf 'host_name: %s\n' "$HOST_NAME"
printf 'host_name_resolution: %s\n' "$HOST_NAME_RESOLUTION"
printf 'host_ipv4: %s\n' "$HOST_IPV4"
printf 'host_lan: %s\n' "$HOST_LAN"
printf 'host_resolution_confidence: %s\n' "$HOST_RESOLUTION_CONFIDENCE"
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
if [ "$environment_name" = container_probable ] ||
  [ "$environment_name" = podman_vm_probable ] ||
  [ "$environment_name" = vm_probable ]; then
  printf '%s\n' '- This environment looks VM/container-side, so shell IPs were not promoted to host LAN values.'
fi
if [ "$HOST_NAME_RESOLUTION" = failed ]; then
  printf -- '- the system resolver did not return an IPv4 address for host_name %s.\n' "$REQUESTED_HOST_NAME"
fi
if [ "$HOST_NAME_RESOLUTION" = resolver_missing ]; then
  printf '%s\n' '- no supported host resolver is available, so host_name could not be resolved from this shell.'
fi
if [ "$HOST_IPV4_SOURCE" = auto_default_interface ]; then
  printf '%s\n' '- host_ipv4 was inferred from the default route interface.'
fi
if [ "$HOST_IPV4" != unknown ] && [ "$HOST_LAN" = unknown ]; then
  printf '%s\n' '- host_ipv4 is known, but host_lan still needs --host-prefix or --host-lan.'
fi
if [ "$HOST_LAN" = unknown ]; then
  printf '%s\n' '- To identify the host-side LAN, rerun with --host-name <router-dns-name>, --host-ip <ipv4> --host-prefix <bits>, or --host-lan <cidr>.'
fi
}
