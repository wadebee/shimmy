# Split Profile Create and Clone Plan

## Objective

Split the profile creation surface into two unambiguous operations:

```text
create = materialize a pristine baseline from current refs/heads/main and registry-current
clone  = reproduce the invoking profile's validated reproducible state
sync   = advance an existing active invoking profile to current main/catalog authority
```

Success requires:

- `shimmy profile create <name>` to resolve the invoking profile's configured
  source URL at exact `refs/heads/main`, pin the installation's current default
  catalog generation, materialize only tracking jq/rg/Skopeo at that
  generation's defaults, and automatically activate the new profile;
- `shimmy profile clone <name>` to preserve the invoking profile's exact
  control commit, catalog pin, complete shim/default/exact-version state, and
  registry redirects under a new profile identity, then automatically activate
  it;
- create, clone, and sync provenance to be distinguishable in behavior, help,
  documentation, retained design records, and dry-run output;
- create and clone to revalidate every authority they consume before candidate
  commit and to retain the existing activation, workload, rollback, and
  AI-skill collision policies; and
- focused and complete acceptance to prove stale-source create, true clone,
  sibling independence, dry-run purity, and concurrency behavior.

This plan does not authorize implementation. It also does not add migration or
compatibility aliases, configurable source refs, remote-HEAD following, Podman
machine provisioning/copying, startup-ledger copying, user-link copying, or a
new shell-completion subsystem.

## Target layout and terminology

The public profile tree becomes:

```text
profile
├── list
├── status
├── create
├── clone
├── activate
├── sync
├── repair-startup
├── delete
└── redirect
```

The exact new forms are:

```text
shimmy profile create <name> [--restart] [--stop-running] [--dry-run]
shimmy profile clone <name> [--restart] [--stop-running] [--dry-run]
```

- **Invoking profile** is the profile containing the launcher. Both create and
  clone take their source URL or source state from this profile even when a
  different profile is active.
- **Prior active profile** remains the engine/registry/active-record authority
  until automatic activation commits the new profile.
- **Create authority** is the invoking source URL plus an exact commit resolved
  only from `refs/heads/main`, together with the snapshotted registry-current
  default-catalog record.
- **Clone authority** is the invoking profile's validated exact source record,
  retained catalog pin, shim and shim-version records, and parsed redirect
  entries.
- **Identity-dependent state** is regenerated for the new name: profile root,
  manifest identity, `shimmy-<name>` engine identity, launcher and
  `shell-init.sh` paths, registry-file ownership header, and both AI-skill
  bundle profile identities.
- **External/runtime state** includes startup-file bytes and ledger ownership,
  Podman machine/connection contents, machine projection records, active-record
  state, locks, transactions, current shell PATH, and user AI-skill links. It is
  never cloned.

The internal target is one shared new-profile transaction:

```text
shimmy_profile_new_run <create|clone>
        |
        +-- shimmy_profile_create_authority_resolve
        |      source URL -> exact refs/heads/main commit
        |      registry-current -> baseline records
        |
        +-- shimmy_profile_clone_authority_resolve
               invoking manifest/catalog/shims/versions/redirects
        |
        v
common candidate materialization
        -> image preparation
        -> authority locks and revalidation
        -> candidate commit (manifest last)
        -> normal activation
        -> active-record and AI-skill reconciliation
        -> shell-selection guidance
```

Shared Git-main discovery belongs in the profile-owned helper
`lib/profile/source.sh`; sync and create must use the same exact-ref fetch and
revalidation rules rather than maintaining two subtly different implementations.

## Recorded design decisions

1. Create and clone are installation-wide source operations keyed by the
   invoking launcher. They do not require the invoking profile to be active,
   but the installation's current active engine/registry state must validate
   before either may transition authority.
2. Create reads only the invoking profile's validated source URL. It resolves
   exactly `refs/heads/main`, never remote HEAD or a configurable branch/tag,
   and uses the installation default catalog's exact registry-current record.
   It materializes tracking jq, rg, and Skopeo at current catalog defaults with
   empty redirects and no startup records.
