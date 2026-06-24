#!/bin/sh
# Host-network orchestration for the public netinfo command.
set -eu

# The public command supplies ROOT_DIR before sourcing this implementation.
# shellcheck source=core/netinfo/cidr.sh
. "$ROOT_DIR/core/netinfo/cidr.sh"
# shellcheck source=core/netinfo/request.sh
. "$ROOT_DIR/core/netinfo/request.sh"
# shellcheck source=core/netinfo/platform.sh
. "$ROOT_DIR/core/netinfo/platform.sh"
# shellcheck source=core/netinfo/render.sh
. "$ROOT_DIR/core/netinfo/render.sh"

shimmy_netinfo_run() {
  shimmy_netinfo_request_reset
  shimmy_netinfo_request_parse "$@"
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
  shimmy_netinfo_render
}
