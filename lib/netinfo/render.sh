#!/bin/sh
# Manifest and human-readable rendering for host-network discovery.

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

shimmy_netinfo_render() {
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
    return 0
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