3. Clone is an actual reproducible-state clone, not the old baseline-only create
   behavior under a new name. It preserves the exact source URL/tracking
   ref/commit, catalog generation record, all shim tracking/pinned policies,
   every default version, every additional exact version, and every parsed
   redirect entry.
4. Clone reconstructs owned artifacts through existing renderers and retained
   authority instead of recursively copying a profile directory. Control assets
   and the control bundle may use the existing validated installed-source path;
   the control bundle manifest is rerendered for the new profile identity.
   Shim assets and the shim bundle are regenerated from the retained catalog
   generation and cloned records. Redirects are parsed from the invoking
   profile and rerendered with the new ownership header.
5. Candidate materialization accepts normalized registry-entry records, not an
   opaque registry file. Bootstrap/create pass an empty list; clone passes the
   invoking entries; sync parses and rerenders its own entries. This preserves
   canonical bytes while allowing clone to change profile identity safely.
6. Both new profiles have absent `startup_shell` and no `startup_file` records.
   They do not inspect, copy, edit, or remove startup files. Existing startup
   integration remains owned by its recorded profile lifecycle.
7. Neither operation copies `active-profile.conf`, lock directories, temporary
   transaction state, `machine-projection.txt`, shell PATH/function state,
   user-level skill links, or Podman state. Normal activation derives
   `shimmy-<new-profile>`, applies registry projection, commits active authority,
   and reconciles the new profile's exact bundle-declared user links with the
   existing bounded-compensation behavior.
8. `--restart`, `--stop-running`, automatic activation, shell retargeting after
   successful sourced invocation, and direct-execution shell guidance retain
   their current meanings for both create and clone. Linux continues to reject
   the two macOS-only acknowledgements.
9. Dry run is read-only. Create may perform `git ls-remote` for exact
   `refs/heads/main` resolution but must not create a fetch checkout, candidate,
   lock, image/engine call, active-record write, startup mutation, or link
   mutation. Clone uses only validated local state. Both preserve the current
   common activation/image/link plan fields and add explicit provenance:

   ```text
   create: would_resolve_control_ref=refs/heads/main|<commit>
           would_pin_catalog=<generation>
           would_materialize_shim=<tool>|<default>|tracking

   clone:  would_clone_profile=<invoking>
           would_clone_control_ref=<commit>
           would_pin_catalog=<generation>
           would_clone_shim=<tool>|<tracking|pinned>
           would_clone_shim_version=<tool>|<version>|<default|exact>
           would_clone_redirect=<prefix>|<location>

   both:   would_startup_shell=absent
           would_startup_file=none
   ```

   Control collision planning uses the fixed validated management-skill name
   set; shim collision planning uses the selected baseline or cloned inventory.
   Source URLs are not printed, avoiding credential-bearing URL disclosure.
10. Non-dry-run create first resolves exact main, fetches/stages that exact
    commit, and rejects a fetch mismatch or a later `refs/heads/main` change.
    Under catalog/activation/profile/registry locks it revalidates the invoking
    source manifest, prior active/user-root authority, registry-current record,
    target absence, and the prepared candidate before manifest-last commit.
11. Non-dry-run clone fingerprints the invoking manifest and registry config
    before staging. It acquires catalog then activation, lexical source/target
    profile locks, then lexical required registry locks; under those locks it
    rereads the invoking candidate and redirect entries and rejects any change
    before target commit. Source and clone thereafter mutate independently.
12. The implementation must not maintain two large lifecycle bodies. Shared
    root creation/removal, candidate commit, activation, rollback, cleanup, and
    shell-selection behavior remain one path selected by explicit authority
    resolver output.
13. There are no compatibility aliases, environment aliases, migration paths,
    configurable refs, or tests whose only purpose is proving an obsolete form
    absent. Positive surface and behavioral tests define the new contract;
    concurrency rejection is retained because it protects the durable
    transactional-integrity boundary.
14. No executable shell-completion implementation exists in the current tree.
    `plans/bash-completion.md` remains a separate not-started subsystem plan;
    this work updates its future command authority matrix to the current public
    surface including clone, but does not implement completion assets.
15. `plans/redesign-control-surface.md` remains a related retained design and
    execution record, not this plan's authority. Its accepted historical
    evidence remains truthful; superseded create decisions and Chunk 8
    acceptance language receive explicit supersession notes rather than
    rewriting history. Existing uncommitted Chunk 10/11 evidence must be
    preserved exactly except for intentional, narrowly scoped semantic edits.

