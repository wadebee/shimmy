# Catalog and Profile Separation — First Pass

## Objective

Eliminate the UX and ownership disconnect where a tool added to Shimmy's
catalog is invisible to an already-installed profile until that profile is
rebuilt.

The target model is:

- the **catalog** is the profile-independent authority for every available tool
  and concrete version;
- a **profile** records and materializes only the catalog tool versions selected
  for that profile; and
- adding a valid tool to the active catalog makes it installable into every
  existing and future profile without refreshing those profiles first.

This first pass compares two architectural corrections. It intentionally does
not choose a final option, define migration compatibility, or provide a
detailed implementation checklist.

## Confirmed root cause

The current behavior follows directly from the flat-profile architecture:

1. `profile_control_assets_stage` in `lib/install/profile-assets.sh` copies the
   complete repository `commands/`, `lib/`, `tools/`, `tests/`, and `plugins/`
   trees into each profile.
2. Installed management commands derive `ROOT_DIR` from their enclosing
   profile and set `SHIMMY_TOOLS_DIR=$ROOT_DIR/tools`.
3. `lib/catalog/catalog.sh` discovers availability only from that resolved
   `SHIMMY_TOOLS_DIR`.
4. `shimmy install --shim ...`, `shimmy status --available`, image
   verification, skill discovery, and update selection therefore consult the
   invoking profile's copied catalog snapshot rather than the checkout where a
   new tool was created.
5. The profile manifest correctly records the selected subset, but the same
   profile also owns a full availability catalog and its management code. These
   separate concepts are conflated by the profile payload boundary.

This was an intentional consequence of making every profile a complete,
self-contained control/runtime tree. Prior architecture work explicitly relied
on copying the complete `tools/` tree so installed commands could access all
metadata and helper runtimes locally. The new-shim failure exposes the cost of
that choice: catalog freshness is scoped to profile refresh, while users
reasonably expect catalog availability to be global.

## Target terminology and invariants

- **Catalog authority**: one logical source of available tool and version
  definitions for the Shimmy installation, independent of profiles.
- **Catalog source**: either an immutable installed snapshot or a deliberately
  configured live source checkout that supplies the catalog authority.
- **Profile selection**: the exact tool/version entries recorded in one profile
  manifest.
- **Profile materialization**: the runtime, metadata, dispatcher, and any
  version-owned assets required to run only that profile's selected entries.

The following invariants apply to either option:

1. All profiles consult the same catalog authority for availability and new
   install requests.
2. Installing a catalog entry into one profile does not install or alter it in
   another profile.
3. Catalog default changes do not silently change an already-installed
   profile. The selected concrete version and the metadata needed to run it
   remain materialized in that profile until an explicit profile operation
   changes them.
4. Removing, moving, or corrupting the catalog source must not stop already
   materialized profile tools from running; it may block catalog-dependent
   management operations with a precise error.
5. Catalog publication or activation is atomic. No profile may observe a
   partially written tool or schema transition.
6. `default` and `upstream` remain profile selections, not catalog namespaces.
   A tool is not “available only in upstream” merely because it was created in
   an upstream checkout.

## Option 1 — Shared catalog, profile-local control planes

Retain profile-local `shimmy` launchers and the current profile-bound safety
model, but move catalog availability outside profile roots.

Conceptually:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/
  catalog/                 # shared catalog authority or binding
  profiles/
    default/
      bin/ commands/ lib/  # profile-local management surface
      manifest             # selected tool versions
      tools/               # selected/materialized tool versions only
    upstream/
      ...                  # independent selection, same shared catalog
