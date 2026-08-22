# Named and Custom Profile Activation Plan
**Status:** not started

## Objective

Extend Shimmy's installed-profile model so a sourced shell can run:

```sh
shimmy profile activate <profile-name> [--restart] [--stop-running] [--dry-run]
```

and, after a successful non-dry-run activation, use that named profile as the
only Shimmy profile selected in the current shell. The target may be either of
the built-in profiles (`default` or `upstream`) or any valid installed custom
profile.

Custom profiles must be creatable through the existing checkout bootstrap:

```sh
. ./bootstrap.sh --profile <profile-name>
```

They must receive the fixed jq/rg baseline, bind to the published `default`
catalog, own independent tools and registry redirects, update and uninstall
through their own installed launcher, and use the deterministic Darwin Podman
machine and rootless connection name `shimmy-<profile-name>`. Existing
`default` and `upstream` behavior must remain valid, including the no-name
`shimmy profile activate` form, which continues to target the invoking profile.

Success means:

- a safe installed custom profile is a first-class producer and consumer of
  manifests, installed commands, registry policy, Podman affinity, updates,
  uninstall, global uninstall, and agent preflight;
- named activation validates and delegates to the target profile's own
  installed control plane rather than mutating the invoking profile's state;
- a sourced `shell-init.sh` supplies the shell-level integration needed for the
  exact command above to update the parent shell after engine activation;
- successful shell selection removes every sibling Shimmy profile `bin/` entry
  from `PATH`, so commands cannot fall through to an inactive sibling;
- failure, help, and dry-run paths do not change the current shell selection;
- distinct shell sessions may select different profile command sets, while
  each installed runtime still fails closed if the process-global Podman engine
  or registry policy belongs to another profile; and
- code, tests, contexts, user documentation, contributor guidance, and
  canonical skills describe the same named/custom profile behavior.

Explicit exclusions:

- Do not introduce a shared installed control plane, global launcher, profile
  symlink, per-session filesystem registry, or profile-selection environment
  variable consumed by executables. Installed launchers remain profile-local.
- Do not add selectors to `status`, `install`, `uninstall`, `update`,
  `redirect`, catalog, images, skills, test, or tool-dispatch commands. Those
  commands remain bound to their invoking launcher; only `profile activate`
  accepts an optional target name.
- Do not add a separate `shimmy profile create`, clone, rename, or catalog
  selection command. Checkout bootstrap remains the profile-creation surface.
- Do not let custom profiles bind to the live `upstream` catalog. `upstream`
  remains the sole upstream-catalog profile; every custom profile uses the
  published `default` catalog.
- Do not provision, adopt, rename, or remove Podman machines. Users create
  `shimmy-<profile-name>` when Darwin activation reports it missing.
- Do not make bootstrap or shell initialization activate Podman implicitly.
  Engine activation remains an explicit command.
- Do not make Podman engine or Linux registry-link selection shell-local; both
  are external process/global state. The shell-local guarantee applies to
  Shimmy command and tool selection.
- Do not add compatibility aliases or edit generated `.agents/skills/`
  adapters. Canonical skill sources change in place; adapters update only
  through the explicit skills lifecycle after implementation review.

## Target layout and terminology

### Installed state

```text
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/
  catalogs/
    default/                  # published immutable catalog authority
    upstream/                 # live checkout catalog authority
  profiles/
    default/                  # catalog=default; owns startup integration
    upstream/                 # catalog=upstream; owns source_checkout
    work/                     # custom; catalog=default
    ci-minimal/               # custom; catalog=default
```

Every profile remains a complete independent materialized tree with its own
`bin/shimmy`, `shell-init.sh`, manifest, tools, registry policy, and optional
Darwin projection record.

### Stable terms

- **Built-in profile** means `default` or `upstream`. An omitted checkout
  bootstrap selector still creates/selects `default`.
- **Custom profile** means any other safe profile name installed below the
  canonical `profiles/` root. It binds to `catalog=default`, has no
  `source_checkout`, and never owns persistent startup blocks.
- **Invoking profile** means the profile containing the executable launcher
  that received a command.
