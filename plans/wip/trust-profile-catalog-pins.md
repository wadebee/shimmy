# Simplify catalog authority and trust established profile pins

## Objective

First remove `catalog.conf` and establish a `tools/`-only catalog payload with
self-describing `generation.conf` metadata. Then remove full catalog-tree
validation and catalog fingerprint recomputation from ordinary profile
activities. Trust the generation identity established by
bootstrap/publication or reconfirmed by `profile sync`, and inherited by
profile create/clone. Retain lightweight reference checks, profile-local
validation, and operation-specific transaction safeguards.

Success means:

- Source payload and fingerprint scope are `tools/` only; retained generations
  contain exactly `generation.conf` and `tools/`. Parser metadata lives in
  implementation constants and `generation.conf`, outside the fingerprint.
- Activation resolves retained pins without traversing or hashing complete
  catalog payloads, during dry-run/preflight and real activation's under-lock
  recheck. Dry-run itself does not acquire those locks.
- Profile create/clone, shim activities, and AI-skill activities use the same
  trust boundary, including indirect shared-helper calls.
- `profile sync` explicitly validates the selected generation's complete
  contents before adoption, even when shared profile helpers become lightweight.
- Bootstrap/publication and `catalog verify` retain full integrity checks.
- A profile can use a retained pin older than registry current/previous;
  unrelated retained payload damage does not prevent ordinary profile work.
- Profile/registry formats, generation-name derivation, pin inheritance,
  locking, engine policy, manifest-last commits, rollback, and skill-link
  ownership remain intact. Generation metadata/layout and fingerprint inputs
  change together in the initial atomic cutover.
- Comparable before/after measurements demonstrate the activation improvement;
  remaining latency is reported separately from removed catalog work.

The prior trust plan records acceptance of the trade-off that out-of-band
changes to a previously validated catalog may be consumed by create/clone or
shim operations without a generation-wide fingerprint mismatch being detected.
This review preserves that design premise; editing the plan does not authorize
implementation. Sync detects changes in the registry-current generation chosen
for adoption; verify checks current, previous, and the active pin. Neither
promises detection in every retained generation or retroactive repair of
already materialized profile files.

Exclusions: validation caches, validation timestamps/markers, migration or
compatibility readers for the prior catalog contract, new public commands or
flags, fingerprint changes beyond the `tools/`-only cutover, filesystem
immutability enforcement, language rewrites, Podman provisioning changes, image
updates, and unrelated profile performance optimization. This work does not
redefine catalog status/tools/refresh/rollback behavior beyond adapting to the
new payload/metadata contract, or global uninstall ownership rules. Their
direct catalog-domain checks retain full validation.

The combined plan is accepted and Chunk 1 implementation is explicitly
authorized. This file remains authoritative at
`plans/wip/trust-profile-catalog-pins.md`. The incorporated plan is retained as
historical design input with a supersession note; its separate execution
sequence remains inert.

## Target layout and terminology

The final installed layout is:

```text
catalogs/default/
  registry.conf
  generations/sha256-<64 lowercase hex>/
    generation.conf
    tools/
profiles/<name>/
  install-manifest.txt
  tools/
  ai-skills/
  ...
```

- **Catalog payload:** source-authored `tools/` content only. Publication stages
  tracked `tools/` from a clean attached `main` commit. Fingerprinting preserves
  deterministic file ordering and executable-bit identity.
- **Generation metadata:** `generation.conf` contains parser identity and
  provenance in this exact order, with a final newline:

  ```text
  catalog_format=shimmy-catalog
  catalog_schema=1
  catalog_source_commit=<40 lowercase hex>
  catalog_content_fingerprint=sha256:<64 lowercase hex>
  ```

  Metadata remains outside the fingerprint. Registry selection and profile-pin
  formats do not change. The old metadata/layout contract is replaced in place;
  implementation does not migrate or rewrite existing installations. Existing
  installations need removal with compatible old controls and fresh bootstrap
  as a separately authorized lifecycle operation.
- **Catalog pin:** the profile manifest record
  `default|<generation>|<catalog-source-commit>|sha256:<hex>`. It is a metadata
  reference, not a filesystem symlink. Its provenance commit is independent
  of the profile's control-source commit.
- **Reference validation:** resolve the exact canonical retained directory;
  validate safe paths, the generation-name grammar, required direct entries,
  and agreement between the pin, directory name, and generation metadata.
  This does not establish that present payload bytes still match the digest.
- **Full integrity validation:** validate payload structure/metadata, enumerate
  payload files, recompute their fingerprint, and compare with recorded identity.
- **Profile-local validation:** inspect the materialized profile's own state,
  wrappers, selected runtime assets, engine binding, registry policy, and skill
  bundles. Hashing profile manifests or skill files remains legitimate.
- **Staged-copy validation:** verify that the selected materialized files match
  the source files used by that transaction. It proves copy consistency, not
  the integrity of the complete pinned generation.

Reference work is bounded by canonical path depth and the fixed set of metadata
records read, without enumerating generation entries. Work on selected tools
or installed profile assets may scale with that selection;
it must not grow with unrelated retained generations or all catalog tools.

## Recorded design decisions

1. Ordinary profile activities trust the established catalog pin. No persistent
   cache or additional certificate of previous validation is necessary.
2. Publication/bootstrap establish identity. Among profile lifecycle operations,
   only `profile sync` performs full catalog integrity validation. Create
   inherits the invoking profile's pin and resets tool selection to the jq/rg/
   Skopeo defaults in that generation, not the invoking profile's custom
   selection. Clone inherits the source pin and supported selection,
   materializing selected assets from that generation. Shim operations
   continue using the existing pin and do not adopt registry current.
3. Lightweight checks retain normalized absolute canonical paths, non-symlink
   parent/direct-entry checks, generation existence and name syntax, and exact
   pin/generation-metadata provenance and fingerprint agreement. Check
   `generation.conf` as a non-symlink regular file and `tools/` as a non-symlink directory
   without walking `tools/` or enumerating unrelated generations. Parse the
   expanded generation metadata contract established in Phase 1. Exact
   direct-entry inventory and complete payload/layout validation remain full-
   integrity responsibilities; ordinary reference resolution does not scan
   for extra entries.
4. Retain strict registry parsing where a consumer needs registry metadata.
   Parsing a registry must not validate current/previous payloads or require
   the profile pin to equal either pointer. Consumers that need current
   authority must read it explicitly, not depend on a full-validation side effect.
