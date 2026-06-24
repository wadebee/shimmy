#!/bin/sh
# IPv4, CIDR, and line-list helpers for host-network discovery.

shimmy_netinfo_fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

shimmy_ipv4_cidr_network_render() {
  ip_value=$1
  prefix_value=$2

  old_ifs=$IFS
  IFS=.
  set -- $ip_value
  IFS=$old_ifs

  [ "$#" -eq 4 ] || shimmy_netinfo_fail "invalid IPv4 value: $ip_value"

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
