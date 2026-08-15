---
name: shimmy-tool-nmap
description: Guidance for using, changing, testing, and troubleshooting the Nmap shim in this repository, including LAN scan opt-ins, rootless Podman limits, and privileged escalation safeguards.
---

# Nmap Shim

Use this skill when working with the Nmap tool, its tests, its docs, or Nmap usage through Shimmy.

## Files

- Tool metadata: `tools/nmap/tool.conf`
- Concrete runtime: `tools/nmap/versions/7.98/run.sh`
- User guide: `tools/nmap/guide.md`
- Tests: `tools/nmap/tests/nmap.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `nmap` normally
and inspect the invoking profile with `shimmy status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate` command. Running containers
require separate explicit confirmation before adding `--stop-running`. A missing
machine must be provisioned by the user in a normal shell with the exact
`podman machine init shimmy-<profile>` guidance; agents never run direct Podman
machine lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To test `upstream`, use the
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream`.

For source validation, use `./commands/run-tool.sh nmap --preview-shim --version`
or the concrete `tools/nmap/versions/7.98/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: `docker.io/instrumentisto/nmap@sha256:96f6ed194519b62421a1a1c57809e65a7f94d2aa1c8c25676f247e5e148c0827` from version-owned `image.conf`
- Image override: `SHIMMY_NMAP_IMAGE`
- Pull override: `SHIMMY_NMAP_IMAGE_PULL=always`
- Network override: `SHIMMY_NMAP_NETWORK`
- LAN scan opt-in: `SHIMMY_NMAP_LAN_SCAN=1` sets host networking and adds `NET_RAW` plus `NET_ADMIN`
- Podman privileged opt-in: `SHIMMY_PODMAN_PRIVILEGED=1`
- Rootful connection selector: `SHIMMY_PODMAN_PRIVILEGED_CONNECTION`
- Nmap privileged mode: `SHIMMY_NMAP_PRIVILEGED=1` passes `--privileged`
- Nmap unprivileged mode: `SHIMMY_NMAP_PRIVILEGED=0` passes `--unprivileged`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mount: `$PWD` to `/work`
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

## Change Rules

1. Never make LAN scan, raw socket, rootful connection, or Podman privileged behavior the default.
2. Keep rootless host-discovery guidance explicit for `-sn` and `-sP`; users should opt into privileged Podman only for approved scans.
3. Keep `SHIMMY_NMAP_LAN_SCAN=1` incompatible with non-host `SHIMMY_NMAP_NETWORK` values.
4. Prefer TCP reachability scans such as `nmap -sT -Pn -p PORTS TARGET` when raw LAN discovery is not required.
5. Remember that macOS Podman runs in a VM, so LAN visibility can differ from native host Nmap.
6. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
7. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh nmap --version`
- Opt-in smoke: `SHIMMY_NMAP_LAN_SCAN=1 ./commands/run-tool.sh nmap --version`
- Network smoke: `SHIMMY_NMAP_NETWORK=none ./commands/run-tool.sh nmap --version`
- Rootless guidance tests should fail before execution for host discovery without approved privileged Podman.

## Learning Guidance

- Capture Nmap-specific lessons here when they affect scan modes, rootless Podman behavior, privileged approval wording, macOS LAN visibility, or safe validation commands.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
