# Decouple Management Skills from Catalog

## Objective

Make canonical management skills exclusively control-plane-owned. The direct
skill directories under `plugins/shimmy/skills/` must determine every profile's
control bundle from that profile's exact control-source Git commit, without a
hard-coded inventory. Management skills must no longer be archived, validated,
fingerprinted, or versioned as default-catalog payload.

The replacement ownership model is:

- `catalog.conf` and `tools/` are the complete catalog payload;
- `tools/<tool>/SKILL.md` remains a catalog-owned tool skill;
- `plugins/shimmy/skills/<name>/SKILL.md` is control-plane source only;
- a profile control bundle is materialized from its exact `shimmy_source_ref`;
  and
- the profile's catalog pin and control-source commit remain independent.

Success means:

- catalog creation/publication archives only `catalog.conf` and `tools/`;
- catalog validation and content fingerprinting never read
  `plugins/shimmy/skills/`;
- catalog generations contain only their catalog payload plus
  `generation.conf`, and legacy management-skill trees are not accepted as part
  of the replacement generation layout;
- a commit that changes only management skills leaves catalog content identity
  unchanged and reuses the already retained content-addressed generation rather
  than reporting a source-commit identity collision;
- adding a valid direct management-skill directory makes it appear in a control
  bundle materialized from that exact commit, while removing it from a later
  commit removes it from the new bundle and the established recognized-stale
  reconciliation removes only its prior Shimmy-owned user link;
- current and future control skills require no production allowlist, fixed test
  inventory, or fixed bundle count;
- malformed management skills fail at control-bundle/profile materialization,
  not catalog publication; and
- catalog tool validation, immutable generation identity, retained rollback,
  profile pinning, control-bundle integrity, and unrelated user-skill
  preservation continue to work.

Backward compatibility is explicitly excluded. Shimmy is unreleased; existing
installations must be uninstalled with the version that created them and then
bootstrapped from the replacement implementation. There will be no dual reader,
legacy fingerprint path, catalog migration command, in-place state rewrite, or
compatibility schema.

This change also excludes:

- automatic catalog publication or automatic profile synchronization;
- changing tool-skill ownership or tool/version catalog discovery;
- supporting management-skill resources beyond the current bundle-owned
  `SKILL.md` file;
- changing exact collision replacement, unrelated-name preservation, or
  recognized stale-link ownership rules;
- adding public catalog/profile commands or compatibility aliases; and
- creating or editing generated repository `.agents/skills/` adapters.

## Target layout and terminology

### Source and installed layout

```text
<source checkout>/
  catalog.conf
  tools/                              # complete catalog payload
    <tool>/SKILL.md                   # catalog-owned tool skill
    <tool>/tool.conf
    <tool>/versions/...
  plugins/shimmy/skills/              # control-plane source, not catalog
    <management-skill>/SKILL.md

<installation>/
  catalogs/default/
    registry.conf
    generations/<catalog-fingerprint>/
      catalog.conf
      generation.conf
      tools/                          # no plugins/ tree
  profiles/<profile>/
    install-manifest.txt              # independent source ref and catalog pin
    ai-skills/control/
      bundle.conf
      skills/<management-skill>/SKILL.md
    ai-skills/shims/
      bundle.conf
      skills/shimmy-tool-<tool>/SKILL.md
```

### Independent identity flows

```text
catalog.conf + tools/
  --> catalog validation and SHA-256 content fingerprint
  --> immutable default-catalog generation
  --> profile catalog pin and tool-skill materialization

exact control-source Git commit: plugins/shimmy/skills/*
  --> validated dynamic control bundle
  --> active-profile management-skill links
```

- **Catalog payload**: exactly the catalog-owned source inputs
  `catalog.conf` and `tools/`. `generation.conf` is retained-generation
  metadata, not fingerprint input.
- **Catalog content identity**: the deterministic SHA-256 fingerprint of only
  the catalog payload. It is independent of management-only source commits.
