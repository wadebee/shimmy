# shimmy

Commonly used CLI tools exposed through Podman shims for POSIX-oriented shells.

## Overview

Shimmy wraps popular CLI tools in lightweight Podman containers, providing:
- **No local installations required** — tools run in containers
- **Consistent environments** across different machines and projects
- **Customizable** — override container images via environment variables
- **Transparent usage** — add to PATH and use tools as if they were installed locally

For tools that do not ship a usable upstream container image, Shimmy can build and cache a local image from a checked-in `Containerfile` context. The image tag is derived from the build-context hash and resolved platform, so Podman reuses the cached image until the `Containerfile`, supporting files, or host platform changes.

Shimmy also resolves the container platform at runtime without changing the command a user runs. Linux hosts run containers as `linux/amd64`, while macOS hosts run containers as `linux/arm64`. Explicit `<PREFIX>_IMAGE` overrides still select the image reference, and Shimmy applies the platform selection underneath.

## Contributor Guidance

Contributor guidance lives in `CONTRIBUTING.md`.

That document is the contributor source of truth, including naming conventions for files, functions, and variables. It is also referenced from `AGENTS.md` and the shared project prompt so future AI contributors pick it up automatically.

## Included Shims

| Tool | Purpose | Image Source | Usage |
|------|---------|----------------|-------|
| **aws** | AWS CLI | `public.ecr.aws/aws-cli/aws-cli:2.31.21` | `aws s3 ls`, `aws sts get-caller-identity` |
| **go** | Go toolchain CLI | `docker.io/library/golang:latest` | `go version`, `go test ./...` |
| **jq** | JSON processor | `ghcr.io/jqlang/jq:1.8.1` | `jq .foo file.json` |
| **netcat** | TCP/UDP debugging client | local build from `images/netcat/Containerfile` | `netcat --help`, `netcat example.com 443` |
| **nmap** | Network discovery and security scanner | `docker.io/instrumentisto/nmap:7.98-r2` | `nmap --version`, `nmap scanme.nmap.org` |
| **rg** | Ripgrep search | `docker.io/vszl/ripgrep:latest` | `rg "pattern" .` |
| **task** | Taskfile task runner | local build from `images/task/Containerfile` | `task --version`, `task --list` |
| **terraform** | Infrastructure as Code | `docker.io/hashicorp/terraform:latest` | `terraform plan`, `terraform apply` |
| **textual** | Textual developer CLI | local build from `images/textual/Containerfile` | `textual --help`, `textual run app.py` |

## Requirements

- **POSIX shell** — `/bin/sh` or another POSIX-compatible shell for the current proof-of-concept rewrite
- **Podman CLI** — Explicit required dependency. Podman *Desktop* is not required. 
For macOS run `podman machine init` if needed, then run `podman machine start` from a normal user shell after installation.
Install and configure for rootless operation separately before using Shimmy. Official install guide: <https://podman.io/docs/installation>
If Podman is installed from the macOS pkg installer, the binary may live at `/opt/podman/bin/podman`. `shimmy activate` accounts for that path for interactive shell activation, and Shimmy's shared Podman preflight also checks it directly for runtime shims plus Podman-backed lifecycle commands such as `shimmy update --pull`, `shimmy update --build`, and `shimmy test`.
When Podman is installed but unreachable, Shimmy now fails with shared guidance that points to `podman info`, user-shell `podman machine start`, `podman system connection list`, and `CONTAINER_HOST` verification.

### Podman rootless requirement

Shimmy expects a working rootless Podman engine setup. On some minimal Linux environments, including Chromebook's Crostini, rootless requirements for subordinate id ranges do not exist. In this scenario Podman will warn "no subuid ranges found" and fall back to a single UID/GID mapping.

Check your configuration (should output a range of id values, eg: 10000:65536):
```
grep "^$(whoami):" /etc/subuid /etc/subgid
```

When only a single id is present run this command to correct.
```
- sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $(whoami)
- podman system migrate
```

