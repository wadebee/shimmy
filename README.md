# shimmy

Commonly used CLI tools exposed through Podman shims for POSIX-oriented shells.

## Overview

Shimmy wraps popular CLI tools in lightweight Podman containers, providing:
- **No local installations required** — tools run in containers
- **Consistent environments** across different machines and projects
- **Customizable** — override container images via environment variables
- **Transparent usage** — add to PATH and use tools as if they were installed locally

For tools that do not ship a usable upstream container image, Shimmy can build and cache a local image from a checked-in `Containerfile` context. The image tag is derived from the build-context hash, so Podman reuses the cached image until the `Containerfile` or its supporting files change.

## Contributor Guidance

Contributor guidance lives in `CONTRIBUTING.md`.

That document is the contributor source of truth, including naming conventions for files, functions, and variables. It is also referenced from `AGENTS.md` and the shared project prompt so future AI contributors pick it up automatically.

## Included Shims

| Tool | Purpose | Default Image | Usage |
|------|---------|----------------|-------|
| **aws** | AWS CLI | `public.ecr.aws/aws-cli/aws-cli:2.31.21` | `aws s3 ls`, `aws sts get-caller-identity` |
| **jq** | JSON processor | `docker.io/stedolan/jq:latest` | `jq .foo file.json` |
| **netcat** | TCP/UDP debugging client | local build from `images/netcat/Containerfile` | `netcat --help`, `netcat example.com 443` |
| **rg** | Ripgrep search | `docker.io/vszl/ripgrep:latest` | `rg "pattern" .` |
| **task** | Taskfile task runner | local build from `images/task/Containerfile` | `task --version`, `task --list` |
| **terraform** | Infrastructure as Code | `docker.io/hashicorp/terraform:latest` | `terraform plan`, `terraform apply` |
| **textual** | Textual developer CLI | local build from `images/textual/Containerfile` | `textual --help`, `textual run app.py` |
| **tessl** | Tessl CLI | local build from `images/tessl/Containerfile` | `tessl --help`, `tessl init` |

## Requirements

- **POSIX shell** — `/bin/sh` or another POSIX-compatible shell for the current proof-of-concept rewrite
- **Podman CLI** — Explicit required dependency. Podman *Desktop* is not required. 
For macOS run `podman machine init` and `podman machine start` after installation.
Install and configure for rootless operation separately before using Shimmy. Official install guide: <https://podman.io/docs/installation>
If Podman is installed from the macOS pkg installer, the binary may live at `/opt/podman/bin/podman`. The current proof-of-concept rewrite accounts for that path, but it is still best to make `/opt/podman/bin` available on `PATH` for shells and automation.

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

## Installation

### Option 1: Shimmy wrapper workflow

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
eval "$(./shimmy shellenv)"
```

The current POSIX proof-of-concept installer does not edit shell rc files. Use `eval "$(./shimmy shellenv)"` for immediate activation, and add that line to your preferred shell config manually if you want persistent activation.

Shimmy treats `SHIMMY_INSTALL_DIR`, `SHIMMY_SHIM_DIR`, `SHIMMY_IMAGES_DIR`, and `SHIMMY_SHIM_LIB_DIR` as the authoritative install paths when they are exported, so installs can keep metadata, shims, local image contexts, and shared shim helper libraries in separate locations without assuming they all live under one hard-coded root.

Common install arguments still pass through to the installer:

```sh
./shimmy install --symlink
./shimmy install --install-dir "$HOME/.local/share/shimmy"
./shimmy install --shim aws --shim terraform
```

### Option 2: Direct script workflow

Use the underlying scripts directly when you want the lower-level interfaces explicitly:

```sh
sh ./scripts/install-shimmy.sh
sh ./scripts/status-shimmy.sh
sh ./scripts/update-shimmy.sh --pull --build
sh ./scripts/test-shimmy.sh
sh ./scripts/install-shimmy.sh --uninstall
```

This is the same functionality the wrapper exposes, without the repo-root dispatcher.

## Usage

Once shims are in your PATH, use tools naturally:

```sh
# Terraform
terraform version
terraform -chdir=examples/dev plan

# AWS CLI
aws s3 ls
aws sts get-caller-identity

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

