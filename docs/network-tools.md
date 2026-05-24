# Networking Tool Shims

Shimmy includes container-backed networking shims for connectivity checks and
network discovery. These tools are most useful when an agent can run them from
the same checkout, container network, or home-lab context it is already
debugging.

Shimmy also includes the repo-level `shimmy netinfo` command for identifying the
current shell's network perspective before choosing a container-backed network
tool. `netinfo` is intentionally not a Podman-backed shim: it reports what the
shell VM or container can see, including interfaces, routes, DNS, and optional
host-side identity supplied through DNS or explicit arguments.

This document is prompt-oriented. It focuses on what to ask an agent to do with
the shims, not on every command-line option each tool supports.

## Netinfo

`shimmy netinfo` is the safest first check when the question is "which network
perspective am I in?" It does not scan the LAN, require Podman, or infer a
physical subnet from NAT-side VM addresses.

Best fit:

- Identify Crostini, VM, or Podman-machine shell-side routes and interfaces.
- Record the route source address used for one or more targets.
- Resolve a user-provided host-side DHCP/DNS name with `getent ahostsv4`.
- Make missing host-side LAN information explicit before running `netcat` or
  `nmap`.

Prompt examples:

```text
Use `./shimmy netinfo` to identify this shell's network perspective. If this is
Crostini, do not use hostname `penguin` as the Chromebook identity; tell me what
host-side DHCP/DNS name or LAN CIDR is still needed.
```

```text
Run `./shimmy netinfo --host-name chromebook-home --host-prefix 24` and explain
which address is shell-side, which address came from router DNS, and what subnet
should be used for a later scoped nmap check.
```

Notes:

- Crostini shells commonly return `penguin` from `hostname`; that is the Linux
  container hostname, not the Chromebook's DHCP/DNS name.
- `--host-name <name>` resolves with `getent ahostsv4 <name>` and works only
  when the router or local DNS registers that name.
- Use `--host-ip <ipv4> --host-prefix <bits>` or `--host-lan <cidr>` when DNS
  registration is unavailable.

## Agent Prompt Patterns

Good prompts give the agent a target, the network perspective to use, and the
level of intrusiveness you are comfortable with.

Useful prompt ingredients:

- Target: client name, IPv4 address, IPv4 CIDR, Podman network, or port range.
- Perspective: default container network, a named Podman network, or explicit
  LAN/host-network visibility.
- Safety boundary: non-intrusive only, no privileged mode, or explicit approval
  for host-network scans.
- Output expectation: summarize findings, save raw output, compare before and
  after, or propose next checks.

Example:

```text
Use the Shimmy networking shims to debug why API client `api-dev` at
`10.88.0.20` cannot reach Postgres client `db-dev` at `10.88.0.30`. Start from
non-intrusive checks only. Inspect TCP reachability from the project's Podman
network named appnet, summarize likely causes, and ask before using host
networking or privileged mode.
```

## Netcat

`netcat` runs `ncat` from Shimmy's local Netcat image. Use it when the agent
needs a small, direct TCP or UDP probe, a simple listener, or a quick TLS
connectivity check that does not require full network discovery.

Best fit:

- Check whether a TCP port is reachable from the agent's current project
  context.
- Compare connectivity to a named client and its IPv4 address.
- Test whether a Kubernetes port-forward, local reverse proxy, or containerized
  service accepts connections.
- Send a minimal protocol request to confirm that the service answering a port
  is the expected one.

Prompt examples:

```text
Use netcat to test TCP reachability from this checkout to API client `api-prod`
at `198.51.100.25` on ports 443 and 8443. Summarize which ports connect and
whether failures look like timeout or connection refusal.
```

```text
Use netcat to verify that my Kubernetes port-forward on `127.0.0.1:15432` is
accepting Postgres connections for client `db-forward`. Do not send
credentials; just confirm whether the port is open and report the exact command
and result.
```

```text
Use netcat to test Home Assistant client `homeassistant-01` at `192.168.1.50`
on port 8123. Tell me whether the problem appears to be TCP reachability from
this network perspective.
```

Shim notes:

- The shim mounts the current working directory at `/work`.
- `SHIMMY_NETCAT_IMAGE` can override the runtime image.
- `SHIMMY_NETCAT_IMAGE_BUILD=always` rebuilds the local image.
- `SHIMMY_NETCAT_BASE_IMAGE` changes the base image used by the local build.
- `SHIMMY_NETCAT_IMAGE_PULL=always` pulls when `SHIMMY_NETCAT_IMAGE` is an explicit remote
  override.

## Nmap

`nmap` runs the Instrumentisto Nmap image. Use it when the agent needs network
discovery, port scanning, service fingerprinting, or a structured inventory of
reachable hosts.

Best fit:

- Discover active devices on a home-lab subnet after explicit LAN-scan approval.
- Scan a narrow port range for a known IPv4 client.
- Inspect a user-defined Podman network for reachable services.
- Compare expected Kubernetes, ingress, or load-balancer exposure with actual
  reachable ports.
