# Catalog Tool List

## Objective

Add a read-only `shimmy catalog list` action that lets an installed Shimmy user
enumerate every valid tool in a resolved named catalog.
Move catalog-availability presentation and coverage out of `shimmy status`, so
`status` remains responsible for installed profile state and catalog provenance
while `catalog list` becomes the user-facing catalog discovery surface.

Success requires:

- both `default` and `upstream` catalogs can be listed explicitly with
  `--name`, including when the named catalog is not the catalog bound to the
  activated profile;
- when `--name` is omitted, the activated profile's recorded default catalog
  binding determines which catalog is listed;
- output is deterministic in human and manifest formats;
- live upstream changes, default publication, and rollback are visible through
  `catalog list` at the same lifecycle boundaries currently proved through
  `status --available`;
- the obsolete `status --available` option, `shimmy_available_tool` output, and
  unit tests specific to them are removed from maintained code and guidance;
  and
- command help, repository guidance, retained contexts, and installed-launcher
  summaries describe the new ownership boundary.

Backward compatibility is not required. The removed `status --available`
surface, its output keys, and tests that exist only for that obsolete behavior
are deleted rather than retained through aliases or compatibility assertions.

This work does not add profile selection, filtering, family/group metadata,
version listing, or installation mutations. `--name` selects a catalog
registry by its validated catalog name; it does not select a profile or accept
a filesystem path.

## Target layout and terminology

- **Catalog tool**: every schema-valid direct tool entry exposed by
  `shimmy_tool_list` from the selected named catalog. Installed tools remain
  catalog tools and are included.
- **Installed tool**: a tool recorded in the invoking profile manifest. Only
  `shimmy status` reports this profile-owned state.
- **Selected catalog**: the catalog named by `catalog list --name <catalog>`.
  When `--name` is omitted, the selected catalog is the default catalog binding
  recorded by the activated/invoking profile manifest. Selection does not
  activate a profile, change `PATH`, or mutate catalog or profile state.
- **Catalog list**: the read-only `shimmy catalog list` action. It resolves and
  validates the selected catalog before rendering output.

Target command surface:

```text
shimmy catalog list [--name <catalog>] [--format human|manifest]
shimmy catalog publish
shimmy catalog rollback
shimmy catalog rebind --checkout <absolute-path>

shimmy status [--format human|manifest]
```

Target output contract:

```text
# human
Shimmy Catalog
catalog: default
- aws
- jq
...

# manifest
shimmy_catalog_name=default
shimmy_catalog_tool=aws
shimmy_catalog_tool=jq
...
```

Tool records retain the deterministic lexical order already provided by
`shimmy_tool_list`.

## Recorded design decisions

1. `catalog list` reports the complete resolved catalog, not only tools absent
   from the profile. A catalog command should describe catalog membership;
   installed-versus-uninstalled comparison remains a separate profile concern.
2. `catalog list` is valid from both canonical installed profiles. Only
   `publish`, `rollback`, and `rebind` retain the upstream-profile restriction.
3. Human output includes a short heading and catalog identity followed by one
   bullet per tool. Manifest output uses `shimmy_catalog_name` and repeated
   `shimmy_catalog_tool` records; it does not retain the status-owned
   `shimmy_available_tool` name.
4. The list options are `--format human|manifest` and `--name <catalog>`. They
   may appear in either order. Help must be available before profile or catalog
   validation, matching other third-level actions.
5. `status --available` is removed rather than retained as an alias. No
   compatibility behavior or compatibility-specific test is required.
6. Shared discovery remains in `lib/catalog/catalog.sh`; the existing validated
   and sorted `shimmy_tool_list` producer is reused. Command-specific parsing
   and rendering move to `commands/catalog.sh`, so no new central tool list or
   duplicated metadata traversal is introduced.
7. The transition is one atomic implementation chunk. Splitting command,
   tests, and documentation would temporarily leave either an undocumented
   compatibility surface or a documented command without regression coverage.
8. Backward compatibility is explicitly out of scope. Delete unit tests whose
   sole subject is the removed status availability implementation; do not
   rename or mechanically migrate obsolete test cases. Add catalog-list tests
   for the new contract while preserving independent lifecycle, validation,
   isolation, and status-health coverage.