## Installation Options

### Option: AI Agent Plugin

Shimmy includes a packaged AI Agent plugin under `plugins/shimmy`. The plugin provides Shimmy-specific skills plus the jq and ripgrep tool skills, so an AI Agent can apply the repository's conventions when creating shims, troubleshooting Podman-backed commands, managing Shimmy installs, and working on the jq or rg wrappers.

The primary plugin intentionally does not bundle every tool skill. Optional tool-specific plugins can supplement it later, for example AWS, Terraform, or Go plugins, but the AI Agent plugin manifest used here does not declare plugin dependencies. Install or enable supplemental plugins independently when a workstation or repo needs those capabilities.

This repository also includes `.agents/plugins/marketplace.json`, which registers the local Shimmy plugin from `./plugins/shimmy`.

#### Use the plugin in this repository

Open a new AI Agent session from the Shimmy checkout after the plugin files are present. Agent plugin discovery usually happens at session startup, so an already-running session may not see newly added plugin metadata until it is restarted.

When prompted, install or enable the `shimmy` plugin from the local marketplace. Once enabled, requests that involve Shimmy, jq, or ripgrep shim work can use the packaged skills automatically.

#### Use Shimmy tools from an AI Agent faster

AI Agent approvals are often evaluated on the outer command. If `podman info` succeeds but a Shimmy wrapper still reports that Podman is unreachable, approve the exact wrapper prefix that the AI Agent is trying to run, such as `["rg"]` for an activated shim or `["./shims/rg"]` for a repo-local shim. Approval for `["podman", "info"]` only verifies the engine; it does not approve nested Podman access through a wrapper.

From a fresh AI Agent session, run the non-mutating preflight to list the exact approval prefixes and smoke commands:

```sh
./scripts/agent-shimmy-preflight.sh
```

The script checks `podman info`, discovers active installed shims and repo-local shims, and prints harmless `--version` or `--help` commands to approve with your AI Agent's approval mechanism and the listed `agent_prefix_rule` values. Use `--smoke` from a normal shell when you want the script to run those checks directly.

#### Use the plugin from other local repositories

For one workstation-wide setup, copy or sync the packaged plugin into your home plugin directory and register it in your home marketplace:

```text
~/plugins/shimmy/
~/.agents/plugins/marketplace.json
```

The home marketplace entry should point at `./plugins/shimmy`:

```json
{
  "name": "shimmy-local",
  "interface": {
    "displayName": "Shimmy Local"
  },
  "plugins": [
    {
      "name": "shimmy",
      "source": {
        "source": "local",
        "path": "./plugins/shimmy"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    }
  ]
}
```

After that, start a new AI Agent session in any repository on that workstation and install or enable the Shimmy plugin from the local marketplace.

#### Use the plugin on another workstation

Clone or copy this repository, then use the packaged plugin directory from `plugins/shimmy`. For a repo-local setup, open the AI Agent from the Shimmy checkout so it can read `.agents/plugins/marketplace.json`. For a workstation-wide setup, copy `plugins/shimmy` to `~/plugins/shimmy` on the target machine and add the home marketplace entry shown above.

Linux and macOS can use the same plugin layout. Shimmy itself still requires a POSIX shell and a working rootless Podman installation. On macOS, start the Podman machine from a normal user shell before using Podman-backed Shimmy tools:

```sh
podman machine start
podman info
```

On Windows, use WSL or another POSIX-compatible environment for Shimmy workflows. On Chromebooks, use Crostini and a bash shell.

Put the plugin and marketplace files in the Linux home directory used by the AI Agent in that environment, for example `/home/<user>/plugins/shimmy` and `/home/<user>/.agents/plugins/marketplace.json`. Configure Podman inside that same environment before running Shimmy-backed tools.

### Option: Shimmy wrapper workflow

Use the repo-root `shimmy` wrapper as the primary control surface:

```sh
./shimmy install
./shimmy status
./shimmy update --pull --build
./shimmy test
./shimmy uninstall
```

