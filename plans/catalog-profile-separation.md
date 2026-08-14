# Catalog and Profile Separation — Chosen Architecture

## Objective

Implement a shared named catalog with profile-local control planes
and an explicit catalog schema contract.

The target behavior is:

- each shared named catalog is a profile-independent authority for its
  available tools, concrete versions, and canonical Shimmy skills;
- each profile retains its own `shimmy` launcher, management code, manifest,
  selected tool materializations, and mutation boundary;
- every profile records an explicit named-catalog binding rather than deriving
  catalog identity implicitly from its profile name;
- after a new tool has been completely created in `upstream`, it is available
  for installation into the `upstream` profile on the next `shimmy` command
  invocation, without closing or reopening the shell, refreshing that profile,
  or running an intermediate synchronization step to pick up the local code
  change; and
- installed tools continue to execute from profile-owned materializations if
  the catalog is unavailable or later changes.

This plan does not preserve or migrate the current flat installed layout.
Existing Shimmy installations and profiles will be uninstalled and recreated
with the new implementation. It also does not introduce a shared global
control plane or silently change an installed profile when a catalog default
changes.

One decision group remains open: catalog source lifecycle/topology and the
four Choice D gaps concerning publication, dirty checkouts, live code scope,
and multiple checkouts. They are detailed in **Unresolved** and must be closed
before implementation begins.

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
resources. The `upstream` profile explicitly binds to the `upstream` catalog.
Whether the `default` profile shares that authority or binds to a separate
`default` catalog remains part of the unresolved source-lifecycle decision.

### Logical target layout

The unresolved catalog source lifecycle may refine the files below the named
catalog, but it must preserve this ownership boundary:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/
  catalogs/
    <catalog-name>/            # shared registry entry
      registry.conf            # name, source type, and source location/generation
      <source-specific state>  # unresolved: live binding, snapshot, or hybrid
  profiles/
    default/
      bin/                    # profile-local shimmy and selected tool dispatchers
      commands/ lib/          # profile-local management control plane
      manifest                # catalog binding and selected tool versions
      implementations/        # selected tool implementations
      tools/                  # selected version-owned runtime/assets only
    upstream/
      ...                     # independent selection and explicit catalog binding
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
7. Catalog activation or publication and profile materialization are staged,
   validated, and committed atomically. A profile must not observe or install
   a partially validated catalog entry.

### Named catalogs and multiple checkouts

1. Catalog identity is name-based rather than inferred from the invoking
   checkout or profile.
2. The `upstream` profile records `catalog=upstream`. The `default` profile's
   binding depends on the selected source-lifecycle option.
3. Profile-to-catalog bindings are explicit manifest data. Bootstrap may
   enforce built-in pairings, but resolution must not concatenate or otherwise
   derive a catalog name from a profile name.
4. No checkout may silently replace another source registered under the same
   catalog name. The source-lifecycle decision must define the explicit
   activation, replacement, or publication transaction for `upstream`.
5. The plural `catalogs/` registry and profile manifest binding preserve a path
   for future named catalogs. Adding another catalog, catalog-selection CLI,
   precedence rules, or cross-catalog tool resolution is outside this first
   implementation.
6. If multiple checkout catalogs are added later, each checkout must use a unique
   catalog name and each profile must resolve exactly one catalog. Tool lookup
   will not merge catalogs implicitly.

This establishes the identity and collision boundary without prematurely
adding catalog precedence or implicit merging. Exact first-release behavior
for a second checkout remains unresolved below.

### Explicit catalog schema contract

The initial contract is exact-versioned rather than best-effort compatible.
Catalog binding metadata and catalog payload identity are separate contracts.
At minimum, each registry entry owns a `registry.conf` containing:

```text
catalog_name=<safe-registry-name>
catalog_source_type=<lifecycle-specific-type>
<lifecycle-specific source location or generation>
```

The resolved catalog authority owns a root `catalog.conf` containing one value
for each of:

```text
catalog_format=shimmy-catalog
catalog_schema=1
```

`catalog_format` is a fixed identity marker, analogous to file magic: it proves
that a live binding or snapshot points at a Shimmy catalog payload before the
reader interprets schema-specific keys and directory structure.

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
mutation. The selected source lifecycle must define the completion/commit
boundary that makes a new tool valid and visible.

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

### Catalog source lifecycle and topology

**Gap.** Named registry entries and the schema contract identify what a profile
reads and how it validates the result, but they do not yet determine how many
initial catalogs exist, which physical files are authoritative for each one,
or what operation moves validated development content into stable user state.

