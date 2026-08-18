# Make startup policy profile-owned

**Status:** Final review

## Objective

Make the default profile's startup-shell policy immutable after first
bootstrap and remove every later public mechanism that can replace, narrow,
broaden, or disable that policy.

Success means:

- a fresh `./install.sh` default-profile bootstrap records exactly one
  normalized startup shell, selected from `--shell <name>` or inferred from
  `$SHELL` when the option is omitted;
- fresh-bootstrap `--no-startup` records the selected shell but deliberately
  records no managed startup files;
- later checkout bootstrap, installed `shimmy install`, management refresh,
  tool materialization, and startup repair inherit the recorded profile state;
- installed `shimmy install` exposes only repeatable `--shim` selection;
- `shimmy update --repair-startup` repairs only the exact paths already owned
  by the profile and exposes no shell or path selector;
- `--startup-file` is removed everywhere, with no compatibility alias,
  migration path, special legacy error, or removed-option test;
- repeated checkout bootstrap cannot use `--shell` or `--no-startup` to change
  an existing default profile's startup policy;
- the internal `startup_file=` records remain the exact ownership ledger used
  by repair and uninstall; and
- production request and forwarding code is smaller and contains no public or
  private startup-path replay interface.

Explicit exclusions:

- Do not add `--profile` to an installed command. An installed launcher remains
  bound to its enclosing profile; `shimmy install --profile default` is not a
  target interface.
- Do not add a post-bootstrap command for changing the selected shell or
  enabling/disabling persistent startup integration.
- Do not remove `--repair-startup`; it remains a repair-only operation over
  existing profile-owned paths.
- Do not remove startup-file helpers, `STARTUP_FILE_PATHS`, or manifest
  `startup_file=` records; they implement internally resolved ownership.
- Do not redesign marker rendering, symlink handling, Bash startup precedence,
  or the generated `shell-init.sh` PATH behavior.
- Do not add Bash-only implementation syntax; runtime code remains POSIX
  `/bin/sh`.
- Do not edit generated `.agents/skills/` files directly.
- Do not update, uninstall, or recreate the user's installed profiles while
  implementing or verifying this plan. Generated refresh uses disposable
  profile state compatible with the new manifest identity.

## Target layout and terminology

- **Startup shell** is the normalized `bash`, `zsh`, `sh`, `ksh`, or `mksh`
  value assigned when a fresh default profile is bootstrapped. `dash`
  normalizes to `sh`. This setting chooses startup-file paths only; it does not
  select a command interpreter for Shimmy's POSIX wrappers.
- **Managed startup policy** means a fresh default bootstrap selected a shell
  without `--no-startup`. Shimmy resolves the conventional targets once,
  records them, and owns only those exact paths.
- **Manual startup policy** means a fresh default bootstrap used
  `--no-startup`. The manifest still records `startup_shell=` but contains no
  `startup_file=` entries. The user owns any manual source block.
- **Startup ownership ledger** is the set of absolute `startup_file=` records
  in the default profile manifest. Repair and uninstall consume the ledger
  exactly; they do not re-resolve paths from the current `$HOME`, `$SHELL`, or
  current Bash login-file precedence.
- **Profile inheritance** means every operation reads and preserves the
  invoking profile's recorded startup state. Installed launchers already derive
  profile identity from their enclosing root and therefore need no public
  `--profile` selector.
- **Upstream profile** has no persistent startup policy. Its POSIX
  `shell-init.sh` remains available for explicit sourcing, but it records no
  `startup_shell=` or `startup_file=` state.

The target public surface is:

```text
./install.sh [--profile default] [--shell <name>] [--no-startup]
./install.sh --profile upstream

shimmy install --shim <tool[@version]> [--shim <tool[@version]> ...]

shimmy update [--shim <name> ... | --all] [--pull] [--build]
              [--repair-startup]
```

`--shell` and `--no-startup` are fresh default-profile bootstrap inputs only.
They are rejected when the default profile already exists, even when the
requested value happens to match, so the CLI does not imply a supported
reconfiguration operation. An unqualified repeat bootstrap inherits the
manifest policy and repairs its exact managed paths. Management self-update
inherits the same state without touching startup files unless
`--repair-startup` was requested on `shimmy update`.

Advanced users with a nonstandard startup chain choose manual policy during
fresh bootstrap and own the source block:

```sh
. ./install.sh --no-startup

shimmy_shell_init_file=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/shell-init.sh
if [ -r "$shimmy_shell_init_file" ]; then
  . "$shimmy_shell_init_file"
fi
unset shimmy_shell_init_file
```

Documentation must state that a non-empty `XDG_CONFIG_HOME` remains absolute,
that this block initializes PATH only, and that Bash users place it in their
own interactive/login source chain rather than using `BASH_ENV` globally.

## Recorded design decisions

1. The startup shell and managed/manual choice are creation-time profile
   policy, not per-operation request state. Only the checkout bootstrap may
   accept `--shell` and `--no-startup`, and only while creating a fresh default
   profile.
2. An unqualified fresh default bootstrap normalizes `$SHELL`; it no longer
   installs both zsh and Bash blocks automatically. Explicit `--shell` remains
   the bootstrap override. The selected shell is always recorded, including
   manual-policy bootstrap.
3. Conventional managed targets are resolved once at creation. Bash records
   `.bashrc` plus the selected login file; zsh records `.zshrc`; POSIX-like
   shells record `.profile`. Later changes to `$HOME`, `$SHELL`, or the set of
   Bash login files do not silently transfer ownership.
4. Installed `shimmy install` removes `--shell`, `--startup-file`, and
   `--no-startup` from help and parsing. Additive install preserves manifest
   startup state byte-for-byte and never updates startup files.
5. `shimmy update` removes `--shell` and `--startup-file`. Ordinary management
   refresh preserves startup state without external startup mutation.
   `--repair-startup` updates only exact manifest-owned `startup_file=` paths.
   On a manual-policy profile it reports that there are no managed targets and
   succeeds without changing policy or files.
6. Delete `REQUESTED_STARTUP_FILES`, `STARTUP_OPTION_REQUESTED`, and all
   installed/update request consumers. Remove internal `--no-startup`
   forwarding from management refresh and selected-tool materialization;
   lifecycle context determines preservation directly.
7. Keep `STARTUP_FILE_PATHS` as internal resolved/recorded state. Fresh managed
   bootstrap populates it from the selected shell; existing-profile operations
   load it from the manifest and never replace it.
8. Tightening `startup_shell=` from optional to required for default profiles
   changes the owned manifest identity. Advance both
   `shimmy_install_manifest_version` and `shimmy_profile_manifest_version` from
   2 to 3 while retaining `shimmy_install_layout=profile-materialized-root`.
   Update all producers, consumers, validators, fixtures, and
   rollback/transaction paths in one implementation unit, and provide no
   migration because the repository explicitly treats earlier layouts as
   unsupported.
9. The new default-profile validator requires one supported normalized
   `startup_shell=`. Zero `startup_file=` entries denotes manual policy;
   nonzero entries denote managed policy. Upstream forbids both fields.
10. A startup update failure may occur after the profile commit. The committed
    manifest retains the intended exact ownership ledger, and guidance points
    to `shimmy update --repair-startup`; installed `shimmy install` is not a
    repair path.
11. The prohibition on changing startup policy is a durable profile-ownership
    invariant explicitly requested by the user. One lowest-cost negative
    assertion may protect an existing-profile bootstrap from `--shell` or
    `--no-startup`; generic unknown-argument coverage remains sufficient for
    removed installed/update options.
12. Remove obsolete option-specific rejection/help-absence tests and do not add
    tests that fossilize removed spellings. Positive tests cover supported
    surfaces, inheritance, exact repair, and ownership.
13. Update normative source, end-user, contributor, context, canonical-skill,
    and current-plan guidance together. Completed historical plans retain their
    evidence with concise supersession notes where necessary.
14. Change the canonical `plugins/shimmy/skills/shimmy-install/SKILL.md` in
    Chunk 1. Refresh generated `.agents/skills/` adapters only through the
    profile-local skills lifecycle in Chunk 2 after human acceptance.
15. Because Chunk 1 makes existing version-2 profiles unsupported without
    migration, Chunk 2 must not use a pre-existing installed upstream profile
    as its refresh authority. Bootstrap a disposable version-3 upstream profile
    under temporary absolute `HOME` and `XDG_CONFIG_HOME`, invoke its absolute
    launcher from the repository root, and remove only that temporary state
    after verification.