The wrapper delegates to script-based interfaces in `scripts/`.

After `./shimmy install`, activate the installed Shimmy paths in the current shell immediately with:

```sh
eval "$(./shimmy activate)"
```

`./shimmy install` writes one activation file under the install root and updates your shell startup file by default so future shells can source it. It cannot change your current shell session, so use `eval "$(./shimmy activate)"` to make the install available immediately.

The installed activation file is:

```sh
~/.config/shimmy/activate.sh
```

Startup files contain only a small managed block that sources that activation file. This keeps the PATH logic in one place even when multiple startup files need to load Shimmy.

Supported startup shells:

| Shell | Startup files updated by default |
| --- | --- |
| `bash` | `~/.bashrc` and the first existing login file from `~/.bash_profile`, `~/.bash_login`, or `~/.profile`; creates `~/.bash_profile` if none exist |
| `zsh` | `~/.zshrc` |
| `sh` | `~/.profile` |
| `ksh` | `~/.profile` |
| `mksh` | `~/.profile` |

You can override or skip that behavior:

```sh
./shimmy install --shell zsh
./shimmy install --startup-file "$HOME/.config/shimmy/profile"
./shimmy install --no-startup
```

You can repeat `--startup-file` when more than one startup file should source Shimmy. Shimmy writes one managed startup block per startup file, so rerunning install refreshes those blocks idempotently instead of appending duplicates.

If you prefer not to modify your startup files, use `--no-startup` and add activation logic manually.

```sh
./shimmy install --no-startup
eval "$(./shimmy activate)"
```

If your startup file ever needs to be rewritten or repaired later, use update:

```sh
./shimmy update --repair-startup
./shimmy update --repair-startup --shell zsh
./shimmy update --repair-startup --startup-file "$HOME/.config/shimmy/profile"
```

Without `--repair-startup`, `update` refreshes installed assets only and leaves startup files alone.

The active install layout is always derived from one install root, which defaults to `~/.config/shimmy` and can be overridden with `--install-dir`.

Common install arguments still pass through to the installer:

```sh
./shimmy install --install-dir "$HOME/.local/share/shimmy"
./shimmy install --shim aws --shim terraform
```

#### Option: Direct script workflow

Use the underlying scripts directly when you want the lower-level interfaces explicitly:

```sh
sh ./scripts/install-shimmy.sh
sh ./scripts/status-shimmy.sh
sh ./scripts/update-shimmy.sh --pull --build
sh ./scripts/test-shimmy.sh
sh ./scripts/install-shimmy.sh --uninstall
```

This is the same functionality the wrapper exposes, without the repo-root dispatcher.

### Install manifest and lifecycle state

Shimmy stores install state in one POSIX-readable manifest under the install root:

```sh
~/.config/shimmy/install-manifest.txt
```

The manifest is the source of truth for activation, status, update, startup-file repair, and uninstall. It uses one `key=value` entry per line and repeated keys for lists.

Core fields include:
- `install_dir` — active install root
- `activate_file` — generated activation script
- `startup_shell` — shell used for managed startup-file selection
- `startup_file` — managed startup file; repeated when more than one file is updated
- `shim` — installed shim name; repeated for each installed tool

Shimmy also reserves `shimmy_*` fields for lifecycle metadata such as the installed source URL/ref, update policy, last update check, previous ref, and validation status. Install and update preserve unknown `shimmy_*` fields so agent-driven lifecycle metadata is not lost during normal refreshes.

For machine-readable inspection, use:

```sh
./shimmy status --format manifest
```

The current implementation can reinstall from the checked-out source, refresh remote images with `--pull`, rebuild local images with `--build`, repair startup files, and preserve lifecycle metadata. Full latest-version resolution, semver enforcement such as `>=0.10.0`, and rollback to release versions require a release/tag/version convention for Shimmy itself.

## Usage

Once shims are in your PATH, use tools naturally:

```sh
# Terraform
terraform version
terraform -chdir=examples/dev plan

# AWS CLI
aws s3 ls
aws sts get-caller-identity

# Go CLI
go version
go test ./...

# jq
echo '{"name": "shimmy"}' | jq .name

# ripgrep
rg "pattern" .

# Task
task --version
task --list

# Textual CLI
textual --help
textual run app.py
```

## Configuration

Each shim respects environment variables for customization.

### AWS CLI

- `AWS_IMAGE` — Container image (default: `public.ecr.aws/aws-cli/aws-cli:2.31.21`)
- `AWS_IMAGE_PULL` — Set to `always` to force pulling the latest image

Example:

```sh
AWS_IMAGE=public.ecr.aws/aws-cli/aws-cli:2.31.21 aws --version
```

**Mounts:**
- `$PWD` → `/work` (read-write)
- `~/.aws` → `/root/.aws` (read-only, if exists)

**Environment variables forwarded:**
- `AWS_*`

**Runtime platform:**
- Linux → `linux/amd64`
- macOS → `linux/arm64`

### Go CLI

- `GO_IMAGE` — Container image (default: `docker.io/library/golang:latest`)
- `GO_IMAGE_PULL` — Set to `always` to force pulling the latest image

Example:

```sh
GO_IMAGE=docker.io/library/golang:latest go version
```

**Mounts:**
- `$PWD` → `/work` (read-write)

**Container I/O:**
- Keeps stdin open without allocating a container TTY, which avoids Podman terminal resize signal warnings for short-lived commands such as `go help test`.

**Runtime platform:**
- Linux → `linux/amd64`
- macOS → `linux/arm64`

### jq

- `JQ_IMAGE` — Container image (default: `ghcr.io/jqlang/jq:1.8.1`)
- `JQ_IMAGE_PULL` — Set to `always` to force pulling the configured image

Example:

```sh
JQ_IMAGE=ghcr.io/jqlang/jq:1.8.1 jq --version
```

**Mounts:**
- `$PWD` → `/work` (read-write)

**Runtime platform:**
- Linux → `linux/amd64`
- macOS → `linux/arm64`

### Netcat

- `NETCAT_IMAGE` — Override the runtime image entirely
- `NETCAT_IMAGE_BUILD` — Set to `always` to rebuild the local Netcat image even if it is already cached
- `NETCAT_IMAGE_PULL` — Set to `always` to force pulling `NETCAT_IMAGE` when using an explicit remote override
- `NETCAT_BASE_IMAGE` — Override the `Containerfile` base image (default build arg: `registry.access.redhat.com/ubi9/ubi-minimal:latest`)

Example:

```sh
NETCAT_BASE_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal:latest netcat --help
```

The default Netcat image is built locally from `images/netcat/Containerfile`, which starts from UBI 9 minimal and installs the `nmap-ncat` package. This keeps the base image small while still using a practical Red Hat-supported package manager for the install. Shimmy tags the resulting image under `localhost/shimmy-netcat:<context-hash>-<platform>` so Podman keeps a reusable local cache and automatically rebuilds when the build context or runtime platform changes.

**Mounts:**
- `$PWD` → `/work` (read-write)

**Runtime platform:**
- Linux → `linux/amd64`
- macOS → `linux/arm64`

### Nmap

- `NMAP_IMAGE` — Container image (default: `docker.io/instrumentisto/nmap:7.98-r2`)
- `NMAP_IMAGE_PULL` — Set to `always` to force pulling the configured image
- `SHIMMY_NMAP_NETWORK` — Pass a Podman network to the container with `--network <value>`, for example a user-defined network that contains app containers
- `SHIMMY_NMAP_LAN_SCAN` — Set to `1` to opt into local-network scan support with `--network host`, `--cap-add NET_RAW`, and `--cap-add NET_ADMIN`
- `SHIMMY_NMAP_PRIVILEGED` — Set to `1` to add `--privileged`; use only as a last-resort opt-in, usually together with `SHIMMY_NMAP_LAN_SCAN=1`

