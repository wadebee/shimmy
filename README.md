# Shimmy

Shimmy makes common CLI tools available through small POSIX shell wrappers that
run containers with Podman. Tools mount the present working directory as `/work`, retain
their documented configuration and credential mounts, and expose image
overrides through `SHIMMY_*` environment variables.

## Context-first layout

Read [CONTEXT.md](CONTEXT.md) before changing the repository. Source code and
its operational context share the same hierarchy:

```text
commands/  management entrypoints
lib/       shared catalog, profile, runtime, startup, and network behavior
tools/     one self-contained directory per tool kind and version
tests/     POSIX validation and context-tree verification
```

Each tool directory owns its guide, version metadata, concrete runtime,
container context, test guidance, and agent skill. `tool.conf` defines the
default version and optional selector; `commands/run-tool.sh` resolves it.
This keeps the context an AI agent needs close to the files it may change,
reduces repository-wide scanning, and makes tool-specific guidance installable
from the canonical source tree.

## Requirements

- POSIX-compatible `/bin/sh`
- Podman CLI and a reachable engine in the shell that invokes Shimmy

On macOS, the Podman pkg installer may place the binary at
`/opt/podman/bin/podman`. Run `podman machine start` and `podman info` from a
normal user shell before running a shim.

## Install and use

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
| `shimmy install` | Add explicitly selected tool shims to the profile. |
| `shimmy uninstall` | Remove the profile and its managed startup integration. |
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
Install any other tool afterward with `shimmy install --shim <kind>`.

Executing `./install.sh` performs the same bootstrap for automation, but its
shell initialization ends with that process. To initialize another shell
directly from an existing profile, source its generated asset:

```sh
. "${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/shell-init.sh"
```

Each profile has its own self-contained `bin/shimmy`, and installed launchers
manage only their enclosing profile.

Profiles are independent flat installations below an absolute
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>` root. A relative,
non-empty `XDG_CONFIG_HOME` is rejected. The `default` profile alone may own a
persistent startup block; `upstream` never changes shell startup files. Switch
profiles by sourcing the desired profile's `shell-init.sh`, not with an
installed command option or environment selector.

Agent skills exported to a repository or home agent profile are external,
target-manifest-owned state. Every profile payload already includes canonical
agent sources and its packaged plugin skills. Profile install, update, and
uninstall do not implicitly refresh or remove repository or home exports. Use
the standalone `shimmy skills install --target repo|profile` or `shimmy skills
update --target repo|profile` operation to write those external targets, and
`shimmy skills uninstall --target repo|profile` to remove their manifest-owned
entries. The `plugin` target is the packaged bundle inside the invoking
profile, not a shared external target.

Earlier installation layouts are intentionally unsupported. Remove them with
the Shimmy version that created them, then bootstrap the desired profile.

## Preview a runtime command

`--preview-shim` prints the Podman command without contacting the engine,
pulling, building, or running a container:

```sh
jq --preview-shim --version
oc --preview-shim version
```

## Included tools

| Tool | Guide |
|---|---|
| aws | [tools/aws/guide.md](tools/aws/guide.md) |
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

## Development

Run the complete repository check from the root:

```sh
./tests/test.sh
```

For a tool-specific preview, invoke its generic dispatcher or the concrete
version runtime listed in its context:

```sh
./commands/run-tool.sh jq --preview-shim --version
./commands/run-tool.sh oc --preview-shim version
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [docs/testing.md](docs/testing.md), and
[docs/podman.md](docs/podman.md) for contributor, testing, and Podman details.