## Verified implementation inventory

This inventory is a verified baseline, not permission to ignore dependencies
discovered during implementation.

- `commands/profile.sh` parses only create today and dispatches it to
  `shimmy_profile_create_run`; clone has no parser or route.
- `lib/install/lifecycle.sh` owns bootstrap, current create dry-run/run, shared
  new-root commit/removal, automatic activation, external compensation, and
  shell guidance. Current create copies the invoking installed control
  assets/bundle, pins its exact catalog generation, materializes only baseline
  shims, leaves startup/redirects empty, and fingerprints only the source
  manifest for under-lock revalidation.
- `lib/install/profile.sh` already supports Git-derived or validated-installed
  control materialization, identity-aware launcher/shell rendering,
  catalog-derived shim/default/exact-version reconstruction, and identity-aware
  control/shim bundle generation. Its registry argument currently accepts a
  same-profile file, which cannot safely clone a differently named header.
- `lib/update/profile.sh` owns sync's exact-main fetch/revalidation and complete
  candidate replacement. Sync snapshots registry-current, preserves shim
  policies/exact versions/startup and registry bytes, resolves tracking
  defaults, and revalidates the prior manifest, catalog registry, redirect
  config, active record, and current generation.
- `lib/profile/management.sh`, `lib/profile/state.sh`, and
  `lib/profile/activation.sh` validate candidates, distinguish invoking and
  active authority, derive `shimmy-<profile>`, and implement activation ordering
  and rollback. `lib/profile/transaction.sh` owns external compensation.
- `lib/registries/registries.sh` can strictly parse canonical redirects to
  normalized `prefix|location` records and rerender them for a target identity;
  raw file copying would retain the wrong ownership header.
- `lib/ai-skill/ai-skill.sh` and `lib/ai-skill/bundle.sh` can materialize exact
  commit/catalog bundles and rerender bundle identity. Activation already owns
  exact direct-link reconciliation and collision compensation.
- `commands/help.sh`, `commands/README.md`, root `README.md`, `BOOTSTRAP.md`,
  `CONTRIBUTING.md`, `commands/CONTEXT.md`, `lib/install/CONTEXT.md`,
  `lib/update/CONTEXT.md`, and `tests/commands/CONTEXT.md` describe the current
  create/sync surface.
- `plugins/shimmy/skills/shimmy-install/SKILL.md` is the only canonical
  management skill found that documents profile creation. Generated
  `.agents/skills/` copies remain out of scope.
- `tests/commands/lifecycle.sh` is the indivisible public end-to-end profile
  world and currently proves baseline-only create, automatic activation,
  no-startup inheritance, sibling isolation, sync, and dry-run nonmutation.
  `tests/commands/surface.sh` owns complete help grammar; focused activation and
  shell-selection behavior lives in `tests/commands/profile.sh`.
- `plans/redesign-control-surface.md` currently records the superseded exact
  invoking-commit/catalog create decision and related Chunk 8 acceptance. It
  also contains unrelated user modifications that must not be overwritten.
- `plans/bash-completion.md` is not implemented and predates the current public
  surface; its future grammar is a documentation consumer, not runtime code.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Extract the shared new-profile and exact-main infrastructure
  without changing current public behavior. **Active chunk.**
- [ ] Chunk 2 — Atomically add true clone, redefine create, update every public
  consumer, and complete acceptance.

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

## Chunk 1 — Shared new-profile infrastructure

### Goal

Refactor current create and sync internals into reusable authority, registry-
entry, materialization, cleanup, and commit seams while preserving the existing
public command grammar and current create behavior at this review gate.

### Files

- `commands/profile.sh`
- `lib/profile/source.sh` (new) and `lib/profile/CONTEXT.md`
- `lib/install/lifecycle.sh`, `lib/install/profile.sh`,
  `lib/install/CONTEXT.md`
- `lib/update/profile.sh`, `lib/update/CONTEXT.md`
- `lib/registries/registries.sh` if a narrow shared entry renderer/parser seam
  is required