```

Catalog-aware commands would use a shared catalog root for discovery and
request validation, while execution dispatch would continue using
profile-local materialized tool data. This requires separating the current
single `SHIMMY_TOOLS_DIR` concept into catalog tools and profile tools.

For maintainer UX, the shared catalog can be bound deliberately to a live
checkout, making a newly added `tools/<tool>/` directory immediately visible to
every profile. For release/user UX, it can be an atomically installed catalog
snapshot updated independently of any profile. Selecting how these two modes
coexist is unresolved below.

Advantages:

- Meets the requested catalog/profile model with the smallest change to
  launcher identity, shell profile switching, and profile-scoped mutation.
- Preserves the safety property that an installed tool runs its profile-pinned
  materialization rather than whatever version the shared catalog currently
  advertises.
- Allows catalog lifecycle and profile lifecycle to fail or roll back
  independently.

Tradeoffs:

- Management code remains duplicated and can become older than the shared
  catalog schema, so catalog schema compatibility needs an explicit contract.
- A new global catalog owner, manifest, transaction, and uninstall policy must
  be introduced.
- Profile-local skills, image verification, and status currently assume the
  full catalog tree is under the profile and must be split between “available”
  and “installed/materialized” views.

## Option 2 — Shared control plane and catalog, execution-only profiles

Move both catalog ownership and the management command surface to one shared
control installation. Profiles become execution selections containing their
manifest, shell initialization, public tool dispatchers, and selected runtime
materializations.

Conceptually:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/
  control/
    bin/shimmy commands/ lib/ catalog/
  profiles/
    default/
      manifest bin/ implementations/ tools/
    upstream/
      manifest bin/ implementations/ tools/
```

One `shimmy` control command would resolve a target profile and perform catalog
operations against the shared authority. Tool commands would remain
profile-specific through the selected profile's `bin/` directory and would run
only materialized versions.

Advantages:

- Produces the cleanest ownership boundary: one control plane, one catalog,
  many profile selections.
- Catalog and management schema update atomically, avoiding an old
  profile-local manager reading a newer shared catalog.
- Removes duplicated control/catalog payload from every profile and makes
  catalog refresh naturally visible everywhere.

Tradeoffs:

- Reopens the deliberately removed global-control/profile-selection problem.
  The design must define how `shimmy` selects `default` versus `upstream`
  without ambiguous environment state or unsafe implicit mutation.
- Requires a larger layout, launcher, bootstrap, uninstall, update, rollback,
  and manifest transition than Option 1.
- Weakens the current property that each profile is a complete independent
  management tree; control availability becomes a shared dependency even when
  already-installed tool execution remains profile-local.

## Initial recommendation

Use Option 1 as the next design iteration unless a single global management
control plane is itself a desired product change. It directly corrects catalog
ownership while preserving the existing profile-bound launcher and mutation
safety model.

The next pass should make the catalog-source lifecycle explicit before any
implementation plan is approved. In particular, “immediately available after
creation” requires a deliberate live-checkout binding or an automatic atomic
catalog publication step; merely moving the same copied snapshot to a shared
directory would fix cross-profile inconsistency but would not fix the observed
maintainer workflow.

## Verified implementation inventory

The first implementation pass will need to account for these current
consumers and ownership boundaries:

- catalog discovery and version resolution: `lib/catalog/catalog.sh`;
- profile installation and complete-tree staging:
  `lib/install/install.sh`, `lib/install/profile-assets.sh`, and
  `lib/install/request.sh`;
- profile structure and manifest validation: `lib/profile/profile.sh` and
  `lib/install/manifest.sh`;
- profile-local launcher and tool dispatch:
  `lib/install/launcher-template.sh`, `commands/dispatch-tool.sh`, and
  `commands/run-tool.sh`;
- catalog consumers: install, status, images, skills, agent preflight, update,
  and profile tests;
- update and rollback transactions under `lib/update/` and `lib/install/`;
- bootstrap, profile switching, lifecycle, status, skills, image, dispatcher,
  and catalog coverage under `tests/`;
- architecture statements in `CONTEXT.md`, `CONTRIBUTING.md`, `README.md`,
  `commands/README.md`, and related child contexts.

