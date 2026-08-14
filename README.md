# Shimmy

Shimmy makes common CLI tools available through small POSIX shell wrappers that
run containers with Podman. Tools mount the present working directory as `/work`, retain
their documented configuration and credential mounts, and expose image
overrides through `SHIMMY_*` environment variables.

## Requirements

- POSIX-compatible `/bin/sh`
- Podman CLI and a reachable engine in the shell that invokes Shimmy

On macOS, the Podman pkg installer may place the binary at
`/opt/podman/bin/podman`. Run `podman machine start` and `podman info` from a
normal user shell before running a shim.

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
| `shimmy catalog` | Publish or roll back `default`, or explicitly rebind `upstream`. |
| `shimmy images` | Verify pinned remote image indexes and report upstream drift. |
| `shimmy install` | Add explicitly selected tool shims to the profile. |
| `shimmy uninstall` | Remove one profile, or explicitly remove all Shimmy-owned state. |
| `shimmy netinfo` | Show host, VM, and container network perspectives. |
| `shimmy skills` | Install, update, uninstall, or export Shimmy agent skills. |
| `shimmy status` | Show installed shims, versions, and profile details. |
| `shimmy test` | Validate the profile with non-mutating shim smoke commands. |
| `shimmy update` | Refresh the profile and optionally pull or build tool images. |

Run `shimmy <command> --help` for command-specific options.

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

Profiles are independent materialized installations below an absolute
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>` root. A relative,
non-empty `XDG_CONFIG_HOME` is rejected. The `default` profile alone may own a
persistent startup block; `upstream` never changes shell startup files. Switch
profiles by sourcing the desired profile's `shell-init.sh`, not with an
installed command option or environment selector.

Shared named catalogs live beside profiles under the same `shimmy/` config
root. `upstream` is a validated live binding to one Git checkout, so a complete
schema-valid tool or skill edit is visible to upstream catalog operations on
the next command. `default` is an immutable generation published only from a
clean committed upstream checkout. Publication changes catalog availability;
installed profile versions remain materialized and unchanged until an explicit
`shimmy update` or `shimmy install --shim` operation selects the newer catalog
default.

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
