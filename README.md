# shimmy

Commonly used CLI tools exposed through Podman shims for Bash, direnv, and other shells.

## Overview

Shimmy wraps popular CLI tools in lightweight Podman containers, providing:
- **No local installations required** — tools run in containers
- **Consistent environments** across different machines and projects
- **Easy customization** — override container images via environment variables
- **Transparent usage** — add to PATH and use tools as if they were installed locally

## Included Shims

| Tool | Purpose | Default Image | Usage |
|------|---------|----------------|-------|
| **terraform** | Infrastructure as Code | `docker.io/hashicorp/terraform:1.5.6` | `terraform plan`, `terraform apply` |
| **aws** | AWS CLI | `amazon/aws-cli:2.15.0` | `aws s3 ls`, `aws sts get-caller-identity` |
| **jq** | JSON processor | `docker.io/stedolan/jq:latest` | `jq .foo file.json` |
| **rg** | Ripgrep search | `docker.io/vszl/ripgrep:latest` | `rg "pattern" .` |

## Installation

### Option 1: System-wide installation

Install shims to `~/.local/bin/shims` and update your shell configuration:

```bash
./scripts/install-shims.sh
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
./scripts/install-shims.sh --help
```

- `--install-dir <dir>` — Custom installation directory (default: `~/.local/bin/shims`)
- `--symlink` — Install as symlinks to this repo (default)
- `--copy` — Copy shim files instead of symlinking
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
```

## Configuration

Each shim respects environment variables for customization:

### Terraform

- `TF_IMAGE` — Container image (default: `docker.io/hashicorp/terraform:1.5.6`)
- `TF_IMAGE_PULL` — Set to `always` to force pulling the latest image

Example:

```bash
TF_IMAGE=hashicorp/terraform:1.14.5 terraform version
TF_IMAGE_PULL=always terraform plan
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
RG_IMAGE=ghcr.io/burntsushi/ripgrep:14.1.1 rg --version
```

**Mounts:**
- `$PWD` → `/work` (read-write)

## Testing

Run the test suite to validate that shims generate correct Podman arguments:

```bash
make test-shims
# or
./scripts/test-shims.sh
```

Tests verify:
- Default behavior for each shim
- Mount generation (AWS credentials, Terraform plugin cache)
- Image pull policy overrides
- Custom image specifications
- All environment variable forwarding

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
│   └── terraform
├── scripts/
│   ├── install-shims.sh      # Installation script
│   └── test-shims.sh         # Test suite
├── .envrc                    # direnv configuration
├── .pre-commit-config.yaml   # Git https://github.com/pre-commit/pre-commit-hooks
├── .github/
│   └── workflows/
│       └── test.yml          # CI/CD workflow
├── Makefile                  # Build targets
└── README.md                 # This file
```

## AI Generation 
This code was ![AI-developed](https://img.shields.io/badge/AI-Generated-blue) and human-reviewed/curated in concert with Codex GPT-5.3.


## License

See LICENSE file for details.
