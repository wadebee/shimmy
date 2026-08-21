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

- `catalogs/default/` contains one registry and retained immutable generations;
- `profiles/<name>/` contains independent control/runtime materializations;
- `active-profile.conf` records the installation-wide active profile and exact
  user skill root.

Profile names use lowercase letters, digits, and single hyphens. Every profile
records schema-2 identity, source `refs/heads/main` and commit, one retained
default-catalog generation, shim tracking/pinning and concrete-version roles,
startup ownership, and validated AI-skill bundles.

Catalog publication accepts only a clean committed attached local `main`
checkout. Profiles do not follow registry changes implicitly; `profile sync`
or shim operations adopt content explicitly.

## Transactions and ownership

Catalog, profile, shim, startup, registry, engine, active-record, and skill-link
changes use staged validation, locks, exact commit checks, and compensating
rollback. Preserve the last valid manifest or registry until its replacement is
committed. Unrecognized or unsafe state blocks mutation.

Activation is the authority boundary for engine, registry, active record, and
AI-skill links. Exact bundle-declared user skill destinations are overwritten
without backup or recovery. Only recognized stale links may be removed; never
recursively clean the user skill root or unrelated names.

Uninstall removes validated Shimmy-owned installation state and preserves source
checkouts, Podman machines, unrelated registry policy, unrelated user skills,
and the user skill root.

## Podman and runtimes

Podman is an explicit dependency. Shimmy never installs it or provisions,
adopts, renames, migrates, or deletes machines. On macOS, a profile uses the
pre-existing deterministic `shimmy-<profile>` machine/connection. On Linux it
validates the current user's local rootless engine.

The runtime helper normalizes supported Linux/Darwin `amd64` and `arm64` hosts
to native `linux/amd64` or `linux/arm64`. Concrete versions own `run.sh`,
`smoke.conf`, `image.conf`, refresh behavior, and local container contexts.
Runtimes mount `$PWD:/work` unless documented otherwise. Skopeo is the initial
registry-policy consumer; catalog verification inherits that policy through
Skopeo.

Every Shimmy-defined user environment variable uses `SHIMMY_`. Tool-native
variables are forwarded only where documented.

## Source map

- `commands/`: checkout and installed management entrypoints
- `lib/`: shared sourceable modules
- `tools/<tool>/`: metadata, canonical skill, guide, tests, and versions
- `plugins/shimmy/skills/`: canonical management skills
- `tests/`: bounded POSIX behavioral suite
- `docs/`: contributor and subsystem documentation
- `plans/`: retained plans and evidence

Read relevant child context before changing `commands/`, `lib/`, or `tests/`.
Tool and plugin trees use their guide and canonical skill instead of child
context files.