## Verified implementation inventory

This is a verified baseline, not permission to ignore newly discovered
dependencies.

- Root bootstrap:
  - `install.sh` establishes `SHIMMY_BOOTSTRAP_PROFILE`, appends the fixed jq/rg
    baseline, and delegates startup options to `commands/install.sh`.
  - The same entrypoint is used for fresh bootstrap, repeat bootstrap, and
    fetched management refresh, so lifecycle state must distinguish them.
- Install production:
  - `lib/install/install.sh` initializes the requested startup variables and
    currently skips startup for an existing profile only when no startup option
    was supplied.
  - `lib/install/request.sh` advertises and parses all three startup selectors.
  - `lib/install/startup.sh` currently reloads manifest state but replaces it
    whenever a request supplies paths, a shell, or unqualified bootstrap.
  - `lib/install/manifest.sh` emits `startup_shell=` only for an explicit shell
    and emits `startup_file=` as the exact ownership ledger.
- Update production:
  - `lib/update/request.sh` advertises and parses repair shell/path selectors.
  - `lib/update/management.sh` reconstructs startup arguments for the fetched
    bootstrap and otherwise forwards `--no-startup`.
  - `lib/update/profile.sh` invokes installed materialization with
    `--no-startup`.
  - `lib/update/update.sh` has upstream guards coupled to the removable request
    state.
- Manifest consumers:
  - `lib/profile/profile.sh` accepts optional unvalidated `startup_shell=` and
    absolute unique `startup_file=` entries for default only.
  - `lib/install/launcher-template.sh` independently validates both manifest
    identity versions before dispatch and must advance in the same atomic
    schema change.
  - `lib/install/uninstall.sh` removes markers only from manifest-owned files.
  - `lib/startup/startup.sh` owns shell normalization, conventional path
    resolution, and exact marker mutation.
- Behavioral tests:
  - `tests/commands/startup.sh` currently proves that a repeat bootstrap can
    replace zsh-only policy with multi-shell policy and that installed install
    can reselect startup paths; both expectations must be reversed.
  - `tests/commands/catalog.sh`, `dispatcher.sh`, `images.sh`, `lifecycle.sh`,
    `onboarding.sh`, `profiles.sh`, `skills.sh`, `startup.sh`, `update.sh`,
    `install.sh`, `management.sh`, and shared fixture helpers directly depend
    on the changed options or manifest identity. `tests/commands/profile.sh`
    also asserts the manifest version; status and installed-test groups consume
    the shared profile fixtures and launcher validation.
  - Existing profile/manifest coverage supplies the appropriate home for the
    schema identity update; do not duplicate generic malformed-state tests.
- Guidance and generated artifacts:
  - `README.md`, `BOOTSTRAP.md`, `commands/README.md`, `CONTRIBUTING.md`,
    `docs/prompt-shimmy-project.md`, `docs/testing.md`, relevant `CONTEXT.md`
    files, and
    `plugins/shimmy/skills/shimmy-install/SKILL.md` describe mutable startup
    selection.
  - `.agents/skills/shimmy-install/SKILL.md` and its manifest fingerprint are
    lifecycle-owned generated output and must not be patched directly.
  - Historical/current plans containing mutable or multi-shell guidance must be
    classified semantically rather than mechanically rewritten.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 (active after approval) — Implement immutable profile startup
  policy, remove later selectors, update schema/tests/docs, and revise
  canonical guidance.
- [ ] Chunk 2 — Refresh generated guidance through its lifecycle and complete
  repo-wide and full-suite verification.

The two-chunk boundary is deliberate. Chunk 1 is large, but schema identity,
startup ownership, public parsing, exact repair/uninstall behavior, fixtures,
tests, contexts, documentation, and canonical guidance form one atomic review
unit and cannot leave mutually incompatible intermediate states. Chunk 2 is a
separate generated-output ownership boundary that cannot begin until the
canonical source change and its one explicit partial result are accepted.

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

At each review gate, surface every `[~]` verification item with what passed,
what remains, why it is partial, its impact, the next action, and whether it
blocks acceptance or is proposed for explicit deferral.

## Chunk 1 — Make startup policy immutable

### Suggested agentic thinking level

