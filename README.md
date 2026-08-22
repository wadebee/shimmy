# Shimmy

Shimmy exposes CLI tools through small POSIX shell wrappers that run containers
with Podman. Tool runtimes mount the current directory at `/work`, select the
native Linux platform, and retain each tool's documented configuration and
credential boundaries.

> **Overwrite warning:** profile activation and `shimmy ai-skill repair`
> unconditionally replace every exact skill destination declared by the active
> profile's bundles. Shimmy creates no backup and provides no recovery for
> overwritten foreign content. It never recursively deletes the user's skill
> root or unrelated skill names. Run `shimmy profile activate <name> --dry-run`
> before activation to inspect exact collisions.

## Requirements

- POSIX-compatible `/bin/sh`
- Git
- Podman CLI and a reachable local rootless engine

Shimmy does not install, provision, adopt, rename, or delete Podman. On macOS,
create the deterministic machine for each profile in a normal user shell before
using that profile, for example:

```sh
podman machine init shimmy-default
podman machine init shimmy-team-one
```

The official macOS package may install Podman at `/opt/podman/bin/podman`.

## Bootstrap

Bootstrap from a clean, committed checkout on the attached local `main` branch:

```sh
. ./bootstrap.sh
jq --version
rg --version
```

The bootstrap creates and activates `default`, publishes the checkout as the
first immutable `default` catalog generation, installs jq, rg, and Skopeo, and
sources the generated `shell-init.sh` when the bootstrap itself is sourced.
Executing `./bootstrap.sh` performs the same installation but cannot change its
parent shell.

Use `--shell <bash|zsh|sh|ksh|mksh>` to select the recorded startup shell or
`--no-startup` to record manual startup policy. The installation root is
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy`; a non-empty `XDG_CONFIG_HOME` must
be absolute. Bootstrap refuses any pre-existing installation root instead of
merging or migrating it.

See [BOOTSTRAP.md](BOOTSTRAP.md) for first-contact installation and engine
preparation.

## Command surface

The installed launcher has five groups:

| Group | Purpose |
|---|---|
| `shimmy admin` | Inspect network/installation state or uninstall all owned state. |
| `shimmy profile` | List, inspect, create, activate, sync, repair, or delete profiles and redirects. |
| `shimmy catalog` | Inspect, verify, publish, or roll back the immutable default catalog. |
| `shimmy shim` | Add, remove, select, sync, list, or test profile-local tool versions. |
| `shimmy ai-skill` | Inspect or repair active-profile skill links. |

Help is state-independent:

```sh
shimmy --help
shimmy profile --help
shimmy profile activate --help
```

There are no compatibility aliases for the previous `install`, `update`,
`images`, `skills`, `status`, `test`, `netinfo`, or `uninstall` top-level
commands. Remove an older layout with the Shimmy version that created it before
bootstrapping this one.

## Profiles and activation

Profiles are independent materialized installations below
`.../shimmy/profiles/<name>`. Names use lowercase letters, digits, and single
hyphens. The launcher containing the command is the invoking profile; the
installation-wide active record independently owns engine, registry, mutation,
and user-skill-link authority.

Create and inspect a sibling safely:

```sh
shimmy profile create team-one --dry-run
shimmy profile create team-one
shimmy profile list
```

Creation activates the new profile. To switch back, inspect the transition
before applying it, then source the selected profile in the current shell:

```sh
shimmy profile activate default --dry-run
shimmy profile activate default
. "${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/shell-init.sh"
```

On Linux, activation selects the exact user registry-policy link and validates
the current user's local rootless Podman process. On macOS, it uses the
pre-existing same-name `shimmy-<profile>` machine and may need to stop an idle
alternate machine or restart the selected machine after registry changes.
Running containers block interruption unless the separately reviewed command
includes `--stop-running`. Shimmy never provisions a missing machine.

`CONTAINER_CONNECTION`, `CONTAINER_HOST`, `CONTAINERS_REGISTRIES_CONF`, and
`CONTAINERS_REGISTRIES_CONF_OVERRIDE` can mask profile authority and therefore
fail closed. Diagnostics name the variable but do not print its value.

Registry redirects are profile-local:

```sh
shimmy profile redirect list
shimmy profile redirect set --prefix docker.io \
  --location registry.corp.example/docker --dry-run