- **Target profile** means the optional name supplied to `profile activate`, or
  the invoking profile when the name is omitted.
- **Engine-active profile** means the profile selected by the process-global
  Podman connection and registry state. On Darwin its engine is
  `shimmy-<profile-name>`; on Linux its registry file is the target of the one
  Shimmy-owned active drop-in.
- **Shell-selected profile** means the one profile whose launcher and tools are
  exposed by the sourced shell integration in one shell session.
- **Session switch** means: validate the target shell asset, perform explicit
  engine activation, and only after success source the target's generated
  `shell-init.sh` in the caller so it replaces sibling Shimmy `PATH` entries
  and updates the shell's profile-local `shimmy` function.

The official Podman machine contract permits a named machine argument and
states that only one Podman-managed VM can run at a time. Shimmy preserves that
external constraint rather than claiming VM state is per shell:
[Podman machine start](https://docs.podman.io/en/latest/markdown/podman-machine-start.1.html).

### Public command forms

```text
# Creation from a source checkout; custom profiles use catalog=default.
source ./bootstrap.sh --profile work [install options]
./bootstrap.sh --profile work [install options]

# Backward-compatible invocation-profile activation.
shimmy profile activate [--restart] [--stop-running] [--dry-run]

# Named activation and sourced-shell session switch.
shimmy profile activate work [--restart] [--stop-running] [--dry-run]

# Absolute/direct execution can activate the target engine but cannot mutate
# its parent shell, so it prints the exact shell-init source command.
"$profile_root/bin/shimmy" profile activate work [options]
```

The optional profile name must appear immediately after `activate`, before
options. A second positional value, a name after options, an empty/unsafe name,
or an unknown/uninstalled profile is rejected before Podman, registry, `PATH`,
or profile state changes.

## Recorded design decisions

### Profile identity, catalog binding, and lifecycle

1. Use one canonical profile-name validator everywhere. Valid names contain
   lowercase ASCII letters, digits, and single hyphens; they are non-empty,
   do not begin or end with `-`, and do not contain `--`. Path separators, dots,
   underscores, uppercase letters, whitespace, shell metacharacters, and
   control characters are rejected. `default` and `upstream` satisfy the same
   grammar but retain their built-in roles.
2. Preserve profile manifest version 2 and its materialized-root identity.
   Generalize its binding invariant from profile-name equality to this exact
   policy:

   ```text
   profile=upstream        -> catalog=upstream, one source_checkout
   profile=default         -> catalog=default, no source_checkout
   profile=<custom-name>   -> catalog=default, no source_checkout
   ```

   Existing valid built-in manifests remain valid. No arbitrary manifest
   catalog binding, in-place profile rename, or legacy layout is accepted.
3. Extend root `bootstrap.sh --profile` to accept the canonical grammar. A fresh
   custom bootstrap initializes or resolves the published `default` catalog
   through the same clean committed source transaction used for the built-in
   default profile, installs jq/rg, materializes a canonical custom tree, and
   selects it only when the bootstrap is sourced.
4. Only `default` owns persistent startup-file blocks. `upstream` and all
   custom profiles reject startup mutation and direct users to source their
   generated `shell-init.sh`.
5. Self-update must replay the exact profile name. Upstream-only checkout
   behavior remains conditional on the manifest's upstream binding; custom
   profiles refresh from the default catalog and retain their profile name,
   selected tools, registries file, and projection record.
6. Profile-local uninstall remains the removal surface for a custom profile.
   Global uninstall must discover every direct child of `profiles/`, validate
   the complete set before mutation, reject symlinks/unmanaged/damaged entries,
   then remove all validated built-in and custom profiles deterministically.
   It must not retain the current two-name loop.

### Engine, registry, and runtime generalization

1. Resolve every Darwin profile to `shimmy-<profile-name>` for both machine and
   rootless connection identity. Existing workload guards, restart semantics,
   commit-last default selection, and rollback behavior remain unchanged.
2. Replace every `default|upstream` registry-path allowlist with structural
   validation of an exact canonical
   `<config-root>/profiles/<safe-name>/registries.conf` target. The fixed
   root/rootless VM scripts must independently parse and validate the one name
   segment; they must not accept nested paths, traversal, symlink substitution,
   or merely matching suffixes.
3. Linux active-link inspection must derive the profile name from an exact
   canonical target, validate that profile's managed file, and report
   `current`, `sibling`, `absent`, or `invalid` without enumerating only the two
   built-ins.
4. The registry-client mount resolver, Darwin runtime affinity check, and
   installed-shim agent preflight must recognize any canonical validated
   profile. Invalid directory names or manifests continue to fail closed or be
   ignored only where the existing discovery contract is explicitly
   best-effort.
5. Profile names and shell state must never become Podman or registry argument
   injection surfaces. All command arguments remain separately quoted, and
   fixed remote action tokens stay validated before SSH execution.

### Named activation and shell-session behavior

1. Keep `profile activate` without a name as a compatibility form for the
   invoking profile. Add one optional positional target before the existing
   flags. Preserve duplicate-option rejection, OS-specific flag validation,
   help-before-profile-validation, workload acknowledgement, dry-run,
   activation locks, and rollback.
2. When the target differs from the invoking profile, the invoking control
   plane validates the safe name, exact canonical target root, regular
   executable launcher, manifest/structure identity, and generated shell-init
   format before mutation. It then delegates to the target's absolute launcher
   with the name removed. The target control plane owns all engine and registry
   mutation. This avoids mutating global profile variables to impersonate a
   sibling and respects profile-local control-plane ownership.
3. Add an exact generated shell-init format marker. Named session switching
   rejects an older or damaged target without this marker before engine
   mutation and gives update/recreate guidance. No mixed-version best effort is
   allowed across a shell switch.
4. Generated `shell-init.sh` remains POSIX-sourceable and defines a `shimmy`
   shell function. The function delegates ordinary commands to the currently
   shell-selected profile's absolute launcher. It recognizes only the exact
   `profile activate [<name>] ...` form for session switching.
5. Before activation the function validates the target `shell-init.sh` as a
   readable regular non-symlink with the expected marker. It invokes public
   named activation. After a successful non-dry-run activation it sources the
   target asset, which:
   - removes every direct canonical `profiles/<safe-name>/bin` entry from
     `PATH`;
   - prepends exactly the target profile's `bin/`;
   - replaces the shell function's target with the target's absolute launcher;
   - clears command hashing where supported; and
   - exports only the resulting `PATH`, not a profile selector.
6. `--dry-run`, `--help`, parsing failure, validation failure, workload refusal,
   or activation/rollback failure leaves the function target and `PATH`
   byte-for-byte unchanged. Same-profile activation is idempotent.
7. The shell helper's retained state uses `SHIMMY_`-prefixed internal shell
   variables, is not exported, and is never accepted by an executable as a
   profile selector. Every function invocation revalidates its canonical root
   before executing it.
8. Direct or absolute executable invocation cannot change a parent shell. It
   performs engine activation and prints the exact target `shell-init.sh`
   source command. Documentation must distinguish this behavior from the
   sourced function without implying that a child process changed `PATH`.
9. Different shells may retain different shell-selected profiles. Podman's one
   Darwin VM/default connection and Linux's one active registry link remain
   shared external state, so a tool invoked from a shell whose profile is not
   engine-active must continue to fail with targeted named-activation guidance.

### Compatibility, guidance, and generated artifacts

1. Preserve all current no-name activation examples as valid, but prefer named
   examples when teaching switching from an already initialized shell.
2. Add a supersession note to `plans/podman-registry-redirect.md` rather than
   rewriting its historical implementation record. Its earlier exclusion of
   arbitrary profile names is superseded by this reviewed plan.
3. Update canonical control-plane skills in `plugins/shimmy/skills/`, the
   generic template, and every canonical tool `SKILL.md` that describes
   profile activation. Agent workflows still use target absolute launchers for
   approval-sensitive engine activation; a shell function does not broaden an
   approved outer command.
4. Do not edit `.agents/skills/`. After implementation is accepted, users may
   refresh generated adapters with the explicit profile-local skills lifecycle.

## Verified implementation inventory

The following is the verified baseline. Implementation must still classify and
update newly discovered dependencies rather than treating this inventory as a
closed allowlist.

- Public parsing and dispatch: `bootstrap.sh`, `commands/profile.sh`,
  `commands/agent-preflight.sh`, and `lib/install/launcher-template.sh`.
- Canonical identity and activation: `lib/profile/profile.sh`,
  `lib/profile/activation.sh`, and their contexts.
- Profile producers and lifecycle consumers: `lib/install/request.sh`,
  `lib/install/install.sh`, `lib/install/manifest.sh`,
  `lib/install/profile-assets.sh`, `lib/install/startup.sh`,
  `lib/install/uninstall.sh`, `lib/update/management.sh`,
  `lib/update/profile.sh`, and `lib/update/update.sh`.
- Registry and runtime consumers with fixed built-in assumptions:
  `lib/registries/registries.sh`, `lib/runtime/podman.sh`, and their contexts.
- Catalog behavior is already capable of resolving an explicit manifest
  binding in `lib/catalog/catalog.sh`; profile validation and install policy,
  not the catalog resolver, currently force profile name and catalog name to
  match.
- Primary behavioral tests: `tests/support.sh`,
  `tests/commands/onboarding.sh`, `tests/commands/startup.sh`,
  `tests/commands/profile.sh`, `tests/commands/profiles.sh`,
  `tests/commands/lifecycle.sh`, `tests/commands/install.sh`,
  `tests/commands/update.sh`, `tests/commands/management.sh`,
  `tests/lib/profile-activation.sh`, `tests/lib/registries.sh`,
  `tests/lib/runtime.sh`, and `tools/skopeo/tests/skopeo.sh`.
- Test and architecture guidance: `CONTEXT.md`, `commands/CONTEXT.md`,
  `lib/CONTEXT.md`, `lib/profile/CONTEXT.md`, `lib/install/CONTEXT.md`,
  `lib/startup/CONTEXT.md`, `lib/registries/CONTEXT.md`,
  `lib/runtime/CONTEXT.md`, `tests/CONTEXT.md`,
  `tests/commands/CONTEXT.md`, `tests/lib/CONTEXT.md`, and
  `docs/testing.md`.
- User and contributor documentation: `README.md`, `BOOTSTRAP.md`,
  `CONTRIBUTING.md`, `commands/README.md`, `docs/podman.md`,
  `docs/registries.md`, `docs/netinfo.md`, `docs/prompt-shimmy-project.md`, and
  `AGENTS.md`.
- Canonical guidance sources: `plugins/shimmy/skills/shimmy-install/SKILL.md`,
  `plugins/shimmy/skills/shimmy-init/SKILL.md`,
  `plugins/shimmy/skills/shimmy-escalation/SKILL.md`,
  `docs/templates/generic-shim/SKILL.md`, and activation guidance in
  `tools/*/SKILL.md`.
- Historical design constraint to supersede explicitly:
  `plans/podman-registry-redirect.md`.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Generalize profile identity, creation, lifecycle, registries,
  and runtimes for safe custom profiles.
- [ ] Chunk 2 — Add named activation and transactional sourced-shell session
  switching, then complete guidance and full regression verification.

Active chunk: Chunk 1. Implementation has not been authorized.

## Execution protocol

For every chunk:

1. Read `AGENTS.md`, `CONTEXT.md`, every child context on the path to a changed
   file, this plan, and the chunk's target files.
2. Execute only that chunk's scope.
3. Run its verification checklist and record `[x]`, `[ ]`, or `[~]` with notes.
4. Update the cumulative **Lessons learned** block.
5. Summarize changes, tests, failures, uncertainties, and remaining risks.
6. Stop for human review and explicit acceptance before starting the next
   chunk.

Repository paths in this plan are relative to `<repo>` so it remains portable
across workstations and sessions.

## Chunk 1 — Safe custom-profile lifecycle

### Goal

Make arbitrary safe custom profiles coherent across creation, manifests,
installed launchers, registries, runtime affinity, updates, and removal while
retaining the current invocation-profile activation and explicit shell-init
workflow. At this gate a custom profile must be usable through its absolute
launcher and direct `shell-init.sh`; named activation is intentionally deferred
to Chunk 2 and must be documented as pending until that chunk is accepted.

### Files

Primary surfaces:

- `bootstrap.sh`, `commands/agent-preflight.sh`, and installed launcher rendering;
- `lib/profile/`, `lib/install/`, `lib/update/`, `lib/registries/`, and
  `lib/runtime/podman.sh`;
- the applicable `CONTEXT.md` files;
- profile, onboarding, install, lifecycle, update, registry, runtime, Skopeo,
  and test-support modules under `tests/` and `tools/skopeo/tests/`; and
- `README.md`, `BOOTSTRAP.md`, `CONTRIBUTING.md`, `commands/README.md`,
  `docs/testing.md`, `docs/podman.md`, and `docs/registries.md` for the
  independently usable custom-profile state.

### Implementation requirements

1. Implement the canonical safe-name validator and built-in/custom
   classification once in `lib/profile/profile.sh`; duplicate only the minimum
   self-contained validation required by the generated launcher and fixed
   remote scripts, with parity tests preventing drift.
2. Generalize canonical paths, launcher validation, manifest ownership,
   structure validation, install catalog preparation/registration, manifest
   rendering, update replay, and startup policy according to the recorded
   binding table. Existing built-in profiles must not require migration.
3. Extend checkout bootstrap creation to custom names without accepting a
   user-selected catalog or weakening clean default-catalog publication.
   Custom creation must retain the same staged validation, commit, rollback,
   collision, and symlink protections as built-in creation.
4. Generalize the Darwin engine mapping and every Linux/Darwin registry target
   validator to a safe canonical custom name. Preserve all existing workload,
   projection, fingerprint, locking, commit, detach, and rollback invariants.
5. Generalize installed runtime affinity, registry-client mounting, and agent
   preflight discovery. A custom tool runtime must reject a sibling engine or
   registry policy with guidance naming its own profile.
6. Replace fixed global-uninstall loops with deterministic direct-child
   discovery and prevalidation. Prove that malformed names, symlinked profile
   roots, unmanaged directories, invalid manifests, active locks, retained
   projections, and foreign Linux links stop the entire transaction before
   any built-in or custom profile is removed.
7. Update context and user documentation in the same change. State clearly
   that custom profiles use `default`, only `default` owns persistent startup,
   custom Darwin machines remain user-provisioned, and named activation will
   be delivered in Chunk 2.

### Verification checklist

- [ ] POSIX syntax checks pass for every changed runnable or sourced shell file.
- [ ] Valid-name tests cover built-ins and representative custom names; invalid
  tests cover empty, leading/trailing/repeated hyphens as applicable, dots,
  underscores, uppercase, whitespace, separators, traversal, metacharacters,
  and control/newline input without filesystem or Podman mutation.
- [ ] Sourced and executed `./bootstrap.sh --profile work` create an independent
  canonical profile with jq/rg, `shimmy_profile_name=work`, `catalog=default`,
  no `source_checkout`, no persistent startup block, and a valid generated
  registry file. Existing default/upstream bootstrap tests remain unchanged in
  outcome.
- [ ] Custom profile status, catalog resolution, tool installation/dispatch,
  management refresh, registry edits, and profile-local uninstall operate only
  on the custom root and preserve built-in siblings.
- [ ] Fake-Podman tests prove custom Darwin identity
  `work -> shimmy-work`, workload guards, dry-run, projection validation,
  default-connection commit, and rollback; Linux tests prove safe custom
  active-link switching and exact rollback.
- [ ] Registry VM scripts reject unsafe/nested/custom lookalike targets while
  accepting only the exact canonical safe custom target; runtime affinity and
  Skopeo policy mounting accept a valid custom profile and reject sibling,
  stale, and damaged state.
- [ ] Agent preflight discovers active tools from valid custom manifests
  without trusting unmanaged profile entries.
- [ ] Global uninstall prevalidates and removes all validated built-in/custom
  profiles, and injected malformed, symlinked, locked, projected, or unmanaged
  custom entries leave every profile and catalog intact.
- [ ] `./tests/test.sh` passes with no live Podman mutation and no generated
  `.agents/skills/` changes.

### Human review gate

Confirm that custom profiles are fully lifecycle-safe, always bind to the
published default catalog, preserve built-in behavior, and introduce no hidden
selector or machine-provisioning surface. Accepting Chunk 1 authorizes only
Chunk 2 planning state to become active; it does not authorize Chunk 2 work.

## Chunk 2 — Named activation and shell-session switch

### Goal

Add the optional profile-name parameter and sourced-shell transaction so the
exact user-facing command selects the named target's engine and, only after
success, makes it the sole Shimmy profile selected in that shell.

### Files

Primary surfaces:

- `commands/profile.sh`, `lib/install/launcher-template.sh`,
  `lib/install/startup.sh`, `lib/profile/profile.sh`, and
  `lib/profile/activation.sh`;
- activation, onboarding, startup, management, runtime, and lifecycle tests;
- applicable context files and `docs/testing.md`;
- `AGENTS.md`, `README.md`, `BOOTSTRAP.md`, `CONTRIBUTING.md`,
  `commands/README.md`, `docs/podman.md`, `docs/registries.md`,
  `docs/netinfo.md`, and `docs/prompt-shimmy-project.md`;
- canonical skills under `plugins/shimmy/skills/`,
  `docs/templates/generic-shim/SKILL.md`, and `tools/*/SKILL.md`; and
- a supersession note in `plans/podman-registry-redirect.md`.

### Implementation requirements

1. Add the exact optional positional grammar, validation, same-profile fast
   path, and target-profile delegation. Help must remain available before
   profile/Podman validation. Unknown names, damaged targets, unsupported shell
   formats, duplicate names/options, and positional values after flags fail
   before mutation.
2. Add and validate the generated shell-init format marker. Keep direct
   executable activation useful and explicit about its inability to modify a
   parent shell.
3. Render a POSIX `shimmy` shell function that delegates ordinary commands
   transparently and implements the prevalidate -> activate -> source target
   sequence. Preserve exit status and caller state, including working
   directory, positional parameters, shell flags, traps, unrelated functions,
   and unrelated variables.
4. Make shell selection exclusive by removing every exact canonical sibling
   profile `bin/` entry before prepending the target. Preserve empty and
   non-Shimmy `PATH` components and `/opt/podman/bin` behavior. Repeated and
   same-profile activation must be idempotent.
5. Ensure failure and dry-run paths retain the prior function target and exact
   `PATH`. If external engine activation reports an incomplete rollback, do
   not compound it with a shell switch; surface the engine uncertainty and
   retain the prior shell selection.
6. Update runtime/profile guidance to recommend named activation from sourced
   interactive shells and exact absolute target launchers for approval-bound
   automation. Keep `--stop-running` separately authorized and never imply a
   shell function broadens outer-command approval.
7. Update canonical sources only. Do not modify generated `.agents/skills/`.

### Verification checklist

- [ ] Command parsing accepts `activate`, `activate work`, and their valid
  options; rejects unsafe/unknown/multiple/misordered names and duplicate or
  unknown options before any fake-Podman or filesystem log entry.
- [ ] Named activation from one profile delegates to the target profile's
  launcher/control plane, preserves dry-run and rollback behavior, and never
  edits the invoking profile's manifest, registries, projection record, or
  shell asset.
- [ ] In clean `/bin/sh`, Bash, and Zsh sessions where available, sourcing a
  generated asset defines working ordinary `shimmy` delegation; successful
  `shimmy profile activate work` changes both function dispatch and tool
  resolution to `work`, leaves exactly one Shimmy profile `bin/` in `PATH`, and
  supports repeated default/upstream/custom switches.
- [ ] Shell tests prove byte-for-byte `PATH` and dispatch retention after
  help, dry-run, malformed target, damaged/missing/old shell-init marker,
  workload refusal, target activation failure, and incomplete rollback.
- [ ] Shell switching preserves caller working directory, positional
  parameters, flags, traps, unrelated variables/functions, empty `PATH`
  components, non-Shimmy path ordering, and Podman fallback-path behavior.
- [ ] Two independent shell processes can retain different shell-selected
  profiles; a runtime from the shell whose profile is not engine-active fails
  with precise named-activation guidance rather than falling through to a
  sibling tool.
- [ ] Direct absolute execution activates or dry-runs the named target and
  prints the exact source command without claiming the parent shell changed.
- [ ] All help, contexts, docs, canonical skills, and the prior-plan
  supersession note agree with the implemented grammar and session/global
  distinction; generated adapters remain untouched.
- [ ] POSIX syntax checks and `./tests/test.sh` pass. Relevant fake-Podman
  activation tests exercise success, failure, restart, workload guard,
  registry projection, commit-last selection, and rollback for a custom name.

### Human review gate

Confirm the requested exact command performs an exclusive session switch only
after successful target-engine activation, direct execution is documented
honestly, failures preserve prior shell selection, custom and built-in profiles
remain isolated, the full suite passes, and no generated adapter or external
Podman/profile state changed unexpectedly.

## Risk register

- **Shell function compatibility:** defining `shimmy` changes `command -v`
  output and function precedence. Mitigation: document `command shimmy` and
  absolute launchers as direct-execution escape hatches; test POSIX sh, Bash,
  and Zsh behavior and exact exit propagation.
- **Global engine versus session selection:** separate shells may select
  different profiles while Podman and the Linux active link are shared.
  Mitigation: use distinct terms, retain runtime affinity failure, and never
  report engine state as shell-local.
- **Mixed installed control versions:** switching to an older target could
  activate its engine and then fail to update the shell. Mitigation: require
  the shell-init format marker and validate it before mutation; provide
  update/recreate guidance.
- **Unsafe dynamic paths:** replacing two fixed names expands filesystem and VM
  path inputs. Mitigation: one restrictive validator, exact canonical root
  checks, independent remote-script validation, symlink rejection, and focused
  traversal/lookalike tests.
- **Global uninstall expansion:** dynamic discovery could delete unmanaged
  data or partially remove profiles. Mitigation: inspect only direct children,
  prevalidate the complete set before mutation, reject any foreign shape, and
  preserve manifest-bounded removal.
- **Historical guidance drift:** the completed registry plan and many tool
  skills encode invocation-bound activation. Mitigation: add a supersession
  note, update every canonical source identified by search, and verify
  generated adapters remain unchanged.
- **Chunk boundary:** Chunk 1 intentionally creates custom profiles before the
  named switch exists. Mitigation: retain absolute launcher and explicit
  shell-init workflows, update docs to mark named activation pending, and stop
  at the review gate before Chunk 2.

## Lessons learned

### Initial

- Current profile identity is hard-coded beyond CLI parsing: manifest catalog
  equality, launcher validation, registry active-link recognition, fixed VM
  SSH path allowlists, runtime affinity, agent preflight, global uninstall, and
  tests all assume exactly `default|upstream`.
- The catalog resolver already treats catalog binding as explicit manifest
  data. Custom profiles can therefore use `catalog=default` without adding a
  new catalog lifecycle or merging catalog identities.
- An executable cannot mutate its parent shell. The exact one-command session
  requirement needs sourced shell integration; engine activation alone is not
  shell selection.
- Existing shell initialization prepends the selected profile but retains
  sibling profile bins later in `PATH`. Exclusive session selection requires
  removing all exact sibling entries so missing tools cannot fall through.
- Podman officially permits a named machine argument but allows only one
  Podman-managed VM to run at a time. Session-local command selection must not
  be presented as session-local VM state.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, root `CONTEXT.md`, `CONTRIBUTING.md`, this plan, and every
   retained child `CONTEXT.md` on the path to the active chunk's changed files.
2. Read the active chunk's target files and reconcile `git status` without
   discarding unrelated user work.
3. Preserve POSIX shell architecture, profile-local control planes, explicit
   Podman dependency, fixed registry ownership, no machine provisioning, and
   the prohibition on direct `.agents/skills/` edits.
4. Execute only the active chunk. Chunk 1 is active and not yet authorized.
5. Update this plan's progress checklist, verification notes, and cumulative
   lessons before stopping at the chunk's human review gate.
