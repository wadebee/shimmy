# shimmy

Commonly used CLI tools exposed through Podman shims for POSIX-oriented shells.

## Overview

Shimmy wraps popular CLI tools in lightweight Podman containers, providing:
- **No local installations required** — tools run in containers
- **Consistent environments** across different machines and projects
- **Customizable** — override container images via environment variables
- **Transparent usage** — add to PATH and use tools as if they were installed locally

For tools that do not ship a usable upstream container image, Shimmy can build and cache a local image from a checked-in `Containerfile` context. The image tag is derived from the build-context hash and resolved platform, so Podman reuses the cached image until the `Containerfile`, supporting files, or host platform changes.

Shimmy also resolves the container platform at runtime without changing the command a user runs. Linux hosts run containers as `linux/amd64`, while macOS hosts run [containers](https://github.com/apple/container/blob/main/docs/technical-overview.md) as `linux/arm64`. Explicit `SHIMMY_{TOOL_PREFIX}_IMAGE` overrides still select the image reference, and Shimmy applies the platform selection underneath.

For diagnostic purposes you may inspect the shim command that gets passed to Podman without actually running the command using the `--preview-shim`
flag in your tool command. Shimmy will intercept that flag and print a shell-quoted `podman run` command, then exit without checking
Podman engine reachability, pulling images, building local images, or starting a
container.

```sh
jq --preview-shim --version
netcat --help --preview-shim
```

## Included Shims

| Tool | Purpose | Quick start |
|------|---------|-------------|
| **aws** | AWS CLI | [docs/shims/aws.md](docs/shims/aws.md) |
| **go** | Go toolchain CLI | [docs/shims/go.md](docs/shims/go.md) |
| **gcloud** | Google Cloud CLI | [docs/shims/gcloud.md](docs/shims/gcloud.md) |
| **gdrive** | MCP server for interacting with Google Drive and Sheets | [docs/shims/gdrive.md](docs/shims/gdrive.md) |
| **jq** | JSON processor | [docs/shims/jq.md](docs/shims/jq.md) |
| **netcat** | TCP/UDP debugging client | [docs/shims/netcat.md](docs/shims/netcat.md) |
| **nmap** | Network discovery and security scanner | [docs/shims/nmap.md](docs/shims/nmap.md) |
| **opnsense-mcp-admin** | OPNsense firewall MCP server, admin-capable change tooling | [docs/shims/opnsense-mcp-admin.md](docs/shims/opnsense-mcp-admin.md) |
| **opnsense-mcp-read-only** | OPNsense firewall MCP server, read-only default | [docs/shims/opnsense-mcp-read-only.md](docs/shims/opnsense-mcp-read-only.md) |
| **rg** | Ripgrep search | [docs/shims/rg.md](docs/shims/rg.md) |
| **task** | Taskfile task runner | [docs/shims/task.md](docs/shims/task.md) |
| **terraform** | Infrastructure as Code | [docs/shims/terraform.md](docs/shims/terraform.md) |
| **tessl** | Tessl CLI, present as a repo shim but not installed by default | [docs/shims/tessl.md](docs/shims/tessl.md) |
| **textual** | Textual developer CLI | [docs/shims/textual.md](docs/shims/textual.md) |

## Requirements

- POSIX shell — `/bin/sh` or another POSIX-compatible shell

- Podman CLI - Shimmy runs tools through `podman run`, so the cli and engine must be
 installed and reachable from the same shell where you use Shimmy. Podman Desktop is not required.

  See [docs/podman.md](docs/podman.md) for a Podman Quick Start, Troubleshooting, and Basic Hygiene.

## Installation Options

### Option: AI Agent Plugin

Shimmy includes a packaged AI Agent plugin. The plugin provides core Shimmy management skills (`shimmy-install`, `shimmy-init`, `shimmy-create-tool`, and `shimmy-escalation`) plus the jq and ripgrep tool skills most AI agents use. This allows an AI Agent to manage Shimmy installs, quickly create new shims, troubleshoot Podman, and work with the jq or rg tooling.

The primary plugin intentionally does not bundle every tool skill. Optional tool-specific plugins can be added later, for example AWS, Terraform, or Go. Install or enable supplemental plugins when a workstation or repo needs those capabilities.

This repository also includes `.agents/plugins/marketplace.json`, which registers a local Shimmy plugin repo to `plugins/shimmy`.

#### Use the plugin in this repository

Open a new AI Agent session from the Shimmy git clone checkout after the plugin files are present. Agent plugin discovery usually happens at session startup, so an already-running session may not see newly added plugin metadata until it is restarted.

When prompted, install or enable the `shimmy` plugin from the local marketplace repo. Once enabled, requests that involve Shimmy, jq, or ripgrep can use the packaged skills automatically.

#### Share Shimmy skills

Shimmy skills can be shared beyond the default project repo and into your user profile, or exported as a packaged plugin bundle:

```sh
./shimmy skills install --target repo
./shimmy skills install --target profile
./shimmy skills update --target plugin
./shimmy skills install --export ./shimmy-skills
./shimmy skills install --export ./shimmy-skills.zip
```

Targets:
- `repo` writes to `.agents/skills` in the current directory.
- `profile` writes to your user profile at `~/.agents/skills`.
- `plugin` writes to `plugins/shimmy/skills` in the active Shimmy source or installed management bundle.
- `--export` writes a portable skills folder, or a zip archive when the path ends in `.zip`; zip archives require either `zip` or `python3`.

With no explicit skill names, `install` shares the core Shimmy management skills plus `shimmy-tool-*` skills for shims recorded in the selected profile manifest. To share an additional generated shim skill, pass it explicitly:

```sh
./shimmy skills install --target repo shimmy-tool-example
./shimmy skills update --target repo
```

#### Use Shimmy tools from an AI Agent faster

From a fresh AI Agent session, run the agent preflight to review the exact prompt approval escalations Shimmy will need from you for normal operations:

```sh
./scripts/agent-shimmy-preflight.sh
```

The script checks `podman info`, discovers active installed shims and repo-local shims, and prints harmless `--version` or `--help` commands. Once you have approved these with your AI Agent's approval mechanism future Shimmy use will be less "needy". Preflight also supports a `--smoke` toggle which runs a smoke check on shimmed tools directly.

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

Linux and macOS can use the same plugin layout. Shimmy itself still requires a POSIX shell and a working rootless Podman installation; see [docs/podman.md](docs/podman.md) for workstation setup and verification.

On Windows, use WSL or another POSIX-compatible environment for Shimmy workflows. On Chromebooks, use Crostini and a bash shell.

Put the plugin and marketplace files in the Linux home directory used by the AI Agent in that environment, for example `/home/<user>/plugins/shimmy` and `/home/<user>/.agents/plugins/marketplace.json`. Configure Podman inside that same environment before running Shimmy-backed tools.

### Option: Shimmy wrapper workflow

Use the repo-root `shimmy` wrapper to install and manage Shimmy from a source checkout:

```sh
./shimmy install
./shimmy install --profile upstream
./shimmy netinfo
./shimmy skills install --target repo
./shimmy status
./shimmy status --profile upstream
./shimmy status --available
./shimmy update --pull --build
./shimmy test
./shimmy test --profile upstream
./shimmy uninstall
```

The wrapper delegates to script-based interfaces in `scripts/`.

After installation, Shimmy also installs a management command at:

```sh
~/.config/shimmy/bin/shimmy
```

Activated shells can use the installed command from any directory:

```sh
shimmy status
shimmy status --available
shimmy install --shim opnsense-mcp-read-only
shimmy install --shim opnsense-mcp-admin
shimmy netinfo
shimmy skills update --target repo
shimmy update --all --pull --build
shimmy test
eval "$(shimmy activate)"
```

`shimmy install --shim opnsense-mcp-read-only` for normal inspection, and
`shimmy install --shim opnsense-mcp-admin` only for change-capable workflows.
Create separate Podman secrets for each shim: `opnsense_mcp_read_only_api_key`
and `opnsense_mcp_read_only_api_secret` for read-only, and
`opnsense_mcp_admin_api_key` and `opnsense_mcp_admin_api_secret` for admin.
The removed `opnsense-mcp-server` command is not an alias for either new shim.

### Profiles and profile selection

Shimmy uses one user-scoped install root with two built-in profiles:

- `default` is the normal external-user profile. It is selected when no profile is provided.
- `upstream` is an opt-in maintainer profile. It runs installed commands through wrappers that exec source files from a recorded Shimmy checkout.

Bare `shimmy install` creates or repairs only the `default` profile. Install the maintainer profile explicitly with `shimmy install --profile upstream`.

Profile default selection follows this progression:

1. An explicit `--profile default|upstream` flag wins.
2. Otherwise `SHIMMY_PROFILE_ACTIVE=default|upstream` wins.
3. Otherwise Shimmy uses `default`.

Use explicit flags for one-off operations:

```sh
./shimmy install --profile upstream
eval "$(./shimmy activate --profile upstream)"
shimmy status --profile upstream
shimmy test --profile upstream
shimmy update --profile upstream
```

Use `SHIMMY_PROFILE_ACTIVE` for a whole shell session:

```sh
export SHIMMY_PROFILE_ACTIVE=upstream
eval "$(shimmy activate --profile upstream)"
rg --version
shimmy status
shimmy test
```

Direct tool commands such as `rg` and `jq` do not take `--profile`. They read `SHIMMY_PROFILE_ACTIVE`, then dispatch through the selected profile. `command -v rg` shows the stable dispatcher under the install root; `shimmy status --format manifest` shows the selected profile's manifest, implementation directory, and source checkout when upstream profile is active.

`SHIMMY_UPSTREAM_DIR` is Shimmy-managed profile state. By default it is:

```text
~/.config/shimmy/profiles/upstream
```

It is not the git checkout. To install upstream profile from a specific checkout, set `SHIMMY_UPSTREAM_CHECKOUT_DIR` for `shimmy install --profile upstream`; Shimmy records the resolved absolute checkout path in the upstream manifest.

```sh
SHIMMY_UPSTREAM_CHECKOUT_DIR=/path/to/shimmy ./shimmy install --profile upstream
```

After an upstream install, editing an existing source shim such as `/path/to/shimmy/shims/rg` is reflected by activated upstream commands without reinstalling. Moving or renaming shim source files requires rerunning `shimmy install --profile upstream`.

#### Management-plane updates

Shimmy separates management-plane updates from shim image refreshes. A bare
management-plane update refreshes the installed `shimmy` command, lifecycle
scripts, activation file, helper libraries, the management source catalog, and
runtime wrapper files for installed default shims such as `jq` and `rg`.

Contributor workflow:

```sh
cd /path/to/shimmy
git pull --ff-only
./shimmy update --all
```

When `update` is run from the repo-root `./shimmy` launcher, it refreshes the
install from that current checkout. Use this path when developing Shimmy,
testing local changes, or intentionally installing from a specific source tree.
For default-profile updates from a checkout, omit `--profile` or pass
`--profile default`. Use `--shim <name>` to refresh one installed profile shim,
or `--all` to refresh every installed profile shim.

Installed-user workflow:

```sh
shimmy update
```

When `update` is run from the installed `shimmy` command, Shimmy reads
`shimmy_source_url` from the selected profile manifest, fetches that
source into a temporary checkout, and refreshes the installed management plane
from the fetched source. This path works from any activated shell and does not
require the user to keep a Shimmy source checkout open.

Both workflows preserve the currently installed shim list from the manifest.
Newly available shims are not added automatically during update; install them
explicitly:

```sh
shimmy install --shim opnsense-mcp-read-only
shimmy install --shim opnsense-mcp-admin
```

Shim container image refresh is still explicit. Normal management-plane updates
do not pull newer remote images or rebuild local images unless requested:

```sh
shimmy update --pull
shimmy update --build
shimmy update --pull --build
```

`shimmy netinfo` reports the current shell's network perspective on Linux and
macOS without requiring Podman or probing the LAN. It is useful in VM-heavy
environments such as Crostini, Proxmox guests, macOS hosts, and macOS Podman VMs
because it distinguishes the shell-side IP and routes from a host-side LAN
identity supplied by DNS, inferred from a host-authoritative default interface,
or provided by the user. For Crostini and other VM/container-like shells, it
keeps host-side values unknown instead of treating nested routes as the physical
LAN. Do not use the shell hostname `penguin` as the Chromebook host identity;
provide the Chromebook's router/DNS name instead:

```sh
shimmy netinfo
shimmy netinfo --host-name chromebook-home --host-prefix 24
shimmy netinfo --host-lan 192.168.1.0/24
```

See [docs/netinfo.md](docs/netinfo.md) for details.

After `./shimmy install`, activate the installed Shimmy paths in the current shell immediately with:

```sh
eval "$(~/.config/shimmy/bin/shimmy activate)"
```

`./shimmy install` writes one activation file under the install root and updates your shell startup file by default so future shells can source it. It cannot change your current shell session, so use the installed `shimmy activate` command to make the install available immediately.

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
eval "$(~/.config/shimmy/bin/shimmy activate)"
```

If your startup file ever needs to be rewritten or repaired later, use update:

```sh
shimmy update --repair-startup
shimmy update --repair-startup --shell zsh
shimmy update --repair-startup --startup-file "$HOME/.config/shimmy/profile"
```

Without `--repair-startup`, `update` refreshes installed assets only and leaves startup files alone.

The active install layout is always derived from one install root, which defaults to `~/.config/shimmy` and can be overridden with `--install-dir` during migration or testing.

Common install arguments still pass through to the installer:

```sh
./shimmy install
./shimmy install --install-dir "$HOME/.local/share/shimmy"
./shimmy install --shim aws --shim terraform
./shimmy install --skills-target repo
```

With no explicit `--shim`, install creates or completes the default external-user profile with `jq` and `rg`. Repeated `--shim` flags add missing shims to the selected profile. If a shim is already installed, install leaves it alone and points you to `shimmy update --shim <name>` for refresh behavior.

During an interactive install, Shimmy asks where to share Shimmy agent skills: `repo`, `profile`, `plugin`, or `none`. For non-interactive installs, pass `--skills-target <repo|profile|plugin>` or run `shimmy skills install` later.

#### Option: Direct script workflow

Use the underlying scripts directly when you want the lower-level interfaces explicitly:

```sh
sh ./scripts/install-shimmy.sh
sh ./scripts/status-shimmy.sh
sh ./scripts/status-shimmy.sh --available
sh ./scripts/update-shimmy.sh --pull --build
sh ./scripts/test-shimmy.sh
sh ./scripts/install-shimmy.sh --uninstall --profile default
```

This is the same functionality the wrapper exposes, without the repo-root dispatcher.

### Install manifest and lifecycle state

Shimmy stores install state in POSIX-readable root and profile manifests:

```text
~/.config/shimmy/install-manifest.txt
~/.config/shimmy/profiles/default/install-manifest.txt
~/.config/shimmy/profiles/upstream/install-manifest.txt
```

The root manifest records install-wide integration state:

- `shimmy_install_manifest_version` — root manifest format version
- `install_dir` — active install root
- `dispatcher_dir` — stable direct-command entrypoint directory
- `control_bin` — installed `shimmy` management command
- `activate_file` — generated activation script
- `shimmy_profile_default` — default profile, currently `default`
- `default_shim` — baseline shim name for a bare install; currently repeated for `jq` and `rg`
- `profile` — installed profile name; repeated for each installed profile
- `startup_shell` and `startup_file` — managed startup-file state

The selected profile manifest is the source of truth for profile-specific shims, update, direct dispatch, and profile cleanup. It uses one `key=value` entry per line and repeated keys for lists. Each installed shim also has a config file under `<config_dir>/shims/<shim>.conf`; `shimmy test --shim` and `shimmy test --all` read repeated `smoke_arg=` entries from that config instead of guessing a default command.

Profile fields include:
- `shimmy_profile_manifest_version` — profile manifest format version
- `shimmy_profile_name` — selected profile name
- `config_dir` — selected profile config directory
- `bin_dir` — selected profile implementation directory
- `profile_implementation_dir` — selected profile implementation directory
- `shim_source` — `copied-source-shim` for default or `generated-exec-wrapper` for upstream
- `source_checkout` — resolved upstream checkout path for upstream installs
- `shim` — installed shim name; repeated for each installed tool
- `shimmy_source_url`, `shimmy_source_ref`, and `shimmy_previous_source_ref` — profile lifecycle source metadata

Root and profile manifests do not own generated skill audit state. Each skills target gets a local `.shimmy-skills-manifest.txt` under the target skills directory, and that file is the durable owner of repeated `shimmy_skill=` entries. `shimmy skills update` reads that manifest to refresh the same skill set idempotently, so generated `shimmy-tool-*` skills can be audited and updated without duplicate entries.

For machine-readable inspection, `shimmy status --format manifest` emits a normalized view with `shimmy_` install/status keys and `shimmy_profile_` selected-profile keys. It reports derived paths and incomplete-profile diagnostics without treating the root manifest as a default-profile substitute.

For machine-readable inspection, use:

```sh
shimmy status --format manifest
shimmy status --profile upstream --format manifest
```

The current implementation can:
- Reinstall from the checked-out source
- Refresh the selected profile from the checked-out source or from an installed command's recorded source URL
- Refresh remote images with `--pull`
- Rebuild local images with `--build`
- Repair startup files, and preserve lifecycle metadata. 

Full latest-version resolution, semver enforcement such as `>=0.10.0`, and rollback to release versions require a release/tag/version convention for Shimmy itself.
To compare installed shims with the supported shims still available to install, use:

```sh
shimmy status --available
shimmy status --available --format manifest
```

## Usage

Once shims are in your PATH, use tools naturally:

```sh
aws sts get-caller-identity
go test ./...
gcloud auth list
gdrive --help
jq . file.json
netcat 198.51.100.10 443
nmap --version
opnsense-mcp-admin --help
opnsense-mcp-read-only
rg "pattern" .
task --list
terraform plan
textual --help
```

## Shim Quick Starts

Each runtime shim has a focused quick-start document with upstream links, source summary, top-level command notes, Shimmy configuration, and example prompts.

Some shims also document required setup checks. For example, `opnsense-mcp-read-only` and `opnsense-mcp-admin` require `OPNSENSE_URL`, default to self-signed-lab SSL preflight behavior, validate that the endpoint responds to a local `curl` request before starting the container, and use separate Podman secret defaults. Prefer `opnsense-mcp-read-only` for inventory, status, diagnostics, inspection, and policy review. Use `opnsense-mcp-admin` only for explicit configuration changes, approved change-window workflows, or capabilities missing from the read-only library. The old `opnsense-mcp-server` command was removed and is not an alias.

| Tool | Quick start |
|------|-------------|
| **aws** | [docs/shims/aws.md](docs/shims/aws.md) |
| **go** | [docs/shims/go.md](docs/shims/go.md) |
| **gcloud** | [docs/shims/gcloud.md](docs/shims/gcloud.md) |
| **gdrive** | [docs/shims/gdrive.md](docs/shims/gdrive.md) |
| **jq** | [docs/shims/jq.md](docs/shims/jq.md) |
| **netcat** | [docs/shims/netcat.md](docs/shims/netcat.md) |
| **nmap** | [docs/shims/nmap.md](docs/shims/nmap.md) |
| **opnsense-mcp-admin** | [docs/shims/opnsense-mcp-admin.md](docs/shims/opnsense-mcp-admin.md) |
| **opnsense-mcp-read-only** | [docs/shims/opnsense-mcp-read-only.md](docs/shims/opnsense-mcp-read-only.md) |
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

After installing upstream profile, maintainers can exercise source changes through the installed dispatcher path:

```sh
./shimmy install --profile upstream
eval "$(./shimmy activate --profile upstream)"
shimmy test --profile upstream
shimmy test --profile upstream --shim rg
shimmy test --profile upstream --all
SHIMMY_PROFILE_ACTIVE=upstream rg --version
```

When a profile is selected, `shimmy test` validates the root manifest and selected profile structure, then smoke-tests root default shims such as `jq` and `rg`. Use `--shim <name>` to test one installed shim in its owning output section. Use `--all` to test root default shims plus profile-owned non-default shims, with root and profile smoke results reported separately.

Tests verify:
- `/bin/sh` parser compatibility for the repo wrapper, shared shim helpers, repo lifecycle scripts, and all supported in-scope shims
- install, activate, status, available-shim comparison, machine-readable manifest output, update, startup-file repair, and uninstall behavior for default and upstream profiles
- Shimmy skill sharing, export, idempotent skills manifest updates, and install-time management skill sharing
- live Podman execution for the supported shim set: `aws`, `go`, `gcloud`, `gdrive`, `jq`, `netcat`, `nmap`, `opnsense-mcp-admin`, `opnsense-mcp-read-only`, `rg`, `task`, `terraform`, and `textual`

## Directory Structure
```
shimmy/
├── shimmy                        # Repo-root wrapper command
├── shims/                        # OCI wrapper scripts
│   ├── aws
│   ├── go
│   ├── gcloud
│   ├── gdrive
│   ├── jq
│   ├── netcat
│   ├── nmap
│   ├── opnsense-mcp-admin
│   ├── opnsense-mcp-read-only
│   ├── rg
│   ├── task
│   ├── tessl
│   ├── textual
│   └── terraform
├── images/                       # Custom shim image build contexts
│   ├── gdrive
│   ├── netcat
│   ├── opnsense-mcp-admin
│   ├── opnsense-mcp-read-only
│   ├── task
│   ├── tessl
│   └── textual
├── docs/
│   ├── podman.md                 # Podman setup, verification, troubleshooting, and hygiene
│   └── shims/                    # Per-shim quick-start documentation
├── lib/
│   ├── repo/                     # Repo-only sourced helpers for wrapper/scripts
│   └── shims/                    # Installed shared helper scripts for shims
├── scripts/
│   ├── agent-shimmy-preflight.sh # AI Agent approval preflight
│   ├── install-shimmy.sh         # Installation script
│   ├── skills-shimmy.sh          # Agent skill sharing/export script
│   ├── status-shimmy.sh          # Status script
│   ├── test-shimmy.sh            # Test suite
│   └── update-shimmy.sh          # Update script
├── plugins/
│   └── shimmy/                   # Packaged AI Agent plugin for Shimmy skills
├── .agents/
│   ├── plugins/                  # Local AI Agent plugin marketplace metadata
│   └── skills/                   # Repo-local agent skills used while developing Shimmy
├── .pre-commit-config.yaml       # Git https://github.com/pre-commit/pre-commit-hooks
├── .github/
│   └── workflows/
│       └── test.yml              # CI/CD workflow
└── README.md                     # This file
```

## AI Generation
This code was ![AI-developed](https://img.shields.io/badge/AI-Generated-blue) and human-reviewed/curated with AI Agent assistance.

## Contributor Guidance

Contributor guidance lives in `CONTRIBUTING.md`.

That document is the contributor source of truth, including naming conventions for files, functions, and variables. It is also referenced from `AGENTS.md` and the shared project prompt so future AI contributors pick it up automatically.

## License

See LICENSE file for details.
