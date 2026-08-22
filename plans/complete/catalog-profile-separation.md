# Catalog and Profile Separation — Chosen Architecture
**Status:** complete

## Objective

Implement shared named catalogs with profile-local control planes and an
explicit catalog schema contract.

The target behavior is:

- each shared named catalog is a profile-independent authority for its
  available tools, concrete versions, and canonical Shimmy skills;
- each profile retains its own `shimmy` launcher, management code, manifest,
  selected tool materializations, and mutation boundary;
- every profile records an explicit named-catalog binding rather than deriving
  catalog identity implicitly from its profile name;
- after a new tool has been completed and is schema-valid in the `upstream`
  catalog, it is available for installation into the `upstream` profile on the
  next `shimmy` command invocation, without closing or reopening the shell,
  refreshing that profile, or running an intermediate synchronization step to
  pick up the local code change; and
- installed tools continue to execute from profile-owned materializations if
  the catalog is unavailable or later changes.

This plan does not preserve or migrate the current flat installed layout.
Existing Shimmy installations and profiles will be uninstalled and recreated
with the new implementation. It also does not introduce a shared global
control plane or silently change an installed profile when a catalog default
changes.

Catalog lifecycle and topology are fixed: the `upstream` catalog is a live
binding to one maintainer checkout, while the `default` catalog is a
Shimmy-owned immutable generation published from committed upstream content.
Dirty checkout publication is forbidden, and alternate live/snapshot
topologies are outside this plan.

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
- **Catalog name**: a stable registry identifier for a catalog. The catalog
  name is binding metadata and is not embedded in the reusable catalog
  payload.
- **Catalog authority**: the complete schema-valid source of available tools,
  versions, management skills, and tool skills for a named catalog.
- **Catalog source**: the physical storage behind a catalog authority: the
  live checkout bound to `upstream` or the current immutable generation of
  `default`.
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
resources. The `upstream` profile explicitly binds to the `upstream` catalog,
and the `default` profile explicitly binds to the `default` catalog. Matching
names are bootstrap policy, not resolver behavior.

### Logical target layout

```text
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/
  catalogs/
    upstream/
      registry.conf           # catalog name, source type, absolute checkout path
    default/
      registry.conf           # catalog name, source type, current generation
      generations/
        <content-identity>/    # immutable catalog payload and provenance
  profiles/
    default/
      bin/                     # profile-local shimmy and selected dispatchers
      commands/ lib/           # profile-local management control plane
      install-manifest.txt     # catalog=default plus selected versions
      tools/                   # selected version-owned runtime/assets only
    upstream/
      ...                      # catalog=upstream; otherwise independently owned
```

Canonical skills belong to the catalog authority, not to a profile control
payload:

```text
<catalog-authority>/
  catalog.conf                # payload format and schema declaration
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

1. Profile-local launchers and management control planes
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
7. Each catalog registration, rebind, or publication transaction and each
   profile materialization transaction is staged, validated, and committed
   atomically. A profile must not observe or install a partially validated
   catalog entry.

### Named catalogs and multiple checkouts

1. Catalog identity is name-based rather than inferred from the invoking
   checkout or profile.
2. The `upstream` profile records `catalog=upstream`; the `default` profile
   records `catalog=default`.
3. Profile-to-catalog bindings are explicit manifest data. Bootstrap may
   enforce built-in pairings, but resolution must not concatenate or otherwise
   derive a catalog name from a profile name.
4. No checkout may silently replace another source registered under the same
   catalog name. Replacing the `upstream` source requires an explicit rebind
   transaction.
5. The plural `catalogs/` registry and profile manifest binding preserve a path
   for future named catalogs. Adding another catalog, catalog-selection CLI,
   precedence rules, or cross-catalog tool resolution is outside this first
   implementation.
6. The first implementation supports one active checkout binding for the
   built-in `upstream` catalog. A second checkout that tries to register that
   name is rejected unless the user explicitly requests a rebind.
7. Rebind validates the replacement catalog, atomically swaps only the
   registry binding, reports the prior and new absolute paths, and never
   modifies or deletes either checkout.
8. Simultaneous multi-checkout operation is deferred. If additional checkout
   catalogs are added later, each must use a unique catalog name and each
   profile must resolve exactly one catalog. Tool lookup will not merge
   catalogs or search them by precedence.

This establishes the identity and collision boundary without adding catalog
precedence, implicit merging, or user-selected catalog names to the first
implementation.

### Catalog lifecycle and publication

The accepted topology is Option D: separate live `upstream` and stable
`default` catalogs with these intrinsic lifecycles:

```text
repository checkout
  -> upstream catalog (live checkout authority)
     -> upstream profile
        -> explicit validated publication from a clean committed checkout
           -> default catalog (immutable generation outside the repository)
              -> default profile