XHigh. This is one indivisible owned-format and lifecycle transition spanning
two manifest identities, independent launcher/shared validators, sourced and
executed bootstrap behavior, fetched self-update, exact external-file
ownership, post-commit failure recovery, shared fixtures, and normative
guidance. Splitting those decisions across review gates would leave an invalid
schema or contradictory ownership model.

### Goal

Assign one startup shell and managed/manual policy at fresh default-profile
bootstrap, remove all later selectors, and preserve exact profile-owned startup
state through every install, refresh, repair, and uninstall path.

### Files

- Bootstrap and install lifecycle: `install.sh`,
  `lib/install/{install,request,startup,manifest,launcher-template}.sh`, plus
  any directly affected transaction or profile-asset modules.
- Update lifecycle: `lib/update/{request,management,profile,update}.sh`.
- Manifest ownership: `lib/profile/profile.sh` and verification-only review of
  `lib/install/uninstall.sh` and `lib/startup/startup.sh`.
- Behavioral coverage and fixtures: `tests/support.sh` and the catalog,
  dispatcher, images, install, lifecycle, management, onboarding, profile,
  profiles, skills, startup, status, test, and update modules under
  `tests/commands/`, plus their retained `CONTEXT.md` files.
- Normative guidance: `README.md`, `BOOTSTRAP.md`, `commands/README.md`,
  `CONTRIBUTING.md`, `docs/prompt-shimmy-project.md`, `docs/testing.md`, root
  and relevant child `CONTEXT.md` files, and
  `plugins/shimmy/skills/shimmy-install/SKILL.md`.
- Retained-plan consistency and this plan's evidence/progress sections.

### Implementation requirements

1. Recheck worktree state and the exact request/schema inventory before edits.
   Preserve unrelated changes and stop if they overlap this chunk.
2. Scope `--shell` and `--no-startup` to fresh default bootstrap. Normalize and
   record one shell even for manual policy. Reject either policy selector once
   the profile exists; an unqualified repeat bootstrap inherits existing state.
3. Remove automatic multi-shell resolution from the default path. Retain the
   conventional resolver for the one recorded shell and preserve Bash's
   interactive plus login targets.
4. Remove installed install and update parser/help support for later shell,
   path, or suppression selection. Remove associated request variables,
   branches, upstream guards, forwarding loops, and examples without hidden
   aliases.
5. Make additive install and selected-tool materialization preserve manifest
   startup fields without mutating external startup files. Do not depend on an
   internal public-looking `--no-startup` argument.
6. Make management refresh preserve the profile policy. Ordinary update must
   not touch startup files; repair must update only exact recorded paths. A
   manual-policy repair is an informational no-op.
7. Advance both manifest identity values to 3 while retaining the existing
   layout identity, and validate the transition atomically in the shared
   profile module and generated-launcher template. Require the selected shell
   for default, preserve exact absolute unique startup records, forbid startup
   fields for upstream, and update every fixture, error message, context, test,
   and identity consumer.
8. Preserve commit/failure behavior: a failed managed startup write leaves a
   valid profile whose exact intended paths can be retried with
   `shimmy update --repair-startup`.
9. Rewrite tests to prove fresh inferred/explicit shell assignment, manual
   policy, repeat-bootstrap inheritance, additive-install preservation,
   ordinary-update preservation, exact repair, upstream isolation, failure and
   retry, and uninstall's exact ownership cleanup.
10. Protect the immutable-policy boundary with one low-cost existing-profile
    assertion. Remove obsolete option-specific tests and rely on generic
    unknown-argument coverage for removed public spellings.
11. Update all normative guidance and the canonical install skill. State that
    profile selection comes from the installed launcher, not `--profile`, and
    that a different startup policy requires uninstalling/recreating the
    profile rather than mutating it in place.
12. Do not edit `.agents/skills/` in this chunk. Record its expected stale
    adapter as the only intentional partial state at review.

### Verification checklist

- [ ] `git diff --check` and POSIX syntax checks pass for every changed shell
  file.
- [ ] Manifest identity tests prove one normalized default-profile shell,
  managed/manual representation, exact unique paths, and no upstream startup
  fields without redundant removed-layout coverage.
- [ ] Positive behavior proves fresh inferred and explicit selection, exact
  Bash/zsh conventional targets, manual policy, immutable repeat bootstrap,
  and preservation by additive install and ordinary update.