- **Generation provenance commit**: the source commit recorded when a unique
  catalog payload was first materialized. If a later source commit has identical
  catalog content, publication reuses the retained generation and its original
  provenance rather than rewriting immutable metadata.
- **Control source**: the exact Git commit recorded as `shimmy_source_ref` in a
  profile manifest.
- **Canonical management-skill set**: the non-empty, lexically sorted set of
  valid direct Git-tree directories under `plugins/shimmy/skills/` at the
  control source.
- **Recognized stale link**: an existing direct user-skill link proven by
  `lib/ai-skill/link.sh` to point into a Shimmy-owned profile bundle but absent
  from the newly desired bundle records.

## Recorded design decisions

1. Catalog and management-skill ownership are fully separated. No production
   catalog archive, path validator, skill validator, authority validator,
   fingerprint renderer, fixture, or current guidance may treat
   `plugins/shimmy/skills/` as catalog content.
2. Replace the current unreleased `catalog_schema=1` contract in place rather
   than introducing schema 2 or a dual reader. Schema 1 now means
   `catalog.conf` plus `tools/` only. Existing installed state is intentionally
   unsupported and must be removed/recreated; do not add compatibility logic.
3. Source-checkout validation may run at the repository root and therefore
   validates only the catalog-owned paths without rejecting unrelated checkout
   content. Retained-generation validation is stricter: it must accept only
   `catalog.conf`, `generation.conf`, and `tools/` at the generation root and
   must reject unsafe or unrecognized generation-owned state.
4. Catalog fingerprints include every regular file below `tools/` plus
   `catalog.conf`, in lexical path order with the existing executable-mode and
   file-hash encoding. They exclude `generation.conf` and every control-plane
   path.
5. Catalog staging archives exactly `catalog.conf` and `tools/` from the clean,
   attached `main` commit. The complete staged payload is validated and
   fingerprinted before immutable generation metadata is added, preserving the
   existing stage/commit/rollback transaction.
6. A retained generation is content-addressed, not `(content, latest HEAD)`-
   addressed. When publication stages a fingerprint whose generation already
   exists, validate the existing generation and reuse its original provenance
   commit even if the current checkout `HEAD` differs. Never rewrite immutable
   generation metadata merely to record an equivalent later source commit.
   Registry records and profile catalog pins continue to match the selected
   generation's stored provenance.
7. A management-only commit therefore makes catalog publication a truthful
   no-op: the current generation, registry provenance, and retained generation
   count remain unchanged. `profile sync` may still adopt that newer commit as
   its independent control source while retaining the unchanged catalog pin.
8. Control-bundle materialization enumerates the complete direct Git tree at
   the requested resolved commit, rejects non-tree or unsafe entries, requires
   a non-empty set, sorts names under `LC_ALL=C`, and materializes every
   discovered `SKILL.md`. It never derives management-skill membership from a
   catalog generation or the mutable checkout worktree.
9. Remove `shimmy_ai_skill_control_names_render` and all installed/profile
   equality checks against a compiled set. A materialized control bundle is
   authoritative for its dynamic inventory while retaining bundle schema,
   non-empty records, lexical uniqueness, exact source-ref equality, per-file
   fingerprint, matching frontmatter, managed-copy header, regular-tree, and
   cross-bundle collision validation.
10. Reconciliation remains bundle-driven. A newly desired control record is
    linked through the existing exact replacement transaction; a removed record
    permits only the existing recognized-stale-link cleanup. Unrelated names and
    the user skill root remain outside Shimmy ownership.
11. Tests must not replace production hard-coding with fixture hard-coding.
    Counts and desired names are derived from the isolated control source or
    materialized bundle. One integrated synthetic management skill add/remove
    transition is the authoritative proof of dynamic control membership and
    catalog isolation.
12. The absence of management skills from catalog generations is a permanent
    ownership invariant explicitly required by this plan. Protect it once at
    the lowest-cost catalog generation/staging boundary; do not duplicate
    generic absence assertions across commands.
13. Current contributor and reusable-project guidance must state that management
    skills are control-plane-only and tool skills remain catalog-owned.
    Historical completed plans remain historical evidence and are not edited.

