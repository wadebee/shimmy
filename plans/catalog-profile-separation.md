# Catalog and Profile Separation — Chosen Architecture

## Objective

Implement **Option 1: a shared named catalog with profile-local control planes
and an explicit catalog schema contract**.

The target behavior is:

- the shared catalog is the profile-independent authority for every available
  tool, concrete version, and canonical Shimmy skill;
- each profile retains its own `shimmy` launcher, management code, manifest,
  selected tool materializations, and mutation boundary;
- every profile initially uses the single named catalog `upstream`;
- after a new tool has been completely created in `upstream`, it is available
  for installation into an existing or new profile on the next `shimmy`
  command invocation, without closing or reopening the shell, refreshing a
  profile, or running an intermediate synchronization step to pick up the
  local code change; and
- installed tools continue to execute from profile-owned materializations if
  the catalog is unavailable or later changes.

This plan does not preserve or migrate the current flat installed layout.
Existing Shimmy installations and profiles will be uninstalled and recreated
with the new implementation. It also does not introduce a shared global
control plane or silently change an installed profile when a catalog default
changes.

One decision remains open: the storage and publication lifecycle of the
`upstream` catalog source. That gap is detailed in **Unresolved** and must be
closed before implementation begins.

## Confirmed root cause

The current behavior follows directly from the flat-profile architecture:

1. `profile_control_assets_stage` in `lib/install/profile-assets.sh` copies the
   complete repository `commands/`, `lib/`, `tools/`, `tests/`, and `plugins/`
   trees into each profile.
2. Installed management commands derive `ROOT_DIR` from their enclosing
   profile and resolve `SHIMMY_TOOLS_DIR` to that profile's copied `tools/`
   tree.
3. `lib/catalog/catalog.sh` discovers availability only from that tools root.
4. Install, available status, image verification, skill discovery, agent
   preflight, and update selection therefore consult the invoking profile's
   catalog snapshot rather than the checkout where a new tool was created.
5. The profile manifest correctly records a selected subset, but the profile
   payload also owns the full availability catalog and canonical skills. These
   distinct ownership boundaries are currently conflated.

The required correction is not a shell initialization change. Catalog-aware
commands must resolve and read the shared named catalog on every invocation;
the shell continues to select only the profile-local launcher and tool
dispatchers through `PATH`.

## Target layout and terminology

### Stable terms

- **Catalog registry**: shared installation state that resolves a unique
  catalog name to its authority. It is outside every profile root.
- **Catalog name**: a stable identifier for a catalog. The first implementation
  contains exactly one catalog named `upstream`.
- **Catalog authority**: the complete schema-valid source of available tools,
  versions, management skills, and tool skills for a named catalog.
- **Catalog source**: the physical storage behind a catalog authority, such as
  a live source checkout or an installed immutable snapshot.
- **Profile selection**: the exact tool and concrete-version entries recorded
  in one profile manifest.
- **Profile materialization**: the runtime, metadata, dispatcher, and
  version-owned assets copied or rendered for only the selected entries in one
  profile.
- **Profile-local control plane**: the installed `shimmy` launcher, commands,
  and shared libraries bound to one profile's mutation boundary.
- **Agent user-profile target**: `$HOME/.agents/skills`, selected by `shimmy
  skills --target profile`. This is not a Shimmy execution profile.

The Shimmy profile named `upstream` and catalog named `upstream` are different
resources. Both `default` and `upstream` profiles initially bind to the
`upstream` catalog.

### Logical target layout

The unresolved catalog source lifecycle may refine the files below the named
catalog, but it must preserve this ownership boundary:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/
  catalogs/
    upstream/                 # shared registry entry and catalog authority/binding
      catalog.conf            # catalog identity and schema declaration
      <source-specific state> # unresolved: live binding, snapshot, or hybrid
  profiles/
    default/
      bin/                    # profile-local shimmy and selected tool dispatchers
      commands/ lib/          # profile-local management control plane
      manifest                # catalog binding and selected tool versions
      implementations/        # selected tool implementations
      tools/                  # selected version-owned runtime/assets only
    upstream/
      ...                     # independent selection; same named catalog