```

1. `catalogs/upstream/registry.conf` records a validated absolute checkout
   binding. Schema-valid catalog entries in that checkout are visible to the
   upstream profile on its next catalog-aware command, including valid dirty
   edits that have not yet been committed. Upstream bootstrap establishes the
   binding and `catalog=upstream` profile manifest entry without creating or
   changing a default profile.
2. `catalogs/default/registry.conf` identifies the current immutable
   generation under `catalogs/default/generations/`. Upstream edits do not
   affect default catalog operations until an explicit publication succeeds.
3. Registry state and immutable generations remain under
   `SHIMMY_CONFIG_ROOT`. Moving generations to a separate data root is outside
   this implementation and would require a separate ownership and safe-path
   transition.
4. Bootstrap of the default profile creates its initial default generation
   from the validated installation source using the same clean,
   committed-checkout precondition and staged-generation validation required
   for later publication. It records `catalog=default` without creating or
   changing an upstream profile. Subsequent promotion occurs only through a
   dedicated catalog publication transaction and remains separate from profile
   install or update.
5. Publication from the live upstream checkout is allowed only when Git
   reports a clean index and worktree, including no untracked files, and the
   catalog content being published is present in the recorded `HEAD` commit.
   Maintainers must commit upstream catalog changes before publishing them to
   `default` or any future catalog. Dirty publication has no override.
6. The publisher resolves and validates the complete upstream payload, records
   the source `HEAD` commit, materializes the tracked catalog payload once from
   that commit into same-filesystem staging under `catalogs/default/`, validates
   that fixed staged copy independently under schema 1, and derives the
   immutable generation identity from its content fingerprint rather than from
   the Git commit. Working-tree-only and ignored content cannot enter a
   published generation.
7. Immediately before commit, publication verifies that the upstream `HEAD`
   is unchanged and the checkout remains clean. It then atomically installs
   the generation and swaps the current-generation reference. Any failure or
   concurrent checkout change leaves the prior default authority current.
8. Publication retains the immediately prior valid generation as the rollback
   target. It changes default catalog availability only; existing default
   profile tool materializations remain unchanged until an explicit profile
   install or update. Publication requires an initialized default catalog and
   does not implicitly create either profile.
9. The live upstream boundary includes catalog payloads—tool metadata, version
   runtimes and assets used as installation sources, and canonical skills—but
   excludes installed management commands and shared libraries. Maintainers
   use repo-local preview/source entrypoints while changing control-plane code,
   then recreate or explicitly refresh the upstream profile to test the
   installed control plane.

### Explicit catalog schema contract

The initial contract is exact-versioned rather than best-effort compatible.
Catalog binding metadata and catalog payload identity are separate contracts.
At minimum, each registry entry owns a `registry.conf` containing:

```text
catalog_name=<safe-registry-name>
catalog_source_type=checkout
catalog_source_path=<validated-absolute-path>
```

for `upstream`, or:

```text
catalog_name=<safe-registry-name>
catalog_source_type=generation
catalog_generation_current=<content-identity>
```

for `default`. Source-type-specific required keys are mutually exclusive;
missing, duplicate, unknown, or cross-type keys are invalid.

The resolved catalog authority owns a root `catalog.conf` containing one value
for each of:

```text
catalog_format=shimmy-catalog
catalog_schema=1
```

`catalog_format` is a fixed identity marker, analogous to file magic: it proves
that a live checkout or immutable generation points at a Shimmy catalog payload
before the reader interprets schema-specific keys and directory structure.

It is not a mode or negotiation field. All catalogs in this plan use
`shimmy-catalog`; directory-layout evolution within that native catalog family
increments `catalog_schema` while retaining the format. The value would differ
only if a future Shimmy implementation deliberately introduced another
catalog family with a different parser or representation, such as a signed
index or database instead of this native directory tree. No such alternate
format is planned, and schema-1 readers reject every other value. The marker is
retained because live absolute bindings make an inexpensive wrong-root
discriminator useful, even though `catalog_schema=1` and required-path
validation could technically identify the payload without it.

The implementation must define the version-1 contract in one catalog module
and validate it before any consumer performs discovery or mutation. Version 1
includes:

- the required root identity keys and rejection of missing, duplicate, or
  unknown contract keys;
- a safe catalog-name grammar and an exact match between the registry entry's
  `catalog_name` and the profile manifest binding;
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

### Immediate availability after creation in upstream

“Immediately available after creation” means that once a complete tool entry
in the `upstream` catalog satisfies schema 1, the next catalog-aware command
run by the `upstream` profile can discover and install it. The user does not:

- close or reopen the shell;
- source `shell-init.sh` again;
- refresh, update, or reinstall a profile; or
- run a separate synchronization/publication command solely to make the local
  code change visible.

This requirement does not mean that partially authored or schema-invalid tool
directories are visible. They must be ignored only where discovery can do so
unambiguously or, preferably, cause catalog validation to fail clearly without
mutation. Schema-valid content on disk is the upstream visibility boundary; a
Git commit is not required for upstream discovery or installation. A clean
checkout with those changes committed is required only when publishing the
content to `default` or any future catalog.

There is no immediate-visibility requirement for the `default` profile. Under
a separate stable `default` catalog, new upstream entries become available to
that profile only after an explicit successful catalog publication.

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
  `lib/install/`, and `bootstrap.sh`;
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

None.

## Progress Checklist

- [x] Planning gate — The profile-local architecture, Option D lifecycle,
  schema, naming, compatibility, publication, clean-checkout, live-code-scope,
  multiple-checkout, upstream-immediacy, and skill decisions are recorded and
  internally consistent.
- [x] Chunk 1 — Implement the shared named-catalog contract and convert all
  catalog consumers atomically.
- [x] Chunk 2 — Materialize only selected tools into recreated profile-local
  control planes.
- [x] Chunk 3 — Move canonical skill resolution to the catalog and preserve
  explicit export ownership.
- [x] Chunk 4 — Complete lifecycle, uninstall, documentation, and full
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

Chunk 1 is the next active chunk. Implementation must not begin without
explicit authorization.

## Chunk 1 — Shared catalog contract and consumers

Status: implemented and verified on 2026-08-14; awaiting human review at the
Chunk 1 gate. Chunk 2 has not started.

### Goal

Introduce named catalog registry entries, the schema-1 payload validator, and
one catalog resolver used by every catalog-aware command, without leaving
mixed old/new catalog resolution paths.

### Files

Primary surfaces: `lib/catalog/`, catalog initialization/ownership code under
`lib/install/`, `commands/`, `lib/images/`, `lib/update/`, agent preflight,
and their tests and contexts.

### Implementation requirements

- Implement the fixed live-`upstream`/immutable-`default` topology and its
  atomic publication, binding, and rebind transactions.
- Add and validate checkout- and generation-specific `registry.conf`, payload
  `catalog.conf`, and the exact schema-1 contract.
- Record an explicit catalog name in every new profile manifest and resolve it
  through shared registry state on every catalog-aware invocation. Bootstrap
  records `catalog=upstream` or `catalog=default` in the profile it creates and
  does not implicitly create the sibling profile.
- Reject publication unless the upstream Git checkout is clean and all
  catalog changes are in the recorded `HEAD`; provide no dirty-publication
  override. Materialize the tracked catalog payload once from that `HEAD` into
  same-filesystem staging, validate and fingerprint the staged copy, recheck
  `HEAD` and cleanliness, then atomically advance the default generation while
  retaining the immediately prior valid generation.
- Replace profile-relative `SHIMMY_TOOLS_DIR` authority with explicit catalog
  and profile-materialization roots; do not retain an equivalent legacy
  fallback.
- Convert all catalog consumers together and fail closed on missing, invalid,
  or unsupported catalogs before mutation.
- Report catalog name, source type, resolved source or generation, source
  commit and content fingerprint where applicable, schema, and health in
  machine-readable and human-readable status without leaking shell-dependent
  implicit state.

### Verification checklist

- [x] A valid `upstream` catalog is discovered by the upstream profile without
  shell reinitialization or profile refresh. Installed upstream status resolves
  the registered checkout on every invocation.
- [x] Completing a valid new upstream tool entry, including a valid dirty edit,
  makes it available to the upstream profile on the next command with no
  separate synchronization step. The `instant` fixture proves next-command
  visibility.
- [x] The default profile does not see a new upstream entry until its changes
  are committed and successful publication atomically advances the immutable
  default generation. The same fixture proves isolation before publication and
  visibility after it.
- [x] Publication from a dirty checkout is rejected without an override and
  without staging, generation, current-reference, profile, or export mutation;
  the diagnostic requires the maintainer to commit the changes. Initial and
  later publication rejection are both covered.
- [x] Publication records the source commit and content fingerprint,
  materializes and validates one staged copy from the recorded commit, excludes
  working-tree-only and ignored content, rejects a concurrent checkout or
  `HEAD` change, and retains the immediately prior generation for rollback.
  Tests verify provenance, ignored-file exclusion, final `HEAD` rejection, and
  retained-generation integrity; the transaction uses one `git archive` staged
  on the registry filesystem.
- [x] Missing, duplicate, unknown, malformed, unsafe, or schema-incompatible
  catalog data fails before mutation with precise diagnostics. Schema fixtures
  cover identity keys, unsupported schema, required skills, unsafe links, and
  duplicate logical versions; existing image-schema fixtures cover malformed
  version metadata.
- [x] A second checkout cannot silently replace the registered `upstream`
  source. The registration collision test verifies the registry and profile
  remain unchanged.
- [x] An explicit upstream rebind validates before mutation, atomically updates
  only the registry entry, reports both absolute paths, and leaves both
  checkouts untouched; a failed rebind preserves the prior binding. Both the
  failed and successful paths are covered.
- [x] Every former direct catalog-root consumer is proven to use the shared
  resolver; an obsolete-path search is classified and clean. No
  `SHIMMY_TOOLS_DIR` compatibility surface remains. Residual direct `tools/`
  references are profile execution materialization, source runtime/test
  discovery, checkout validation, or fixtures—not availability resolution.
- [x] Failed catalog registration, rebind, or publication preserves the prior
  valid authority. Collision, invalid-rebind, dirty-initialization, and
  dirty-publish tests verify the relevant registry and profile checksums.

Verification evidence:

- `git diff --check` and POSIX `sh -n` over command, library, and test shell
  files passed.
- `./tests/context-tree.sh` passed.
- The obsolete-path audit used the installed Shimmy `rg` wrapper and found no
  legacy `SHIMMY_TOOLS_DIR` reference.
- `./tests/test.sh` passed all 113 tests with live non-mutating Podman access.

### Human review gate

Confirm the separate live-upstream and immutable-default lifecycles, clean
publication boundary, common schema enforcement, and absence of compatibility
fallbacks that recreate profile-local availability snapshots.

## Chunk 2 — Profile-local materialization and recreation

Status: implemented and verified on 2026-08-14; awaiting human review at the
Chunk 2 gate. Chunk 3 has not started.

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
- Keep installed upstream management commands and shared libraries bound to
  the profile copy; do not dispatch them to the checkout or hot-reload checkout
  control-plane changes.
- Reject legacy and mixed-layout installations with uninstall-and-recreate
  guidance. Do not add migration or compatibility aliases.
- Preserve default/upstream profile mutation isolation, startup ownership,
  rollback, collision, and safe-path protections.

### Verification checklist

- [x] Installing a catalog tool into one profile changes only that profile's
  dispatcher, manifest, and materialized assets.
- [x] New and recreated profiles record and validate the fixed bindings:
  default binds `default` and upstream binds `upstream` while retaining
  independent selections.
- [x] Changing or removing the catalog does not change or break execution of
  already-materialized tools.
- [x] Editing checkout `commands/` or `lib/` does not change installed upstream
  management behavior; recreating or explicitly refreshing the upstream
  profile is required to test those control-plane changes as installed code.
- [x] A failed materialization or commit restores the prior coherent profile
  and does not change sibling profiles or catalog state.
- [x] Legacy and mixed layouts are rejected before mutation; clean uninstall
  followed by recreation succeeds.
- [x] Profile payload inspection confirms that unselected catalog tools and
  canonical skill sources are absent.

Verification evidence:

- `git diff --check` and POSIX `sh -n` over command, library, and test shell
  files passed.
- `./tests/context-tree.sh` passed.
- The obsolete-layout audit found only deliberate manifest-v1 rejection
  fixtures and assertions proving profile skill/plugin absence; no production
  `profile-flat-root` identity or checkout-bound implementation root remains.
- `./tests/test.sh` passed all 116 tests with live non-mutating Podman access.
- Lifecycle coverage verifies profile-only additive mutation, selected-version
  payload shape, catalog-loss execution, explicit upstream control-plane
  refresh, fixed catalog bindings, mixed-layout rejection and recreation,
  late-commit rollback, and sibling/catalog checksum preservation.

### Human review gate

Confirm profile execution independence, absence of legacy transition code,
and bounded ownership for recreated profiles before accepting the new layout.

## Chunk 3 — Catalog-owned skills and explicit exports

Status: implemented and verified on 2026-08-14; awaiting human review at the
Chunk 3 gate. Chunk 4 has not started.

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
- [x] A newly created valid upstream tool skill can be explicitly exported by
  the upstream profile on the next command without profile refresh; default
  can export it only after clean committed content is published successfully.
- [x] Default skill export includes core management skills and only the
  invoking profile's installed-tool skills.
- [x] Project and agent user-profile targets remain isolated and their
  manifests govern update/uninstall behavior.
- [x] Catalog loss or schema mismatch fails an install/update/export before
  target mutation; manifest-owned uninstall behavior remains safe.
- [x] Profile and catalog uninstall leave external exported skills untouched.

Verification evidence:

- Catalog validation now verifies the exact five-skill management layout and
  matching non-empty skill frontmatter for every management and tool skill.
- Skills install, update, folder export, and archive export stage complete
  one-file adapters plus their target manifest, revalidate one coherent
  catalog snapshot, and commit only after validation; target commits restore
  prior owned entries on failure.
- Lifecycle coverage verifies immediate dirty live-upstream skill visibility,
  clean-publication-gated immutable-default visibility, invoking-profile
  default selection, repository/home isolation, external-target preservation,
  schema and registry failure before mutation, and catalog-independent
  manifest-owned uninstall.
- `git diff --check`, POSIX `sh -n` over changed shell files, and
  `./tests/context-tree.sh` passed.
- `./tests/test.sh` passed all 118 tests with live non-mutating Podman access.

### Human review gate

Confirm the catalog is the only canonical skill source and all writes outside
Shimmy remain explicit and independently owned.

## Chunk 4 — Lifecycle integration, documentation, and regression

Status: implemented and verified on 2026-08-14; awaiting human review at the
Chunk 4 gate.

### Goal

Complete the fixed catalog update, rollback, bootstrap, status, and uninstall
behavior; align all guidance; and verify the full architecture.

### Files

Primary surfaces: `bootstrap.sh`, `lib/update/`, uninstall and status behavior,
the complete affected test matrix, `README.md`, `BOOTSTRAP.md`,
`CONTRIBUTING.md`, contexts, command documentation, and canonical skills.

### Implementation requirements

- Apply the recorded live-upstream and immutable-default ownership,
  publication, replacement, rollback, checkout-loss, and uninstall rules
  consistently.
- Make catalog and profile lifecycle operations independently recoverable and
  prevent one profile uninstall from removing shared state needed by another.
- Update generated/copied guidance from canonical sources only after semantic
  review; remove stale flat-profile and profile-owned-skill statements.
- Preserve deterministic offline default tests and native Podman acceptance
  requirements for tool runtimes.

### Verification checklist

- [x] Default bootstrap from no installed state and a clean committed checkout
  creates the immutable default generation through the same staged validation
  used by later publication and records `catalog=default` without creating an
  upstream profile.
- [x] Upstream bootstrap validates and binds its live checkout and records
  `catalog=upstream` without creating or changing a default profile; a
  conflicting existing binding requires the explicit rebind transaction.
- [x] Profile uninstall cannot remove the shared catalog or sibling profile
  assets; global uninstall removes only owned shared catalog state and never a
  user-owned source checkout or external skill export.
- [x] Catalog source loss, invalid edits or generations, dirty-publication
  attempts, replacement conflicts, failed updates, and rollback match the
  recorded lifecycle and preserve installed execution.
- [x] Catalog default changes leave recorded profile versions unchanged until
  explicit update.
- [x] Default offline tests, shell checks, context-tree checks, obsolete-term
  searches, and live non-mutating Podman smokes pass.
- [x] Documentation and canonical skills describe named catalogs, recreation,
  immediate visibility, schema failures, skill export, and recovery accurately.

Verification evidence:

- Default and upstream bootstrap isolation now asserts the expected catalog
  registry, immutable generation metadata, fixed profile binding, and absence
  of the sibling profile/catalog.
- `shimmy catalog rollback` validates and atomically activates the retained
  generation. Coverage includes upstream checkout loss, corrupt-retained
  rejection without registry mutation, and recovery when the current
  generation is invalid.
- Selected `shimmy update` operations adopt the current catalog default through
  an atomic profile materialization while retaining other explicit concrete
  versions. Publication alone leaves profile manifests and runtime assets
  unchanged.
- Ordinary uninstall preserves sibling profiles and shared catalogs. Explicit
  `shimmy uninstall --global` rejects unrecognized state, removes only valid
  manifest/registry-owned state, and preserves moved source checkouts plus
  independently owned skill exports.
- `git diff --check`, POSIX `sh -n` over repository shell files,
  `./tests/context-tree.sh`, and the obsolete-term audit passed. The remaining
  `profile-flat-root` search hit is a deliberate legacy-rejection fixture; the
  skill-copy hits state that canonical skills are not copied into profiles.
- `./tests/test.sh` passed all 120 tests. The suite remains offline for default
  runtime coverage; local Ansible workdir validation now occurs before Podman
  preflight.
- Direct Podman reported `linux/arm64`; live non-mutating jq, rg, and
  community-ansible-dev-tools version smokes passed on Apple Silicon macOS.
  Native Linux `amd64` acceptance was not available in this environment and
  remains a release-platform verification item.

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
| Catalog update is visible before all files are valid. | Profiles bound to that catalog can observe incomplete availability. | Validate live upstream content before use; stage and validate immutable generations before atomic binding/generation replacement; preserve prior authority. |
| Dirty or concurrently changing checkout content is published. | Default provenance is ambiguous and the published bytes may not match the reviewed commit. | Require a clean checkout with catalog changes committed, stage tracked content once from the recorded `HEAD`, validate the staged copy, recheck `HEAD` and cleanliness, and provide no dirty-publication override. |
| A live checkout is moved, deleted, or temporarily invalid. | Upstream install, update, status-available, images, and skills operations fail. | Scope the live binding to upstream, report precise health, avoid profile mutation, and preserve installed execution. |
| Two checkouts claim `upstream`. | Catalog authority becomes surprising or nondeterministic. | Unique name registry and explicit serialized replacement; never infer authority from current directory or recency. |
| Shared uninstall removes assets needed by profiles. | Catalog operations fail for surviving profiles. | Independent catalog ownership and explicit global uninstall/reference validation. |
| Removing profile-owned canonical skills breaks exports. | `shimmy skills` cannot resolve sources after profile recreation. | Resolve and validate all canonical skills from the named catalog. |
| Legacy state is partially reused. | Mixed ownership defeats safety and complicates rollback. | Detect and reject legacy/mixed layouts; require clean uninstall and recreation. |

## Review boundary

No implementation is authorized by this document. Review should confirm the
decision-complete Option D topology and its committed-content publication
boundary. Chunk 1 requires explicit implementation authorization in a later
message.

## Lessons learned

### Initial

- The profile manifest already models selected tools; the disconnect is caused
  by packaging the availability catalog and canonical skills inside the same
  profile boundary.
- Shell startup should select a profile, not determine catalog freshness.
  Resolving the profile's named catalog on each command removes the need to
  reopen the shell.
- Named catalogs resolve identity and collision behavior; separate live and
  immutable sources make their lifecycle and profile bindings explicit.
- Scoping immediate visibility to upstream permits a live maintainer catalog
  and a separate immutable default catalog without a global mode switch.
- Keeping catalog names in registry/profile metadata rather than payload data
  allows the same validated bytes to move from upstream into a default
  generation without identity rewriting.
- An explicit schema prevents stale profile control planes from guessing, but
  it intentionally turns future schema evolution into a coordinated
  producer/consumer change.
- Catalog availability, canonical skill availability, and installed execution
  have different lifecycle boundaries and must not share implicit ownership.
- Upstream immediacy and publication provenance are compatible when valid
  dirty edits remain visible only to the live upstream catalog and publication
  requires a clean checkout with those changes committed.
- A single staged copy materialized from the recorded commit plus a final
  `HEAD` and cleanliness check prevents the published generation from drifting
  away from its provenance or including ignored working-tree content.

### Chunk 1

- POSIX shell helpers share variable scope. Validating the retained rollback
  generation initially overwrote the current generation path; keeping current
  and previous identity variables distinct and testing both payloads prevents
  mixed metadata/payload resolution.
- Publication tests cannot bootstrap immutable default state from a dirty
  developer checkout. A disposable clean committed source fixture makes the
  clean-HEAD boundary deterministic while isolated copies exercise dirty and
  committed transitions.
- Catalog availability and installed execution need visibly different path
  variables during the staged refactor. `SHIMMY_CATALOG_TOOLS_DIR` is authority;
  `SHIMMY_PROFILE_MATERIALIZATION_TOOLS_DIR` and source `ROOT_DIR/tools` are
  execution or test roots pending Chunk 2 materialization changes.
- Retaining a rollback directory is insufficient; resolution must validate its
  schema, generation metadata, name/fingerprint identity, and content hash so
  the recorded rollback target is demonstrably valid.

### Chunk 2

- A profile format identity must describe its ownership boundary, not only its
  directory shape. Bumping both manifest versions and naming the
  `profile-materialized-root` layout makes full-catalog and mixed profiles
  unambiguously rejectable instead of silently refreshing them in place.
- A whole-catalog fingerprint recheck detects authority changes, but it does
  not by itself prove a copy made during transient live edits is coherent.
  Comparing every staged selected metadata file and version directory against
  the re-resolved authority closes that gap before commit.
- Installed upstream execution independence requires profile-root-relative
  logical dispatch and explicit materialized-version smoke routing; neither
  path may require the recorded checkout to remain available.
- Installed test mode must select its profile-smoke surface before sourcing
  repository-only tool suites; selected-only profile payloads intentionally do
  not carry every catalog tool's contributor tests.

### Chunk 4

- POSIX shell functions share caller variables, including internal validator
  names. A rollback validator initially replaced the caller's destination path
  with its temporary registry path; distinct transaction-specific names and a
  real registry-swap test are required for atomic-file code.
- Catalog rollback must validate the retained target independently of the
  current authority. Requiring the current generation to resolve would make
  rollback unusable for the corruption case it is intended to recover.
- Management refresh and catalog-default adoption are separate operations.
  Preserving the manifest during control refresh, then atomically replacing
  only selected tool/version labels, prevents unrelated catalog defaults from
  changing during a targeted update.
- A global uninstall is safe only after complete ownership preflight. Rejecting
  unknown shared entries before removing any profile keeps the destructive
  boundary explicit while still allowing uninstall when an external upstream
  checkout has moved or disappeared.
- Deterministic local request validation must precede Podman preflight. A
  missing host mount is actionable without an engine and must not turn an
  offline regression test into a sandbox or machine-readiness test.

## Session bootstrap

In a fresh implementation session, read `AGENTS.md`, `CONTRIBUTING.md`, root
`CONTEXT.md`, this entire plan, `lib/catalog/catalog.sh`,
`lib/install/profile-assets.sh`, `commands/skills.sh`, and the context files for
every source or test path under consideration. Treat the profile-local control
plane, separate live `upstream` and immutable `default` catalogs, explicit
profile bindings, schema version 1, no backwards compatibility or migration,
next-command upstream catalog-entry availability, clean committed-content-only
publication, one explicit upstream rebind, and catalog-owned canonical skills
as non-negotiable. Chunks 1 through 4 are implemented and verified, with native
Linux `amd64` acceptance still recorded as a release-platform verification
item. Stop at the Chunk 4 human review gate.