- `tests/commands/lifecycle.sh`, `tests/commands/profile.sh`
- this plan

The list is the primary surface, not a limit on newly discovered required
consumers.

### Implementation requirements

- Move exact `refs/heads/main` lookup/fetch/revalidation and checkout cleanup
  into profile-owned shared helpers. Preserve sync's option terminators, exact
  commit validation, fixed ref, error behavior, and no remote-HEAD fallback.
- Extract `shimmy_profile_new_run`, one common dry-run renderer, authority
  output globals/records, authority revalidation, lexical lock acquisition,
  root creation/removal, candidate commit, activation, cleanup, and shell
  guidance from current create without changing its visible semantics yet.
- Keep `shimmy_profile_create_authority_resolve` on the current invoking exact
  commit/catalog plus baseline-only behavior until Chunk 2. Do not expose clone,
  change help, or change create provenance in this chunk.
- Refactor candidate registry input to normalized entries and rerender the
  identity-aware file. Update sync to parse/rerender its own entries while
  preserving its canonical redirect content and existing under-lock fingerprint
  revalidation.
- Keep bootstrap semantics unchanged and use the same materializer with empty
  redirects. Do not change schema versions or manifest records.
- Preserve manifest-last commit, candidate/full-state validation, image
  preparation before locks, activation ordering, external compensation,
  interruption cleanup, and safe new-root deletion boundaries.
- Avoid temporary compatibility-named functions or duplicated create/clone
  bodies. Internal names introduced here must remain truthful after Chunk 2.

### Verification checklist

- [ ] Current public `profile create` still copies the invoking exact control
  commit/catalog, materializes only baseline shims, has no startup/redirect
  inheritance, automatically activates, and retains current dry-run fields.
- [ ] Bootstrap and profile sync retain their accepted source, catalog,
  redirect, startup, shim-policy, image, bundle, activation, and rollback
  behavior after shared-helper extraction.
- [ ] Focused `commands-profile`, `commands-surface`, and
  `commands-lifecycle` groups pass with the default bounded scheduler using
  `./tests/test.sh --group commands-profile --group commands-surface --group commands-lifecycle --jobs 3`.
- [ ] Changed POSIX shell files parse, executable modes remain correct, no
  generated `.agents/skills/` tree appears, and `git diff --check` passes.
- [ ] The only user-visible behavior at this gate is none; any unavoidable
  divergence is reported and reviewed before Chunk 2.

### Human review gate

Confirm that the extraction is behavior-preserving, that create/sync share
exact-main and registry-entry primitives without conflating their authority,
and that the new transaction seam is small enough to support both create and
clone. Acceptance authorizes only Chunk 2.

## Chunk 2 — Atomic create/clone semantic cutover

### Goal

Add the public clone command and redefine create in one coherent transition,
then update tests, help, documentation, canonical skills, contexts, and retained
plans so no current consumer describes the superseded semantics.

### Files

- `commands/profile.sh`, `commands/help.sh`, `commands/README.md`
- `lib/profile/source.sh`, `lib/install/lifecycle.sh`,
  `lib/install/profile.sh`, and any shared profile/registry/AI-skill seam proven
  necessary by Chunk 1
- `tests/commands/lifecycle.sh`, `tests/commands/profile.sh`,
  `tests/commands/surface.sh`, `tests/commands/CONTEXT.md`
- `README.md`, `BOOTSTRAP.md`, `CONTRIBUTING.md`, applicable retained
  `CONTEXT.md` files
- `plugins/shimmy/skills/shimmy-install/SKILL.md`
- `plans/redesign-control-surface.md`, `plans/bash-completion.md`
- this plan

The list is the primary surface, not a limit on newly discovered required
consumers.

### Implementation requirements

- Add clone parser/help/dispatch with the exact create option grammar and the
  same safe-name, duplicate-option, host-OS, activation, and sourced-shell
  behavior.
- Rewrite create authority resolution to snapshot the invoking source URL,
  exact `refs/heads/main` commit, registry-current generation, and baseline
  tracking records. Use `git ls-remote --refs` for mutation-free dry-run
  resolution; non-dry-run fetches/stages the exact resolved commit and
  revalidates it before commit.
