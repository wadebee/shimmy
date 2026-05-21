# Networking Tool Shims

Shimmy includes container-backed networking shims for connectivity checks,
socket inspection, and network discovery. These tools are most useful when an
agent can run them from the same checkout, container network, or home-lab
context it is already debugging.

This document is prompt-oriented. It focuses on what to ask an agent to do with
the shims, not on every command-line option each tool supports.

## Agent Prompt Patterns

Good prompts give the agent a target, the network perspective to use, and the
level of intrusiveness you are comfortable with.

Useful prompt ingredients:

- Target: hostname, IP, CIDR, Kubernetes service, Podman network, or port range.
- Perspective: default container network, a named Podman network, or explicit
  LAN/host-network visibility.
- Safety boundary: non-intrusive only, no privileged mode, or explicit approval
  for host-network scans.
- Output expectation: summarize findings, save raw output, compare before and
  after, or propose next checks.

Example:

```text
Use the Shimmy networking shims to debug why my local API cannot reach Postgres.
Start from non-intrusive checks only. Inspect DNS and TCP reachability from the
project's Podman network named appnet, summarize likely causes, and ask before
using host networking or privileged mode.
```

## Netcat

`netcat` runs `ncat` from Shimmy's local Netcat image. Use it when the agent
needs a small, direct TCP or UDP probe, a simple listener, or a quick TLS/DNS
connectivity check that does not require full network discovery.

Best fit:

- Check whether a TCP port is reachable from the agent's current project
  context.
- Compare connectivity to a service by hostname and by IP address.
- Test whether a Kubernetes port-forward, local reverse proxy, or containerized
  service accepts connections.
- Send a minimal protocol request to confirm that the service answering a port
  is the expected one.

Prompt examples:

```text
Use netcat to test TCP reachability from this checkout to api.internal.example
on ports 443 and 8443. Summarize which ports connect and whether failures look
like DNS, timeout, or connection refusal.
```

```text
Use netcat to verify that my Kubernetes port-forward on localhost:15432 is
accepting Postgres connections. Do not send credentials; just confirm whether
the port is open and report the exact command and result.
```

```text
Use netcat to compare connectivity to homeassistant.local:8123 and its current
LAN IP. Tell me whether the problem appears to be name resolution or TCP
reachability.
```

Shim notes:

- The shim mounts the current working directory at `/work`.
- `NETCAT_IMAGE` can override the runtime image.
- `NETCAT_IMAGE_BUILD=always` rebuilds the local image.
- `NETCAT_BASE_IMAGE` changes the base image used by the local build.
- `NETCAT_IMAGE_PULL=always` pulls when `NETCAT_IMAGE` is an explicit remote
  override.

## Netstat

`netstat` runs BusyBox `/bin/netstat` from the same Instrumentisto Nmap image
used by the Nmap shim. Use it when the agent needs to inspect sockets, listeners,
or routing tables from a containerized network perspective.

Best fit:

- Inspect the routing table visible to a containerized tool.
- Check which ports are listening inside the selected network namespace.
- Compare default container-network visibility with an explicit host-network
  view.
- Investigate whether a service is bound to loopback, all interfaces, or a
  specific address.

Prompt examples:

```text
Use netstat to inspect the route table visible to Shimmy's default container
network. Explain how that differs from the host route table and whether it
matters for reaching 192.168.1.0/24.
```

```text
Use SHIMMY_NETSTAT_NETWORK=appnet with netstat to inspect routes and listening
sockets from the appnet container network. Correlate the findings with my
Compose services and suggest the next non-mutating check.
```

```text
Use SHIMMY_NETSTAT_LAN_VIEW=1 netstat -tuln to inspect host-network listener
visibility. Do not use host PID or privileged mode unless the first pass cannot
answer which ports are listening.
```

```text
Use netstat to compare default container-network routing with LAN-view routing.
Summarize only the routes that explain why my agent can reach the internet but
not devices on 10.0.30.0/24.
```

Shim notes:

- The shim mounts the current working directory at `/work`.
- `NETSTAT_IMAGE` defaults to `docker.io/instrumentisto/nmap:7.98-r2`.
- `NETSTAT_IMAGE_PULL=always` pulls the configured image.
- `SHIMMY_NETSTAT_NETWORK=<name>` runs the shim on a specific Podman network.
- `SHIMMY_NETSTAT_LAN_VIEW=1` opts into Podman host networking.
- `SHIMMY_NETSTAT_HOST_PID=1` adds host PID visibility for `netstat -p` when
  permissions allow it.