9. With no `--name`, list validates the invoking profile manifest and resolves
   its recorded default catalog binding through `shimmy_catalog_profile_resolve`.
   With `--name`, list validates the catalog name and resolves that registry
   directly through `shimmy_catalog_registry_resolve` under the invoking
   profile's canonical configuration root. The named catalog need not be bound
   to the activated profile, but it must exist and pass full registry and
   payload validation.

## Verified implementation inventory

This inventory is the verified baseline, not permission to ignore additional
dependencies discovered during implementation.

- `commands/status.sh` owns `SHOW_AVAILABLE`, the installed-tool predicate,
  `--available` parsing/help, and `shimmy_available_tool`/`available:` rendering.
  Its remaining profile, installed-version, image-description, and invalid
  catalog-health behavior must stay intact.
- `commands/catalog.sh` already dispatches `publish`, `rollback`, and `rebind`,
  provides group/action help before validation, resolves the enclosing profile,
  and applies a common upstream-only gate that must become mutation-action
  specific when `list` is added.
- `lib/catalog/catalog.sh` validates the full catalog authority and exposes
  `shimmy_tool_list`, which returns catalog tool names in lexical order.
- `lib/install/launcher-template.sh` dispatches the existing top-level catalog
  group and needs only its installed help summary realigned. Its existing
  blanket rejection of `--profile` remains unchanged. Profile staging already
  copies the complete `commands/`, `lib/`, and `tests/` trees.
- `tests/commands/status.sh` contains basic available/not-installed assertions
  that are obsolete and must be removed, while installed metadata and
  materialized-image validation remain status tests.
- `tests/commands/catalog.sh` owns lifecycle fixtures and currently observes
  live upstream, published default, and rollback membership through
  `status --available`; those assertions must use `catalog list` and its new
  manifest key.
- `tests/commands/management.sh` verifies group/action discovery, third-level
  help, profile binding, and non-mutation. It must recognize `catalog list` as
  a fourth catalog action, prove it is available to the default profile, and
  retain the blanket `--profile` rejection expectation.
- `tests/commands/lifecycle.sh` verifies status's invalid catalog-health output.
  That diagnostic remains status behavior; catalog-list failure on unresolved
  state should be added without replacing it.
- `tests/test.sh` already sources and invokes the catalog and status command
  modules, so no test-runner module move is required.
- User and maintainer documentation is in `README.md` and
  `commands/README.md`; ownership summaries are retained in
  `commands/CONTEXT.md` and `tests/commands/CONTEXT.md`.
- Repository search found the obsolete public surface only in the files above
  plus historical `plans/tool_grouping.md`. That retained speculative plan is
  historical and outside this change; it should not be mechanically rewritten.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Move catalog tool discovery to named `shimmy catalog list`,
  remove `status --available` and its obsolete tests, and realign maintained
  tests and documentation. **Active chunk after approval.**

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

## Chunk 1 — Catalog tool discovery ownership

### Goal

Deliver one coherent public-interface transition from `status --available` to
named `catalog list`, preserving catalog validation and lifecycle visibility
while making command ownership, output naming, help, tests, and documentation
agree.

### Files

Primary change surface:

- `commands/catalog.sh`
- `commands/status.sh`
- `lib/install/launcher-template.sh`
- `tests/commands/catalog.sh`
- `tests/commands/status.sh`
- `tests/commands/management.sh`
- `tests/commands/lifecycle.sh`
- `README.md`
- `commands/README.md`
- `commands/CONTEXT.md`
- `tests/commands/CONTEXT.md`
- `plans/catalog-tool-list.md` for execution status and lessons

No change is expected in `lib/catalog/catalog.sh`, profile manifests, catalog
schema, installation transactions, or `tests/test.sh` unless implementation
discovers a required dependency and records the divergence before editing it.

### Implementation requirements

1. Add `list` to catalog group discovery and action-specific help. Document
   usage, `--name`, `--format`, both output modes, and examples; include
   `list` in the group examples and installed launcher's catalog summary.
