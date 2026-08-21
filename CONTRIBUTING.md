# Contributing

This is the source of truth for repository contribution guidance.

## Workflow

- Read root `CONTEXT.md` and every retained child `CONTEXT.md` on the path to
  changed files under `commands/`, `lib/`, or `tests/`.
- For tool or plugin work, also read the canonical `SKILL.md` and tool guide.
- Update implementation, tests, bootstrap/install behavior, documentation, and
  retained-plan evidence together when behavior changes.
- Keep executable shell files executable and validate generated shell artifacts
  by parsing and exercising the rendered result.
- Preserve unrelated work in a dirty tree.
- Follow [docs/testing.md](docs/testing.md) for test organization.

Shimmy is a POSIX shell project. Do not replace shared behavior or runtimes with
Go, Rust, Python, or another language unless the requested design explicitly
leaves this architecture.

## Architecture

The root `bootstrap.sh` is the only checkout lifecycle entrypoint. It delegates
to `commands/bootstrap.sh`. An installed profile owns a direct `bin/shimmy`
launcher with this fixed group surface:

```text
admin  profile  catalog  shim  ai-skill
```

Do not add compatibility forwarding for removed top-level commands. Public
management entrypoints live in `commands/`; shared modules live in `lib/`;
runtime, metadata, guides, tests, skills, and concrete versions live below
`tools/<tool>/`.

The installation root is
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy`. It contains:

- one immutable, retained-generation catalog named `default`;
- arbitrary safe-name materialized profiles under `profiles/<name>`;
- one exact active-profile record.

Each profile records source `refs/heads/main`, a retained default-catalog pin,
profile-local shim policies and concrete versions, startup ownership, and
validated control/tool skill bundles. There is no live upstream catalog, fixed
upstream profile, implementation-name routing layer, or profile-copied test
suite.

Catalog publication runs only from a clean attached local `main` checkout.
Publishing or rolling back changes registry authority but does not rewrite
existing profile pins. Profile adoption requires explicit `profile sync` or
shim lifecycle work.

## Profiles, Podman, and startup

Profile names use lowercase letters, digits, and single hyphens. On macOS the
deterministic engine identity is `shimmy-<profile>`; on Linux Shimmy validates
the current user's local rootless engine. Podman is an explicit dependency:
never add installation, provisioning, adoption, renaming, migration, or
deletion behavior for it.

Activation owns engine, registry, active-record, and AI-skill-link transitions.
On macOS, switching or refreshing projection state may stop an idle machine;
running workloads require a separate `--stop-running` acknowledgement. On
Linux, activation atomically switches only the exact user registry-policy link.
Never print the values of connection or registry override variables.

The initial default bootstrap and `profile create` activate their profile.
`profile activate <name> --dry-run` must remain side-effect free and list exact
collisions and engine effects. `shell-init.sh` is PATH-only and must never
activate an engine.

Managed startup policy owns exact marked blocks in a recorded path ledger.
Manual policy owns no startup files. `profile repair-startup` consumes only the
recorded ledger. Preserve sourced-script failure behavior under callers using
`set -e`.

## AI-skill ownership

Canonical management skills live in `plugins/shimmy/skills/`; tool skills live
at `tools/<tool>/SKILL.md`. Do not create or edit generated repository adapters
under `.agents/skills`; this repository intentionally has no such tree.

Every canonical skill must place this warning immediately after frontmatter:

> Shimmy active-profile reconciliation unconditionally overwrites this exact
> bundle-declared skill destination without backup, never deletes unrelated
> skill names, and profile copies must not be edited.

Profiles materialize validated bundles and reconcile direct links in the active
user's `$HOME/.agents/skills`. Exact declared collisions are overwritten with
no backup or recovery. Never recursively clean that root. Preserve unrelated
names and reject unsafe parent/path state.

## Tool workflow

A tool is the stable user command. A concrete version owns its runtime:

```text
tools/<tool>/
  tool.conf
  guide.md
  SKILL.md
  tests/
  versions/<major.minor>/
    run.sh
    smoke.conf
    image.conf
    refresh.sh
    container/       # local builds only