## Verified implementation inventory

This is a verified baseline, not permission to ignore dependencies discovered
during implementation.

- `catalog.conf` currently declares `catalog_schema=1`; the schema has a single
  reader and no compatibility layer, so replacing its unreleased contract is
  localized but intentionally invalidates prior installed state.
- `lib/install/catalog.sh:71-93` stages catalog generations. Its Git archive
  currently names `catalog.conf`, `tools`, and `plugins/shimmy/skills`, then
  fingerprints the extracted payload before adding `generation.conf`.
- `lib/catalog/catalog.sh:98-136` requires and path-validates both `tools/` and
  `plugins/shimmy/skills/`; `:302-329` fingerprints all three catalog inputs;
  and `:332-408` hard-codes and validates the management-skill inventory.
- `lib/catalog/authority.sh:18-56` repeats a six-name management-skill authority
  check and managed-header validation before validating catalog-owned tool
  skills. `shimmy_catalog_generation_record_validate` recomputes the payload
  fingerprint and compares it with immutable generation metadata.
- `lib/install/catalog.sh:223-275` currently treats an existing content-addressed
  generation created at a different source commit as an identity collision.
  After management skills leave catalog content, ordinary management-only
  commits will exercise this case and require content-equivalent reuse.
- `lib/catalog/state.sh` stores one provenance commit and fingerprint in each
  generation, registry, and profile catalog pin. Those formats remain usable if
  equivalent payload reuse retains the first generation's stored provenance.
- `tests/test.sh` and `commands/agent-preflight.sh` validate the repository root
  as a source catalog payload. The replacement source validator must ignore
  control-plane paths rather than require a catalog-only repository root.
- `tests/lib/catalog.sh` copies `plugins/` into payload fixtures, advances
  generations by editing `shimmy-catalog`, and assumes a control-skill change is
  catalog content. These fixtures must move to tool-owned changes and add one
  authoritative catalog/control isolation scenario.
- `tests/lib/codec.sh` fixes the current catalog fingerprint vector using a
  management-skill file and must be replaced with a catalog-only vector.
- `plugins/shimmy/skills/` currently contains seven direct skill directories.
  Commit `81ccc2d` added `shimmy-tool-discover` and updated only one catalog
  allowlist, exposing the split hard-coded inventories.
- `lib/ai-skill/bundle.sh` renders six control names through
  `shimmy_ai_skill_control_names_render`.
- `lib/ai-skill/ai-skill.sh` already reads the direct management-skill names and
  files from an exact Git commit, but compares them with the six-name renderer.
  It otherwise has the correct producer boundary and validates each
  materialized file's frontmatter, managed header, and fingerprint.
- `lib/profile/state.sh` and `shimmy_ai_skill_supported_bundles_validate` repeat
  the static control-name comparison after structural/source validation.
- `lib/ai-skill/ai-skill.sh` and `lib/ai-skill/link.sh` already compute desired
  links from validated bundle records and narrowly remove recognized stale
  profile links; the destructive ownership mechanism itself does not need
  redesign.
- `tests/lib/ai-skill-state.sh`, `tests/commands/ai-skill.sh`,
  `tests/commands/profile.sh`, and `tests/commands/lifecycle.sh` consume the
  static renderer or fixed control count `6` and need fixture-derived
  expectations.
- `README.md`, `docs/prompt-shimmy-project.md`, and
  `lib/catalog/CONTEXT.md` explicitly describe management skills as catalog
  payload. `CONTRIBUTING.md`, root `CONTEXT.md`, and
  `lib/ai-skill/CONTEXT.md` need the replacement control-only ownership and
  adoption boundary stated explicitly.
- The current focused baseline
  `./tests/test.sh --group lib-catalog --group lib-ai-skill-state --group
  commands-ai-skill --jobs 3` fails with `catalog control skills do not match
  the canonical set`; AI-skill-state cases pass independently.

## Unresolved

None.

## Progress Checklist