The decision must preserve these boundaries:

- the `upstream` profile gets next-command visibility of valid changes in its
  bound `upstream` catalog;
- catalog identity and source lifecycle are explicit registry metadata rather
  than consequences of the current directory or matching profile name;
- catalog payloads use the same schema regardless of whether their source is a
  checkout or immutable generation;
- profile tool execution remains independent of every catalog source; and
- canonical skills are part of the same authority and transaction as their
  catalog's tool metadata.

#### Choice A — One live catalog bound to a source checkout

`catalogs/upstream/` records a validated absolute checkout binding. The
`upstream` profile uses it directly; other profiles could bind to the same
authority, although only upstream has an immediate-visibility requirement.

This is the smallest source-lifecycle implementation and exposes arbitrary
valid local edits without publication. It also places checkout loss, invalid
intermediate edits, and dirty working state directly in every bound profile's
catalog-management path. Rollback requires changing the checkout or explicitly
rebinding it because Shimmy owns no stable prior generation.

#### Choice B — One immutable installed catalog with automatic publication

`catalogs/upstream/` owns an immutable generation. A supported creation
workflow validates and atomically publishes a new generation as its final
step.

Readers receive a stable, reproducible view that survives checkout loss, but
ordinary manual repository edits are not visible until publication. This only
satisfies upstream immediacy if all creation paths publish automatically, which
is not guaranteed by the current contributor workflow.

#### Choice C — One catalog with a live/snapshot mode switch

The single `upstream` registry entry can point either at a live checkout or an
installed immutable generation, with one global mode active at a time.

This supports both development and stable operation through one catalog name,
but creates mode-switch transactions, precedence rules, rollback decisions,
and a larger state matrix. Every profile bound to the catalog changes source
mode together.

#### Choice D — Separate live `upstream` and stable `default` catalogs

Create two catalog registry entries with different intrinsic lifecycles:

```text
repository checkout
  -> upstream catalog (live checkout authority)
     -> upstream profile
        -> explicit validated publication
           -> default catalog (immutable generation outside the repository)
              -> default profile
```

The initial product policy is:

| Profile | Explicit manifest binding | Catalog lifecycle | Purpose |
| --- | --- | --- | --- |
| `upstream` | `catalog=upstream` | Live absolute checkout binding | Maintainer edit, validation, and debugging loop |
| `default` | `catalog=default` | Shimmy-owned immutable generation | Stable user operation independent of the checkout |

The matching names are bootstrap defaults, not a resolver shortcut. The
profile manifest supplies the catalog name, the registry resolves its source,
and the catalog payload supplies only format/schema identity. This permits a
validated upstream payload to be published into `default` without rewriting a
payload-embedded catalog name.

A first-pass layout remains within the existing Shimmy configuration root:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/
  catalogs/
    upstream/
      registry.conf           # source type plus user-owned checkout path
    default/
      registry.conf           # source type plus current generation identity
      generations/
        <content-identity>/    # immutable tools, metadata, and canonical skills
  profiles/
    upstream/
      install-manifest.txt    # catalog=upstream
    default/
      install-manifest.txt    # catalog=default
