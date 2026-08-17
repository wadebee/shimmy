# Shimmy

Shimmy makes common CLI tools available through small POSIX shell wrappers that
run containers with Podman. Tools mount the present working directory as `/work`, retain
their documented configuration and credential mounts, and expose image
overrides through `SHIMMY_*` environment variables.

## Requirements

- POSIX-compatible `/bin/sh`
- Podman CLI and a reachable local rootless engine in the shell that invokes
  Shimmy

On macOS, the Podman pkg installer may place the binary at
`/opt/podman/bin/podman`. Each profile uses a pre-existing named rootless
machine created explicitly in a normal user shell:

```sh
podman machine init shimmy-default
podman machine init shimmy-upstream
```

Shimmy never provisions, adopts, renames, or removes machines. Existing data
in `podman-machine-default` is not migrated or removed.

## Install and use

For first-time checkout prerequisites, entrypoint roles, profile selection,
and verification, see [BOOTSTRAP.md](BOOTSTRAP.md).

```sh
. ./install.sh
jq --version
rg --version

shimmy install --shim oc@4.18
SHIMMY_OC_VERSION=4.18 oc version
```

Each installed launcher exposes this management surface:

| Command | Purpose |
|---|---|
| `shimmy catalog` | List catalog tools, publish or roll back `default`, or rebind `upstream`. |
| `shimmy images` | Verify pinned remote image indexes and report upstream drift. |
| `shimmy install` | Add explicitly selected tool shims to the profile. |
| `shimmy uninstall` | Remove one profile, or explicitly remove all Shimmy-owned state. |
| `shimmy netinfo` | Show host, VM, and container network perspectives. |
| `shimmy profile` | Inspect or activate the engine and manage strict registry redirects. |
| `shimmy skills` | Install, update, uninstall, or export Shimmy agent skills. |
| `shimmy status` | Show installed shims, versions, and profile details. |
| `shimmy test` | Validate the profile with non-mutating shim smoke commands. |
| `shimmy update` | Refresh the profile and optionally pull or build tool images. |

Every second-level command supports `shimmy <command> --help` with its usage,
options, and examples. Command groups also summarize their third-level actions
when invoked without one; use `shimmy <group> <action> --help` for action
requirements and examples.

The repository contains only the minimal `install.sh` bootstrap; it does not
contain a runnable `shimmy` launcher. Source `. ./install.sh` to bootstrap
`default` and initialize the current shell, or source `. ./install.sh --profile
upstream` for the maintainer profile. Every bootstrap installs jq and rg.
Install any other tool afterward with `shimmy install --shim <tool>`.
An unqualified default bootstrap also installs its managed startup block for
zsh and for login and non-login interactive Bash sessions. Explicit `--shell`,
repeatable `--startup-file`, and `--no-startup` options narrow or disable those
updates.

Executing `./install.sh` performs the same bootstrap for automation, but its
shell initialization ends with that process. To initialize another shell
directly from an existing profile, source its generated asset:

```sh
. "${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/shell-init.sh"
```

Each profile has its own self-contained `bin/shimmy`, and installed launchers
manage only their enclosing profile.

On macOS, engine activation and shell selection are separate. The launcher
fixes the engine name (`default -> shimmy-default`, `upstream ->
shimmy-upstream`). Podman permits only one managed VM to run at a time, so
activation may stop one idle alternate machine and can interrupt workloads
hosted there. Running
containers are displayed and block a stop unless interruption is explicitly
acknowledged with `--stop-running`:

```sh
profile_root=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default
"$profile_root/bin/shimmy" profile status
"$profile_root/bin/shimmy" profile activate --dry-run
"$profile_root/bin/shimmy" profile activate
. "$profile_root/shell-init.sh"
```

On Linux, activation atomically selects the invoking profile's registry policy
through the exact user drop-in
`containers/registries.conf.d/shimmy-active-profile.conf`, then validates a
fresh current-user local-rootless Podman process. It never manages a VM.
Non-empty `CONTAINER_CONNECTION`, `CONTAINER_HOST`,
`CONTAINERS_REGISTRIES_CONF`, or `CONTAINERS_REGISTRIES_CONF_OVERRIDE` must be
unset; status reports only the masking variable name, never its value.

Each profile also owns a strict generated `registries.conf`. Redirect CRUD is
deterministic and profile-local:

```sh
shimmy profile redirect --prefix docker.io --location registry.corp.example/docker
shimmy profile redirect list
shimmy profile redirect remove --prefix docker.io
```

