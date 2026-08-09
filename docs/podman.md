# Podman for Shimmy

Shimmy is built on Podman. Every runtime shim is a small shell wrapper that
starts a container with `podman run`, so a working Podman install is a
foundational requirement, not an optional accelerator.

Shimmy does not install or provision Podman for you. Install Podman with your
operating system's package manager or the official installer, then verify that
the `podman` CLI can talk to the engine from the same shell where you will run
Shimmy.

Official Podman installation guide: <https://podman.io/docs/installation>

## Quick Start

1. Install Podman.

2. Verify the CLI is on `PATH`:

   ```sh
   podman --version
   ```

3. On macOS, initialize and start the Podman machine if needed:

   ```sh
   podman machine init
   podman machine start
   ```

4. Verify that the engine is reachable:

   ```sh
   podman info

   ```
   If `podman info` fails, fix Podman before troubleshooting Shimmy. Shimmy wrappers
   cannot work until Podman can start containers from your user shell.

5. Run a lightweight container smoke check:

   ```sh
   podman run --rm quay.io/podman/hello
   ```

6. Install or activate Shimmy, then run a shim smoke check:

   ```sh
   ./install.sh
   eval "$("${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/bin/shimmy" activate)"
   jq --version
   rg --version
   ```

## What Podman Does For Shimmy

Shimmy exposes command-line tools as if they were installed locally, but the
tools actually run in containers. That gives Shimmy its main value:

- Tools do not need separate local installs.
- Tool versions and runtime dependencies are isolated from the workstation.
- Project directories can be mounted into short-lived tool containers.
- Users can override container images with `SHIMMY_{TOOL_PREFIX}_IMAGE`.

For tools that do not ship a usable upstream image, Shimmy can build and cache a
local image from a checked-in `Containerfile` context. The local image tag is
derived from the build-context hash and resolved platform, so Podman reuses the
cached image until the context or platform changes.

Shimmy also resolves the container platform at runtime. Linux hosts run
containers as `linux/amd64`; macOS hosts run containers as `linux/arm64`.

Podman Desktop is not required. Shimmy needs the Podman CLI and an engine the
CLI can reach.

## Linux Setup

Most Linux distributions package Podman directly. Install Podman with your OS
package manager, then verify:

```sh
podman --version
podman info
```

Shimmy expects a working rootless Podman setup for normal tool execution. In
rootless mode, containers run as your user instead of requiring a root-owned
daemon.

### Rootless ID Ranges

Some minimal Linux environments, including Chromebook Crostini, may not have
subordinate UID/GID ranges configured. Podman can warn with text like `no subuid
ranges found` and fall back to a single UID/GID mapping. That can work for some
containers, but it is not the best baseline for Shimmy.

Check the current user's ranges:

```sh
grep "^$(whoami):" /etc/subuid /etc/subgid
```

A healthy setup usually shows ranges similar to:

```text
/etc/subuid:current-user:100000:65536
/etc/subgid:current-user:100000:65536
```

If no range exists, add one and migrate Podman state:

```sh
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$(whoami)"
podman system migrate
```

Log out and back in if your distribution requires a new login session for the
updated user mapping.

### Storage Performance

Shimmy starts many short-lived containers, so Podman's storage driver matters.
The best baseline is `overlay` storage. While `vfs` provides a "lowest common denominator" of compatibility it also makes working with container images noticeably slower because of the inherent disk-heavy copying of filesystem data instead of using overlay layers.

On Linux rootless Podman, many distros use `fuse-overlayfs` which works well when native rootless kernel overlay support is unavailable or not configured.

On macOS, Podman runs inside a Linux VM. The default high-performance
`overlay` storage backed by the VM's Linux filesystem is `xfs`. It is
better than a userspace `fuse-overlayfs` path and does not require extra
Shimmy-specific tuning.

Check the active storage driver:

```sh
podman info --format '{{.Store.GraphDriverName}}'
```

If this reports `vfs` on Linux, consider reconfiguring it to use `fuse-overlayfs`.
Changing your existing Podman storage driver requires a `podman system reset`, which removes local Podman containers, images, pods, and **volumes** for that user. 

**Data Loss Alert**: Treat this as you would any system reset. If you have been running podman for awhile and have existing container services and volumes - be sure to back them up! 

## macOS Setup

On macOS, Podman runs Linux containers inside a small virtual machine. Install
Podman with the official installer or another trusted package source, then run
the setup commands from a normal user shell:

```sh
podman machine init
podman machine start
podman info
```

If the machine already exists, `podman machine init` may report that and no
longer be needed. The important check is that `podman info` succeeds.

The official macOS pkg installer may place the binary at:

```text
/opt/podman/bin/podman
```

Shimmy accounts for that path during activation and runtime preflight checks.
If you are running Podman manually and `podman` is not found, either add
`/opt/podman/bin` to `PATH` or call `/opt/podman/bin/podman` directly while you
repair your shell setup.

Useful macOS checks:

```sh
podman machine list
podman system connection list
```

When Podman is unreachable on macOS, the usual fix is:

```sh
podman machine start
```

Run that in the same normal user environment where you intend to use Shimmy.

## Verification Checks