- [ ] `shimmy update --repair-startup` repairs only the manifest ledger and is
  a policy-preserving no-op for a manual profile.
- [ ] Failure/retry and uninstall tests prove the same exact ownership ledger
  remains authoritative.
- [ ] Installed install help contains only repeatable `--shim`; update help
  retains selector-free `--repair-startup`; no obsolete option-specific test or
  fixture was added.
- [ ] A focused source inventory shows no requested custom-path state, later
  shell selector, startup suppression forwarding, or replacement abstraction.
- [ ] The final Chunk 1 tree passes the directly affected non-generated groups
  serially: `commands-catalog`, `commands-dispatcher`, `commands-images`,
  `commands-install`, `commands-lifecycle`, `commands-management`,
  `commands-onboarding`, `commands-profile`, `commands-profiles`,
  `commands-startup`, `commands-status`, `commands-test`, and
  `commands-update`.
- [ ] `commands-skills` passes after its behavioral invocations are updated.
  Its fingerprint check is not evidence of canonical/generated semantic
  equality, so a separate comparison must prove that `shimmy-install` is the
  only stale adapter.
- [ ] Core request/forwarding code is a net simplification.
- [ ] Canonical guidance is updated and the generated adapter delta is recorded
  as the sole `[~]` item intentionally pending Chunk 2, including what differs,
  why lifecycle refresh is deferred, and why that partial does not affect
  runtime behavior.

### Human review gate

Confirm the profile-owned policy semantics, schema transition, reduced public
surfaces, exact repair/uninstall ownership, test evidence, and production-code
simplification. The review must surface the exact generated-adapter partial
state: `commands-skills` itself must pass, while the generated adapter remains
the sole `[~]` item and the separate semantic comparison must show only expected
`shimmy-install` drift. Acceptance of that explicit partial authorizes only
Chunk 2's generated refresh and final verification.

## Chunk 2 — Refresh generated guidance and close integration

### Suggested agentic thinking level

Medium. The expected mutation is a mechanically constrained lifecycle refresh
of one adapter plus its fingerprint, followed by semantic inventory and full
integration verification. Switch to High and stop for review if preflight or
refresh reveals broader canonical drift, unexpected generated output, or a
failure outside the known Chunk 1 adapter semantic drift.

### Goal

Refresh the lifecycle-owned install-skill adapter and verify that immutable
startup policy is coherent across the full repository.

### Files

- Expected generated targets:
  `.agents/skills/shimmy-install/SKILL.md` and
  `.agents/skills/.shimmy-skills-manifest.txt`.
- Verification-only source: accepted Chunk 1 changes and final inventory
  matches.
- This plan for progress, evidence, lessons, and handoff.

### Implementation requirements

1. Begin only after explicit Chunk 1 acceptance. Re-read applicable guidance,
   this plan, canonical skill, generated adapter, and target manifest.
2. Create a boundary-checked temporary root with `mktemp -d`, assign absolute
   `HOME` and `XDG_CONFIG_HOME` descendants, bootstrap a fresh version-3
   upstream profile from the accepted checkout, and validate its binding to
   that checkout. Do not inspect, activate, update, uninstall, or recreate the
   user's installed profiles. Skill refresh does not require Podman activation.
3. Compare every tracked adapter with canonical source. If drift is broader
   than `shimmy-install`, stop for user direction.
4. From the repository root, refresh only through the disposable profile's
   absolute launcher with `shimmy skills update --target repo`. Do not hand-edit
   generated output or fingerprints. Remove only the validated disposable
   profile state after refresh and verification.
5. Require the generated diff to remain limited to the expected adapter and
   manifest fingerprint unless separately approved.
6. Audit active runtime, tests, help, docs, skills, and generated adapters for
   mutable startup-policy surfaces. Retained option names in this plan or
   historical evidence are not active interfaces.
7. Run generated-skill checks and the complete default suite once.

### Verification checklist

- [ ] Preflight proves only the expected adapter differs before refresh.
- [ ] Disposable bootstrap produces a valid version-3 upstream profile bound to
  the accepted checkout without touching any installed user profile.
- [ ] Lifecycle refresh succeeds through that disposable profile's absolute
  launcher and only its validated temporary state is cleaned up.
