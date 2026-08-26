# Shimmy

Shimmy is a profile-aware OCI tool harness that exposes containerized tool implementations as ordinary host CLI commands, with version selection, runtime isolation, registry policy, and AI-agent tool integration. Tool runtimes mount the current directory at `/work`, select the native Linux platform, and retain each tool's documented configuration and
credential boundaries.

                         SHIMMY PROFILE
                              │
              ┌───────────────┼────────────────┐
              │               │                │
        tool policy      runtime policy   registry policy
              │               │                │
              ▼               ▼                ▼
          jq@1.8          shared/isolated   image redirect
          rg@15.1             engine
              │
              ▼
         host-visible
            shims
              │
              ▼
      implementation resolution
              │
              ▼
           OCI image
              │
              ▼
       isolated tool process

## Requirements

- POSIX-compatible `/bin/sh`
- Git
- Podman CLI and a reachable local rootless engine

Shimmy does not install Podman or adopt existing machines. On macOS, fresh
bootstrap provisions the installation-owned shared machine `shimmy-default`; leave that
machine and connection name unused beforehand. Existing per-profile machines
are recorded only by explicit migration and remain external.

The official macOS package may install Podman at `/opt/podman/bin/podman`.
Machine creation uses the Podman 5.8-compatible `machine init <name>` command
surface and preserves any existing default connection itself.

## Host CA bundles

CA-aware tool implementations can opt in to one host trust file with
`SHIMMY_HOST_CA_BUNDLE=/absolute/path/to/bundle.pem`. Shimmy validates that the
configured path is an absolute, readable regular file, mounts that exact file
read-only at `/tmp/shimmy-host-ca-bundle.pem`, and explicitly assigns the
implementation's native CA variable to the container path. The host-only
`SHIMMY_HOST_CA_BUNDLE` variable is not forwarded. Unset or empty leaves the
Podman command unchanged.

| Opted-in implementation | Native container assignment |
|---|---|
| AWS CLI `2.31` | `AWS_CA_BUNDLE` |
| Google Cloud CLI `573.0` | `CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE` |
| npx `24.18`, gdrive `0.2`, Tessl `0.1` | `NODE_EXTRA_CA_CERTS` |
| Go `1.26`, Terraform `1.15`, GitHub CLI `2.94`, Task `3.45` | `SSL_CERT_FILE` |
| OpenShift CLI `4.18`, `4.20`, `4.22`; Skopeo `1.22` | `SSL_CERT_FILE` |
| OPNsense MCP read-only `0.4` | `SSL_CERT_FILE` |

Node's `NODE_EXTRA_CA_CERTS` augments built-in public roots. The AWS, Google
Cloud CLI, Go, and HTTPX mechanisms can replace normal trust-file discovery or
have implementation-specific precedence. Supply a combined public and
corporate bundle when the selected runtime must trust both; Shimmy does not
discover, merge, parse, or install certificates. Application-specific CA flags
or configuration can still take precedence. For OPNsense MCP read-only, also
set `OPNSENSE_VERIFY_SSL=true`; Shimmy then gives the same host bundle to the
curl reachability preflight through `--cacert`.

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
parent shell. On macOS it transactionally creates the installation-owned shared
machine and connection named `shimmy-default`; an exact pre-existing name is a collision
and is never adopted. On Linux it records the current local rootless engine as
the shared host-local engine.