```

Using `${XDG_DATA_HOME:-$HOME/.local/share}` for immutable generations would
more strictly separate data from configuration, but it would broaden Shimmy's
ownership, safe-path, uninstall, and rollback boundaries across two roots. The
recommended first implementation keeps both registry state and generations
under the existing `SHIMMY_CONFIG_ROOT`; a later storage-layout change can be
treated as its own schema/ownership transition.

Choice D has these primary implications:

- upstream repository edits cannot destabilize default catalog operations;
- checkout movement or invalidity affects upstream catalog operations only;
- installed tools in both profiles remain profile-owned and runnable during
  either catalog failure;
- upstream canonical skills come directly from the checkout, while default
  canonical skills are the copies included in the published immutable
  generation;
- catalog publication and profile tool update remain separate operations, so
  publishing a new default generation does not silently alter installed
  default tools; and
- there is no global live/snapshot mode toggle. Each catalog's lifecycle is
  stable and visible in status output.

**Current recommendation: Choice D.** It satisfies the upstream maintainer
loop while giving default users a reproducible authority with an explicit
development-to-stable promotion boundary. It remains unresolved until the four
gaps below are accepted or revised.

### Choice D gap 1 — Default catalog creation and publication

**Issue.** The default catalog needs an initial generation and a controlled way
to receive validated upstream changes. Publication must not be conflated with
profile installation/update, and it must not expose a partially copied
generation.

Viable approaches are implicit mirroring, publication during every profile
operation, or a dedicated catalog publication transaction. Implicit mirroring
would defeat default stability; publication during profile mutation would
couple independent rollback boundaries.

**Recommended solution.** Bootstrap of the default profile creates its initial
default generation from the validated installation source. Subsequent
promotion uses one explicit catalog publication operation that:

1. resolves and validates the complete upstream catalog under schema 1;
2. stages a complete copy under `catalogs/default/` so commit stays on the same
   filesystem;
3. records a content fingerprint and available source revision metadata;
4. revalidates the staged generation independently of the live checkout;
5. atomically replaces the default catalog's current-generation reference; and
6. retains the immediately prior valid generation as the rollback target.

Publication changes catalog availability only. Existing default profile tool
materializations remain unchanged until an explicit profile install or update.
Failure before the current-generation swap leaves the prior default authority
intact.

### Choice D gap 2 — Dirty checkout publication policy

**Issue.** Requiring a clean Git checkout improves provenance but prevents a
maintainer from promoting validated local work for realistic default-profile
testing. Allowing arbitrary dirty state without provenance makes a published
generation difficult to identify or reproduce.

**Recommended solution.** Permit publication from a dirty checkout only when
the entire staged catalog passes schema and semantic validation. The immutable
generation identity is the staged content fingerprint, not the Git commit.
When Git metadata is available, record the source commit plus an explicit dirty
indicator as provenance; do not treat either as the generation identity.

The publisher must copy once into staging and validate that fixed staged copy.
It must not validate the live tree and then perform a second unconstrained copy,
which could publish different bytes if the working tree changes concurrently.
Schema-invalid or incomplete content fails without changing the current
default generation.

### Choice D gap 3 — Scope of live upstream code

**Issue.** A live catalog exposes new or changed tool definitions and canonical
skills immediately, but Option 1 still places the `shimmy` launcher, commands,
and shared libraries inside the upstream profile. Repository edits to
`commands/` or `lib/` therefore do not become live merely because the catalog
is live.

Expanding the upstream profile to execute repository control-plane code would
create a second control-plane architecture, weaken the selected profile-local
boundary, and make installed management behavior depend on a mutable checkout.

**Recommended solution.** Keep the upstream control plane profile-local. The
live boundary includes catalog payloads—tool metadata, version runtimes and
assets used as installation sources, and canonical skills—but excludes
installed management commands and shared libraries. Maintainers use existing
repo-local preview/source entrypoints while changing control-plane code, then
recreate or explicitly refresh the upstream profile to test the installed
control plane.

The upstream immediacy requirement must be documented as catalog-entry
immediacy, not arbitrary management-code hot reload.

### Choice D gap 4 — Multiple checkout behavior

**Issue.** The built-in `upstream` catalog can have only one live source at a
time. Allowing another checkout to claim the same name silently makes catalog
authority depend on command order; registering additional live catalogs does
not provide simultaneous use unless profiles can bind to them explicitly.

**Recommended solution.** The first implementation supports the two built-in
catalog names `default` and `upstream` and one active upstream checkout binding.
A second checkout attempting to register `upstream` is rejected unless the
user invokes an explicit rebind transaction. Rebind validates the replacement,
atomically swaps only the registry binding, reports the prior and new absolute
paths, and never modifies or deletes either checkout.

Simultaneous multi-checkout operation is deferred. A future extension may add
safe user-selected catalog names and additional profile bindings, but must not
merge catalogs or search them by precedence. Each profile continues to resolve
exactly one explicitly recorded catalog.

No other architecture question remains unresolved.

## Progress Checklist

- [~] Planning gate — Option 1 and its schema, naming, compatibility, upstream
  immediacy, and skill decisions are recorded; Choice D is recommended, but
  its publication, dirty-checkout, live-code-scope, and multiple-checkout
  solutions remain under review and block implementation authorization.
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

Implementation must not begin until the catalog source lifecycle/topology and
the four remaining Choice D gaps are recorded as design decisions and the
affected chunk requirements are revised to match them.

## Chunk 1 — Shared catalog contract and consumers

### Goal

Introduce named catalog registry entries, the schema-1 payload validator, and
one catalog resolver used by every catalog-aware command, without leaving
mixed old/new catalog resolution paths.

### Files

Primary surfaces: `lib/catalog/`, catalog initialization/ownership code under
`lib/install/`, `commands/`, `lib/images/`, `lib/update/`, agent preflight,
and their tests and contexts.

### Implementation requirements

- Implement the selected source topology and its atomic publication, binding,
  and rebind transactions.
- Add and validate lifecycle-specific `registry.conf`, payload `catalog.conf`,
  and the exact schema-1 contract.
- Record an explicit catalog name in every new profile manifest and resolve it
  through shared registry state on every catalog-aware invocation. If Choice D
  is accepted, bootstrap records `catalog=upstream` for upstream and
  `catalog=default` for default.
- Replace profile-relative `SHIMMY_TOOLS_DIR` authority with explicit catalog
  and profile-materialization roots; do not retain an equivalent legacy
  fallback.
- Convert all catalog consumers together and fail closed on missing, invalid,
  or unsupported catalogs before mutation.
- Report catalog name, source type, resolved source/generation, schema, and health in
  machine-readable and human-readable status without leaking shell-dependent
  implicit state.

### Verification checklist

- [ ] A valid `upstream` catalog is discovered by the upstream profile without
  shell reinitialization or profile refresh.
- [ ] Completing a valid new upstream tool entry makes it available to the
  upstream profile on the next command with no separate synchronization step.
- [ ] If Choice D is accepted, the default profile does not see the entry until
  successful publication atomically advances its immutable catalog generation.
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
- [ ] New and recreated profiles record and validate the bindings required by
  the selected topology; under Choice D, default binds `default` and upstream
  binds `upstream` while retaining independent selections.
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

- [ ] A newly created valid upstream tool skill can be explicitly exported by
  the upstream profile on the next command without profile refresh; under
  Choice D, default can export it only after successful publication.
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

- [ ] Bootstrap from clean state creates the catalogs required by the selected
  topology; under Choice D it binds the live upstream checkout, creates an
  immutable default generation, and records the two explicit profile bindings.
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
| Catalog update is visible before all files are valid. | Profiles bound to that catalog can observe incomplete availability. | Lifecycle-specific staging plus atomic binding/generation replacement; preserve prior authority. |
| A live checkout is moved, deleted, or temporarily invalid. | Upstream install, update, status-available, images, and skills operations fail. | Scope the live binding to upstream, report precise health, avoid profile mutation, and preserve installed execution. |
| Two checkouts claim `upstream`. | Catalog authority becomes surprising or nondeterministic. | Unique name registry and explicit serialized replacement; never infer authority from current directory or recency. |
| Shared uninstall removes assets needed by profiles. | Catalog operations fail for surviving profiles. | Independent catalog ownership and explicit global uninstall/reference validation. |
| Removing profile-owned canonical skills breaks exports. | `shimmy skills` cannot resolve sources after profile recreation. | Resolve and validate all canonical skills from the named catalog. |
| Legacy state is partially reused. | Mixed ownership defeats safety and complicates rollback. | Detect and reject legacy/mixed layouts; require clean uninstall and recreation. |

## Review boundary

No implementation is authorized by this document. Review should confirm the
recorded decisions, select a catalog source topology, and resolve the four
Choice D gaps if D is selected. After those decisions, update the target
physical layout, lifecycle requirements, verification expectations, risk
mitigations, progress status, and session bootstrap before authorizing Chunk 1.

## Lessons learned

### Initial

- The profile manifest already models selected tools; the disconnect is caused
  by packaging the availability catalog and canonical skills inside the same
  profile boundary.
- Shell startup should select a profile, not determine catalog freshness.
  Resolving the profile's named catalog on each command removes the need to
  reopen the shell.
- Named catalogs resolve identity and collision behavior but do not by
  themselves define a source lifecycle or profile binding.
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

## Session bootstrap

In a fresh planning session, read `AGENTS.md`, `CONTRIBUTING.md`, root
`CONTEXT.md`, this entire plan, `lib/catalog/catalog.sh`,
`lib/install/profile-assets.sh`, `commands/skills.sh`, and the context files for
any source or test path under consideration. Treat Option 1, explicit
profile-to-catalog bindings, schema version 1, no backwards compatibility or
migration, next-command upstream availability, and catalog-owned canonical
skills as non-negotiable. Review Choice D and resolve only its publication,
dirty-checkout, live-code-scope, and multiple-checkout gaps; then revise this
plan to make the accepted topology executable and stop for review. Do not
implement Chunk 1 without explicit authorization.