- [ ] Active — Chunk 1: atomically replace catalog schema-1 ownership, make
  control-skill discovery directory-driven, update tests/guidance, and verify
  clean-install behavior.

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

## Chunk 1 — Replace catalog ownership and dynamic control inventory

### Goal

Land the catalog format replacement, content-equivalent publication semantics,
dynamic exact-source control bundles, ownership tests, and current guidance as
one coherent transition. A clean bootstrap must produce catalog generations
without management skills while profiles still materialize and reconcile every
management skill from their independent control source.

This remains one chunk because the catalog owned-format identity and every
producer, consumer, validator, fixture, transaction, and rollback path must be
updated as one review unit. Splitting the catalog replacement from dynamic
control materialization would leave the current seven-skill source unable to
bootstrap or sync at an intermediate review gate.

### Files

Primary implementation surface:

- `lib/catalog/catalog.sh`
- `lib/catalog/authority.sh`
- `lib/install/catalog.sh`
- `lib/ai-skill/bundle.sh`
- `lib/ai-skill/ai-skill.sh`
- `lib/profile/state.sh`
- `tests/lib/catalog.sh`
- `tests/lib/codec.sh`
- `tests/lib/ai-skill-state.sh`
- `tests/commands/ai-skill.sh`
- `tests/commands/profile.sh`
- `tests/commands/lifecycle.sh`
- `README.md`
- `CONTRIBUTING.md`
- `CONTEXT.md`
- `docs/prompt-shimmy-project.md`
- `lib/catalog/CONTEXT.md`
- `lib/install/CONTEXT.md`
- `lib/ai-skill/CONTEXT.md`

`catalog.conf`, catalog registry/generation metadata schemas, profile manifests,
and canonical skill contents are expected to remain byte-compatible in source;
their interpreted catalog ownership changes. This list is the verified primary
surface, not permission to ignore a newly discovered consumer required for the
same atomic transition.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. The shell edits are compact, but the change
redefines an owned format, immutable content identity, publication deduplication,
profile source separation, and destructive link reconciliation.

1. Redefine catalog schema 1 as `catalog.conf` plus `tools/`. Remove every
   management-skill path/name/header check from catalog validation and authority.
   Narrow catalog skill helpers/constants to truthful tool-skill terminology
   where they no longer have management-skill callers.
2. Make source payload path/type validation operate only on `tools/` while still
   allowing invocation at the repository root. Add retained-generation root
   validation that admits only `catalog.conf`, `generation.conf`, and `tools/`
   and preserves existing safe regular path and no-symlink guarantees.
3. Fingerprint only `catalog.conf` and every regular file under `tools/`, with
   existing deterministic ordering, executable-mode marker, SHA-256 file hash,
   temporary-file cleanup, and error handling. Replace the fixed codec vector
   with one containing only catalog-owned bytes.
4. Change Git archive staging to include only `catalog.conf` and `tools/`.
   Inspect and exercise the staged generation so archive behavior, generation
   root layout, metadata timing, and file modes—not only renderer source—prove
   the new ownership boundary.
5. Modify publication reuse so a valid existing generation with the staged
   content fingerprint is reusable even when its stored provenance commit is
   not the current checkout `HEAD`. Carry the retained generation's original
   commit into registry commit validation whenever that generation becomes
   current; never rewrite its metadata. Preserve lock order, clean-HEAD
   revalidation, collision handling for invalid/tampered generations, registry-
   last commit, rollback, and cleanup.
6. Treat a management-only committed source change as a catalog no-op. Do not
   advance current/previous generation, registry bytes, or retained generation
   count. Keep status truthful by reporting the current generation's original
   provenance commit rather than claiming the later control-only commit was
   catalog content.
7. Replace `shimmy_ai_skill_control_names_render` with exact-commit direct-tree
   discovery inside the control-bundle producer. Account for every direct entry,
   require regular Git trees with safe names, require a non-empty set, sort under
   `LC_ALL=C`, and materialize/validate every `SKILL.md` from that commit.