- Produce repeatable scan commands that another agent can rerun after a network
  or firewall change.

Prompt examples:

```text
Use nmap in non-intrusive mode to scan only ports 80, 443, 6443, and 8080 on
Kubernetes ingress client `k8s-ingress-01` at `10.0.20.15`. Explain which
services appear reachable and what you would check next in Kubernetes.
```

```text
Use SHIMMY_NMAP_NETWORK=appnet and nmap -sT -Pn to inspect the appnet container
network for API client `api-dev` at `10.88.0.20` and database client `db-dev`
at `10.88.0.30`. Keep the scan narrow and report exact commands, results, and
likely misconfigurations.
```

```text
I approve a LAN discovery pass. Use SHIMMY_NMAP_LAN_SCAN=1 to discover active
hosts on `192.168.1.0/24`, then group likely infrastructure, developer
machines, and unknown devices from the scan output. Include client names such as
`nas-01` or `workstation-01` when the scan output provides them. Do not use
privileged mode unless capability-based LAN scanning fails.
```

```text
Use nmap to verify whether home Kubernetes ingress client `k8s-ingress-01` at
`192.168.1.80` exposes only 80 and 443 from the LAN. Scan that IPv4 address
only, avoid OS detection, and summarize any unexpected open ports as follow-up
risks.
```

Shim notes:

- The shim mounts the current working directory at `/work`.
- `SHIMMY_NMAP_IMAGE` defaults to `docker.io/instrumentisto/nmap:7.98-r2`.
- `SHIMMY_NMAP_IMAGE_PULL=always` pulls the configured image.
- `SHIMMY_NMAP_NETWORK=<name>` runs the shim on a specific Podman network.
- `SHIMMY_NMAP_LAN_SCAN=1` opts into host networking plus `NET_RAW` and
  `NET_ADMIN` capabilities for local-network discovery.
- `SHIMMY_PODMAN_PRIVILEGED=1` adds Podman privileged mode and should be used
  only when the narrower LAN-scan capability set is not enough.
- `SHIMMY_PODMAN_PRIVILEGED_CONNECTION=<name>` selects the rootful Podman
  connection used only for `SHIMMY_PODMAN_PRIVILEGED=1`. When unset, Shimmy
  uses a `<default-connection>-root` companion connection if Podman provides one.
- `SHIMMY_NMAP_PRIVILEGED=1` passes Nmap `--privileged`.
- `SHIMMY_NMAP_PRIVILEGED=0` passes Nmap `--unprivileged` when rootless Podman
  cannot provide raw socket capabilities.

On macOS, LAN discovery runs from the Podman VM's network perspective. Results
can differ from a native host-installed Nmap scan on the physical macOS host.
With rootless Podman, raw `nmap -sn` discovery requires explicit approval for
`SHIMMY_PODMAN_PRIVILEGED=1`; keep that opt-in scoped to the approved scan.
Shimmy leaves the normal Podman default connection unchanged and routes only the
approved privileged invocation through `SHIMMY_PODMAN_PRIVILEGED_CONNECTION`.
Do not make `SHIMMY_PODMAN_PRIVILEGED=1` a default. If the privileged
connection still cannot see the physical LAN, use a native host Nmap or another
network perspective. For TCP reachability, use non-discovery checks such as
`nmap -sT -Pn -p PORTS IPv4_OR_CIDR`.

## Choosing A Shim

Use `netcat` when the question is "can I connect to this port?" Use `nmap`
when the question is "what hosts or services are reachable?"

Prompt examples:

```text
Use the least intrusive Shimmy networking shim that can answer whether
Grafana client `grafana-01` at `192.168.1.60:3000` is reachable from this
project. Escalate from netcat to nmap only if the basic TCP check is ambiguous.
```

```text
Build a two-step network triage plan using netcat and nmap for a containerized
app client `api-dev` at `10.88.0.20` that cannot reach Redis client `redis-01`
at `10.0.30.20` on my home-lab VLAN. Run only the non-mutating checks, explain
each result, and stop before privileged diagnostics.
```

```text
Compare reachability from the default Shimmy container network and the appnet
Podman network for client `agent-runner-01`. Use the networking shims to
collect evidence and tell me which perspective matches my failing workload.
```

## Guardrails For Agentic Use

Network tools can surprise people when run from an automation context. Give the
agent explicit boundaries before asking it to scan.

Recommended guardrails:

- Prefer narrow host and port targets before scanning a full subnet.
- Ask the agent to use default container networking first.
- Require explicit approval before `SHIMMY_NMAP_LAN_SCAN=1` or
  `SHIMMY_PODMAN_PRIVILEGED=1`.
- Avoid OS detection, broad version detection, and large port ranges unless they
  are necessary for the diagnostic.
- Ask the agent to preserve exact commands and raw outputs when results may need
  to be compared later.

Prompt example:

```text
You may use Shimmy networking shims for this investigation. Stay non-intrusive:
no privileged mode and no broad subnet scans without asking. For each command,
explain what network perspective it uses and why that command is the smallest
useful next check.
```