5. Preserve safety checks on the specific files/directories that an operation
   reads, copies, executes, overwrites, or deletes. In particular, removing a
   whole-tree symlink check must not permit an unsafe selected source path to
   enter a staging transaction. Check the selected subtree where necessary;
   do not replace the removed check with another complete catalog traversal.
6. Separate ordinary profile-local checks from catalog source comparisons.
   Activation must not recursively compare installed runtime trees against
   catalog versions. Preserve selected source/candidate comparisons at staging
   boundaries, plus profile-local schema, layout, executable, and bundle checks.
7. `profile sync` fully validates the selected current generation before using
   it to stage a candidate and explicitly revalidates it at the existing
   under-lock commit boundary. Preserve exact registry/manifest/policy snapshots,
   source revalidation, lock order, and compensation. Repeated full checks at
   these sync transaction boundaries are acceptable in this scope. Shared
   helpers must not add further hidden full checks.
8. Keep `shimmy_catalog_generation_record_validate` and
   `shimmy_catalog_tree_validate` strong for catalog-domain callers. Do not
   globally weaken or rename them into lightweight behavior.
9. `catalog verify` remains the existing explicit integrity inspection surface.
   It fully checks current, previous when present, and the active profile pin,
   then performs remote image/index checks through active jq/Skopeo. It does
   not fingerprint every other retained generation. Preserve its selection,
   network/authentication, output, and failure semantics; add no offline/all-
   generations mode in this work.
10. No change to public command grammar or profile/registry record formats.
    Phase 1 changes generation metadata and fingerprint scope atomically;
    Phase 2 makes no further format change. Profile status
    health describes checked reference/profile consistency, not a new claim
    that all catalog bytes were audited. Clarify that meaning in documentation
    while preserving existing structured output contracts.
11. Phase 2 starts with a low-fidelity function-contract pass after Phase 1's
    atomic catalog cutover has been accepted.
    Later chunks may consolidate, rename, remove, or change proposed private
    signatures when evidence warrants it, updating this plan and every caller.
    The behavioral decisions above remain binding; a material change to them
    requires review. Avoid compatibility aliases for private helper changes.
12. Preserve POSIX shell architecture and executable modes. Edit canonical
    skills only; never create a repository `.agents/skills/` adapter tree or
    modify installed profile copies as an implementation shortcut.
13. Phase 1 replaces the catalog contract in place without a dual reader or
    migration. Define parser identity in one canonical code location and reuse
    it for strict metadata rendering/reading. Keep `catalog_schema=1` as specified
    by the incorporated plan; this is an incompatible contract replacement,
    not compatibility with existing schema-1 metadata. Profile/registry schema
    identities remain unchanged.
14. Within the new contract, equivalent `tools/` content reuses a retained
    generation and its original provenance. Management-skill-only or other
    non-`tools/` changes remain publication no-ops. Old fingerprints are not
    translated to new ones; generation names still derive from the digest.

### Operation matrix

This is the final target after both implementation phases. Every row retains
applicable path safety, local validation, ownership, locks, snapshots, and
compensation. Intermediate chunks explicitly retain some full checks.

| Operation | Catalog authority | Validation boundary |
| --- | --- | --- |
| Activation/dry-run, profile status/list/startup repair/redirect, ordinary AI-skill activities | Existing profile pins, including prior/target pins when needed | Lightweight references and profile-local checks; selected-source checks only when copying catalog inputs. Real activation also rechecks under lock. |
| Shim lifecycle | Existing invoking profile pin | Lightweight reference; selected input safety and staged-copy comparisons for materialized assets. |
| Profile create | Invoking profile pin; pinned jq/rg/Skopeo defaults | Lightweight reference, selected baseline inputs, and staged-copy checks. |
| Profile clone | Source profile pin and supported selection | Lightweight reference, selected source inputs, and staged-copy checks. |
| Profile sync | Explicit snapshot of registry current | Full chosen-generation validation before catalog-derived selection/staging and again under lock before commit; staged-copy and profile-local checks also apply. |
| Bootstrap/publication | Newly published or reused retained generation | Existing full publication/reuse checks adapted to `tools/`-only content; subsequent materialization uses reference and staged-copy checks. |
| Catalog verify | Current, previous when present, and active profile pin | Full integrity checks and existing remote image checks; not an audit of every retained generation. |
| Other direct catalog operations and admin catalog inspection | Existing operation-specific authority | Direct catalog-domain checks remain strong under the new contract. |
| Profile delete/global uninstall | Existing ownership and lifecycle authority | Shared profile resolution becomes lightweight; direct catalog checks and destructive ownership/journal rules remain intact. |

Strict registry parsing remains required wherever the existing record contract
needs it. Independence from unrelated payload damage does not imply tolerance
of malformed registry metadata, unsafe canonical parents, or missing required
pin entries. Sync's explicit full checks target the chosen current generation;
they do not add an audit of the old profile pin or registry previous.

## Verified implementation inventory

Original trust-planning baseline: source commit `549728e`; the original plan
records a clean worktree before it was added. Internal-consistency review at
`b29cd59` started from a clean worktree and spot-checked sync, activation,
materialization, reference, and verify boundaries. The originally reported
approximately seven-second timings are observations, not reproduced
measurements. The inventory below retains the original planning evidence;
implementation must recheck it, especially after Phase 1 changes the contract.