```

Canonical skills belong to the catalog authority, not to a profile control
payload:

```text
<catalog-authority>/
  catalog.conf
  plugins/shimmy/skills/      # canonical control-plane skills
  tools/<tool>/SKILL.md       # canonical tool skill beside tool metadata
  tools/<tool>/tool.conf
  tools/<tool>/versions/<major.minor>/...
```

Profile materialization must not depend on those exact physical paths after a
tool has been installed. The implementation may choose a smaller profile-owned
runtime layout as long as dispatch remains independent of catalog availability.

## Recorded design decisions

### Architecture and ownership

1. Option 1 is selected. Profile-local launchers and management control planes
   remain; a shared global control plane will not be introduced.
2. Catalog availability and profile materialization use separate roots and
   separate ownership records.
3. Catalog-aware commands resolve the invoking profile's catalog name on every
   invocation. They must not cache a catalog path in shell startup state or
   require profile refresh to discover a new valid entry.
4. Installing a catalog entry into one profile does not install or alter it in
   another profile.
5. A catalog default change does not silently change an installed profile.
   The recorded concrete version and everything required to run it remain
   profile-owned until an explicit profile install or update operation changes
   them.
6. Catalog-dependent management operations fail before mutation when the
   catalog cannot be resolved or validated. Already-materialized tools continue
   to run.
7. Catalog activation or publication and profile materialization are staged,
   validated, and committed atomically. A profile must not observe or install
   a partially validated catalog entry.

### Named catalogs and multiple checkouts

1. Catalog identity is name-based rather than inferred from the invoking
   checkout or profile.
2. The first implementation creates and recognizes exactly one catalog named
   `upstream`; every created profile records `catalog=upstream`.
3. No checkout may silently replace another source registered under the same
   catalog name. The source-lifecycle decision must define the explicit
   activation, replacement, or publication transaction for `upstream`.
4. The plural `catalogs/` registry and profile manifest binding preserve a path
   for future named catalogs. Adding another catalog, catalog-selection CLI,
   precedence rules, or cross-catalog tool resolution is outside this first
   implementation.
5. If multiple named catalogs are added later, each checkout must use a unique
   catalog name and each profile must resolve exactly one catalog. Tool lookup
   will not merge catalogs implicitly.

This resolves multiple-checkout identity and collision behavior without
prematurely adding multi-catalog selection to the CLI.

### Explicit catalog schema contract

The initial contract is exact-versioned rather than best-effort compatible.
At minimum, the catalog authority owns a root `catalog.conf` containing one
value for each of:

```text
catalog_format=shimmy-catalog
catalog_schema=1
catalog_name=upstream
```

The implementation must define the version-1 contract in one catalog module
and validate it before any consumer performs discovery or mutation. Version 1
includes:

- the required root identity keys and rejection of missing, duplicate, or
  unknown contract keys;
- a safe catalog-name grammar and an exact match between the registry entry,
  `catalog_name`, and the profile manifest binding;
- the required `plugins/shimmy/skills/` management-skill sources;
- tool directory naming and required `tool.conf`, `SKILL.md`, and
  `versions/<label>/` structure;
- tool-default resolution and the required per-version `smoke.conf`,
  `image.conf`, executable runtime, and version-owned assets;
- rejection of unsafe paths, escaping links, duplicate logical tool/version
  identities, incomplete entries, and unsupported schema versions; and
- the catalog data that may be copied into a profile and the metadata that
  must be recorded to identify the source catalog and selected version.

Each profile-local control plane declares the catalog schema versions it can
read. For the initial implementation it accepts exactly schema `1`. A mismatch
must produce a precise error that names the catalog, found schema, and accepted
schema before any profile, catalog, exported skill, or target manifest is
changed.

There is no requirement to read the old flat-profile format or an unversioned
catalog. A future catalog schema change must be planned as a coordinated
producer/consumer transition; version 1 readers must never guess how to read a
newer schema.

### Immediate availability after creation

“Immediately available after creation” means that once a complete tool entry
in the `upstream` catalog satisfies schema 1, the next catalog-aware command
run by any existing profile can discover and install it. The user does not:

- close or reopen the shell;
- source `shell-init.sh` again;
- refresh, update, or reinstall a profile; or
- run a separate synchronization/publication command solely to make the local
  code change visible.

This requirement does not mean that partially authored or schema-invalid tool
directories are visible. They must be ignored only where discovery can do so
unambiguously or, preferably, cause catalog validation to fail clearly without
mutation. The selected source lifecycle must define the completion/commit
boundary that makes a new tool valid and visible.

### Compatibility and existing installations

1. Backwards compatibility is not required.
2. Existing Shimmy installations and all preexisting profiles will be removed
   through the existing uninstall workflow and recreated by the new
   implementation.
3. The implementation adds no in-place profile migration, compatibility
   forwarding paths, legacy manifest aliases, or mixed-layout support.
4. New code must detect legacy or mixed installed state and stop with an
   actionable uninstall-and-recreate error rather than mutating it.
5. Uninstall safety remains required: removal must be bounded to
   manifest/marker-owned Shimmy state, and source checkouts or exported skills
   must not be deleted as a side effect.

### Skill ownership and export

1. Canonical management skills and canonical tool skills are colocated with
   the shared catalog authority.
2. Profiles do not own canonical skill copies. A profile-local `shimmy skills`
   command resolves skill sources from its named catalog and uses the invoking
   profile manifest to determine default installed-tool skill selection.
3. Explicit `shimmy skills install`, `update`, and export operations remain the
   only ways to write adapters or portable skill bundles to a project
   repository or the agent user-profile target.
4. Existing target manifests continue to own exported adapters independently
   of the catalog and profile lifecycles. Catalog/profile uninstall must not
   implicitly remove project or user-profile exports.
5. If the catalog is unavailable or schema-incompatible, new skill exports and
   updates fail without changing their target. Previously exported skills
   remain usable and removable according to their target manifest.

## Verified implementation inventory

The verified baseline of affected producers, consumers, and ownership
boundaries is:

- catalog discovery and version resolution: `lib/catalog/catalog.sh`;
- profile installation and complete-tree staging:
  `lib/install/install.sh`, `lib/install/profile-assets.sh`, and
  `lib/install/request.sh`;
- profile structure and manifest validation: `lib/profile/profile.sh` and
  `lib/install/manifest.sh`;
- profile-local launcher and tool dispatch:
  `lib/install/launcher-template.sh`, `commands/dispatch-tool.sh`, and
  `commands/run-tool.sh`;
- direct catalog-root consumers: install, status, images, skills, agent
  preflight, update, and the test runner;
- canonical skill producers under `plugins/shimmy/skills/` and
  `tools/<tool>/SKILL.md`, plus skill target ownership in `commands/skills.sh`;
- update, rollback, bootstrap, and uninstall transactions under `lib/update/`,
  `lib/install/`, and `install.sh`;
- catalog, lifecycle, bootstrap, status, skills, image, dispatcher, update,
  rollback, and isolation tests under `tests/`; and
- architecture and workflow guidance in `CONTEXT.md`, `CONTRIBUTING.md`,
  `README.md`, `commands/README.md`, `BOOTSTRAP.md`, applicable child context
  files, and canonical skills.

This inventory is a verified baseline, not permission to ignore dependencies
discovered during implementation. The schema and ownership transition must
update every producer, consumer, validator, fixture, transaction boundary, and
rollback path as one reviewed change set.

## Unresolved

### Catalog source lifecycle

**Gap.** The named-catalog and schema decisions identify what every profile
reads and how it validates the result, but they do not identify which physical
files are authoritative or what operation commits a completed local tool into
that authority. The shell-refresh problem cannot be solved until that event is
defined.

The decision must cover:

- whether arbitrary valid edits in a source checkout become authoritative
  immediately or creation must always go through a Shimmy command;
- whether catalog reads require the source checkout to remain at a stable
  absolute path;
- how readers obtain a coherent view while files are being added or changed;
- what catalog update, rollback, source replacement, and uninstall own;
- whether a dirty or schema-invalid checkout blocks all catalog management
  operations or only hides the incomplete entry; and
- what happens when a checkout is moved, deleted, or attempts to claim the
  already-registered `upstream` name.

#### Choice A — Live binding to a source checkout

`catalogs/upstream/` records a validated absolute binding to a checkout, and
catalog commands resolve the checkout's catalog files on every invocation.

Implications:

- This is the only choice that makes arbitrary completed local file edits
  visible on the next command with no publication action.
- The checkout remains user-owned. Shimmy uninstall removes only its binding
  and never removes or rewrites the checkout.
- Moving or deleting the checkout makes catalog-dependent commands unavailable
  until an explicit rebind; installed tool execution remains unaffected.
- Dirty and temporarily incomplete edits are in the global management path.
  Full validation is required before mutation, and profile installation must
  stage a coherent materialization then verify that its source did not change
  before commit.
- Rollback means rebinding to or checking out a previously valid source state;
  Shimmy does not inherently possess an immutable prior catalog unless it
  stores separate recovery metadata.
- Replacing the checkout bound to `upstream` must be explicit and serialized;
  a second checkout cannot win based on recency or the current working
  directory.

#### Choice B — Immutable installed snapshot with automatic publication

`catalogs/upstream/` owns an immutable generation. The supported tool-creation
workflow validates a staged next generation and atomically publishes it as the
final step of creation.

Implications:

- Readers get stable, reproducible generations, and rollback can atomically
  restore a prior valid generation.
- Checkout movement or deletion does not affect the installed catalog after a
  successful publication.
- Direct/manual checkout edits are not immediately authoritative. This choice
  meets the no-intermediate-step requirement only if all supported creation
  paths automatically publish as part of their completion transaction. An
  author who edits `tools/` outside that workflow would need a publication
  action, which does not meet the stated local-code-change behavior.
- Shimmy owns snapshot storage and must define retention, disk usage, update,
  rollback, and global uninstall rules separately from profile lifecycle.
- Creation failure must leave both the checkout and prior catalog generation
  coherent. Cross-filesystem atomic replacement cannot be assumed, so staging
  must occur under the catalog registry filesystem.

#### Choice C — Hybrid live development binding and immutable generations

The `upstream` catalog can resolve to an explicit live checkout in development
and to an installed generation in other operation, with one mode active at a
time.

Implications:

- It can provide direct-edit visibility for maintainers and stable snapshots
  for released use.
- It introduces two source modes, mode-switch transactions, precedence rules,
  status output, rollback behavior, and a larger test matrix at the catalog's
  most critical ownership boundary.
- A profile still binds only to the catalog name `upstream`; mode is global to
  that catalog and cannot vary silently by profile.
- Switching mode must be explicit and atomic. Disabling a live binding must
  define whether the last live state is published, discarded, or rejected if
  it differs from the installed generation.
- Uninstall must distinguish user-owned live sources from Shimmy-owned
  generations and remove only the latter plus the binding record.

#### Decision criteria and current recommendation

If “local code change” includes ordinary direct edits to the checkout, choose
**Choice A**. It is the narrowest model that satisfies immediate visibility as
stated, at the cost of making checkout validity and location part of catalog
availability.

If tool creation is guaranteed to occur only through one transactional Shimmy
workflow, **Choice B** can satisfy the requirement while providing stronger
reproducibility and rollback. That guarantee does not exist in the current
repository workflow.

Choose **Choice C** only if both direct maintainer edits and checkout-independent
released catalogs are requirements for this first implementation; otherwise
its additional state machine is premature.

**Current recommendation: Choice A, live binding for the single `upstream`
catalog.** This is a recommendation, not a recorded decision. The lifecycle
remains unresolved pending confirmation of whether arbitrary valid checkout
edits must be visible and whether checkout-independent catalog operation is a
first-release requirement.

No other architecture question remains unresolved.

## Progress Checklist

- [~] Planning gate — Option 1 and its schema, naming, compatibility, immediate
  availability, and skill decisions are recorded; catalog source lifecycle
  remains unresolved and blocks implementation authorization.
- [ ] Chunk 1 — Implement the shared named-catalog contract and convert all
  catalog consumers atomically.
- [ ] Chunk 2 — Materialize only selected tools into recreated profile-local
  control planes.
- [ ] Chunk 3 — Move canonical skill resolution to the catalog and preserve
  explicit export ownership.
- [ ] Chunk 4 — Complete lifecycle, uninstall, documentation, and full
  regression verification.

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

Implementation must not begin until the catalog source lifecycle is recorded
as a design decision and the affected chunk requirements are revised to match
it.

## Chunk 1 — Shared catalog contract and consumers

### Goal

Introduce the `upstream` catalog registry entry, schema-1 validator, and one
catalog resolver used by every catalog-aware command, without leaving mixed
old/new catalog resolution paths.

### Files

Primary surfaces: `lib/catalog/`, catalog initialization/ownership code under
`lib/install/`, `commands/`, `lib/images/`, `lib/update/`, agent preflight,
and their tests and contexts.

### Implementation requirements

- Implement the selected source lifecycle and its atomic activation,
  publication, or binding transaction.
- Add and validate `catalog.conf` and the exact schema-1 contract.
- Record `catalog=upstream` in every new profile manifest and resolve that name
  through shared registry state on every catalog-aware invocation.
- Replace profile-relative `SHIMMY_TOOLS_DIR` authority with explicit catalog
  and profile-materialization roots; do not retain an equivalent legacy
  fallback.
- Convert all catalog consumers together and fail closed on missing, invalid,
  or unsupported catalogs before mutation.
- Report catalog name, source mode, resolved source, schema, and health in
  machine-readable and human-readable status without leaking shell-dependent
  implicit state.

### Verification checklist

- [ ] A valid `upstream` catalog is discovered by both profile launchers
  without shell reinitialization or profile refresh.
- [ ] Completing a valid new tool entry makes it available on the next command
  according to the selected lifecycle, with no separate synchronization step.
- [ ] Missing, duplicate, unknown, malformed, unsafe, or schema-incompatible
  catalog data fails before mutation with precise diagnostics.
- [ ] A second checkout cannot silently replace the registered `upstream`
  source.
- [ ] Every former direct catalog-root consumer is proven to use the shared
  resolver; an obsolete-path search is classified and clean.
- [ ] Failed catalog activation/publication/binding preserves the prior valid
  authority.

### Human review gate

Confirm that the implemented lifecycle matches the resolved decision, all
catalog consumers enforce one schema contract, and no compatibility fallback
recreates profile-local availability snapshots.

## Chunk 2 — Profile-local materialization and recreation

### Goal

Rebuild profiles as independent control planes containing only their selected
tool materializations while preserving profile-scoped execution and mutation.

### Files

Primary surfaces: `lib/install/`, `lib/profile/`, launcher and dispatch
commands, bootstrap/uninstall entrypoints, lifecycle fixtures, and applicable
contexts.

### Implementation requirements

- Stop copying the complete `tools/` and canonical `plugins/` catalog payloads
  into profiles.
- Stage and validate selected tool/version runtime assets from the shared
  catalog, then atomically commit profile-owned materialization and manifest
  changes.
- Keep dispatch bound to the manifest-recorded profile copy, never to live
  catalog runtime files.
- Reject legacy and mixed-layout installations with uninstall-and-recreate
  guidance. Do not add migration or compatibility aliases.
- Preserve default/upstream profile mutation isolation, startup ownership,
  rollback, collision, and safe-path protections.

### Verification checklist

- [ ] Installing a catalog tool into one profile changes only that profile's
  dispatcher, manifest, and materialized assets.
- [ ] New and recreated `default` and `upstream` profiles both bind to catalog
  `upstream` but retain independent selections.
- [ ] Changing or removing the catalog does not change or break execution of
  already-materialized tools.
- [ ] A failed materialization or commit restores the prior coherent profile
  and does not change sibling profiles or catalog state.
- [ ] Legacy and mixed layouts are rejected before mutation; clean uninstall
  followed by recreation succeeds.
- [ ] Profile payload inspection confirms that unselected catalog tools and
  canonical skill sources are absent.

### Human review gate

Confirm profile execution independence, absence of legacy transition code,
and bounded ownership for recreated profiles before accepting the new layout.

## Chunk 3 — Catalog-owned skills and explicit exports

### Goal

Resolve all canonical skill sources from the named catalog while retaining
explicit, manifest-owned export to project repositories and the agent
user-profile target.

### Files

Primary surfaces: `commands/skills.sh`, catalog validation, management and
tool skill source layout, skills tests, canonical skill guidance, and user
documentation.

### Implementation requirements

- Resolve control-plane and tool skill sources from the validated catalog
  authority rather than the invoking profile root.
- Preserve explicit skill-name selection and default selection from the
  invoking profile's installed tools.
- Preserve `install`, `update`, `uninstall`, portable-folder export, and archive
  export semantics and target-manifest ownership.
- Stage and validate complete skill output before changing a target.
- Keep exported targets independent: catalog/profile uninstall does not remove
  them, and catalog unavailability does not make existing exports unusable.

### Verification checklist

- [ ] A newly created valid catalog tool skill can be explicitly exported from
  both existing profiles on the next command without profile refresh.
- [ ] Default skill export includes core management skills and only the
  invoking profile's installed-tool skills.
- [ ] Project and agent user-profile targets remain isolated and their
  manifests govern update/uninstall behavior.
- [ ] Catalog loss or schema mismatch fails an install/update/export before
  target mutation; manifest-owned uninstall behavior remains safe.
- [ ] Profile and catalog uninstall leave external exported skills untouched.

### Human review gate

Confirm the catalog is the only canonical skill source and all writes outside
Shimmy remain explicit and independently owned.

## Chunk 4 — Lifecycle integration, documentation, and regression

### Goal

Complete source-lifecycle-specific update, rollback, bootstrap, status, and
uninstall behavior; align all guidance; and verify the full architecture.

### Files

Primary surfaces: `install.sh`, `lib/update/`, uninstall and status behavior,
the complete affected test matrix, `README.md`, `BOOTSTRAP.md`,
`CONTRIBUTING.md`, contexts, command documentation, and canonical skills.

### Implementation requirements

- Apply the selected lifecycle's ownership, replacement, rollback, checkout
  loss, and uninstall rules consistently.
- Make catalog and profile lifecycle operations independently recoverable and
  prevent one profile uninstall from removing shared state needed by another.
- Update generated/copied guidance from canonical sources only after semantic
  review; remove stale flat-profile and profile-owned-skill statements.
- Preserve deterministic offline default tests and native Podman acceptance
  requirements for tool runtimes.

### Verification checklist

- [ ] Bootstrap from clean state creates catalog `upstream` and both supported
  profiles follow the new ownership model.
- [ ] Profile uninstall cannot remove the shared catalog or sibling profile
  assets; global uninstall removes only owned shared catalog state and never a
  user-owned source checkout or external skill export.
- [ ] Catalog source loss, invalid edits/generation, replacement conflicts,
  failed update, and rollback match the selected lifecycle and preserve
  installed execution.
- [ ] Catalog default changes leave recorded profile versions unchanged until
  explicit update.
- [ ] Default offline tests, shell checks, context-tree checks, obsolete-term
  searches, and live non-mutating Podman smokes pass.
- [ ] Documentation and canonical skills describe named catalogs, recreation,
  immediate visibility, schema failures, skill export, and recovery accurately.

### Human review gate

Confirm the complete install/catalog/profile/skills lifecycle, final
documentation, test evidence, and any native-platform verification still
required before implementation is considered complete.

## Risk register

| Risk | Impact | Mitigation direction |
| --- | --- | --- |
| Profile-local management code reads a newer catalog schema incorrectly. | Catalog operations corrupt or mis-materialize profiles. | Exact schema declaration and validation; fail before mutation; coordinate future schema transitions. |
| A live or published catalog changes during materialization. | A profile receives a mixed tool/version payload. | Stage a coherent source view, validate before and after copy, and commit atomically. |
| Shared catalog defaults affect installed behavior. | Profile behavior changes without an explicit request. | Dispatch only profile-owned, manifest-recorded materializations. |
| Catalog update is visible before all files are valid. | Every profile's catalog operations can fail simultaneously. | Lifecycle-specific staging plus atomic binding/generation replacement; preserve prior authority. |
| A live checkout is moved, deleted, or temporarily invalid. | New install, update, status-available, images, and skills operations fail globally. | Precise health reporting, no profile mutation, and installed execution independence; decide whether recovery is rebind or rollback. |
| Two checkouts claim `upstream`. | Catalog authority becomes surprising or nondeterministic. | Unique name registry and explicit serialized replacement; never infer authority from current directory or recency. |
| Shared uninstall removes assets needed by profiles. | Catalog operations fail for surviving profiles. | Independent catalog ownership and explicit global uninstall/reference validation. |
| Removing profile-owned canonical skills breaks exports. | `shimmy skills` cannot resolve sources after profile recreation. | Resolve and validate all canonical skills from the named catalog. |
| Legacy state is partially reused. | Mixed ownership defeats safety and complicates rollback. | Detect and reject legacy/mixed layouts; require clean uninstall and recreation. |

## Review boundary

No implementation is authorized by this document. Review should confirm the
recorded decisions and resolve the catalog source lifecycle. After that
decision, update the target physical layout, lifecycle requirements,
verification expectations, risk mitigations, progress status, and session
bootstrap before authorizing Chunk 1.

## Lessons learned

### Initial

- The profile manifest already models selected tools; the disconnect is caused
  by packaging the availability catalog and canonical skills inside the same
  profile boundary.
- Shell startup should select a profile, not determine catalog freshness.
  Resolving the profile's named catalog on each command removes the need to
  reopen the shell.
- Named catalogs resolve identity and collision behavior but do not resolve
  whether the backing authority is a live checkout or installed generation.
- Immediate visibility for arbitrary local edits materially favors a live
  binding; immutable snapshots require creation-integrated publication and do
  not make manual edits visible automatically.
- An explicit schema prevents stale profile control planes from guessing, but
  it intentionally turns future schema evolution into a coordinated
  producer/consumer change.
- Catalog availability, canonical skill availability, and installed execution
  have different lifecycle boundaries and must not share implicit ownership.

## Session bootstrap

In a fresh planning session, read `AGENTS.md`, `CONTRIBUTING.md`, root
`CONTEXT.md`, this entire plan, `lib/catalog/catalog.sh`,
`lib/install/profile-assets.sh`, `commands/skills.sh`, and the context files for
any source or test path under consideration. Treat Option 1, the catalog name
`upstream`, schema version 1, no backwards compatibility or migration,
next-command availability, and catalog-owned canonical skills as
non-negotiable. Resolve only **Catalog source lifecycle**, revise this plan to
make that choice executable, and stop for review. Do not implement Chunk 1
without explicit authorization.
