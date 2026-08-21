# Shimmy

Shimmy exposes common CLI tools through small POSIX shell wrappers that run
Podman containers. Read this file first, then the retained `CONTEXT.md` files
on the path to changed code under `commands/`, `lib/`, or `tests/`. Tool and
management-plugin directories deliberately have no context-file hierarchy.

## Architecture

- `commands/` is the public management-command surface.
- `lib/` contains shared catalog, profile, runtime, startup, and networking
  modules.
- `lib/registries/` owns strict profile registry redirect data, atomic
  profile-local transactions, the exact Linux active-profile drop-in, and the
  exact Darwin VM projection plus local fingerprint record lifecycle.
- `commands/profile.sh` and `lib/profile/activation.sh` own explicit
  profile-bound Podman engine status and activation plus uninstall's guarded
  Darwin cleanup transitions. Shell initialization owns PATH selection only.
- `bootstrap.sh` bootstraps one canonical profile with the fixed jq/rg baseline
  and sources its generated `shell-init.sh`; the repository has no runnable
  `shimmy` launcher and does not accept tool selection. Sourcing the bootstrap
  retains shell initialization, while execution remains suitable for
  automation and absolute-path self-update. Explicit `--activate` performs a
  post-commit profile activation through the shared state machine, selects a
  required stale Darwin restart, and never acknowledges running workloads;
  activation failure retains the installed profile. Fresh default bootstrap
  records one immutable normalized startup shell and a managed exact-path or
  manual policy; an identifiable running-shell discrepancy requires consent
  before managed startup mutation, and later lifecycle operations inherit that
  manifest-owned state.
- `tools/` owns each tool's metadata, versions, container context, guide, and
  canonical skill.
- `plugins/shimmy/skills/` owns the five canonical control-plane skills.
- `tests/` contains the POSIX test runner and shared test support.

Installed profiles are independent materialized control/runtime trees under
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`. Each owns its
own `bin/shimmy`; no installed control payload is shared between profiles.
Each `tools/` tree contains only manifest-selected tool metadata and concrete
version assets. Public `bin/<tool>` links dispatch through the profile-local
`commands/run-tool.sh`; exact-version smokes execute the selected materialized
runtime directly. Canonical skills remain catalog-owned.

## Invariants

- Runtime code is POSIX shell and uses `set -eu`.
- User-facing tool variables use the `SHIMMY_` prefix.
- Tool runs mount `$PWD` at `/work` unless its local context documents why.
- Supported Linux and Darwin hosts select the matching native
  `linux/amd64` or `linux/arm64` image platform; unsupported hosts fail closed.
- Every concrete version owns validated `image.conf` metadata with immutable
  multi-platform defaults.
- Every current profile owns one mode-`0644`, regular non-symlink
  `registries.conf` with exact profile/version markers.
- Linux activation owns only the exact user
  `registries.conf.d/shimmy-active-profile.conf` symlink and validates policy
  with a fresh local-rootless Podman process.
- Darwin activation owns only the exact VM-side
  `/etc/containers/registries.conf.d/shimmy-profile.conf` symlink and a strict
  profile-local projection record; same-path rootless validation precedes
  engine validation and the global connection commit.
- Podman is an explicit dependency; do not provision it from Shimmy.
- Darwin profiles map deterministically to pre-existing `shimmy-<profile>`
  rootless engines; the current public version-1 surface still admits only
  `default` and `upstream`, while the private version-2 surface admits safe
  names. Activation is workload-guarded and commits the global default
  connection last. Stale policy requires explicit restart; uninstall
  transactionally detaches retained projections, clears live cache, and
  restores the initial engine/default state before deletion.
- Skopeo alone mounts a valid current invoking-profile registry policy
  read-only; no activation omits it, invalid state fails closed, and image
  verification inherits the mount without rewriting logical references.
- The uninstalled target catalog candidate verifies current catalog images
  only through jq and Skopeo runtimes from the active target profile's
  materialization; the current public image route remains unchanged.
- The uninstalled target shim candidate mutates only the active disposable
  version-2 profile against its retained catalog pin. It stages direct
  `<tool>|<version>` runtimes, prepares images before a manifest-last commit,
  regenerates the typed shim AI-skill bundle, and reconciles exact active user
  links through bounded external compensation.
- The uninstalled target profile candidate accepts arbitrary safe profile
  names, maps them to deterministic `shimmy-<profile>` engines, and coordinates
  engine/registry activation, the mode-`0644` active record, exact home
  AI-skill links, and shell selection under the target lock hierarchy. Its
  launcher, command, and sourced shell wrapper remain private through Chunk 9;
  current public profile and bootstrap routing is unchanged.
- The private target lifecycle candidate now integrates pristine default
  bootstrap, invoking-revision create, explicit-main/registry-current sync,
  startup repair, guarded deletion, aggregate administration, active network
  inspection, and fail-closed owned-state uninstall. Dry-run performs only
  state reads/classification and leaves no filesystem, engine, registry,
  startup, active-record, or user-link mutation behind.
- Version-1 default manifests own exactly one normalized startup shell and zero
  or more exact absolute startup paths; upstream manifests own neither field.

## Child contexts

- [commands](commands/CONTEXT.md)
- [shared library](lib/CONTEXT.md)
- [tests](tests/CONTEXT.md)

## Maintaining this tree

The default test suite verifies that every source-bearing directory has a
linked context file and that referenced paths exist. When changing a module,
update only its closest context and its parent link. Periodically ask an LLM:
“Read the CONTEXT tree and verify it is up to date.”