| Surface | Verified behavior and planned treatment |
| --- | --- |
| `lib/catalog/authority.sh` | Tree validation checks retained directory layouts and fully validates current/previous. Generation record validation performs payload validation and fingerprint comparison. Retain both; add separate reference helpers. |
| `lib/catalog/state.sh`, `lib/common/common.sh` | Reuse strict pin/name/fingerprint/commit, generation metadata, registry, text-file, and safe-path readers. Do not duplicate their parsers. |
| `lib/catalog/catalog.sh` | Owns full payload, tool/version metadata, and fingerprint logic. Retain full algorithms; reuse appropriate selected-file/version validators without invoking complete payload traversal. |
| `lib/profile/management.sh` | Installation context and candidate resolution each call tree validation; candidate validation invokes shim materialization and AI-skill validation. Activation repeats resolution after locks. Replace catalog work, retain active/prior/target engine and rollback checks. |
| `lib/profile/state.sh` | Already compares pin metadata without hashing the catalog. Consolidate canonical reference checks carefully; existing small fixtures contain metadata-only generation skeletons. |
| `lib/ai-skill/ai-skill.sh` | Context resolution, profile-core checks, and shim-bundle materialization contain full validators. Replace all profile-related catalog checks; retain skill-file hashes, bundle integrity, unsupported-kind policy, and exact link ownership. |
| `lib/shim/shim.sh`, `commands/shim.sh` | Context and under-lock authority checks fully validate generations. Materialization validation recursively diffs selected catalog versions. Split profile-local and staged-source checks; retain manifest fingerprints and staging/rollback. |
| `lib/install/profile.sh` | Shared materialization fully validates the generation; baseline selection validates the whole payload. Change these to reference and selected-input checks. Commands/libs are copied or archived wholesale into profiles. |
| `lib/install/lifecycle.sh` | Bootstrap directly validates its freshly published catalog. Create inherits the invoking pin; clone preserves the source pin. Activation and image-preparation paths reuse shared validators. Keep explicit bootstrap checks and all engine/activation transactions. |
| `lib/update/profile.sh` | Sync currently relies on shared context/materialization checks for full integrity and for registry globals. Make selected-generation checks and registry reads explicit before weakening shared helpers. Startup repair benefits from lightweight candidate resolution. |
| `lib/install/catalog.sh` | Publication, generation reuse/collision handling, rollback, and registry commit validation retain their full checks and original provenance behavior. |
| `lib/images/catalog.sh` | Verify explicitly calls tree and active-pin validation before image checks. Preserve this independent full-validation path. Refresh shares image helpers; do not unintentionally change it. |
| `lib/install/uninstall.sh`, `commands/admin.sh` | Consumers of shared profile resolvers; destructive ownership/journal checks remain intact. Admin status also directly renders catalog status and may retain full catalog inspection. Include regression coverage; do not broaden this task into their redesign. |
| `tests/lib/{catalog,profile-state,ai-skill-state}.sh` | Existing fingerprint, metadata/provenance, path/schema, collision, and rollback proofs. Reuse scenarios and keep inexpensive fixtures. |
| `tests/commands/{profile,shim,ai-skill,catalog,lifecycle}.sh` | Existing activation, inherited pins, shim policies, bundles, verify fixtures, bootstrap, create/clone, sync, and compensation scenarios. Extend these rather than creating a second lifecycle harness. |
| `tests/runtime-benchmark.sh`, `docs/testing.md` | Existing benchmark measures an installed profile, including activation dry-run. It does not measure edited checkout code until that code is materialized; use disposable fixture comparisons for this implementation. |
| Docs and canonical skills | Update root/child contexts, README, bootstrap/command guidance, and relevant canonical management skills. Root context/contributor/install-skill language implying ordinary shim operations adopt current catalog needs correction to match inspected code. |

Original plan discovery inspected `plans/notional`, `plans/wip`, and
`plans/complete`. The later request incorporates the catalog.conf-removal plan
into this authoritative plan. Related create/clone,
activation, catalog separation, completion, and performance plans cover other
changes or historical contracts. Do not resume or overwrite them. If a retained
plan's broad full-validation instruction would conflict with this change, add
a narrow cross-reference when implementing documentation; preserve its history.

The additional Phase 1 inventory from the incorporated plan is `catalog.conf`
(delete), `lib/catalog/{catalog,state,authority}.sh`, `lib/install/catalog.sh`,
generation-metadata consumers, `tests/lib/codec.sh`'s fingerprint vector, and
`tests/support.sh`'s copy-on-write probe. The review confirmed that publication
archives `catalog.conf tools`, fingerprinting enumerates both paths, and the
probe copies root `catalog.conf`. Phase 1 updates those producers and consumers
together. The table above describes pre-cutover behavior; its trust changes
apply to the new format after Phase 1, not to the removed layout.

### Proposed function contracts for human verification

These are concrete starting hypotheses for Chunk 2, not fixed private APIs.
Prefer existing modules over a new framework or mode flag. The bodies below
illustrate signatures only; actual dormant stubs must also implement the
diagnostic/result-clearing contract specified below before returning failure.

```sh
# lib/catalog/authority.sh: proposed new helpers
shimmy_catalog_reference_paths_resolve() { # <config-root>
  # Reuse root_paths_resolve; validate the fixed catalog directory chain.
  # Populate existing canonical path globals. Do not read payloads or registry.
  # Chunk 2: dormant stub returning failure; Chunk 3: real implementation.
  return 1
}

shimmy_catalog_generation_reference_read() { # <config-root> <generation>
  # Resolve canonical root; check fixed entries and generation.conf identity.
  # Success outputs: SHIMMY_CATALOG_REFERENCE_GENERATION, _ROOT,
  # _SOURCE_COMMIT, _CONTENT_FINGERPRINT. Metadata only, not rehashed content.
  return 1
}

shimmy_catalog_pin_resolve() { # <config-root> <catalog-pin>
  # Reuse pin_validate and generation_reference_read; compare commit/digest.
  # Publish the same reference outputs only after complete agreement.
  return 1
}

# lib/update/profile.sh: proposed new explicit sync boundary
shimmy_profile_sync_catalog_validate() { # <config-root> <catalog-pin>
  # Resolve the pin, call full generation_record_validate on the chosen root,
  # and compare full-validation results with the expected pin.
  return 1
}

# lib/shim/shim.sh: proposed new staging-only source comparison
shimmy_shim_materialization_source_validate() { # <profile-root> <generation-root>
  # Check canonical selected inputs and staged-copy consistency for the
  # profile's declared tools/versions. Do not hash the complete generation.
  return 1
}
```

For reference helpers: return 0 on success and nonzero on failure; use
`SHIMMY_CATALOG_AUTHORITY_ERROR` for a specific diagnostic; emit no success
stdout; clear reference result globals on entry/failure. Do not set
`SHIMMY_CATALOG_VALIDATED_GENERATION_*` or catalog health to imply full validation.
Use function-specific scratch variables so nested POSIX calls do not clobber
pin expectations or registry snapshots. Reference resolution must not overwrite
registry current/previous/provenance globals through unrelated metadata reads.