- Implement clone authority resolution from one fully validated invoking
  candidate. Snapshot and preserve its exact source/catalog/shim/version
  records, parse its redirects, derive every image pair, and force empty startup
  records. Rerender every identity-bearing file/bundle for the target name.
- Revalidate create and clone according to Recorded decisions 10 and 11. Add
  deterministic test seams only where required to prove source-manifest,
  redirect, registry-current, or remote-ref changes cannot commit a mixed
  candidate; test-only controls must use `SHIMMY_TEST_` names and remain
  inactive outside explicit test mode.
- Preserve the target root as absent on any pre-commit or activation failure,
  and restore prior engine/registry/active-record/recognized-link state within
  existing bounded rollback. Continue to report irrecoverable overwritten
  foreign skill content as incomplete rather than claiming recovery.
- Render dry-run provenance and full selected inventories exactly as recorded
  above. Assert no checkout/candidate/lock/transient remains, no image or engine
  command runs, and active record, registry projection/config, startup files,
  profiles, and user links retain exact prior state.
- Prove clone independence in both directions and create independence from a
  stale invoking profile. Tests must positively compare source/catalog/shim/
  version/redirect records and identity-bearing outputs; do not add generic
  absence coverage for old behavior.
- Update help-before-state routing and surface inventory so clone appears in
  root/profile/action help and rendered installed command assets remain byte-
  authoritative.
- Update current docs and the canonical `shimmy-install` skill with the
  create/latest, clone/reproduce, sync/advance model, activation warnings, dry-
  run guidance, and exact command forms. Preserve the canonical skill warning
  immediately after frontmatter; do not edit generated skill copies.
- Reconcile `plans/redesign-control-surface.md` narrowly: supersede the old
  recorded create decision, add clone to the command tree, annotate Chunk 8's
  historical acceptance/evidence, and update later acceptance/session language
  without disturbing the user's pending Chunk 10/11 evidence. Update the
  not-started completion plan's future grammar to include the current profile
  surface and clone; do not implement completion.

### Verification checklist

- [ ] From an invoking `C1/G1` profile with current `main=C3` and
  `registry-current=G4`, create produces exact `C3/G4`, tracking jq/rg/Skopeo at
  G4 defaults, empty redirects/startup, target identity, and automatic
  activation.
- [ ] Clone of a profile containing tracking and pinned shims, changed defaults,
  additional exact versions, and multiple redirects preserves all exact
  reproducible records and reconstructed assets while changing only target
  identity and omitting startup/external runtime state.
- [ ] Sync retains its contract: it advances the existing active invoking
  profile to exact main/current while applying tracking/pinning policies and
  preserving startup and redirects.
- [ ] Mutating/syncing the source after clone does not change the clone, and shim
  or redirect mutations in the clone do not change the source.
- [ ] Create and clone dry runs expose the required provenance, inventories,
  engine/activation/image/link plans and leave filesystem, engine, catalog,
  registry, active record, startup, image logs, and user links unchanged.
- [ ] Authority-change tests prove create rejects moved main/current catalog or
  invoking-source changes and clone rejects invoking manifest/redirect changes
  between staging and commit, leaving no target or mixed state.
- [ ] Help, root/profile command summaries, `commands/README.md`, README,
  BOOTSTRAP, contexts, canonical skill, retained redesign, and future completion
  grammar agree on create/latest, clone/reproduce, and sync/advance.
- [ ] `./tests/test.sh --group commands-profile --group commands-surface --group commands-lifecycle --jobs 3` passes, followed by one clean default
  `./tests/test.sh` run. Rerun only observed failures serially for diagnosis.
- [ ] POSIX syntax, executable modes, installed command inventory, canonical
  skill/payload validation, context-tree validation, terminology searches, and
  `git diff --check` pass. The final diff contains no unrelated edits or
  generated `.agents/skills/` artifacts.
- [ ] Manual stale-profile acceptance, when the required pre-existing engines
  are available, proves clone remains `C1/G1` while create becomes `C3/G4` on
  Linux amd64 and Apple Silicon macOS arm64. Any unavailable native evidence is
  surfaced as `[~]` with impact and an explicit review disposition; no machine
  is provisioned or modified outside normal approved activation.