2. Parse list arguments independently, reject missing format values, duplicate
   or unknown arguments, unsupported formats, missing name values, duplicate
   name flags, and unsafe catalog names consistently with established command
   failures. Return list help before profile or catalog validation.
3. Resolve and validate the invoking canonical installed profile for list. If
   `--name` is omitted, resolve the catalog binding recorded by its manifest
   with `shimmy_catalog_profile_resolve`. If `--name <catalog>` is present,
   validate the name and resolve that catalog directly with
   `shimmy_catalog_registry_resolve` under the same canonical configuration
   root. Fail with the catalog resolver's diagnostic before producing partial
   output. Do not alter activation, `PATH`, or profile/catalog state.
4. Apply the upstream profile/catalog requirement only to the three mutating
   catalog actions. Do not acquire a catalog lifecycle lock, stage state, or
   call lifecycle mutation helpers for `list`.
5. Render the resolved catalog name followed by every `shimmy_tool_list` entry
   using the target human or manifest contract. Do not consult installed-tool
   manifest entries to filter catalog membership.
6. Remove `SHOW_AVAILABLE`, the status-local installed predicate, the
   availability loop, `--available` parsing, and its help/examples from
   `commands/status.sh`. Preserve status catalog resolution, provenance,
   health/error output, installed tool/version output, image validation, and
   human/manifest formats.
7. Remove status unit tests made obsolete by deleting availability behavior;
   do not preserve them as compatibility tests. Add catalog-list scenarios for
   human and manifest output, catalog identity, deterministic order, inclusion
   of baseline installed tools and an uninstalled tool, invalid format/name
   and unknown-option failures, help before profile/catalog validation, and
   proof that the invoking profile manifest and catalog state do not change.
8. Replace catalog lifecycle observations of `instant` and `rollback-tool`
   with `catalog list --format manifest`. Preserve the current assertions that
   live upstream sees valid checkout edits immediately, default does not see
   them before publication, publication exposes them, and rollback removes or
   restores them at the correct generation boundary.
9. Do not add compatibility coverage for removed `status --available` or
   `shimmy_available_tool` behavior. Retain all status tests that independently
   protect current installed-state, image, provenance, and health contracts.
10. Extend management help/profile-binding coverage for the new action. Prove
    a default launcher can list the upstream catalog with `--name upstream`
    and vice versa, omitted `--name` uses the invoking profile's recorded
    catalog binding, and nonexistent or invalid named catalogs fail closed.
    Preserve rejection of `--profile` for every installed command. Add a
    catalog-loss assertion without changing the existing status health
    diagnostic or materialized-tool independence checks.
11. Update public documentation and retained command/test contexts together.
    Describe `catalog list` as complete catalog membership and `status` as
    installed profile state; remove current documentation for
    `status --available` without rewriting historical planning artifacts.

### Verification checklist

- [ ] `sh -n` succeeds for every changed executable shell file.
- [ ] Catalog group and list help expose `list`, its format contract, and
  catalog-name selection contract and examples before profile/catalog
  validation.
- [ ] Default and upstream `catalog list` manifest output identify their own
  catalog and contain the same complete baseline tool set in lexical order.
- [ ] From either activated profile, `catalog list --name default|upstream`
  reads the requested catalog without changing activation, `PATH`, profile
  manifests, or catalog state; omitted `--name` uses the activated profile's
  recorded default catalog binding.
- [ ] Catalog list includes both installed baseline tools and tools not
  installed in the invoking profile; human and manifest output contain no
  `shimmy_available_tool` compatibility records.
- [ ] Invalid list options, formats, name values, missing named catalogs, and
  invalid named catalogs fail with specific nonzero diagnostics without
  mutating profile or catalog state.
- [ ] Live upstream, default publication, and rollback membership tests pass
  through `catalog list` at their existing authority boundaries.
- [ ] Missing or invalid catalog state makes `catalog list` fail before partial
  output while status still reports `shimmy_catalog_health=invalid` and
  installed tool wrappers remain executable from materialized state.
- [ ] The complete `./tests/test.sh` suite passes.
- [ ] `rg` confirms no active source, current docs, or test references remain
  for `status --available`, `SHOW_AVAILABLE`, or `shimmy_available_tool`, with
  historical plan matches explicitly classified and retained.