Use `--shell <bash|zsh|sh|ksh|mksh>` to select the recorded startup shell or
`--no-startup` to record manual startup policy. The installation root is
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy`; a non-empty `XDG_CONFIG_HOME` must
be absolute. Bootstrap refuses any pre-existing installation root instead of
merging or migrating it.

A failed bootstrap normally removes its fresh installation root. If Podman
machine initialization is ambiguous or exact rollback cannot finish, Shimmy
reports incomplete rollback and retains the root plus engine lifecycle journal
as recovery evidence. Do not retry bootstrap or delete/adopt the machine by
name; inspect the reported state first.

See [BOOTSTRAP.md](BOOTSTRAP.md) for first-contact installation and engine
preparation.

## Command surface

The installed launcher has five groups:

| Group | Purpose |
|---|---|
| `shimmy admin` | Inspect engine, network, or installation state and manage installation lifecycle. |
| `shimmy profile` | List, inspect, create, clone, activate, sync, repair, or delete profiles and redirects. |
| `shimmy catalog` | Inspect, verify, publish, or roll back the immutable default catalog. |
| `shimmy shim` | Add, remove, select, sync, list, or test profile-local tool versions. |
| `shimmy ai-skill` | Inspect or repair active-profile skill links. |

Invoking the launcher, any group, or the `profile redirect` subgroup without a
child command is exactly equivalent to adding `--help`: it exits successfully,
writes the same bytes to stdout, writes nothing to stderr, and does not validate
or mutate installed state. Actions are different: they retain their documented
defaults or require their documented inputs.

```sh
shimmy
shimmy --help
shimmy profile
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

Ordinary creation binds the profile to the shared engine. On macOS, an explicit
isolated profile provisions a separately owned machine and warns before that
machine is later destroyed:

```sh
shimmy profile create isolated-one --isolated --dry-run
shimmy profile create isolated-one --isolated
shimmy profile delete isolated-one --dry-run
shimmy profile delete isolated-one
```

Creation activates the new profile. Clone copies supported profile-owned
configuration and selection state, then activates the target. Shared sources
clone to the shared engine by default; isolated and legacy-isolated sources
create a new owned isolated machine. Use one explicit override when needed:

```sh
shimmy profile clone default team-two --dry-run
shimmy profile clone isolated-one isolated-two --shared
```

To switch back, inspect the transition
before applying it, then source the selected profile in the current shell:

```sh
shimmy profile activate default --dry-run
shimmy profile activate default
. "${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/shell-init.sh"
```

Ordinary profiles bind to one shared engine. On Linux, activation selects the
exact user registry-policy link and validates the current user's local rootless
Podman process. On macOS, shared-to-shared activation keeps the installation's
owned shared VM (`shimmy-default` for fresh installations or `shimmy` after
compatibility migration) and running containers up. A changed effective
registry policy causes only a brief rootless Podman API interruption while
`podman.service` is recycled; equal
policies require no recycle. A transition between shared and isolated engines
stages the target policy before starting it, stops the prior machine only when
required, and requires `--stop-running` if that interruption would affect
listed workloads. `--restart` remains explicit VM recovery and is not part of
normal shared-profile switching.

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

Active-profile edits update and validate the engine projection immediately;
inactive-profile edits change only their source policy until later activation.

Installations created before the engine registry can inspect and migrate it
explicitly after updating their installed controls:

```sh
shimmy admin engine status --format manifest
shimmy admin engine migrate --dry-run
shimmy admin engine migrate
```

Migration records existing macOS profile machines as external legacy-isolated
engines without renaming, claiming, starting, stopping, or deleting them, then
creates the reserved `shimmy` engine for future shared profiles.

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
shimmy admin uninstall --dry-run
shimmy admin uninstall
```

Uninstall validates ownership before removing all profiles, retained catalog
state, the active record, exact startup blocks, recognized registry projections,
and recognized direct Shimmy skill links. On macOS it also removes every shared
or isolated machine whose complete current host, guest, connection, and inspect
evidence proves Shimmy ownership. It preserves source checkouts, legacy,
external, ambiguous, and Linux host-local engines, unrelated registry policy,
unrelated skill names, and the user skill root.

> **Destructive uninstall warning:** removing an owned machine permanently
> destroys its containers, images, volumes, build caches, and all other VM-local
> data. None of that data will be preserved. Run `--dry-run` first. Listed
> running containers require explicit `--stop-running` acknowledgement.

Machine deletion cannot be rolled back. Shimmy records ordered pending and
completed engines before the first stop or removal. A partial failure retains
the installation and journal, reports preserved/completed/pending engines, and
prints the exact retry command. Reused names are collisions and are never
treated as the machine that was already removed.

Deleting a shared profile never removes the shared engine. Deleting a profile
with a fully proven Shimmy-owned isolated engine permanently deletes that
machine and all VM-local containers, images, volumes, build cache, and other
data. Legacy, external, or ambiguously owned machines are preserved.

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