# Tessl CLI
tessl --help
tessl init --agent codex
```

## Configuration

Each shim respects environment variables for customization:

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
- `$PWD` → `$PWD` (read-write)
- `$PWD` → `/work` (read-write compatibility alias)
- `$HOME` → `$HOME` (read-write, if it exists)
- `/tmp` → `/tmp` (read-write)

When `CONTAINER_HOST` points at a unix-domain Podman socket, the task shim also forwards that socket into the container so Task-driven automation can launch other shims.
- `~/.aws` → `/root/.aws` (read-only, if exists)
- `~/.terraform.d/plugin-cache` → `/root/.terraform.d/plugin-cache` (if exists)

**Environment variables forwarded:**
- `AWS_*`
- `TF_VAR_*`

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

### jq

- `JQ_IMAGE` — Container image (default: `docker.io/stedolan/jq:latest`)
- `JQ_IMAGE_PULL` — Set to `always` to force pulling the latest image

Example:

```sh
JQ_IMAGE=ghcr.io/jqlang/jq:latest jq --version
```

**Mounts:**
- `$PWD` → `/work` (read-write)

### Netcat

- `NETCAT_IMAGE` — Override the runtime image entirely
- `NETCAT_IMAGE_BUILD` — Set to `always` to rebuild the local Netcat image even if it is already cached
- `NETCAT_IMAGE_PULL` — Set to `always` to force pulling `NETCAT_IMAGE` when using an explicit remote override
- `NETCAT_BASE_IMAGE` — Override the `Containerfile` base image (default build arg: `registry.access.redhat.com/ubi9/ubi-minimal:latest`)

Example:

```sh
NETCAT_BASE_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal:latest netcat --help
```

The default Netcat image is built locally from `images/netcat/Containerfile`, which starts from UBI 9 minimal and installs the `nmap-ncat` package. This keeps the base image small while still using a practical Red Hat-supported package manager for the install. Shimmy tags the resulting image under `localhost/shimmy-netcat:<context-hash>` so Podman keeps a reusable local cache and automatically rebuilds when the build context changes.

**Mounts:**
- `$PWD` → `/work` (read-write)

### ripgrep

- `RG_IMAGE` — Container image (default: `docker.io/vszl/ripgrep:latest`)
- `RG_IMAGE_PULL` — Set to `always` to force pulling the latest image

Example:

```sh
RG_IMAGE=docker.io/vszl/ripgrep:latest rg --version
```

**Mounts:**
- `$PWD` → `/work` (read-write)

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

The default Task image is built locally from `images/task/Containerfile`, which starts from Alpine and installs the official Task release binary from GitHub Releases. Shimmy tags the resulting image under `localhost/shimmy-task:<context-hash>` so Podman keeps a reusable local cache and automatically rebuilds when the build context changes.

**Mounts:**
- `$PWD` → `/work` (read-write)

### Tessl CLI

- `TESSL_IMAGE` — Override the runtime image entirely
- `TESSL_IMAGE_BUILD` — Set to `always` to rebuild the local Tessl image even if it is already cached
- `TESSL_IMAGE_PULL` — Set to `always` to force pulling `TESSL_IMAGE` when using an explicit remote override
- `TESSL_BASE_IMAGE` — Override the `Containerfile` base image (default build arg: `dhi.io/node:25-dev`)

Example:

```sh
TESSL_BASE_IMAGE=dhi.io/node:25-dev tessl --help
```

The default Tessl image is built locally from `images/tessl/Containerfile`, which starts from `node:25` and installs the CLI with `npm install -g @tessl/cli` per the Tessl installation docs. Shimmy tags the resulting image under `localhost/shimmy-tessl:<context-hash>` so Podman keeps a reusable local cache and automatically rebuilds when the build context changes.

**Mounts:**
- `$PWD` → `/work` (read-write)
- `~/.tessl` → `/root/.tessl` (read-write, if exists)

**Environment variables forwarded:**
- `TESSL_*`

### Textual CLI

- `TEXTUAL_IMAGE` — Override the runtime image entirely
- `TEXTUAL_IMAGE_BUILD` — Set to `always` to rebuild the local Textual image even if it is already cached
- `TEXTUAL_IMAGE_PULL` — Set to `always` to force pulling `TEXTUAL_IMAGE` when using an explicit remote override
- `TEXTUAL_BASE_IMAGE` — Override the `Containerfile` base image (default build arg: `python:3.13-slim-bookworm`)

Example:

```sh
TEXTUAL_BASE_IMAGE=python:3.13-slim-bookworm textual --help
```

The default Textual image is built locally from `images/textual/Containerfile`, which starts from `python:3.13-slim-bookworm` and installs `textual` plus `textual-dev`. This matches the official Textual docs, where the `textual` command comes from the developer tools package. Shimmy tags the resulting image under `localhost/shimmy-textual:<context-hash>` so Podman keeps a reusable local cache and automatically rebuilds when the build context changes.

**Mounts:**
- `$PWD` → `/work` (read-write)

## Testing

Run the test suite to validate that shim containers run via Podman:

```sh
./shimmy test
# or
sh ./scripts/test-shimmy.sh
```

Tests verify:
- `/bin/sh` parser compatibility for the proof-of-concept shell entrypoints
- install and uninstall behavior
- `shellenv` activation and PATH idempotence
- live Podman execution for the proof-of-concept `jq` shim

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
│   ├── tessl
│   ├── textual
│   └── terraform
├── images/                   # Custom shim image build contexts
│   ├── netcat
│   ├── task
│   ├── tessl
│   └── textual
├── lib/
│   ├── repo/                 # Repo-only sourced helpers for wrapper/scripts
│   └── shims/                # Installed shared helper scripts for shims
├── scripts/
│   ├── install-shimmy.sh     # Installation script
│   ├── status-shimmy.sh      # Status script
│   ├── test-shimmy.sh        # Test suite
│   └── update-shimmy.sh      # Update script
├── .pre-commit-config.yaml    # Git https://github.com/pre-commit/pre-commit-hooks
├── .github/
│   └── workflows/
│       └── test.yml          # CI/CD workflow
└── README.md                 # This file
```

## AI Generation 
This code was ![AI-developed](https://img.shields.io/badge/AI-Generated-blue) and human-reviewed/curated in concert with Codex GPT-5.4.

## License

See LICENSE file for details.