- `SHIMMY_NETSTAT_PRIVILEGED=1` adds privileged mode and should be treated as a
  last-resort diagnostic opt-in.

On macOS, Podman host networking is the Podman VM's host network namespace, not
the physical macOS host network namespace.

## Nmap

`nmap` runs the Instrumentisto Nmap image. Use it when the agent needs network
discovery, port scanning, service fingerprinting, or a structured inventory of
reachable hosts.

Best fit:

- Discover active devices on a home-lab subnet after explicit LAN-scan approval.
- Scan a narrow port range for a known host.
- Inspect a user-defined Podman network for reachable services.
- Compare expected Kubernetes, ingress, or load-balancer exposure with actual
  reachable ports.
- Produce repeatable scan commands that another agent can rerun after a network
  or firewall change.

Prompt examples:

```text
Use nmap in non-intrusive mode to scan only ports 80, 443, 6443, and 8080 on
10.0.20.15. Explain which services appear reachable and what you would check
next in Kubernetes.
```

```text
Use SHIMMY_NMAP_NETWORK=appnet and nmap -sT -Pn to inspect the appnet container
network for the api and db service names. Keep the scan narrow and report exact
commands, results, and likely misconfigurations.
```

```text
I approve a LAN discovery pass. Use SHIMMY_NMAP_LAN_SCAN=1 to discover active
hosts on 192.168.1.0/24, then group likely infrastructure, developer machines,
and unknown devices from the scan output. Do not use privileged mode unless
capability-based LAN scanning fails.
```

```text
Use nmap to verify whether my home Kubernetes ingress exposes only 80 and 443
from the LAN. Scan the ingress IP only, avoid OS detection, and summarize any
unexpected open ports as follow-up risks.
```

Shim notes:

- The shim mounts the current working directory at `/work`.
- `NMAP_IMAGE` defaults to `docker.io/instrumentisto/nmap:7.98-r2`.
- `NMAP_IMAGE_PULL=always` pulls the configured image.
- `SHIMMY_NMAP_NETWORK=<name>` runs the shim on a specific Podman network.
- `SHIMMY_NMAP_LAN_SCAN=1` opts into host networking plus `NET_RAW` and
  `NET_ADMIN` capabilities for local-network discovery.
- `SHIMMY_NMAP_PRIVILEGED=1` adds privileged mode and should be used only when
  the narrower LAN-scan capability set is not enough.

On macOS, LAN discovery runs from the Podman VM's network perspective. Results
can differ from a native host-installed Nmap scan on the physical macOS host.

## Choosing A Shim

Use `netcat` when the question is "can I connect to this port?" Use `netstat`
when the question is "what routes or listeners are visible from this network
namespace?" Use `nmap` when the question is "what hosts or services are
reachable?"

Prompt examples:

```text
Use the least intrusive Shimmy networking shim that can answer whether
grafana.home.arpa:3000 is reachable from this project. Escalate from netcat to
nmap only if the basic TCP check is ambiguous.
```

```text
Build a three-step network triage plan using netcat, netstat, and nmap for a
containerized app that cannot reach Redis on my home-lab VLAN. Run only the
non-mutating checks, explain each result, and stop before privileged diagnostics.
```

```text
Compare the network view from the default Shimmy container network, the appnet
Podman network, and LAN-view mode. Use the networking shims to collect evidence
and tell me which perspective matches my failing workload.
```

## Guardrails For Agentic Use

Network tools can surprise people when run from an automation context. Give the
agent explicit boundaries before asking it to scan.

Recommended guardrails:

- Prefer narrow host and port targets before scanning a full subnet.
- Ask the agent to use default container networking first.
- Require explicit approval before `SHIMMY_NMAP_LAN_SCAN=1`,
  `SHIMMY_NMAP_PRIVILEGED=1`, `SHIMMY_NETSTAT_LAN_VIEW=1`, or
  `SHIMMY_NETSTAT_PRIVILEGED=1`.
- Avoid OS detection, broad version detection, and large port ranges unless they
  are necessary for the diagnostic.
- Ask the agent to preserve exact commands and raw outputs when results may need
  to be compared later.

Prompt example:

```text
You may use Shimmy networking shims for this investigation. Stay non-intrusive:
no privileged mode, no broad subnet scans, and no LAN-view mode without asking.
For each command, explain what network perspective it uses and why that command
is the smallest useful next check.
```