```

- Keep `run.sh` small with `#!/bin/sh` and `set -eu`.
- Mount `$PWD` at `/work` unless the tool has a documented exception.
- Use the shared Podman helper for native platform selection.
- Put tool-specific behavior in the concrete version, not a central dispatcher.
- `tool.conf` declares the default version and optional selector environment.
- `smoke.conf` declares non-mutating smoke environment and arguments; it does
  not declare an implementation name.
- Add no central tool-name or implementation-name routing map.

Every version owns one valid `image.conf`. Use `image_source=external` for a
suitable publisher image or `image_source=local-build` for a version-owned
container context. Repository defaults and every non-`scratch` base must be
fully qualified immutable top-level OCI index or Docker manifest-list digests
with both `linux/amd64` and `linux/arm64`. Mutable tags belong only in upstream
discovery fields.

Audit companion CLIs, plugins, credentials, privileges, packages, installers,
and downloaded archives for both architectures before implementation. Security-
sensitive network, credential, privilege, and write behavior must remain
explicit opt-ins.

Source preview and catalog verification examples:

```sh
./commands/run-tool.sh <tool> --preview-shim --help
shimmy catalog verify --tool <tool>@<version> --format manifest
```

Feature acceptance requires native Linux `amd64` and Apple Silicon macOS
`arm64` version-owned smokes. Cross-emulation is not a substitute.

## Testing

- Use `./tests/test.sh` with the default bounded parallel runner.
- Use `--jobs 3` when stating concurrency explicitly.
- Use `--serial` only for one group, failure diagnosis, or known ordering.
- Prefer positive observable behavior. Do not add absence/rejection tests unless
  they protect an explicit durable security, ownership, integrity, rollback, or
  compatibility invariant.
- Use live Podman and non-mutating tool calls for container acceptance. Unit
  tests may fake engine state only for lifecycle transaction boundaries.
- Do not put remote registry checks into the default offline suite.

Before completion, run relevant focused groups, then the full suite once,
followed by shell syntax, executable-mode, inventory, and `git diff --check`
validation. Rerun only failures serially.

## Naming conventions

Prefer names that read general-to-specific and use truthful actions such as
`create`, `read`, `update`, `delete`, `render`, `resolve`, `install`, and
`validate`. Avoid vague verbs such as `handle`, `process`, or `do`.

### Files

- Executable management commands and shared modules use lowercase kebab-case
  ending in `.sh`.
- Concrete runtimes are always `tools/<tool>/versions/<major.minor>/run.sh`.
- Final public and canonical files do not use `-target` or `target.sh` suffixes.
- Conventional contributor documents use names such as `README.md`,
  `CONTRIBUTING.md`, and `AGENTS.md`; other docs use lowercase kebab-case.

### Functions

- Do not use the `function` keyword.
- Use POSIX-safe `shimmy_` lowercase snake-case names for shared functions.
- Use `shimmy__` for internal helpers.
- Use predicate names that make their `0/1` meaning clear.
- Internal helper names are not API; update all callers instead of adding
  compatibility wrappers.

Examples: `shimmy_catalog_payload_validate`,
`shimmy_profile_paths_resolve_name`, `shimmy__catalog_config_value_read`.

### Variables

- Local variables use lowercase snake case.
- Constants and exported environment variables use uppercase snake case.
- Every Shimmy-defined user-facing environment variable starts with `SHIMMY_`.
- Non-`SHIMMY_` values are allowed only for documented upstream pass-throughs
  such as `AWS_*` or `TF_VAR_*`.
- Do not retain `target` in a name after a staged implementation becomes the
  sole canonical route unless it still describes a real destination.

Consistency with clear nearby vocabulary is the tie-breaker; do not rename
solely for preference.