| Existing function/signature | Proposed reuse or modification |
| --- | --- |
| `shimmy_catalog_root_paths_resolve <config-root>` | Reuse beneath the fixed-path reference resolver. |
| `shimmy_catalog_pin_validate <pin>`, `shimmy_catalog_generation_metadata_read <file>`, `shimmy_catalog_registry_read <file>` | Reuse strict parsing; pin syntax alone is not reference resolution. |
| `shimmy_catalog_generation_record_validate <root> <generation>` | Retain full semantics, including support for a staged publication root that is not yet its final canonical generation directory. |
| `shimmy_catalog_tree_validate <config-root>` | Retain full catalog-domain semantics; remove ordinary profile reachability. |
| `shimmy_profile_candidate_resolve <config-root> <name>` | Replace tree validation with pin resolution; invoke profile-local materialization and bundle checks. Preserve outputs consumed by lifecycle functions. |
| `shimmy_profile_installation_context_resolve <config-root>` | Resolve installation/active state and reference paths; make any required registry read explicit. Preserve prior-active profile checks. |
| `shimmy_shim_materialization_validate <profile-root> <generation-root>` | Proposed final signature is `<profile-root>`; check local manifest/tool/version/config/wrapper consistency. Move catalog comparisons into the staging helper and update all callers atomically. |
| `shimmy_shim_context_resolve <config-root> <profile>`; `shimmy_shim_authority_revalidate` | Use lightweight pin resolution; retain active identity and exact manifest fingerprint rechecks. |
| `shimmy_ai_skill_profile_core_validate <manifest> <registry> <generation-root>` | Propose any simplified private arguments in Chunk 2; implement the change with all callers in Chunk 4. Resolve the pin through canonical config context, compare any supplied paths exactly, and retain manifest/bundle identities. No catalog hashing. |
| `shimmy_ai_skill_shims_bundle_materialize <input> <generation-root> <output>` | Use the input's generation/fingerprint and the canonical reference reader; validate only selected skill sources before copying. Retain rendered skill/bundle hashes. |
| `shimmy_ai_skill_context_resolve <config-root>`; `shimmy_profile_state_validate <manifest> <registry> <generation-root> <control-bundle> <shims-bundle>` | Reuse reference helpers; preserve bundle and state semantics. Where only a registry/root argument exists, derive config context and verify exact canonical path equality, or update private signatures/callers together. |
| `shimmy_profile_materialization_prepare <existing arguments>`; `shimmy_profile_baseline_render <generation-root>` | Retain materialization API unless concrete implementation needs a private adjustment. Resolve the pin once at the boundary; baseline reads only jq/rg/Skopeo selections and safe selected assets. |
| `shimmy_profile_sync_run <config-root> <name>` | Explicit registry snapshot/read plus full sync helper before staging and immediately before candidate commit under existing locks. |
| `shimmy_ai_skill_bundle_read`, `shimmy_profile_manifest_read`, selected version/image validators, wrapper/config renderers, lock and transaction helpers | Reuse for their current specific responsibilities; do not remove their hashes or safeguards merely because catalog hashes are removed elsewhere. |

## Unresolved

None. Private helper names and factoring are implementation hypotheses reviewed
in Chunk 2; they do not leave the behavioral contract open.

## Progress Checklist

Active stage: Phase 1 complete. Chunk 2 is not authorized.

- [x] Original planning: record confirmed objective/root and plan discovery.
- [x] Original planning: trace publication, profile, shim, AI-skill, sync, and verify boundaries.
- [x] Original planning: record corruption trade-off and function hypotheses.
- [x] Review consistency and incorporate catalog.conf removal as Phase 1.
- [x] Combined plan accepted and Chunk 1 implementation explicitly authorized.
- [x] Phase 1 / Chunk 1 — Atomic tools-only catalog contract and guidance cutover.
- [ ] Chunk 2 — Stub function signatures and document concrete contracts.
- [ ] Chunk 3 — Implement reference helpers and explicit full sync validation.
- [ ] Chunk 4 — Switch ordinary profile/shim/AI-skill validation to trusted pins.
- [ ] Chunk 5 — Complete create/clone materialization integration.
- [ ] Chunk 6 — Complete acceptance, performance evidence, and guidance audit.
- [ ] Final human acceptance; date and move the plan to `complete`.

Phase 1 implementation and its recorded acceptance verification are complete.
Phase 2 implementation, its performance measurements, and final combined-plan
acceptance remain pending.

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

## Phase 1 — Remove catalog.conf from catalog authority

### Incorporation and dependency

This phase incorporates both chunks of
`plans/complete/remove-catalog-conf.md`: the atomic contract transition and its
current-facing guidance updates. Its final broad acceptance and historical
guidance sweep are shared with Chunk 6. Keep code, fixtures, and current contract
documentation coherent at the Chunk 1 review gate; do not defer required
format documentation until final acceptance. Phase 2 begins only after explicit
acceptance of this cutover and authorization of Chunk 2.

## Chunk 1 — Atomic catalog contract and guidance cutover

### Goal

Remove root and retained `catalog.conf`, fingerprint `tools/` only, and render
strict self-describing generation metadata. Preserve full catalog validation
throughout this phase; relaxing ordinary profile validation belongs to Phase 2.

### Files

`catalog.conf` (delete), `lib/catalog/{catalog,state,authority}.sh`,
`lib/install/catalog.sh`, generation-metadata consumers including
`lib/profile/state.sh`, `tests/lib/{catalog,profile-state,codec,ai-skill-state}.sh`,
`tests/commands/{catalog,shim,lifecycle}.sh`, `tests/support.sh`, README.md,
CONTRIBUTING.md, BOOTSTRAP.md, root and affected child CONTEXT.md files,
current command/canonical skill guidance that describes the contract, and this
plan. Include newly discovered direct consumers in the same review unit.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high for the atomic format transition and fixture
inventory.

1. After explicit implementation authorization, move this authoritative plan
   from `notional` to `wip`, preserving unrelated changes and updating the
   incorporated plan's pointer. Its superseded execution sequence stays inert.
2. Define parser metadata in one canonical code location. Make source payload
   validation require safe `tools/` content and existing tool/skill invariants
   without requiring a root `catalog.conf`.
3. Enumerate only regular files under `tools/` for fingerprinting, preserving
   lexical ordering and executable-bit identity. Stage only tracked `tools/`
   from the clean attached `main` commit. Keep generation-name derivation intact.
4. Change generation metadata render/read together to the exact four-line
   contract above. Preserve strict text, key order, value, final-newline, and
   render/read checks. Keep metadata outside the fingerprint. Do not change
   registry/profile formats or add compatibility readers or migration.
5. Change full retained-layout validation to enforce exactly `generation.conf`
   and `tools/`. Preserve staged-publication-root support, safe paths, tool
   metadata/skill checks, metadata/name agreement, and recomputed fingerprint
   agreement. Full catalog callers remain strong after the cutover.
6. Preserve publication reuse, original provenance, registry no-op behavior,
   rollback, independent profile pins, transaction boundaries, and compensation
   within the new contract. Existing installations are not rewritten or used
   as fixtures; recreate disposable fixtures with the new format.