- [ ] Tests whose only purpose was the removed status availability behavior are
  absent; remaining tests protect current catalog-list, lifecycle, validation,
  isolation, and status contracts.
- [ ] `git diff --check` passes, executable modes are preserved, and the final
  diff contains no unrelated changes.

### Human review gate

Confirm that `catalog list` is a complete catalog-membership view, its narrow
name override reads a catalog not bound to the activated profile without
mutation, omission uses the activated profile's recorded default catalog,
obsolete status behavior and tests are removed without compatibility support,
output names are appropriate for downstream consumers, lifecycle visibility is
preserved, all verification results are recorded, and any partial items are
accepted or deferred explicitly. Stop after this review; there is no later
implementation chunk.

## Risk register

- **CLI compatibility:** Removing `status --available` breaks callers using the
  old flag or `shimmy_available_tool`. This is accepted: backward compatibility
  is not required. Remove maintained callers/docs/tests and keep no alias.
- **Named-catalog reads:** An unchecked catalog name could escape the registry
  namespace or bypass catalog authority validation. Mitigation: use
  `shimmy_catalog_name_validate`, resolve only beneath the invoking profile's
  canonical configuration root, and require the existing fail-closed registry
  and payload validation before rendering.
- **Semantic drift:** Reusing the old installed-tool exclusion would cause
  `catalog list` to omit valid catalog members. Mitigation: define and test
  complete membership, including jq/rg baseline tools.
- **Authorization regression:** The current common upstream-only gate would
  incorrectly block default users, while moving it too broadly could weaken
  mutation protection. Mitigation: test list from both profiles and retain
  upstream-only assertions for publish/rollback/rebind.
- **Partial output on invalid authority:** Rendering before full catalog
  resolution could expose an incomplete list. Mitigation: use the existing
  fail-closed profile catalog resolver for the no-name path and registry
  resolver for the explicit-name path before calling `shimmy_tool_list`.
- **Test ownership ambiguity:** Lifecycle tests legitimately remain in the
  catalog module even when they observe listing, while status-specific image
  and health tests remain under status/lifecycle. Mitigation: delete tests
  specific to removed availability behavior, add new list-contract coverage,
  retain independent invariants, and update context descriptions precisely.

## Lessons learned

### Initial

- The current available-tool behavior was introduced to compare installed
  tools with supported-but-uninstalled tools, but the later named-catalog
  architecture established a clearer authority boundary that warrants a full
  catalog membership command.
- `shimmy_tool_list` already provides validated, metadata-driven, sorted
  discovery. The feature requires command ownership and rendering changes, not
  a new catalog schema or tool registry.
- `commands/catalog.sh` currently applies its upstream-only restriction before
  action dispatch; adding a read-only end-user action requires narrowing that
  gate without weakening mutation authorization.
- Installed control assets are staged by directory, so changing the catalog
  command and launcher template is sufficient to carry the new action into
  refreshed profiles; no per-command installation allowlist exists.
- `shimmy_catalog_profile_resolve` supplies the no-flag behavior from the
  activated profile manifest, while `shimmy_catalog_registry_resolve` supplies
  explicit named-catalog lookup without selecting or activating another
  profile.

## Session bootstrap

For an implementation session, read repository `AGENTS.md`, `CONTRIBUTING.md`,
root `CONTEXT.md`, `commands/CONTEXT.md`, `lib/CONTEXT.md`,
`lib/catalog/CONTEXT.md`, `lib/install/CONTEXT.md`, `tests/CONTEXT.md`,
`tests/commands/CONTEXT.md`, `docs/testing.md`, and this plan. Reinspect the
primary files listed in Chunk 1 and the current worktree before editing.

The active scope is Chunk 1 only: add complete resolved-catalog listing under
`shimmy catalog list`, allow its read-only `--name <catalog>` selection of a
catalog not bound to the activated profile, use the activated profile's
recorded default catalog when `--name` is omitted, remove `status --available`
without backward compatibility, delete tests obsoleted by that removal, add
tests for the new contract, update maintained docs, preserve POSIX shell
architecture and fail-closed catalog validation, update this plan's checklist
and lessons, run every verification item, and stop at the human review gate.