shimmy profile redirect delete --prefix docker.io
```

Skopeo is the only initial tool-container consumer of this policy.
`shimmy catalog verify` inherits it through the active profile's Skopeo shim.

## Catalog and shims

The installation owns exactly one catalog named `default`. It contains retained
immutable generations. Each profile pins one generation, so publication and
rollback never silently change installed profile contents.

```sh
shimmy catalog status
shimmy catalog tools
shimmy catalog verify --tool jq@1.8 --format manifest
```

`shimmy catalog publish` must run at a clean committed checkout root on attached
local `main`; it publishes tracked `catalog.conf`, `tools/`, and canonical
`plugins/shimmy/skills/` content. `shimmy catalog rollback` selects the retained
previous valid generation without deleting generations. `shimmy profile sync`
updates the invoking active profile from `refs/heads/main` and reconciles its
materialized assets explicitly.

Shim selectors are `tool` or `tool@version` without catalog prefixes:

```sh
shimmy shim add task@3.45
shimmy shim list --format manifest
shimmy shim set-version oc@4.20
shimmy shim sync oc
shimmy shim test oc@4.20
```

An unqualified `shim add` is interactive and records tracking policy. An exact
first selection is noninteractive and records pinned policy. Every profile owns
its direct `bin/<tool>` wrapper and concrete version assets; no implementation-
name routing layer exists.

## AI skills

Canonical management skills live under `plugins/shimmy/skills/`; tool skills
live beside each tool under `tools/<tool>/SKILL.md`. Installed profiles hold
validated bundles and reconcile direct links in the active user's
`$HOME/.agents/skills` directory.

```sh
shimmy ai-skill list --format manifest
shimmy ai-skill repair
```

Only exact bundle-declared names are replaced. Recognized stale Shimmy links may
be removed; unrelated names and the skill root itself are preserved. This
repository deliberately does not contain generated `.agents/skills` adapters.

## Administration and removal

```sh
shimmy admin status --format manifest
shimmy admin network --format manifest
shimmy admin uninstall
```

Uninstall validates ownership before removing all profiles, retained catalog
state, the active record, exact startup blocks, recognized registry projections,
and recognized direct Shimmy skill links. It preserves source checkouts, Podman
machines, unrelated registry policy, unrelated skill names, and the user skill
root. If macOS cleanup requires interrupting listed workloads, review the output
and retry with `--stop-running` only after explicit acceptance.

## Tool guides

| Tool | Guide |
|---|---|
| aws | [tools/aws/guide.md](tools/aws/guide.md) |
| bats | [tools/bats/guide.md](tools/bats/guide.md) |
| community-ansible-dev-tools | [tools/community-ansible-dev-tools/guide.md](tools/community-ansible-dev-tools/guide.md) |
| gcloud | [tools/gcloud/guide.md](tools/gcloud/guide.md) |
| gdrive | [tools/gdrive/guide.md](tools/gdrive/guide.md) |
| gh | [tools/gh/guide.md](tools/gh/guide.md) |
| go | [tools/go/guide.md](tools/go/guide.md) |
| jq | [tools/jq/guide.md](tools/jq/guide.md) |
| logmine | [tools/logmine/guide.md](tools/logmine/guide.md) |
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

## Development

Source previews remain available without contacting Podman:

```sh
./commands/run-tool.sh jq --preview-shim --version
./tests/test.sh --list-groups
./tests/test.sh
```

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing the repository. Registry
ownership details are in [docs/registries.md](docs/registries.md).
