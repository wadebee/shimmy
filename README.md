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

| Tool | Purpose | Quick start |
|------|---------|-------------|
| **aws** | AWS CLI | [docs/shims/aws.md](docs/shims/aws.md) |
| **go** | Go toolchain CLI | [docs/shims/go.md](docs/shims/go.md) |
| **jq** | JSON processor | [docs/shims/jq.md](docs/shims/jq.md) |
| **netcat** | TCP/UDP debugging client | [docs/shims/netcat.md](docs/shims/netcat.md) |
| **nmap** | Network discovery and security scanner | [docs/shims/nmap.md](docs/shims/nmap.md) |
| **opnsense-cli** | OPNsense command runner | [docs/shims/opnsense-cli.md](docs/shims/opnsense-cli.md) |
| **rg** | Ripgrep search | [docs/shims/rg.md](docs/shims/rg.md) |
| **task** | Taskfile task runner | [docs/shims/task.md](docs/shims/task.md) |
| **terraform** | Infrastructure as Code | [docs/shims/terraform.md](docs/shims/terraform.md) |
| **tessl** | Tessl CLI, present as a repo shim but not installed by default | [docs/shims/tessl.md](docs/shims/tessl.md) |
| **textual** | Textual developer CLI | [docs/shims/textual.md](docs/shims/textual.md) |

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

AI Agent approvals are often evaluated on the outer command. If `podman info` succeeds but a Shimmy wrapper still reports that Podman is unreachable, approve the exact dry-run smoke command prefix that the AI Agent is trying to run, such as `["rg","--version"]` for an activated shim or `["./shims/rg","--version"]` for a repo-local shim. Approval for `["podman", "info"]` only verifies the engine; it does not approve nested Podman access through a wrapper.

From a fresh AI Agent session, run the non-mutating preflight to list the exact approval prefixes and smoke commands:

```sh
./scripts/agent-shimmy-preflight.sh
```

The script checks `podman info`, discovers active installed shims and repo-local shims, and prints harmless `--version` or `--help` commands to approve with your AI Agent's approval mechanism and the listed dry-run `agent_prefix_rule` values. Use `--smoke` from a normal shell when you want the script to run those checks directly.

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
aws sts get-caller-identity
go test ./...
jq . file.json
netcat 198.51.100.10 443
nmap --version
opnsense-cli -t root@192.168.1.1 sysinfo
rg "pattern" .
task --list
terraform plan
textual --help
```

## Shim Quick Starts

Each runtime shim has a focused quick-start document with upstream links, source summary, top-level command notes, Shimmy configuration, and example prompts.

| Tool | Quick start |
|------|-------------|
| **aws** | [docs/shims/aws.md](docs/shims/aws.md) |
| **go** | [docs/shims/go.md](docs/shims/go.md) |
| **jq** | [docs/shims/jq.md](docs/shims/jq.md) |
| **netcat** | [docs/shims/netcat.md](docs/shims/netcat.md) |
| **nmap** | [docs/shims/nmap.md](docs/shims/nmap.md) |
| **opnsense-cli** | [docs/shims/opnsense-cli.md](docs/shims/opnsense-cli.md) |
| **rg** | [docs/shims/rg.md](docs/shims/rg.md) |
| **task** | [docs/shims/task.md](docs/shims/task.md) |
| **terraform** | [docs/shims/terraform.md](docs/shims/terraform.md) |
| **tessl** | [docs/shims/tessl.md](docs/shims/tessl.md) |
| **textual** | [docs/shims/textual.md](docs/shims/textual.md) |

`shims/tessl` exists in the repository but is not currently listed in the installer supported shim set. Its quick-start doc notes that status explicitly.

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
- live Podman execution for the supported shim set: `aws`, `go`, `jq`, `netcat`, `nmap`, `opnsense-cli`, `rg`, `task`, `terraform`, and `textual`

## Directory Structure
```
shimmy/
├── shimmy                    # Repo-root wrapper command
├── shims/                    # OCI wrapper scripts
│   ├── aws
│   ├── go
│   ├── jq
│   ├── netcat
│   ├── nmap
│   ├── opnsense-cli
│   ├── rg
│   ├── task
│   ├── tessl
│   ├── textual
│   └── terraform
├── images/                   # Custom shim image build contexts
│   ├── netcat
│   ├── opnsense-cli
│   ├── task
│   ├── tessl
│   └── textual
├── docs/
│   └── shims/                # Per-shim quick-start documentation
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