Linux status reports `current` only for the exact active profile link with a
reachable local-rootless engine; sibling or absent state is `inactive`, and
damaged, foreign, or masked state is `invalid`. Active Linux edits validate in
a fresh process and restore prior bytes on failure.

On macOS, activation installs only
`/etc/containers/registries.conf.d/shimmy-profile.conf` in the deterministic
profile machine as a same-path symlink to the host profile config, validates it
as the rootless VM user, and records its fingerprint locally. Active edits do
not restart the machine; they print the exact profile-local `profile activate
--restart` command. `remove --all --detach` removes only the invoking profile's
recognized Linux link or Darwin link/record. Uninstall refuses an attached
Darwin record. Skopeo is the only initial tool-container opt-in: a current
invoking profile mounts its authoritative file read-only, and `shimmy images
verify` inherits that policy without changing logical references. Profiles
with no activation omit the mount; mismatched, damaged, stale, unsafe, or
connection/registry-overridden state fails closed. Redirects use replacement
`location` with no configured mirror fallback. See
[docs/registries.md](docs/registries.md) for the full ownership and lifecycle
contract.

Profiles are independent materialized installations below an absolute
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>` root. A relative,
non-empty `XDG_CONFIG_HOME` is rejected. The `default` profile alone may own a
persistent startup block; `upstream` never changes shell startup files. Source
the desired profile's `shell-init.sh` to select PATH only; it never starts or
stops Podman or sets connection variables. Installed commands accept no profile
or machine selector.

Shared named catalogs live beside profiles under the same `shimmy/` config
root. `upstream` is a validated live binding to one Git checkout, so a complete
schema-valid tool or skill edit is visible to upstream catalog operations on
the next command. `default` is an immutable generation published only from a
clean committed upstream checkout. Publication changes catalog availability;
installed profile versions remain materialized and unchanged until an explicit
`shimmy update` or `shimmy install --shim` operation selects the newer catalog
default.

List the complete tool membership of the invoking profile's recorded catalog,
or select either named catalog without changing the active profile:

```sh
shimmy catalog list
shimmy catalog list --name upstream --format manifest
```

Use the upstream profile for catalog administration:

```sh
shimmy catalog publish
shimmy catalog rollback
shimmy catalog rebind --checkout /absolute/path/to/shimmy
```

Catalog-dependent operations fail before mutation when a registry, checkout,
generation, or schema is unavailable or invalid. Existing materialized tool
commands continue to run. Ordinary `shimmy uninstall` removes only the
invoking profile and leaves shared catalogs and sibling profiles intact;
`shimmy uninstall --global` explicitly removes every valid owned profile and
shared catalog, without deleting a bound source checkout or external skill
export.

Agent skills exported to a repository or home agent profile are external,
target-manifest-owned state. Canonical management and tool skills remain in
the invoking profile's named catalog and are not copied into profile payloads.
With no explicit skill names, export selects the core management skills plus
skills for tools installed in the invoking profile. The complete output is
staged and catalog-validated before the target changes. Profile and catalog
lifecycle operations do not implicitly refresh or remove repository or home
exports. Use the standalone `shimmy skills install --target repo|profile` or
`shimmy skills update --target repo|profile` operation to write those external
targets, and `shimmy skills uninstall --target repo|profile` to remove their
manifest-owned entries even if the source catalog is unavailable.
After accepting canonical skill changes in a newer catalog generation, use the
explicit `skills update` operation to refresh an existing target; generated
adapters are never refreshed by profile lifecycle commands.

Earlier installation layouts are intentionally unsupported. Remove them with
the Shimmy version that created them, then bootstrap the desired profile.

## Preview a runtime command

`--preview-shim` prints the Podman command without contacting the engine,
pulling, building, or running a container:

```sh
jq --preview-shim --version
oc --preview-shim version
```

Every concrete version owns an `image.conf` that records its public or
authenticated upstream reference, immutable multi-architecture default, and
the required `linux/amd64` and `linux/arm64` platforms. Direct runtimes consume
the pinned digest. Local builds consume configured pinned base digests, and
their cache identity changes with the image configuration, effective build
arguments, context, or selected native platform. Runtime image and base-image
overrides retain their documented `SHIMMY_*` names.

`shimmy update --pull` re-fetches the configured immutable digest; it does not
advance the recorded upstream tag. Adopting a newer upstream artifact requires
a reviewed `image.conf` change.

For a digest rotation, resolve the publisher tag to its top-level index,
verify `linux/amd64` and `linux/arm64`, update only the affected version's
`image.conf`, confirm any local-build cache identity changes, and run the
version-owned smoke on native Linux `amd64` and Apple Silicon `arm64` hosts.
Record the previous digest in review notes as the rollback reference; git
history retains the actual prior value. Upstream drift reported by the verifier
does not modify the pinned snapshot automatically.

Run explicit remote verification when reviewing those pinned defaults:

```sh
shimmy images verify
shimmy images verify --all --public-only
shimmy images verify --shim oc@4.18 --require-current-upstream
```

Installed verification defaults to concrete versions recorded in the invoking
profile. `--all` selects every catalog version, repeated `--shim` selects a tool
default or an exact `tool@version`, and `--format manifest` emits stable
machine-readable result lines. Source-checkout use is
`./commands/images.sh verify` and requires `--all` or an explicit `--shim`.
The command inspects manifests without pulling target layers and never changes
`image.conf`. Upstream movement is a warning unless
`--require-current-upstream` is set. Authenticated entries require the Skopeo
runtime's explicit `SHIMMY_SKOPEO_AUTH_SECRET`; `--public-only` reports them as
skipped rather than verified.

Shimmy detects both host OS and CPU. Supported Linux and Darwin hosts running
on `amd64` or `arm64` select the matching native Linux image platform;
unsupported or unreadable host values fail before Podman is invoked.

## Included tools

| Tool | Guide |
|---|---|
| aws | [tools/aws/guide.md](tools/aws/guide.md) |
| community-ansible-dev-tools | [tools/community-ansible-dev-tools/guide.md](tools/community-ansible-dev-tools/guide.md) |
| gcloud | [tools/gcloud/guide.md](tools/gcloud/guide.md) |
| gdrive | [tools/gdrive/guide.md](tools/gdrive/guide.md) |
| gh | [tools/gh/guide.md](tools/gh/guide.md) |
| go | [tools/go/guide.md](tools/go/guide.md) |
| jq | [tools/jq/guide.md](tools/jq/guide.md) |
| netcat | [tools/netcat/guide.md](tools/netcat/guide.md) |
| nmap | [tools/nmap/guide.md](tools/nmap/guide.md) |
| npx | [tools/npx/guide.md](tools/npx/guide.md) |
| oc | [tools/oc/guide.md](tools/oc/guide.md) |
| opnsense-mcp-admin | [tools/opnsense-mcp-admin/guide.md](tools/opnsense-mcp-admin/guide.md) |
| opnsense-mcp-read-only | [tools/opnsense-mcp-read-only/guide.md](tools/opnsense-mcp-read-only/guide.md) |
| rg | [tools/rg/guide.md](tools/rg/guide.md) |
| skopeo | [tools/skopeo/guide.md](tools/skopeo/guide.md) |
| task | [tools/task/guide.md](tools/task/guide.md) |
| terraform | [tools/terraform/guide.md](tools/terraform/guide.md) |
| tessl | [tools/tessl/guide.md](tools/tessl/guide.md) |
| textual | [tools/textual/guide.md](tools/textual/guide.md) |

## AI Aware repo layout

Agents are instructed via [AGENTS.md](AGENTS.md) to read [CONTEXT.md](CONTEXT.md)
before changing the repository. Retained module contexts cover management,
shared-library, and test code; tool and management-plugin guidance lives in
their guides and canonical skills:

```text
commands/  management entrypoints
lib/       shared catalog, profile, runtime, startup, and network behavior
tools/     one self-contained directory per tool and version
tests/     POSIX validation and retained context-tree verification
```

Each tool directory owns its guide, version metadata including `image.conf`, concrete runtime,
container context, test guidance, and canonical `SKILL.md`. `tool.conf` defines the
default version and optional selector; `commands/run-tool.sh` resolves it.
This keeps tool-specific operating guidance close to the files it may change
and makes that guidance installable from the canonical source tree.

## Contributor Guidance and Testing

See [CONTRIBUTING.md](CONTRIBUTING.md), [docs/testing.md](docs/testing.md), and
[docs/podman.md](docs/podman.md) for contributor, testing, and Podman details.

Run a complete repository check from the root:

```sh
./tests/test.sh
```

For a tool-specific preview, invoke its generic dispatcher or a concrete
version runtime selected by `tool.conf`:

```sh
./commands/run-tool.sh jq --preview-shim --version
./commands/run-tool.sh oc --preview-shim version
```