- [ ] Generated adapter is semantically identical to canonical source and its
  manifest fingerprint validates.
- [ ] `git diff --check` and POSIX syntax checks pass.
- [ ] Repo-wide inventory finds no active custom-path input, installed/update
  shell selector, later startup suppression selector, or policy-changing path.
- [ ] `./tests/test.sh --serial --group commands-skills` passes.
- [ ] The complete default suite passes with `./tests/test.sh`.
- [ ] Final diff contains no compatibility alias, migration, special legacy
  error, removed-option test, or unrelated generated change.

### Human review gate

Confirm generated lifecycle output, full-suite results, semantic inventory,
immutable ownership behavior, and final core-code simplification. Acceptance
closes this refactor only.

## Risk register

- **Profile setting remains ambiguous:** Optional `startup_shell=` cannot
  distinguish inferred multi-shell behavior from manual policy. Mitigation:
  record one normalized shell for every new default profile and advance the
  manifest identity.
- **Repair transfers ownership:** Re-resolving from current shell/home state can
  orphan an old marker or adopt a new file. Mitigation: repair and uninstall
  consume the exact recorded ledger.
- **Management refresh reopens policy:** Reconstructed bootstrap arguments can
  behave like a private mutation API. Mitigation: remove argument forwarding
  and preserve policy through lifecycle state.
- **Manual policy is accidentally enabled later:** A no-startup profile could
  gain managed paths during repair. Mitigation: zero recorded paths is an
  explicit manual policy and repair is a tested no-op.
- **Manifest transition becomes partial:** Updating only render or validation
  can strand fixtures and transaction flows. Mitigation: treat the schema
  identity, every producer/consumer, fixtures, and rollback behavior as one
  Chunk 1 review unit.
- **Bash ownership drifts:** Login-file precedence can change after bootstrap.
  Mitigation: resolve once and retain the exact chosen login path.
- **Negative tests fossilize removed flags:** Specific rejection coverage would
  preserve deleted spellings as contracts. Mitigation: retain only the
  explicitly requested immutable-policy boundary and generic parser coverage.
- **Generated refresh expands unexpectedly:** The lifecycle may refresh
  unrelated stale adapters. Mitigation: preflight the exact drift set and stop
  if it is broader than expected.
- **Version-2 refresh authority becomes invalid:** Chunk 1 intentionally offers
  no migration, so a pre-existing installed upstream profile represents the old
  owned format. Mitigation: use a fresh disposable version-3 upstream profile
  for Chunk 2 and leave installed user profiles untouched.

## Lessons learned

### Initial

- The previous plan removed arbitrary paths but still treated shell selection
  and startup suppression as per-operation controls. That was inconsistent
  with profile-local ownership.
- Current additive install and update parsing can replace startup policy; the
  flags are functional mutation surfaces, not harmless redundant options.
- Installed profile identity is already derived from the launcher's enclosing
  root, so inheritance requires no installed `--profile` selector.
- `startup_file=` is the safest repair source because it preserves exact path
  ownership when `$HOME`, `$SHELL`, or Bash login-file precedence changes.
- Recording exactly one normalized startup shell eliminates the current
  optional-shell/multi-shell ambiguity. Manual integration can remain explicit
  as a shell with zero owned startup paths.
- Because required manifest semantics change, a schema identity advance is
  more coherent than silently reinterpreting existing version-2 state.
- The schema advance also invalidates the earlier assumption that Chunk 2 can
  reuse a pre-existing upstream profile; generated refresh needs disposable
  version-3 profile state.

## Session bootstrap

This plan is at final review. A fresh implementation session must
read `AGENTS.md`, `CONTRIBUTING.md`, root and relevant child `CONTEXT.md` files,
this entire plan, and Chunk 1 target files. The non-negotiable target is a
fresh-bootstrap-only default-profile startup policy: one normalized recorded
shell, managed exact paths or manual zero paths, no later selectors, no
installed profile selector, and exact ledger-based repair/uninstall. No
compatibility layer or removed-option test is allowed.

Chunk 1 begins only after explicit user approval. Stop at its human review
gate and do not refresh `.agents/skills/` until the canonical change is
accepted. Use XHigh reasoning for Chunk 1. After acceptance, Chunk 2 uses
Medium reasoning unless unexpected drift requires High reasoning and another
review stop.
