# Shimmy

Shimmy makes common CLI tools available through small POSIX shell wrappers that
run containers with Podman. Tools use the current directory as `/work`, retain
their documented configuration and credential mounts, and expose image
overrides through `SHIMMY_*` environment variables.

## Context-first layout

Read [CONTEXT.md](CONTEXT.md) before changing the repository. Source code and
its operational context now share a hierarchy:

```text
commands/  management entrypoints
core/      shared catalog, profile, runtime, startup, and network behavior
tools/     one self-contained directory per tool kind and version
tests/     POSIX validation and context-tree verification
```

Each tool directory owns its guide, version metadata, concrete runtime,
container context, test guidance, and agent skill. `tool.conf` defines the
default version and optional selector; `commands/run-tool.sh` resolves it.

## Requirements

- POSIX-compatible `/bin/sh`
- Podman CLI and a reachable engine in the shell that invokes Shimmy

On macOS, the Podman pkg installer may place the binary at
`/opt/podman/bin/podman`. Run `podman machine start` and `podman info` from a
normal user shell before running a shim.

## Install and use

```sh
./shimmy install
eval "$(./shimmy activate)"
jq --version
rg --version

shimmy install --shim oc@4.18
SHIMMY_OC_VERSION=4.18 oc version
```

The management surface is unchanged:

```text
shimmy install | uninstall | activate | netinfo | skills | status | update | test
```

`default` is the normal installed profile. `upstream` is a maintainer profile
that executes a recorded source checkout. Select a profile with `--profile` or
`SHIMMY_PROFILE_ACTIVE`; an explicit flag wins.

Existing layout-version-1 installs are intentionally unsupported. Uninstall
the old installation and run `shimmy install` to create a layout-version-2
metadata-tree installation.

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
| task | [tools/task/guide.md](tools/task/guide.md) |
| terraform | [tools/terraform/guide.md](tools/terraform/guide.md) |
| tessl | [tools/tessl/guide.md](tools/tessl/guide.md) |
| textual | [tools/textual/guide.md](tools/textual/guide.md) |

## Development

Run the complete repository check from the root:

```sh
./shimmy test
```

For a tool-specific preview, invoke its generic dispatcher or the concrete
version runtime listed in its context:

```sh
./commands/run-tool.sh jq --preview-shim --version
./commands/run-tool.sh oc --preview-shim version
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [docs/testing.md](docs/testing.md), and
[docs/podman.md](docs/podman.md) for contributor, testing, and Podman details.
