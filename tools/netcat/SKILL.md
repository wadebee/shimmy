---
name: shimmy-tool-netcat
description: Guidance for using, changing, testing, and troubleshooting the Netcat/Ncat shim in this repository, including local image build behavior and network debugging safety.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Netcat Shim

Use this skill when working with the Netcat tool, its local image, its tests, its docs, or Netcat/Ncat usage through Shimmy.

## AI Agent Evidence Order

1. If the installed wrapper's safe outer-command prefix is already approved,
   run the actual requested operation with escalation on the first attempt. Do
   not first run a sandboxed Podman call or a version smoke.
2. Treat a sandbox-only unreachable, unknown, socket-denied, or
   `operation not permitted` result as `unverified from the sandbox`, not as an
   inactive profile. Retry the same wrapper operation through
   `shimmy-escalation` before profile inspection or fallback.
3. Use `shimmy-init` only if the escalated wrapper still proves a
   profile-affinity, engine, connection, or registry-projection failure. Never
   activate a profile automatically from sandbox-only evidence.
4. Approval scope: require the exact Netcat mode, target, ports, and arguments.
   Do not persist a broad prefix because Netcat can connect, listen, transfer
   data, and expose services over the network.

## Files

- Tool metadata: `tools/netcat/tool.conf`
- Concrete runtime: `tools/netcat/versions/7.92/run.sh`
- User guide: `tools/netcat/guide.md`
- Tests: `tools/netcat/tests/netcat.sh`
- Image context: `tools/netcat/versions/7.92/container/Containerfile`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `netcat` normally
and inspect the invoking profile with `shimmy profile status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate <name> --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate <name>` command. Running containers
require separate explicit confirmation before adding `--stop-running`. A missing
machine must be provisioned by the user in a normal shell with the exact
`podman machine init shimmy-<profile>` guidance; agents never run direct Podman
machine lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To inspect a named profile, use its
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>`.

For source validation, use `./commands/run-tool.sh netcat --preview-shim --help`
or the concrete `tools/netcat/versions/7.92/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: locally built `localhost/shimmy-netcat-7_92:<image-input-hash>-<platform>` from version-owned `image.conf` and `container/`
- Image override: `SHIMMY_NETCAT_IMAGE`
- Build override: `SHIMMY_NETCAT_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_NETCAT_IMAGE_PULL=always`
- Base image override: `SHIMMY_NETCAT_BASE_IMAGE`
- Default base image: `registry.access.redhat.com/ubi9/ubi-minimal@sha256:dd334afa72444fa46238fcf9e6bd399245adf746378735348cf84b9dfdca38f1`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work:rw`
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

## Change Rules

1. Keep package installation inside `tools/netcat/versions/7.92/container/Containerfile`, not the tool dispatcher.
2. Use `SHIMMY_NETCAT_IMAGE` only as a full runtime image override; local build args apply only to Shimmy-built images.
3. Keep `SHIMMY_NETCAT_IMAGE_PULL=always` scoped to external image overrides.
4. Treat network probes as potentially environment-specific. Prefer `netcat --help` for routine validation.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, local image, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh netcat --help`
- Local build validation may pull or build images; use it only when the task changes image behavior.

## Learning Guidance

- Capture Netcat-specific lessons here when they affect local image builds, base image choice, network probe behavior, stdin, or ncat package behavior.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
