# shimmy

Commonly used CLI tools exposed through Podman shims for Bash, direnv, and other shells.

## Overview

Shimmy wraps popular CLI tools in lightweight Podman containers, providing:
- **No local installations required** — tools run in containers
- **Consistent environments** across different machines and projects
- **Easy customization** — override container images via environment variables
- **Transparent usage** — add to PATH and use tools as if they were installed locally

For tools that do not ship a usable upstream container image, Shimmy can build and cache a local image from a checked-in `Containerfile` context. The image tag is derived from the build-context hash, so Podman reuses the cached image until the `Containerfile` or its supporting files change.

## Included Shims

| Tool | Purpose | Default Image | Usage |
|------|---------|----------------|-------|
| **terraform** | Infrastructure as Code | `docker.io/hashicorp/terraform:latest` | `terraform plan`, `terraform apply` |
| **aws** | AWS CLI | `amazon/aws-cli:2.15.0` | `aws s3 ls`, `aws sts get-caller-identity` |
| **jq** | JSON processor | `docker.io/stedolan/jq:latest` | `jq .foo file.json` |
| **rg** | Ripgrep search | `docker.io/vszl/ripgrep:latest` | `rg "pattern" .` |
| **tessl** | Tessl CLI | local build from `runtime/images/tessl/Containerfile` | `tessl --help`, `tessl init` |

## Installation

### Option 1: System-wide installation

Install shims to `~/` and update your shell configuration:

```bash
./scripts/install-shimmy.sh
```

After running this, restart your shell or source your `.bashrc`:

```bash
source ~/.bashrc
```

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
- `--no-update-bashrc` — Skip updating `~/.bashrc`

### Option 3: Session-only (temporary)

For a single shell session:

```bash
export PATH="$PATH:/path/to/shimmy/shims"
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

- `AWS_IMAGE` — Container image (default: `amazon/aws-cli:2.15.0`)
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

The default Tessl image is built locally from `runtime/images/tessl/Containerfile`, which starts from `dhi.io/node:25-dev` and installs the CLI with `npm install -g @tessl/cli` per the Tessl installation docs. Shimmy tags the resulting image under `localhost/shimmy-tessl:<context-hash>` so Podman keeps a reusable local cache and automatically rebuilds when the build context changes.

**Mounts:**
- `$PWD` → `/work` (read-write)
- `~/.tessl` → `/root/.tessl` (read-write, if exists)

**Environment variables forwarded:**
- `TESSL_*`

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
- Working-directory mounts for jq, ripgrep, and Terraform
- AWS config mounting for the AWS CLI shim
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
│   ├── rg
│   ├── tessl
│   └── terraform
├── runtime/
│   ├── images/               # Custom shim image build contexts
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
