---
name: shimmy-tool-nmap
description: Guidance for using, changing, testing, and troubleshooting the Nmap shim in this repository, including LAN scan opt-ins, rootless Podman limits, and privileged escalation safeguards.
---

# Nmap Shim

Use this skill when working with `shims/nmap`, its tests, its docs, or Nmap usage through Shimmy.

## Files

- Runtime shim: `../../../shims/nmap`
- User docs: `../../../docs/shims/nmap.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_MODE=upstream <tool> --version` when validating the upstream profile. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: `docker.io/instrumentisto/nmap:7.98-r2`
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
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Never make LAN scan, raw socket, rootful connection, or Podman privileged behavior the default.
2. Keep rootless host-discovery guidance explicit for `-sn` and `-sP`; users should opt into privileged Podman only for approved scans.
3. Keep `SHIMMY_NMAP_LAN_SCAN=1` incompatible with non-host `SHIMMY_NMAP_NETWORK` values.
4. Prefer TCP reachability scans such as `nmap -sT -Pn -p PORTS TARGET` when raw LAN discovery is not required.
5. Remember that macOS Podman runs in a VM, so LAN visibility can differ from native host Nmap.
6. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
7. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/nmap --version`
- Opt-in smoke: `SHIMMY_NMAP_LAN_SCAN=1 ./shims/nmap --version`
- Network smoke: `SHIMMY_NMAP_NETWORK=none ./shims/nmap --version`
- Rootless guidance tests should fail before execution for host discovery without approved privileged Podman.

## Learning Guidance

- Capture Nmap-specific lessons here when they affect scan modes, rootless Podman behavior, privileged approval wording, macOS LAN visibility, or safe validation commands.
- Promote reusable Shimmy design lessons to `../shimmy-create/SKILL.md` under `Learning Guidance`.