7. Update every direct metadata consumer and fixture in the same chunk,
   including minimal profile/skill fixtures, the codec fingerprint vector,
   publication archives, and the copy-on-write probe. Choose another stable
   tracked file for the probe. Remove root `catalog.conf` with these changes.
8. Preserve existing corruption proofs by mutating `generation.conf` for
   metadata invariants or a valid file under `tools/` for content-integrity
   invariants. Reuse one authoritative proof per invariant. Enforcing the exact
   retained layout is a format-integrity rule; do not add redundant tests solely
   asserting that the old filename/interface is rejected or absent.
9. Update current docs, bootstrap/install guidance, contexts, and canonical
   skills in this chunk to state the new payload, layout, parser metadata, and
   fingerprint scope. Explain the incompatible in-place replacement and fresh
   bootstrap requirement without modifying the user's installation. Add narrow
   historical cross-references where needed; preserve historical evidence.

### Verification checklist

- [x] New generation metadata round-trips exactly; publication and full
      validation agree on a tools-only fingerprint and generation name.
- [x] Equivalent tools content reuses original provenance; rollback, pins,
      collision/integrity checks, and compensation retain their contracts.
- [x] Codec vectors and inexpensive profile/skill fixtures use the new layout;
      source publication and bootstrap operate after the root-file removal.
- [x] `./tests/test.sh --group lib-catalog --group lib-profile-state --group lib-codec --group lib-ai-skill-state --group commands-catalog --group commands-shim --group commands-lifecycle-darwin-bootstrap --group commands-lifecycle-linux-bootstrap --group commands-lifecycle-isolated --group commands-lifecycle-linux-workflow --group commands-lifecycle-uninstall --group commands-lifecycle-control-sync --jobs 3` passes.
      The exact invocation passed all 36 selected tests in a disposable clean
      worktree containing the Chunk 1 patch; the source worktree's unrelated
      ignored content otherwise blocks lifecycle-template preparation.
- [x] Search/classify catalog.conf references across producers, consumers,
      fixtures, docs, and canonical skills; current behavior has no dependency
      on the removed file. Historical references remain labeled historical.
- [x] Current contract guidance agrees with code. Shell syntax, executable
      modes, inventory, generated artifacts where affected, and
      `git diff --check` pass.

### Human review gate

Review the atomic format change, tools-only identity, original-provenance reuse,
strong integrity checks, strict metadata, and incompatible existing-state
boundary. Accept Chunk 1 and authorize Chunk 2 separately. Do not run an
uninstall/bootstrap of the user's installation as part of this gate.

## Phase 2 — Trust established pins under the new catalog contract

Chunks 2–5 implement trusted references using Phase 1's metadata/layout; Chunk 6
provides acceptance for the combined plan. Performance baselines begin after
the format cutover so its effects are not attributed to trust changes.

## Chunk 2 — Function signatures and contracts

### Goal

Make the proposed function boundaries concrete enough for code-level human
review while preserving current runtime behavior.

### Files

`lib/catalog/authority.sh`, `lib/update/profile.sh`, `lib/shim/shim.sh`, relevant
child contexts if needed to identify temporary scaffolding, and this plan.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high for call/ownership review; ordinary care for
the small shell edits. No delegation is required.

1. Confirm Chunk 1 acceptance and explicit Chunk 2 authorization. The plan is
   already in `wip`; recheck worktree changes before touching source.
2. Add dormant POSIX helper stubs for the proposed new functions above.
   Document positional parameters, preconditions, success outputs, errors,
   global-state effects, and intended callers beside each stub.
3. Stubs return nonzero with a specific existing error convention; they must
   never report successful validation. No production caller invokes a stub.
   Mark them temporary and assign replacement to a subsequent chunk.
4. Record proposed signature changes to existing functions and the exact
   caller map in this plan. Do not alter live signatures or remove validation
   in this chunk. Consolidate obvious redundant proposed helpers now.
5. Capture a reproducible baseline after the accepted Phase 1 cutover and before
   trust changes: same-profile and cross-profile activation dry-runs in
   disposable existing test fixtures. Measure both a baseline catalog and an
   enlarged catalog whose added tools are unselected, holding profile selections
   and engine responses fixed. Build valid generations/pins for both sizes;
   exclude fixture setup from timings. Take at least three samples after a
   warmup per case and record times, medians, host, fixture recipe, and source
   identity. Do not use the user's live activation or installed profile.
6. Trace/count full-validator invocations as diagnostic evidence. Dry-run
   covers preflight only; exercise real activation in existing disposable
   fake-engine fixtures to cover under-lock paths, restoring the same initial
   active/profile state between runs. Keep diagnostics fixture-local; do not add
   a permanent test asserting internal function-call absence or a production
   instrumentation interface.

### Verification checklist

- [ ] Added stubs and edited shell files parse with `sh -n`; executable modes
      and normal source-loading behavior remain valid.
- [ ] Review confirms all stub callers are still dormant and existing entrypoint
      behavior is unchanged; no new test suite is needed for placeholder bodies.
- [ ] Baseline timings and validator-path evidence are recorded, with host,
      fixture, sample count, and any measurement limitation.
- [ ] `git diff --check` passes; only approved scaffolding/plan files changed.

### Human review gate

Review function names, arguments, outputs, error/state contracts, and caller
placement. Accept the sketch and authorize Chunk 3 separately. This acceptance
does not freeze private signatures or authorize all subsequent chunks.

## Chunk 3 — Reference helpers and explicit sync integrity

### Goal

Provide the lightweight reference API and make sync's full integrity checks
independent of shared profile validation before any such validation is relaxed.

### Files

`lib/catalog/{authority,state}.sh`, `lib/update/profile.sh`,
`tests/lib/{catalog,profile-state}.sh`, `tests/commands/{catalog,lifecycle}.sh`,
affected child contexts, and this plan. Preserve `lib/install/catalog.sh` and
`lib/images/catalog.sh` full semantics while exercising their callers.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high, especially POSIX global-state interactions and
sync transaction snapshots.

1. Implement the three reference helpers using existing validators. Do not
   enumerate generations, parse every tool, compute catalog hashes, create
   caches, or read current/previous payloads to resolve a profile pin.
2. Make required direct-entry/path checks explicit and return precise errors
   for unsafe paths, missing generation records, or metadata disagreement.
   Keep successful reference outputs distinct from full-validation outputs.