This inventory is a verified baseline, not permission to ignore additional
dependencies found after an option is selected.

## Unresolved

1. **Catalog source lifecycle.** Should the one active catalog be a live source
   checkout, an immutable installed snapshot, or a snapshot with an explicit
   maintainer live-binding mode? Recommendation: snapshot for normal use plus
   one explicit global live-checkout binding for development.
2. **Multiple checkout behavior.** If two checkouts attempt to become the live
   catalog source, should the newest explicit activation replace the prior
   source, or should Shimmy support named catalogs? Recommendation: keep one
   active authority initially and require explicit replacement; named catalogs
   would reintroduce availability namespaces before they are proven necessary.
3. **Existing profile transition.** Should current flat profiles be rejected
   and recreated, or transactionally migrated to the selected layout?
   Recommendation: decide only after selecting Option 1 or 2; the failure and
   rollback surfaces differ materially.
4. **Skill availability.** Co-located tool skills are currently copied
   unconditionally into every profile. Decide whether all catalog tool skills
   move with the shared catalog or whether profiles retain skills only for
   installed tools. Recommendation: global catalog skills for discovery/export,
   profile-selected skills for default no-argument exports.

## Verification themes for the final plan

- Add a tool to the active catalog and prove that both existing profiles and a
  newly created profile report it available without profile refresh.
- Install that tool into one profile and prove that only that profile gains the
  dispatcher, materialized runtime, and manifest ownership.
- Change a catalog default and prove existing profiles continue running their
  recorded concrete versions until explicitly updated.
- Make the shared catalog unavailable and prove installed tools still run while
  catalog-dependent operations fail clearly and without mutation.
- Exercise atomic catalog replacement, failed profile materialization,
  rollback, uninstall isolation, source-checkout loss, and conflicting catalog
  source requests.
- Preserve offline deterministic tests and native container acceptance for
  affected tool runtimes.

## Risk register

| Risk | Impact | Mitigation direction |
| --- | --- | --- |
| Shared catalog changes silently alter installed defaults. | Profile behavior changes without an install/update request. | Materialize and dispatch the recorded concrete version from profile-owned data. |
| A catalog update is visible before all files are valid. | Every profile can fail simultaneously. | Version and validate a staged catalog, then atomically replace its root or pointer. |
| Profile-local management code cannot read a newer catalog schema. | Option 1 recreates the same stale-control UX in another form. | Version the catalog interface and define compatible ranges, or choose Option 2. |
| A live checkout is moved, deleted, or partially edited. | New installs/status availability fail globally. | Validate before activation, preserve the prior authority for rollback, and keep installed execution independent. |
| Two checkouts compete for global catalog authority. | Tool availability becomes surprising or nondeterministic. | Require explicit serialized replacement and report the active source in status. |
| Shared uninstall removes assets still needed by sibling profiles. | Existing profiles become damaged. | Give catalog/control assets independent ownership and remove them only after explicit global uninstall or reference validation. |

## Review boundary

No implementation is authorized by this document. Review should first confirm:

1. whether Option 1 or Option 2 should be developed further;
2. whether immediate development visibility means a live checkout binding or
   an automatic publication transaction; and
3. whether existing installed profiles may be recreated or require migration.

After those decisions, revise this document into a decision-complete plan with
the specific schema, lifecycle, migration, and verification checklist.

## Lessons learned

### Initial

- The manifest already models a profile's selected subset; the disconnect is
  caused by packaging the complete availability catalog inside the same
  profile boundary.
- A shared copied snapshot is insufficient for the reported UX unless catalog
  publication is independent of profile refresh and integrated with the tool
  creation workflow.
- Catalog availability and installed execution need separate roots so global
  catalog movement cannot silently change a profile's selected runtime.
- The prior complete-profile model simplified offline operation and rollback;
  any shared-catalog design must preserve those properties deliberately rather
  than treating the catalog move as a path-only refactor.