Example:

```sh
NMAP_IMAGE=docker.io/instrumentisto/nmap:7.98-r2 nmap --version
SHIMMY_NMAP_NETWORK=appnet nmap -sT -Pn api
SHIMMY_NMAP_LAN_SCAN=1 nmap -sn 192.168.1.0/24
SHIMMY_NMAP_LAN_SCAN=1 SHIMMY_NMAP_PRIVILEGED=1 nmap -sn 192.168.1.0/24
```

The default Nmap image is an Instrumentisto-maintained image pinned to an explicit Nmap release tag. The shim does not add privileged mode, host networking, or extra Linux capabilities by default, so containerized scan behavior can differ from a host-installed `nmap` for scan modes that need raw socket, interface, or host network access.

`SHIMMY_NMAP_NETWORK` is useful when scanning other containers attached to a user-defined Podman network. It is a Shimmy wrapper control, not an `nmap` environment variable. `SHIMMY_NMAP_LAN_SCAN=1` is the explicit opt-in for local subnet discovery and adds host networking plus raw/network capabilities. `SHIMMY_NMAP_PRIVILEGED=1` is a stronger opt-in that adds `--privileged`; combine it with `SHIMMY_NMAP_LAN_SCAN=1` only when the capability-based LAN mode is not enough.

On macOS, Podman containers run inside a Linux VM. In that environment, `--network host` means the Podman VM's host network namespace, not the macOS host's physical LAN interface. LAN discovery from the shim may still be incomplete compared with native host `nmap`.

**Mounts:**
- `$PWD` → `/work` (read-write)

**Runtime platform:**
- Linux → `linux/amd64`
- macOS → `linux/arm64`

### ripgrep

- `RG_IMAGE` — Container image (default: `docker.io/vszl/ripgrep:latest`)
- `RG_IMAGE_PULL` — Set to `always` to force pulling the latest image

Example:

```sh
RG_IMAGE=docker.io/vszl/ripgrep:latest rg --version
```

**Mounts:**
- `$PWD` → `/work` (read-write)

**Runtime platform:**
- Linux → `linux/amd64`
- macOS → `linux/arm64`

### Task

- `TASK_IMAGE` — Override the runtime image entirely
- `TASK_IMAGE_BUILD` — Set to `always` to rebuild the local Task image even if it is already cached
- `TASK_IMAGE_PULL` — Set to `always` to force pulling `TASK_IMAGE` when using an explicit remote override
- `TASK_BASE_IMAGE` — Override the `Containerfile` base image (default build arg: `alpine:3.22`)
- `TASK_VERSION` — Override the Task release version installed into the local image (default build arg: `v3.45.5`)

Example:

```sh
TASK_VERSION=v3.45.5 task --version
```

The default Task image is built locally from `images/task/Containerfile`, which starts from Alpine and installs the official Task release binary from GitHub Releases. Shimmy tags the resulting image under `localhost/shimmy-task:<context-hash>-<platform>` so Podman keeps a reusable local cache and automatically rebuilds when the build context or runtime platform changes.

**Mounts:**
- `$PWD` → `$PWD` (read-write)
- `$PWD` → `/work` (read-write)
- `$HOME` → `$HOME` (read-write, if it exists)
- `/tmp` → `/tmp` (read-write, if it exists)

When `CONTAINER_HOST` points at a unix-domain Podman socket, the task shim also forwards that socket into the container so Task-driven automation can launch other shims.

**Environment variables forwarded:**
- `CONTAINER_HOST` when explicitly set
- `SHIMMY_HOST_PATH`
- `HOME` when the home directory mount is enabled

**Runtime platform:**
- Linux → `linux/amd64`
- macOS → `linux/arm64`

### Terraform

- `TF_IMAGE` — Container image (default: `docker.io/hashicorp/terraform:latest`)
- `TF_IMAGE_PULL` — Set to `always` to force pulling the latest image

Example:

```sh
TF_IMAGE=docker.io/hashicorp/terraform:latest
TF_IMAGE_PULL=always
terraform version
terraform plan
```

**Mounts:**
- `$PWD` → `/work` (read-write)
- `~/.aws` → `/root/.aws` (read-only, if exists)
- `~/.terraform.d/plugin-cache` → `/root/.terraform.d/plugin-cache` (if exists)

**Environment variables forwarded:**
- `AWS_*`
- `TF_VAR_*`

**Runtime platform:**
- Linux → `linux/amd64`
- macOS → `linux/arm64`

### Textual CLI

- `TEXTUAL_IMAGE` — Override the runtime image entirely
- `TEXTUAL_IMAGE_BUILD` — Set to `always` to rebuild the local Textual image even if it is already cached
- `TEXTUAL_IMAGE_PULL` — Set to `always` to force pulling `TEXTUAL_IMAGE` when using an explicit remote override
- `TEXTUAL_BASE_IMAGE` — Override the `Containerfile` base image (default build arg: `python:3.13-slim-bookworm`)

Example:

```sh
TEXTUAL_BASE_IMAGE=python:3.13-slim-bookworm textual --help
```

The default Textual image is built locally from `images/textual/Containerfile`, which starts from `python:3.13-slim-bookworm` and installs `textual` plus `textual-dev`. This matches the official Textual docs, where the `textual` command comes from the developer tools package. Shimmy tags the resulting image under `localhost/shimmy-textual:<context-hash>-<platform>` so Podman keeps a reusable local cache and automatically rebuilds when the build context or runtime platform changes.

**Mounts:**
- `$PWD` → `/work` (read-write)

**Runtime platform:**
- Linux → `linux/amd64`
- macOS → `linux/arm64`

The interactive shims (`aws`, `task`, `terraform`, and `textual`) request `-it` only when both stdin and stdout are attached to a terminal, so version and help commands still work cleanly in scripts and smoke tests.

## Testing

Run the test suite to validate that shim containers run via Podman:

```sh
./shimmy test
# or
sh ./scripts/test-shimmy.sh
```

Tests verify:
- `/bin/sh` parser compatibility for the repo wrapper, shared shim helpers, repo lifecycle scripts, and all supported in-scope shims
- install, activate, status, machine-readable manifest output, update, startup-file repair, and uninstall behavior for the single-root manifest layout
- live Podman execution for the supported shim set: `aws`, `jq`, `netcat`, `rg`, `task`, `terraform`, and `textual`

## Directory Structure
```
shimmy/
├── shimmy                    # Repo-root wrapper command
├── shims/                    # OCI wrapper scripts
│   ├── aws
│   ├── jq
│   ├── netcat
│   ├── rg
│   ├── task
│   ├── textual
│   └── terraform
├── images/                   # Custom shim image build contexts
│   ├── netcat
│   ├── task
│   └── textual
├── lib/
│   ├── repo/                 # Repo-only sourced helpers for wrapper/scripts
│   └── shims/                # Installed shared helper scripts for shims
├── scripts/
│   ├── agent-shimmy-preflight.sh # AI Agent approval preflight
│   ├── install-shimmy.sh     # Installation script
│   ├── status-shimmy.sh      # Status script
│   ├── test-shimmy.sh        # Test suite
│   └── update-shimmy.sh      # Update script
├── plugins/
│   └── shimmy/               # Packaged AI Agent plugin for Shimmy skills
├── .agents/
│   ├── plugins/              # Local AI Agent plugin marketplace metadata
│   └── skills/               # Repo-local agent skills used while developing Shimmy
├── .pre-commit-config.yaml   # Git https://github.com/pre-commit/pre-commit-hooks
├── .github/
│   └── workflows/
│       └── test.yml          # CI/CD workflow
└── README.md                 # This file
```

## AI Generation 
This code was ![AI-developed](https://img.shields.io/badge/AI-Generated-blue) and human-reviewed/curated with AI Agent assistance.

## License

See LICENSE file for details.