3. Implement and wire the explicit sync helper. Read registry current and its
   provenance explicitly, capture the pin/snapshot, and fully validate that
   generation before catalog-derived selection resolution or staging. Under
   the existing catalog/activation/profile/registry locks, explicitly reread
   registry metadata, check the original snapshots/current identity, then fully
   revalidate the same pin immediately before candidate commit.
4. Preserve current strong profile helpers for now. This intermediate chunk
   may temporarily have redundant sync checks; it must not lose integrity
   when Chunk 4 and Chunk 5 remove the implicit ones.
5. Preserve publication staging semantics: full generation validation accepts
   staged roots before publication. Do not force that API through a helper
   that only accepts already-retained canonical roots.
6. Add small positive reference-resolution coverage for current and older
   retained pins, independent control/catalog commits, and repeated reads
   without registry-global corruption. Reuse existing schema/path/provenance
   proofs; add only missing durable integrity/safety cases at the lowest cost.
7. Exercise sync's content mismatch and precommit-change safeguards with an
   existing disposable lifecycle fixture, preserving the prior manifest and
   selected assets on failure. Reuse existing hooks/fixtures where possible.

### Verification checklist

- [ ] Reference resolution returns the exact canonical root and recorded
      identity for an older pin, independently of current/previous payloads.
- [ ] Metadata/path safety and strict schema/provenance proofs remain intact;
      no stale successful reference outputs escape a failed resolution.
- [ ] Sync's chosen-generation integrity and under-lock snapshot guarantees
      hold with explicit validation; failed adoption preserves prior state.
- [ ] `./tests/test.sh --group lib-catalog --group lib-profile-state --group commands-catalog --group commands-lifecycle-control-sync --jobs 3` passes.
- [ ] Shell syntax, changed executable modes, inventory impact, and
      `git diff --check` pass.

### Human review gate

Review lightweight versus full contracts and sync placement. Explicitly accept
the coherent intermediate state, where ordinary callers are still strong,
before authorizing Chunk 4.

## Chunk 4 — Ordinary profile, shim, and AI-skill activities

### Goal

Make activation and ordinary profile/shim/AI-skill operations trust their pin
without losing profile-local validation or transactional safety.

### Files

`lib/profile/{management,state}.sh`, `lib/shim/shim.sh`,
`lib/ai-skill/ai-skill.sh`, `commands/shim.sh`, and mechanically required callers
in `lib/install/{profile,lifecycle}.sh`;
`tests/lib/{profile-state,ai-skill-state}.sh`,
`tests/commands/{profile,shim,ai-skill,lifecycle}.sh`, affected contexts, README,
and plan.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high; this is the main shared-consumer transition.

1. Replace tree/full-generation checks in profile installation/candidate,
   shim context/authority, and AI-skill context/core/materialization paths with
   reference resolution. Update all indirect callers, including repair,
   status/list, redirect, postcommit, and rollback validation paths.
2. Preserve fixed registry parsing when needed. Explicitly save/reload registry
   identity where nested state readers would overwrite it. Do not require a
   healthy unrelated current/previous payload for ordinary profile work.
3. Implement the staging-source helper and split materialization validation.
   Ordinary checks operate on the installed profile's own manifest, selected
   tool/version structure, canonical wrappers/configuration, executable files,
   and bundle input. Keep local consistency checks such as materialized
   `smoke.conf` against the profile's copied config.
4. Remove catalog `diff -r`/catalog tool-config comparisons from ordinary
   activation and command-entry validation. Invoke selected-source comparisons
   after staging copies and after image preparation where currently checked,
   including shared install callers, in this same chunk. Update every caller
   atomically with the local-validator signature change: ordinary/postcommit/
   rollback callers use local validation; staging callers use both local and
   selected-source validation. Leave no comparison gap for Chunk 5 to repair.
   Compare the actual transaction inputs, including rendered tool configuration;
   do not turn this into an implicit full catalog audit.
5. Retain safe selected source paths and file types before reads/copies or
   image preparation. Reuse specific validators; preserve selected subtree
   link/special-file safety without walking unrelated catalog tools.
6. Keep bundle file hashing, skill headers, declared inventory, recognized-link
   ownership, active-profile checks, manifest fingerprints, locks, workload
   guards, and compensation. The trusted catalog decision does not weaken these.
7. Extend existing fixtures to positively prove activation/dry-run, shim work,
   and skill reconciliation with an older retained pin and harmless out-of-band
   catalog content changes. Prove that valid modified selected catalog content
   can be materialized under the accepted trust policy, without rebasing the pin.
   Restore fixture content where later strong catalog checks need a pristine tree.
8. Update the changed contexts and README with the implemented trust boundary.
   Document create/clone as intentionally incomplete until Chunk 5 removes
   their remaining direct full checks.

### Verification checklist

- [ ] Same-profile recovery and cross-profile activation/dry-run succeed with
      trusted references; prior/target engine and rollback behavior is preserved.
- [ ] Shim policies/default/exact versions, staged-copy checks, smoke propagation,
      and AI-skill repair/link preservation remain operational under trusted pins.
- [ ] Profile-local malformed-state, unsafe-path, and transaction tests continue
      to protect their existing invariants; hashes outside catalog scope remain.
- [ ] Update metadata-only library fixtures minimally for required direct entries;
      do not replace them with expensive full publication fixtures.
- [ ] `./tests/test.sh --group lib-profile-state --group lib-ai-skill-state --group commands-profile --group commands-shim --group commands-ai-skill --group commands-lifecycle-control-sync --jobs 3` passes.
- [ ] Run affected bootstrap/create/clone lifecycle groups from Chunk 5 when
      changing shared install callers, keeping their intermediate state valid.
- [ ] Diagnostic call traces confirm ordinary paths use reference resolution;
      treat this as performance evidence, not a new negative-test invariant.
- [ ] Shell syntax, executable modes, inventory, and `git diff --check` pass.

### Human review gate

Review the exact safeguards retained, successful trusted-pin scenarios, and
activation timing change. Accept the documented partial lifecycle integration
and authorize Chunk 5 separately.

## Chunk 5 — Create/clone and shared materialization

### Goal

Finish pin inheritance through create/clone and materialization while preserving
bootstrap publication checks and explicit sync integrity.

### Files

`lib/install/{profile,lifecycle}.sh`, remaining shared consumers if required,
`tests/lib/catalog.sh`, `tests/commands/lifecycle.sh`, README, BOOTSTRAP.md,
installation/profile contexts, and this plan.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high for the create/clone/bootstrap transaction paths.