### Human review gate

Confirm the public semantic distinction, exact clone fidelity, stale-create
behavior, authority revalidation, dry-run purity, activation/rollback limits,
documentation consistency, and any explicitly partial native acceptance. This
gate accepts the implementation; it does not authorize unrelated follow-up
work.

## Risk register

- **Mixed authority during create.** Main and registry-current can move while
  staging. Snapshot exact values, fetch the selected commit, revalidate remote
  main before commit, and hold/revalidate catalog authority under the catalog
  lock. Failure removes the target candidate/root.
- **Mixed clone state.** Shim lifecycle and redirect lifecycle use different
  locks. Fingerprint both manifest and registry config, then acquire lexical
  source/target profile and required registry locks in global order before
  rereading both authorities.
- **Wrong redirect ownership.** Copying `registries.conf` bytes would embed the
  invoking name. Parse canonical entries and rerender the target header; keep
  sync on the same normalized-entry path.
- **Opaque or stale external state leakage.** Recursive profile copying could
  import projection, locks, startup, or transaction files. Materialize only the
  explicit reproducible record set and let activation derive external state.
- **Dry-run side effects.** Reusing the non-dry fetch path would create a
  checkout. Resolve main with read-only `ls-remote`, enumerate fixed validated
  control names and selected shim names locally, and assert all mutation logs
  and filesystem authorities are unchanged.
- **Rollback after automatic activation.** Engine/registry/active record and
  user links cross ownership boundaries. Retain existing deferred engine commit
  and external compensation; continue to report overwritten foreign skill
  content as irrecoverable.
- **Dirty retained redesign plan.** The only pre-plan dirty path is the user's
  `plans/redesign-control-surface.md` Chunk 10/11 evidence. Re-read its diff at
  Chunk 2 entry and patch only superseded semantic sections; stop if overlapping
  changes cannot be preserved.
- **Completion-plan drift.** There is no runtime completion to update. Keep the
  separate not-started plan truthful about the future public grammar without
  importing completion implementation into this objective.
- **Test cost and native availability.** Lifecycle coverage is indivisible and
  native machines may be unavailable. Use the default three-worker focused gate,
  one final full run, and surface native gaps explicitly rather than silently
  substituting emulation or provisioning machines.

## Lessons learned

### Initial

- Current create is neither future create nor true clone: it copies invoking
  control/catalog authority but deliberately resets to baseline shims and empty
  startup/redirect state.
- Existing materialization already reconstructs identity-sensitive launchers,
  shell init, shims, and AI-skill bundles. Registry input is the one materializer
  seam that cannot clone across names without normalization and rerendering.
- Sync owns the exact-main implementation needed by future create; sharing that
  primitive avoids branch/ref drift while keeping sync's policy transformation
  separate from create's pristine baseline.
- Clone concurrency must protect both manifest-backed state and separately
  locked redirects. A manifest fingerprint alone does not snapshot the complete
  requested clone authority.
- The management skill name set is fixed and validated, so create dry-run can
  classify control-link destinations after `ls-remote` without fetching or
  staging the new control tree.
- The repository has no executable shell-completion subsystem. The existing
  completion document is a not-started future plan and must not be mistaken for
  runtime code.
- `plans/redesign-control-surface.md` has unrelated uncommitted progress
  evidence. The new authoritative plan must remain separate, and later semantic
  reconciliation must preserve that work.

## Session bootstrap

Start in Chunk 1. Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, this
plan, and the retained contexts for every changed path. Then read
`commands/profile.sh`, `lib/install/lifecycle.sh`, `lib/install/profile.sh`,
`lib/update/profile.sh`, `lib/profile/{management,state,activation,transaction}.sh`,
`lib/registries/registries.sh`, relevant AI-skill bundle code, and the focused
profile/surface/lifecycle tests. Recheck `git status` and preserve the user's
uncommitted `plans/redesign-control-surface.md` edits. The target is
create=latest pristine, clone=reproduce, sync=advance, with no compatibility,
startup copy, runtime-state copy, machine provisioning, or generated skill
adapters. Execute only Chunk 1 and stop at its human review gate; do not begin
the semantic cutover without explicit acceptance.