Use these checks after installing Podman, after major OS changes, or when Shimmy
wrappers feel slow or unreliable.

Confirm the binary and engine:

```sh
podman --version
podman info
```

Confirm storage driver on Linux:

```sh
podman info --format '{{.Store.GraphDriverName}}'
```

Confirm rootless mode:

```sh
podman info --format '{{.Host.Security.Rootless}}'
```

Confirm the default connection, especially on macOS or remote Podman setups:

```sh
podman system connection list
```

Run a harmless container:

```sh
podman run --rm quay.io/podman/hello
```

Run Shimmy's own status and smoke checks:

```sh
shimmy status
shimmy test
```

From a source checkout, run the repository suite directly:

```sh
./tests/test.sh
```

For maintainer testing through the upstream profile, install and activate that profile first:

```sh
./install.sh --profile upstream
eval "$("${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/bin/shimmy" activate)"
shimmy status
shimmy test
rg --version
```

The bootstrap chooses a profile; installed commands manage only the profile
whose `bin/shimmy` launcher invoked them. The `upstream` profile is
manual-activation-only and never manages persistent shell startup files.

`shimmy test` uses live Podman execution for supported kinds. It is a stronger
check than `podman info` because it verifies that Shimmy's wrappers can actually
start the tool containers.

## Troubleshooting

### `podman` is missing

Shimmy reports a missing Podman dependency when it cannot find the CLI. Install
Podman, then ensure `podman` is available on `PATH`.

On macOS, also check:

```sh
ls /opt/podman/bin/podman
```

Shimmy checks that path directly, but adding `/opt/podman/bin` to your shell
`PATH` still makes manual Podman debugging easier.

### `podman info` fails

If the binary exists but the engine is unreachable, Shimmy cannot start tool
containers. Run:

```sh
podman info
podman system connection list
```

On macOS, start the VM:

```sh
podman machine start
```

If you use `CONTAINER_HOST`, verify that it points at a reachable Podman service
or unset it to use the default connection:

```sh
printf '%s\n' "$CONTAINER_HOST"
unset CONTAINER_HOST
podman info
```

### Shimmy fails but `podman info` works

First run a simple Shimmy smoke check:

```sh
jq --version
rg --version
```

From a source checkout:

```sh
./commands/run-tool.sh jq --version
./commands/run-tool.sh rg --version
```

In AI Agent environments, command approvals are often evaluated on the outer
command. Approving `podman info` only proves the engine works; it may not
approve nested Podman access through a Shimmy wrapper. Approve the exact dry-run
shim command prefix the agent needs, such as `["rg","--version"]` for an
activated shim or `["./commands/run-tool.sh","rg","--version"]` for a repo-local runtime.

The source checkout includes a preflight helper that prints useful approval
prefixes and smoke commands:

```sh
./commands/agent-preflight.sh
```

Use `--smoke` from a normal shell when you want the script to run those checks
directly.

### Linux rootless warnings

If Podman warns about missing subuid or subgid ranges, review the Linux rootless
ID range section above. After changing ranges, `podman system migrate` usually
updates Podman state for the new mapping.

### Slow image startup or high disk usage

Check whether Podman is using `vfs` instead of `overlay`:

```sh
podman info --format '{{.Store.GraphDriverName}}'
```

Prefer `overlay` for normal Shimmy usage. On macOS, `overlay` backed by the
Podman VM's `xfs` filesystem is a good default. On Linux rootless systems,
`fuse-overlayfs` may be the right support package for a working `overlay`
configuration.

Also inspect image usage:

```sh
podman images
podman system df
```

If old images dominate disk usage, see the hygiene section below.

### Networking looks different inside a shim

Containers do not always share the same network view as the host shell. This is
especially visible on macOS, where Podman containers run inside a Linux VM, and
in Chromebook Crostini or other VM-heavy environments.

Use Shimmy's local network perspective command before assuming a container sees
the same LAN as the host:

```sh
shimmy netinfo
```

For network-oriented shims, also see [network-tools.md](network-tools.md).

## Basic Podman Hygiene

Podman keeps downloaded images, locally built images, stopped containers,
volumes, and build cache under your user's Podman storage. That cache is useful:
it makes repeated Shimmy commands faster. It can also grow over time as images
are updated, local image builds change, and short-lived containers come and go.

A good maintenance habit is to inspect first, prune conservative categories
periodically, and reserve broad cleanup for cases where disk usage is clearly
out of hand.

Useful inspection commands:

```sh
podman ps --all
podman images
podman system df
```

Stopped containers are usually safe to remove when you do not need their logs or
filesystem state:

```sh
podman container prune
```

Dangling or unused images are a normal source of growth after image updates and
local rebuilds:

```sh
podman image prune
```

For a broader cleanup, remove unused containers, networks, dangling images, and
build cache:

```sh
podman system prune
```

Use more aggressive image cleanup only when you understand that older images may
need to be pulled or rebuilt later:

```sh
podman system prune --all
```

Avoid `podman system reset` as routine hygiene. It removes all containers,
images, pods, and volumes for the current user and is better treated as a last
resort or an intentional rebuild of local Podman state.

After pruning images, the next Shimmy command may need to pull or rebuild the
tool image. That is expected.