1. Replace the direct full-generation check in shared profile materialization
   with pin resolution. Remove whole-payload validation from baseline rendering;
   validate only the selected jq/rg/Skopeo defaults and inputs needed to copy them.
2. Preserve create's baseline reset, clone's supported source state, independent
   control provenance, binding choices, image preparation, activation, startup,
   and exact skill-link transactions. Neither operation adopts registry current.
3. Retain explicit bootstrap catalog creation/publication checks; ensure initial
   profile materialization can trust the generation they established. Retain
   the explicit sync checks from Chunk 3 despite shared-helper relaxation.
4. Retain the staged-copy integrations completed in Chunk 4 and add any
   selected-input safety checks previously supplied only by the full validators
   removed here. Remove any now-unused transitional stubs/helpers rather than
   keeping private compatibility paths.
5. Extend existing lifecycle scenarios to positively demonstrate create/clone
   inherit a retained pin after registry advancement and consume safe changed
   selected content under the accepted policy. Preserve all engine ownership,
   activation compensation, and deletion/uninstall safeguards.
6. Update bootstrap/install behavior documentation together with these changes.

### Verification checklist

- [ ] Create resets tool selection to the pinned baseline; clone preserves its
      supported source selection; both inherit the exact source catalog pin.
- [ ] Bootstrap still publishes a fully validated generation and compensates
      failed activation/materialization as before.
- [ ] Sync detects changed payload bytes in its chosen current generation;
      verify detects them in its documented inspected generations, despite all
      shared profile helpers now being lightweight.
- [ ] `./tests/test.sh --group lib-catalog --group commands-lifecycle-darwin-bootstrap --group commands-lifecycle-linux-bootstrap --group commands-lifecycle-isolated --group commands-lifecycle-linux-workflow --group commands-lifecycle-uninstall --group commands-lifecycle-control-sync --jobs 3` passes.
- [ ] Shell syntax, executable modes, inventory, and `git diff --check` pass.

### Human review gate

Review inherited trust across complete lifecycle flows, preserved bootstrap/sync
boundaries, and destructive-operation regressions. Authorize final acceptance
work only after accepting this chunk.

## Chunk 6 — Combined acceptance evidence and guidance audit

### Goal

Verify the complete boundary, quantify performance improvement, and leave
canonical guidance consistent with the implemented behavior.

### Files

README.md, CONTRIBUTING.md, BOOTSTRAP.md, root and affected child CONTEXT.md
files, `commands/README.md`, `docs/testing.md`, canonical
`plugins/shimmy/skills/{shimmy-install,shimmy-catalog}/SKILL.md`, relevant
retained-plan cross-references, tests only for acceptance gaps, and this plan.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high for the final call-site and safety audit;
medium for documentation and measurement reporting.

1. Audit every full-validator/fingerprint caller and every staged comparison.
   Classify catalog lifecycle/inspection, sync, test setup, source preflight,
   and ordinary profile consumers explicitly. Direct catalog status/tools/
   refresh/rollback and admin catalog inspection remain outside this change.
2. Preserve `catalog verify` full current/previous/active-pin validation and
   remote image behavior. Extend its existing offline fixture to demonstrate
   local integrity failure for a well-formed payload byte change, using the
   established integrity contract and existing scenario where possible.
3. Document accepted delayed corruption detection, inherited pins, source versus
   catalog commits, and the meaning/scope of lightweight profile health. Correct
   stale language that ordinary shim operations adopt registry current.
   Audit Phase 1's tools-only payload/fingerprint and expanded metadata guidance
   at the same time, including command/help text and narrow historical-plan
   cross-references. This completes the incorporated plan's acceptance sweep.
4. Rerun the Chunk 2 timing procedure against the final code with the same
   fixture recipes, catalog sizes, selections, host, and engine responses.
   Materialize the appropriate baseline/final control code into disposable
   fixtures; do not reuse a fixture still running baseline controls. Report
   before/after medians, sample count, removed full-validation work, and
   remaining profile/engine costs. Use the two catalog sizes plus call traces
   to assess unrelated-catalog scaling separately from end-to-end latency.
   Attribute these results to Phase 2; both sides use Phase 1's new format.
   No arbitrary wall-clock threshold becomes a flaky test.
5. Use the existing runtime benchmark only when its installed target actually
   contains this implementation and its use is authorized. Do not present an
   unchanged installed-profile benchmark as evidence for edited checkout code.
6. Run the full default bounded suite once at the final integration gate. Rerun
   only failures or checks affected by subsequent edits. Record platform or
   live-environment limitations explicitly; fake engines verify transaction
   boundaries, not claims about native container execution.
7. Do not modify the user's installation, activate a real profile, commit, or
   publish as part of acceptance. If live container checking is needed, use
   existing approved wrappers and non-mutating version/help calls only.
   Disposable test-profile materialization, fixture publication, and simulated
   activation are permitted test setup, distinct from changing the user's
   installation or live engine. Fake-engine timings measure validation overhead,
   not native engine transition time.

### Verification checklist

- [ ] Full call-site audit matches the operation matrix and includes indirect
      AI-skill, baseline, status, and materialization consumers.
- [ ] Positive trusted-pin workflows and existing integrity/ownership/rollback
      proofs pass; there is one authoritative proof per negative invariant.
- [ ] `./tests/test.sh --jobs 3` passes, including syntax, executable-mode,
      canonical inventory, and generated launcher/runtime checks.
- [ ] Before/after performance evidence is recorded against comparable code and
      fixtures; remaining costs and any `[~]` limitations are explicit.
- [ ] Canonical docs/skills agree semantically; no generated adapters or installed
      copies were edited. `git diff --check` passes.
- [ ] Final review reports changes, tests, failures, uncertainties, remaining
      risks, lessons, and a distinct partial-verification list (or `None`).

### Human review gate

Request explicit final acceptance. Do not mark the plan complete merely because
tests pass. After acceptance, add `Completed: YYYY-MM-DD` immediately below the
title and move the single authoritative file from `wip` to `complete`, without
overwriting any existing file.

## Risk register

