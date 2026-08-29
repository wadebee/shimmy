---
name: shimmy-install
description: Install, inspect, activate, synchronize, repair, or remove Shimmy profiles and their direct AI-skill links. Use for first-time bootstrap, disposable XDG validation, profile lifecycle, startup integration, and owned-state removal.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Shimmy Installation Lifecycle

## Source of truth

- Read repository `BOOTSTRAP.md` before first-time installation.
- Use root `./bootstrap.sh` from a clean committed attached `main` checkout.
- In an installation, use the desired profile's absolute `bin/shimmy` launcher
  or `shimmy` after sourcing that profile's `shell-init.sh`.
- Inspect with `shimmy admin status --format manifest`, `shimmy profile status
  --format manifest`, and `shimmy shim list --format manifest`.
- Never edit manifests, active records, registry files, or bundles directly.

The repository has no runnable `shimmy` launcher and no generated
`.agents/skills` adapter tree. Canonical management skills live under
`plugins/shimmy/skills`; tool skills live under `tools/<tool>/SKILL.md`.

## First contact

When no checkout exists, install this canonical skill with `$skill-installer`
from:

```text
https://github.com/wadebee/shimmy/tree/main/plugins/shimmy/skills/shimmy-install
```

Refresh agent harness to pickup new Shimmy skills, create or use a checkout, read `BOOTSTRAP.md`, and continue from
the checkout. Do not treat the installed skill copy as a source tree.

## Bootstrap

```sh
. ./bootstrap.sh
```

Bootstrap creates and activates only a `default` profile, publishes the first immutable
default-catalog generation, installs default toolset, reconciles direct user skill
links, applies startup policy, and sources the generated shell initializer when
itself sourced. It accepts only `--shell <name>` and `--no-startup` lifecycle
options. The config root must not already exist.

For disposable validation, use fresh absolute `HOME` and `XDG_CONFIG_HOME`
roots and `./bootstrap.sh --no-startup`. Do not invent an install-directory,
profile, source, activation, or migration option.

Bootstrap activation is part of one compensated lifecycle. On macOS it creates
the installation-owned shared machine and connection `shimmy-default` only after exact
collision preflight; on Linux it records and validates the current user's local
rootless engine. Shimmy does not install Podman or adopt an existing machine,
and bootstrap never supplies `--stop-running`.

A failed bootstrap normally removes its fresh root. If machine initialization
is ambiguous or exact removal cannot finish, Shimmy reports incomplete rollback
and retains the configuration root and shared lifecycle journal. Treat those
paths as recovery evidence: do not retry bootstrap and do not delete, recreate,
or adopt a Podman machine by name.

Earlier schemas are unsupported. Use the version that created an old
installation to remove it, then bootstrap fresh. Do not add forwarding or an
in-place migration.

## Profiles

Profiles live below
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>` and use arbitrary
safe lowercase names. The invoking launcher and installation active profile
are distinct identities.

```sh
shimmy profile list --format manifest
shimmy profile status --format manifest
shimmy profile create team-one --dry-run
shimmy profile create team-one
shimmy profile create isolated-one --isolated --dry-run
shimmy profile clone isolated-one isolated-two --dry-run
shimmy profile activate default --dry-run
shimmy profile activate default
shimmy profile sync
shimmy profile repair-startup
shimmy profile delete team-one
```

Creation activates the new profile. Before selecting an existing profile, run
status and the exact named activation dry-run through an absolute installed
launcher. Request approval only for the exact named activation. If the dry run
lists workloads, obtain separate explicit confirmation before adding
`--stop-running`.

Ordinary profiles use the owned shared engine. Explicit `--isolated` creation
and isolated clone intent transactionally provision a new profile-owned
machine through Shimmy. Never substitute direct Podman machine init, start,
stop, remove, rename, migration, or adoption commands for these control-plane
operations. A missing or mismatched recorded machine is a recovery failure, not
permission to recreate or adopt it manually.

After activation, source the selected profile's absolute `shell-init.sh` to
change PATH. Sourcing never changes engine or registry state. AI-agent calls do
not retain sourcing across tool calls; use an absolute launcher or source and
invoke in the same command.

## Shims and catalog

```sh
shimmy shim add task@3.45
shimmy shim list --format manifest
shimmy shim sync task
shimmy shim test task@3.45
shimmy catalog status --format manifest
shimmy catalog tools
shimmy catalog verify --tool task@3.45 --format manifest
```

Shim selectors are `tool` or `tool@version`. An unqualified add is interactive
and tracks catalog defaults; an exact first add is pinned and noninteractive.
Mutations require the invoking profile to be active.

The installation owns exactly one immutable catalog named `default`. Publish
only from a clean committed attached `main` root; rollback selects the retained
previous generation. Neither changes existing profile pins. Use active-profile
`profile sync` or shim operations for explicit adoption.

## Skills and collisions

Each profile owns validated control and shim bundles. Activation, shim mutation,
and `shimmy ai-skill repair` reconcile direct links under the active record's
exact `$HOME/.agents/skills` root.

They unconditionally overwrite every exact bundle-declared collision without
backup or recovery. They may remove recognized stale Shimmy links. They never
recursively delete the user root or unrelated names. Always review activation
dry-run collision output before mutation; report any overwritten foreign
content as irrecoverable.

There is no repo/profile export target and no `.shimmy-skills-manifest.txt`
lifecycle. Do not recreate the deleted adapter mechanism.

## Startup

Fresh bootstrap records one normalized shell and either conventional exact
startup paths or manual `--no-startup` policy. Only recorded paths may be
repaired or removed. Sibling profiles own no persistent startup block.
`shimmy profile repair-startup` is a no-op for manual policy.

## Removal

```sh
shimmy admin status --format manifest
shimmy admin uninstall --dry-run
shimmy admin uninstall
```

Uninstall validates and removes all installation-owned profiles, catalog state,
active state, exact startup blocks, recognized registry projections,
recognized direct Shimmy user-skill links, and every macOS machine whose
complete current evidence proves Shimmy ownership. It preserves source
checkouts, external, ambiguous, and Linux host-local engines, unrelated
registry policy, unrelated skills, and the user skill root.

Removing an owned machine permanently destroys its containers, images,
volumes, build caches, and all other VM-local data. None is preserved. Machine
deletion cannot be rolled back. Run `--dry-run` first and report exact removal
and preservation targets. If removal partially completes, do not edit the
journal or engine records; report completed and pending engines and use the
exact retry printed by Shimmy. Treat a replacement at a completed machine name
as a collision.

If dry-run lists running containers, obtain explicit confirmation before
retrying with `--stop-running`. That acknowledgement authorizes permanent
deletion of those containers with their owned VM.

## Agent evidence order

1. For an already-selected Shimmy wrapper with an approved safe outer prefix,
   run the actual task operation with escalation first.
2. Treat sandbox-only socket/permission/unreachable results as unverified, then
   retry the same wrapper operation through `shimmy-escalation`.
3. Use `shimmy-init` only after an escalated wrapper proves an engine/profile
   problem.
4. Keep status, named activation dry-run, activation approval, and any
   `--stop-running` acknowledgement separate.
5. Validate with admin/profile/shim manifest output and non-mutating tool smokes.

Podman is an explicit dependency. Do not install or provision it as part of
this lifecycle.
