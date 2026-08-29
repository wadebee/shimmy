# Shimmy Context

Shimmy packages CLI tools as small POSIX shell wrappers around `podman run`.
The repository is both the source catalog and the source control plane.

## Public model

- `bootstrap.sh` is the sole checkout lifecycle entrypoint. It delegates to
  `commands/bootstrap.sh`, creates and activates `default`, and sources the
  installed shell initializer when itself sourced.
- Installed `bin/shimmy` launchers expose only `admin`, `profile`, `catalog`,
  `shim`, and `ai-skill` groups.
- `commands/run-tool.sh` remains a contributor/source dispatcher;
  `commands/agent-preflight.sh` renders AI-agent smoke approval guidance.
- There is no repository `shimmy` launcher, compatibility command forwarding,
  implementation-name routing, or generated repository `.agents/skills` tree.

## Installation state

State lives below `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy`:

- `catalogs/default/` contains one registry and retained immutable generations,
  each with exactly `catalog.conf`, `generation.conf`, and `tools/`;
- `profiles/<name>/` contains independent control/runtime materializations;
- `engines/<id>/` contains engine identity, ownership, projection, and lifecycle
  state;
- `active-profile.conf` records the installation-wide active profile and exact
  user skill root.

Profile names use lowercase letters, digits, and single hyphens. Every profile
holds a schema-1 engine binding to a strict engine record and records schema
identity, source `refs/heads/main` and exact control commit, one independently
retained default-catalog generation, shim tracking/pinning and concrete-version
roles, startup ownership, and validated AI-skill bundles.

Catalog publication accepts only a clean committed attached local `main`
checkout and archives and fingerprints only `catalog.conf` plus `tools/`.
Content-equivalent publication reuses the retained generation and its original
provenance; equivalent current content is a registry-preserving no-op. Profiles
do not follow source or registry changes implicitly; `profile sync` or shim
operations adopt applicable content explicitly.

## Transactions and ownership

Catalog, profile, shim, startup, registry, engine, active-record, and skill-link
changes use staged validation, locks, exact commit checks, and compensating
rollback. Preserve the last valid manifest or registry until its replacement is
committed. Unrecognized or unsafe state blocks mutation.

Machine creation writes durable initializing intent before Podman mutation.
Compensation removes only a machine with committed exact created-identity
evidence; an ambiguous init or incomplete removal retains its lifecycle journal
and installation state instead of deleting by name.

Activation is the authority boundary for engine, registry, active record, and
AI-skill links. Exact bundle-declared user skill destinations are overwritten
without backup or recovery. Only recognized stale links may be removed; never
recursively clean the user skill root or unrelated names.

Profile deletion removes an exactly proven owned isolated macOS engine through
a durable removal journal and preserves shared, external, and ambiguous
engines. Global owned-engine removal remains the durable uninstall transaction's
responsibility.

## Podman and runtimes

Podman is an explicit dependency. Shimmy never installs Podman or adopts a
pre-existing machine. Fresh macOS bootstrap transactionally creates the owned
shared `shimmy-default` machine; explicit isolated profiles create independently owned
`shimmy-<profile>` machines. Ordinary profiles share the installation-owned
`shimmy-default` engine. Same-engine policy changes recycle only its rootless API service.
On Linux profiles share the current user's local rootless engine and Shimmy
performs no machine operation.

The runtime helper normalizes supported Linux/Darwin `amd64` and `arm64` hosts
to native `linux/amd64` or `linux/arm64`. Concrete versions own `run.sh`,
`smoke.conf`, `image.conf`, refresh behavior, and local container contexts.
Runtimes mount `$PWD:/work` unless documented otherwise. Skopeo is the initial
registry-policy consumer; catalog verification inherits that policy through
Skopeo.

Every Shimmy-defined user environment variable uses `SHIMMY_`. Tool-native
variables are forwarded only where documented.

## Source map

- [`commands/`](commands/CONTEXT.md): checkout and installed management entrypoints
- [`lib/`](lib/CONTEXT.md): shared sourceable modules
- `tools/<tool>/`: catalog-owned metadata, canonical tool skill, guide, tests,
  and versions
- `plugins/shimmy/skills/`: control-plane-only canonical management skills,
  discovered dynamically at an exact profile source commit
- [`tests/`](tests/CONTEXT.md): bounded POSIX behavioral suite
- `docs/`: contributor and subsystem documentation
- `plans/`: retained plans and evidence

Read relevant child context before changing `commands/`, `lib/`, or `tests/`.
Tool and plugin trees use their guide and canonical skill instead of child
context files.