| Risk | Consequence | Handling |
| --- | --- | --- |
| Partial catalog format cutover | Producers, readers, fingerprints, or fixtures disagree. | Keep all direct consumers and current contract docs together in Chunk 1; build reference helpers only afterward. |
| Existing installation uses the old contract | New controls cannot interpret old generation metadata/layout. | No migration/dual reader; preserve existing installs during this work and document separately authorized removal with old controls and fresh bootstrap. |
| Format and trust effects are mixed in timings | Reported speedup has an unclear cause. | Capture Phase 2 baseline after Phase 1; compare equal catalog sizes/fixtures under the same new format. |
| Out-of-band catalog edits after validation | Create/clone/shim may copy modified content under the original fingerprint. | Preserve the prior plan's recorded trade-off; document trusted immutability and limited sync/verify detection scope. |
| Hidden full validation remains | Activation or create remains slow despite visible call removal. | Complete caller inventory, operation traces, and comparative timings; inspect AI-skill and baseline paths. |
| Shared relaxation silently weakens sync/verify | Corrupt content can be adopted at a promised integrity boundary. | Wire explicit sync checks first; preserve verify's independent full path and its regression proof. |
| Removing global traversal also removes selected path safety | A copied/read path may escape or reference unsafe file types. | Validate canonical reference chain and selected source paths/subtrees at the consuming boundary. |
| Local checks accidentally become source comparisons again | Ordinary operations still depend on catalog payload bytes. | Separate profile-local and staged-copy validation; review call placement. |
| POSIX globals are clobbered | Wrong pin/current metadata reaches a transaction. | Function-specific scratch names, explicit snapshots, distinct reference outputs, and repeated-read coverage. |
| Older pin is treated as registry current | Profiles change behavior or become unusable after publication. | Positive older-pin inheritance/use tests; keep control and catalog commits independent. |
| Destructive consumers lose ownership checks | Delete/uninstall could remove unrelated state. | Change catalog trust only; preserve local ownership/journal checks and run lifecycle regression groups. |
| Misleading health or performance claims | Users infer content integrity or speedups never measured. | Document reference health, verify scope, actual benchmark target, sample data, and remaining latency. |
| Large new test fixtures negate development gains | Slow suite and repeated invariant proofs. | Extend existing scenarios, keep metadata fixtures small, use default bounded parallelism. |

## Lessons learned

### Initial

- The hot path contains more full-validation calls than the two initially
  observed calls; shared AI-skill and materialization paths matter.
- Registry current/previous validity is broader than a profile's retained-pin
  dependency. Retained generation existence is not registry-pointer membership.
- Create and shim already use inherited/existing pins in the inspected code;
  some documentation overstates their adoption behavior.
- Full generation validation also accepts publication staging paths. A new
  canonical-reference helper must not break that distinct lifecycle.
- Hashing catalog bytes, hashing local skill bundles, and fingerprinting a
  manifest for commit authority have different purposes. Scope removal precisely.
- Existing installed controls are independent materializations; checkout changes
  do not automatically reach them or an installed-profile benchmark.

### Internal-consistency review (before implementation)

- Incorporated catalog.conf removal as an initial atomic phase, preserving its
  tools-only identity, expanded metadata, strict format, and no-migration scope.
- Clarified create's baseline reset, clone's selection inheritance, and sync's
  chosen-generation scope; supplied the operation matrix used by acceptance.
- Kept private signature changes and affected staging comparisons together in
  Chunk 4. Chunk 2 only records contracts and adds dormant new helpers.
- Separated dry-run measurements from simulated under-lock activation and
  required two catalog sizes for comparable before/after scaling evidence.
- This was a document-only review. No implementation chunk or runtime
  acceptance check was executed; original planning claims remain historical.

### Chunk 1 — Atomic catalog contract and guidance cutover

- Parser identity now has one implementation source in `lib/catalog/catalog.sh`;
  strict generation metadata renders and reads the exact four-line format,
  schema, provenance, and tools-only fingerprint contract.
- Publication archives tracked `tools/` only. Fingerprinting enumerates regular
  files below `tools/` in lexical order and retains executable-mode identity.
  Retained generations admit exactly `generation.conf` and `tools/` while full
  payload, metadata/name, and recomputed-fingerprint validation remains strong.
- Equivalent tools content still reuses retained metadata and original
  provenance. Existing rollback, collision, corrupt-current recovery, profile
  pin, bootstrap, sync, shim, and compensation scenarios passed unchanged in
  purpose under the new layout.
- Content-integrity fixtures now mutate a valid tool skill, the fixed codec
  vector covers tools-only identity, and minimal profile metadata fixtures
  round-trip the expanded generation metadata exactly. The copy-on-write probe
  uses tracked `CONTEXT.md`.
- Current README, bootstrap, command, context, contributor, reusable project
  prompt, and canonical catalog-skill guidance describe the incompatible
  tools-only contract and fresh-bootstrap boundary. Completed plans retain
  historical references; the unrelated notional completion plan was aligned
  so it will not recreate the removed file.
- The exact 12-group Chunk 1 command passed all 36 selected tests. Additional
  `lib-runtime` syntax/mode coverage passed all 12 tests, and
  `tests/context-tree.sh` passed inventory/context validation. The first
  source-worktree attempt exposed unrelated ignored content in lifecycle
  fixture copying; rerunning from a disposable clean worktree preserved that
  user-owned content and produced the required acceptance evidence.
- No Phase 2 helper or trust-boundary behavior changed. Chunk 2 remains gated
  on explicit acceptance of this cutover.

Add a subsection for each executed chunk, including durable findings, changed
function hypotheses, verification results, and implications for future chunks.

## Session bootstrap

1. Read AGENTS.md, CONTRIBUTING.md, root CONTEXT.md, this plan's decisions,
   progress, lessons, and active chunk. Read child contexts for the chunk's
   changed paths plus its target files.
2. Inspect worktree state. Preserve unrelated changes. Discover this plan by
   its lifecycle location; do not create a duplicate copy.
3. Phase 1 is complete: the authoritative plan remains in `wip` because the
   trusted-pin work is pending. Do not execute the incorporated plan's old chunk
   sequence separately; this combined plan owns the work. Await explicit Chunk 2
   authorization before making Phase 2 changes.
4. Phase 1 preserves full validation while changing the catalog contract.
   Phase 2 keeps full validation at publication/bootstrap, explicit sync, and
   verify, while switching ordinary profile work to lightweight references.
   Preserve selected path, profile-local, engine, ownership, and transaction
   safeguards. Preserve the recorded corruption trade-off and operation-matrix
   exceptions; document review itself grants no execution authority.
5. Treat Chunk 2 APIs as revisable private implementation hypotheses. Update
   this plan and all callers for refinements; seek direction only for material
   behavioral divergence. Phase 1 owns the atomic metadata/layout/fingerprint
   change; Phase 2 must not introduce further format changes, a cache, public
   mode, language rewrite, or generated skill adapters.
6. Execute only the authorized chunk, verify it, update progress and lessons,
   surface every partial item, and stop at its human review gate.