8. Remove static-name equality from supported-bundle and profile-state readers.
   Add explicit non-empty control-record checks and retain all existing bundle
   structure, source-ref, per-file fingerprint, frontmatter, warning-header,
   lexical uniqueness, cross-bundle collision, and profile/catalog-pin checks.
9. Update existing isolated fixtures and assertions to derive control names and
   counts. Integrate one synthetic management-skill add/commit/publish/sync and
   remove/commit/publish/sync sequence: catalog publication remains a no-op,
   profile `shimmy_source_ref` advances independently, catalog pin remains
   unchanged, the added skill link appears, and its recognized stale link is
   removed after the later sync while unrelated user content survives.
10. Keep one authoritative catalog-generation layout assertion proving the
    permanent ownership boundary. Update catalog lifecycle advancement fixtures
    to mutate catalog-owned tool content, preserving existing generation,
    rollback, collision, transaction, and recovery coverage without duplicating
    generic negative tests.
11. Update README, contributor guidance, reusable project prompt, and current
    contexts together. State the clean reinstall boundary, control-only
    management-skill source, catalog-owned tool skills, catalog-only archive and
    fingerprint, content-equivalent no-op publication, and explicit profile sync
    adoption. Do not rewrite historical completed plans.
12. Do not add migration readers, legacy fingerprint branches, in-place state
    conversion, compatibility aliases, new public commands, or repository
    `.agents/skills/` adapters.

### Verification checklist

- [ ] A live-tree search shows no catalog archive, validator, authority,
  fingerprint, fixture, or current guidance that classifies
  `plugins/shimmy/skills/` as catalog content; control-plane materialization and
  canonical source guidance remain the only intentional references.
- [ ] Source catalog validation succeeds against the repository root using only
  `catalog.conf` and `tools/`; tool-skill frontmatter/header, version metadata,
  safe paths, executable modes, and image contracts remain enforced.
- [ ] A fresh staged/installed catalog generation has the exact replacement
  root layout, contains no management-skill tree, and its deterministic
  fingerprint changes for tool-owned bytes or modes but not management-skill
  bytes.
- [ ] Publishing a management-only commit validates the checkout but leaves the
  current/previous registry entries, registry provenance/fingerprint, retained
  generation metadata, and generation count unchanged; publishing a tool change
  still creates and selects a new immutable generation, and rollback still
  selects the prior valid generation.
- [ ] Reusing an older retained generation for content-equivalent catalog bytes
  uses that generation's stored provenance and does not weaken tamper/collision
  rejection or rewrite immutable state.
- [ ] Exact-source control materialization includes all current management
  skills and a synthetic added skill without a compiled list; a later committed
  removal produces the reduced non-empty bundle deterministically.
- [ ] Profile sync across the synthetic add/remove commits advances only the
  control source when catalog content is unchanged, adds/removes the exact
  recognized management-skill link, and preserves unrelated user content and
  rollback behavior.
- [ ] Malformed control bundles/source mismatches, empty control sets,
  cross-bundle collisions, malformed tool skills, unsafe catalog state, and
  modified generation fingerprints retain their existing fail-closed ownership
  and integrity behavior at the correct subsystem boundary.
- [ ] Run focused independent groups with bounded parallelism:
  `./tests/test.sh --group lib-catalog --group lib-codec --group
  lib-ai-skill-state --group commands-agent-preflight --group commands-catalog
  --group commands-ai-skill --group commands-profile --group commands-shim
  --group commands-lifecycle-bootstrap --group commands-lifecycle-end-to-end
  --jobs 3`.
- [ ] Run the complete default suite with its default bounded parallel runner:
  `./tests/test.sh`.
- [ ] Parse every changed shell source and shell test with `/bin/sh -n`; verify
  runnable modes remain correct and no generated `.agents/skills/` tree exists.
- [ ] `git diff --check` passes and `git status --short` shows only the approved
  implementation, tests, current guidance, and this plan.

### Human review gate

