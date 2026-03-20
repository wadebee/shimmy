# shimmy

Commonly used CLI tools exposed through Podman shims for Bash, direnv, and other shells.

## Overview

Shimmy wraps popular CLI tools in lightweight Podman containers, providing:
- **No local installations required** — tools run in containers
- **Consistent environments** across different machines and projects
- **Customizable** — override container images via environment variables
- **Transparent usage** — add to PATH and use tools as if they were installed locally

For tools that do not ship a usable upstream container image, Shimmy can build and cache a local image from a checked-in `Containerfile` context. The image tag is derived from the build-context hash, so Podman reuses the cached image until the `Containerfile` or its supporting files change.

## Included Shims

| Tool | Purpose | Default Image | Usage |
|------|---------|----------------|-------|
| **aws** | AWS CLI | `docker.io/amazon/aws-cli:2.15.0` | `aws s3 ls`, `aws sts get-caller-identity` |
| **jq** | JSON processor | `docker.io/stedolan/jq:latest` | `jq .foo file.json` |
| **netcat** | TCP/UDP debugging client | local build from `images/netcat/Containerfile` | `netcat --help`, `netcat example.com 443` |
| **rg** | Ripgrep search | `docker.io/vszl/ripgrep:latest` | `rg "pattern" .` |
| **terraform** | Infrastructure as Code | `docker.io/hashicorp/terraform:latest` | `terraform plan`, `terraform apply` |
| **textual** | Textual developer CLI | local build from `images/textual/Containerfile` | `textual --help`, `textual run app.py` |
| **tessl** | Tessl CLI | local build from `images/tessl/Containerfile` | `tessl --help`, `tessl init` |

## Podman rootless requirement

Shimmy expects a working rootless Podman setup. On some minimal Linux environments, including Chromebook's Crostini, rootless requirements for subordinate id ranges do not exist. In this scenario Podman will warn "no subuid ranges found" and fall back to a single UID/GID mapping.

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


### Option 1: System-wide installation

Install shims to `~/` and update your shell configuration:

```bash
./scripts/install-shimmy.sh
```

To remove the installed shims and Shimmy-managed shell/profile artifacts later:

```bash
./scripts/install-shimmy.sh --uninstall
```

After running this, restart your shell or source the managed Shimmy file:

```bash
source ~/.bashrc_shimmy
```

The installer keeps the PATH block in `~/.bashrc_shimmy` and adds a sourcing line to both `~/.bashrc` and `~/.bash_profile` so Bash behaves consistently on Linux interactive shells and macOS login shells.

### Option 2: Use with direnv

If you have [direnv](https://direnv.net/) installed:

```bash
cd /path/to/shimmy
direnv allow
```

This automatically adds `shims/` to your PATH whenever you're in this directory.

#### Installation options

```bash
./scripts/install-shimmy.sh --help
```

- `--install-dir <dir>` — Custom installation directory (default: `~/.local/bin/shimmy`)
- `--symlink` — Symlink shims to the repo instead of copying them
- `--copy` — Copy shims to the install directory (default)
- `--no-update-bashrc` — Skip updating `~/.bashrc`, `~/.bash_profile`, and `~/.bashrc_shimmy`
- `LOG_LEVEL` — Global verbosity for installer and runtime-helper output: `debug`, `info`, `warn`, `error`, or `silent`

Uninstall options:

```bash
./scripts/install-shimmy.sh --help
```

### Option 3: Session-only (temporary)

For a single shell session:

```bash
export PATH="$PATH:$SHIMMY_SHIM_DIR"
```

## Usage

Once shims are in your PATH, use tools naturally:

```bash
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

```bash
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
- `TF_VARS_*`

### AWS CLI

- `AWS_IMAGE` — Container image (default: `docker.io/amazon/aws-cli:2.15.0`)
- `AWS_IMAGE_PULL` — Set to `always` to force pulling the latest image

Example:

```bash
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

```bash
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

```bash
NETCAT_BASE_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal:latest netcat --help
```

The default Netcat image is built locally from `images/netcat/Containerfile`, which starts from UBI 9 minimal and installs the `nmap-ncat` package. This keeps the base image small while still using a practical Red Hat-supported package manager for the install. Shimmy tags the resulting image under `localhost/shimmy-netcat:<context-hash>` so Podman keeps a reusable local cache and automatically rebuilds when the build context changes.

**Mounts:**
- `$PWD` → `/work` (read-write)

### ripgrep

- `RG_IMAGE` — Container image (default: `docker.io/vszl/ripgrep:latest`)
- `RG_IMAGE_PULL` — Set to `always` to force pulling the latest image

Example:

```bash
RG_IMAGE=docker.io/vszl/ripgrep:latest rg --version
```

**Mounts:**
- `$PWD` → `/work` (read-write)

### Tessl CLI

- `TESSL_IMAGE` — Override the runtime image entirely
- `TESSL_IMAGE_BUILD` — Set to `always` to rebuild the local Tessl image even if it is already cached
- `TESSL_IMAGE_PULL` — Set to `always` to force pulling `TESSL_IMAGE` when using an explicit remote override
- `TESSL_BASE_IMAGE` — Override the `Containerfile` base image (default build arg: `dhi.io/node:25-dev`)

Example:

```bash
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

```bash
TEXTUAL_BASE_IMAGE=python:3.13-slim-bookworm textual --help
```

The default Textual image is built locally from `images/textual/Containerfile`, which starts from `python:3.13-slim-bookworm` and installs `textual` plus `textual-dev`. This matches the official Textual docs, where the `textual` command comes from the developer tools package. Shimmy tags the resulting image under `localhost/shimmy-textual:<context-hash>` so Podman keeps a reusable local cache and automatically rebuilds when the build context changes.

**Mounts:**
- `$PWD` → `/work` (read-write)

## Testing

Run the test suite to validate that shim containers run via Podman:

```bash
make test-shimmy
# or
./scripts/test-shimmy.sh
```

Tests verify:
- Each shim launches through Podman with a non-mutating command
- Custom image overrides and `*_IMAGE_PULL=always` execution paths
- Netcat local image build behavior on UBI 9 minimal
- Working-directory mounts for jq, ripgrep, and Terraform
- AWS config mounting for the AWS CLI shim
- Textual CLI local image build behavior
- Tessl CLI local image build + cache behavior
- Installer profile-copy behavior

## Requirements

- **Podman** — Install via your package manager (or Docker as a fallback)
- **Bash** — Version 4.0+

## Directory Structure
```
shimmy/
├── shims/                    # OCI wrapper scripts
│   ├── aws
│   ├── jq
│   ├── netcat
│   ├── rg
│   ├── textual
│   ├── tessl
│   └── terraform
├── images/                   # Custom shim image build contexts
│   ├── netcat
│   ├── tessl
│   └── textual
├── runtime/
│   └── lib/                  # Shared runtime helper scripts
├── scripts/
│   ├── install-shimmy.sh      # Installation script
│   └── test-shimmy.sh         # Test suite
├── .envrc                     # direnv configuration
├── .pre-commit-config.yaml    # Git https://github.com/pre-commit/pre-commit-hooks
├── .github/
│   └── workflows/
│       └── test.yml          # CI/CD workflow
├── Makefile                  # Build targets
└── README.md                 # This file
```

## AI Generation 
This code was ![AI-developed](https://img.shields.io/badge/AI-Generated-blue) and human-reviewed/curated in concert with Codex GPT-5.4.

## License

See LICENSE file for details.