The reviewer must confirm that management skills are absent from all new
catalog ownership and identity, catalog schema 1 has been replaced without a
compatibility reader, content-equivalent publication retains truthful immutable
provenance, control bundles dynamically follow exact source commits, add/remove
reconciliation preserves its narrow ownership boundary, clean bootstrap and the
full suite pass, and every partial verification item has an explicit accepted
disposition. Stop after this gate; final acceptance is required before moving
the plan to `complete`.

## Risk register

- **Old installed state becomes unreadable.** This is intentional and approved
  for the unreleased product. Mitigation: no ambiguous partial support; require
  uninstall with the creating version and fresh bootstrap, and add no migration
  or dual-reader paths.
- **Management-only commits collide with retained catalog identity.** Mitigation:
  make generation reuse content-based, preserve the first generation's immutable
  provenance, and test current-generation no-op plus older-generation reuse.
- **Equivalent-content reuse weakens collision protection.** Mitigation: reuse
  only an existing generation that passes full root-layout, payload, metadata,
  generation-name, and recomputed-fingerprint validation; invalid state remains
  a hard collision failure.
- **Source validation and retained-generation validation are conflated.**
  Mitigation: source validation inspects owned catalog paths inside a larger
  checkout, while generation validation enforces its exact owned root layout.
- **Malformed management skills escape all validation.** Mitigation: their
  validation moves entirely to exact-source control-bundle materialization and
  profile consistency; catalog publication intentionally has no authority over
  them.
- **A hidden allowlist survives in tests or installed readers.** Mitigation:
  derive expectations from isolated source/bundle data and search the complete
  live tree for the static renderer, current name list, and fixed counts.
- **A removed skill causes broad user-root deletion.** Mitigation: preserve the
  existing recognized direct-link classifier and external compensation
  transaction; test the synthetic removal together with unrelated-name survival.
- **Users mistake directory discovery for automatic adoption.** Mitigation:
  document that commits, catalog publication for catalog changes, and profile
  sync remain explicit transactions even though no inventory code changes are
  needed for management-skill membership.

## Lessons learned

### Initial

- The original seven-versus-six failure exposed two separate issues: compiled
  control-skill inventories and an obsolete catalog ownership decision. Updating
  every list would preserve the wrong architecture.
- Catalog archive and fingerprint logic already include the complete management-
  skill tree, while control bundles independently read an exact Git commit. The
  two flows can be separated without moving canonical skill files.
- Removing management skills from catalog content makes same-content/different-
  HEAD publication routine. Current generation reuse incorrectly treats that as
  an identity collision, so publication provenance semantics are part of the
  ownership transition.
- Profile manifests already store independent control-source and catalog-pin
  commits, and profile sync already fetches them independently. No profile
  schema change is required to express the target model.
- Because the product is unreleased and upgrade is uninstall/reinstall, the
  cleanest result is one replacement schema with no legacy reader or migration
  state. This prevents obsolete catalog/management coupling from surviving as
  permanent compatibility code.
- Existing desired-link rendering and recognized-stale cleanup already operate
  on bundle records, so dynamic membership does not require a broader
  destructive boundary.

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, this plan, and
`docs/testing.md`. Then read `lib/CONTEXT.md` plus
`lib/{catalog,install,ai-skill,profile}/CONTEXT.md`, `tests/CONTEXT.md` plus
`tests/{lib,commands}/CONTEXT.md`, and every Chunk 1 target file.

Reconfirm the worktree and preserve unrelated changes. The active scope is the
single atomic Chunk 1: replace catalog schema-1 ownership with catalog-only
archive/validation/fingerprint semantics, implement content-equivalent
generation reuse, make management-skill bundles dynamically follow the exact
control source, update existing tests/current guidance, run the checklist,
record progress and lessons here, and stop at the human review gate.

Do not add any legacy catalog reader, fingerprint compatibility branch,
migration command, automatic uninstall/reinstall behavior, public command,
canonical skill rewrite solely for generated copies, or repository
`.agents/skills/` adapter. Implementation remains unauthorized until the user
explicitly approves this revised plan.
