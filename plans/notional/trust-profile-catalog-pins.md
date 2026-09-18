# Trust established profile catalog pins

## Objective

Remove full catalog-tree validation and catalog fingerprint recomputation from
ordinary profile activities. Trust the generation identity established by
bootstrap/publication or reconfirmed by `profile sync`, and inherited by
profile create/clone. Retain lightweight reference checks, profile-local
validation, and operation-specific transaction safeguards.

Success means:

- Activation, including dry-run and its under-lock recheck, resolves retained
  pins without traversing or hashing complete catalog payloads.
- Profile create/clone, shim activities, and AI-skill activities use the same
  trust boundary, including indirect shared-helper calls.
- `profile sync` explicitly validates the selected generation's complete
  contents before adoption, even when shared profile helpers become lightweight.
- Bootstrap/publication and `catalog verify` retain full integrity checks.
- A profile can use a retained pin older than registry current/previous;
  unrelated retained payload damage does not prevent ordinary profile work.
- Existing schemas, generation names, pin inheritance, locking, engine policy,
  manifest-last commits, rollback, and skill-link ownership remain intact.
- Comparable before/after measurements demonstrate the activation improvement;
  remaining latency is reported separately from removed catalog work.

The user explicitly accepts that out-of-band changes to a previously validated
catalog may be consumed by create or shim operations without a generation-wide
fingerprint mismatch being detected. Full inspection or sync detects such
changes later, within the generations those operations inspect.

Exclusions: validation caches, validation timestamps/markers, schema migration,
new public commands or flags, changes to generation fingerprints, filesystem
immutability enforcement, language rewrites, Podman provisioning changes, image
updates, and unrelated profile performance optimization. This work does not
redefine catalog status/tools/refresh/rollback behavior or global uninstall
ownership rules. Their direct catalog-domain checks remain as implemented.

Planning inputs were confirmed by the user: this objective and the existing
repository-relative planning root `plans`. This new plan is authoritative at
`plans/notional/trust-profile-catalog-pins.md`. No implementation is authorized.

## Target layout and terminology

The installed layout remains:

```text
catalogs/default/
  registry.conf
  generations/sha256-<64 lowercase hex>/
    catalog.conf
    generation.conf
    tools/
profiles/<name>/
  install-manifest.txt
  tools/
  ai-skills/
  ...
```

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

Reference work is bounded by canonical path depth and fixed metadata size. Work
on selected tools or installed profile assets may scale with that selection;
it must not grow with unrelated retained generations or all catalog tools.

## Recorded design decisions

1. Ordinary profile activities trust the established catalog pin. No persistent
   cache or additional certificate of previous validation is necessary.
2. Publication/bootstrap establish identity. Among profile lifecycle operations,
   only `profile sync` performs full catalog integrity validation. Create
   inherits the invoking profile's pin and baseline tool selection; clone
   inherits the source pin and supported materialization. Shim operations
   continue using the existing pin and do not adopt registry current.
3. Lightweight checks retain normalized absolute canonical paths, non-symlink
   parent/direct-entry checks, generation existence and name syntax, and exact
   pin/generation-metadata provenance and fingerprint agreement. Check regular
   `catalog.conf` and `generation.conf` and a regular `tools/` directory without
   walking `tools/` or enumerating unrelated generations.
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
10. No change to public command grammar or record formats. Profile status
    health describes checked reference/profile consistency, not a new claim
    that all catalog bytes were audited. Clarify that meaning in documentation
    while preserving existing structured output contracts.
11. The first chunk is deliberately a low-fidelity function-contract pass.
    Later chunks may consolidate, rename, remove, or change proposed private
    signatures when evidence warrants it, updating this plan and every caller.
    The behavioral decisions above remain binding; a material change to them
    requires review. Avoid compatibility aliases for private helper changes.
12. Preserve POSIX shell architecture and executable modes. Edit canonical
    skills only; never create a repository `.agents/skills/` adapter tree or
    modify installed profile copies as an implementation shortcut.

## Verified implementation inventory

Planning baseline: source commit `549728e`; worktree was clean before this plan
was added. The user's approximately seven-second call timings are reported
observations, not measurements reproduced during planning. This inventory is
a verified baseline, not permission to ignore newly discovered dependencies.

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

Plan discovery inspected `plans/notional`, `plans/wip`, and `plans/complete`.
No existing plan unambiguously owns this objective. Related create/clone,
activation, catalog separation, completion, and performance plans cover other
changes or historical contracts. Do not resume or overwrite them. If a retained
plan's broad full-validation instruction would conflict with this change, add
a narrow cross-reference when implementing documentation; preserve its history.

### Proposed function contracts for human verification

These are concrete starting hypotheses for Chunk 1, not fixed private APIs.
Prefer existing modules over a new framework or mode flag.

```sh
# lib/catalog/authority.sh: proposed new helpers
shimmy_catalog_reference_paths_resolve() { # <config-root>
  # Reuse root_paths_resolve; validate the fixed catalog directory chain.
  # Populate existing canonical path globals. Do not read payloads or registry.
  # Chunk 1: dormant stub returning failure; Chunk 2: real implementation.
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
| `shimmy_ai_skill_profile_core_validate <manifest> <registry> <generation-root>` | Keep or simplify private arguments in Chunk 1; resolve the pin through canonical config context, compare any supplied paths exactly, and retain manifest/bundle identities. No catalog hashing. |
| `shimmy_ai_skill_shims_bundle_materialize <input> <generation-root> <output>` | Use the input's generation/fingerprint and the canonical reference reader; validate only selected skill sources before copying. Retain rendered skill/bundle hashes. |
| `shimmy_ai_skill_context_resolve <config-root>`; `shimmy_profile_state_validate <manifest> <registry> <generation-root> <control-bundle> <shims-bundle>` | Reuse reference helpers; preserve bundle and state semantics. Where only a registry/root argument exists, derive config context and verify exact canonical path equality, or update private signatures/callers together. |
| `shimmy_profile_materialization_prepare <existing arguments>`; `shimmy_profile_baseline_render <generation-root>` | Retain materialization API unless concrete implementation needs a private adjustment. Resolve the pin once at the boundary; baseline reads only jq/rg/Skopeo selections and safe selected assets. |
| `shimmy_profile_sync_run <config-root> <name>` | Explicit registry snapshot/read plus full sync helper before staging and immediately before candidate commit under existing locks. |
| `shimmy_ai_skill_bundle_read`, `shimmy_profile_manifest_read`, selected version/image validators, wrapper/config renderers, lock and transaction helpers | Reuse for their current specific responsibilities; do not remove their hashes or safeguards merely because catalog hashes are removed elsewhere. |

## Unresolved

None. Private helper names and factoring are implementation hypotheses, with a
dedicated first review chunk; they do not leave the behavioral contract open.

## Progress Checklist

Active stage: PLAN / initial human review. No implementation chunk has started.

- [x] Confirm objective and `plans` root; inspect all lifecycle directories.
- [x] Trace publication, profile, shim, AI-skill, sync, and verify boundaries.
- [x] Record accepted corruption trade-off and concrete function hypotheses.
- [ ] Initial plan accepted and Chunk 1 implementation explicitly authorized.
- [ ] Chunk 1 — Stub function signatures and document concrete contracts.
- [ ] Chunk 2 — Implement reference helpers and explicit full sync validation.
- [ ] Chunk 3 — Switch ordinary profile/shim/AI-skill validation to trusted pins.
- [ ] Chunk 4 — Complete create/clone materialization integration.
- [ ] Chunk 5 — Complete acceptance, performance evidence, and guidance audit.
- [ ] Final human acceptance; date and move the plan to `complete`.

No partial verification items at planning time. Implementation tests and
performance measurements have not been run.

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

## Chunk 1 — Function signatures and contracts

### Goal

Make the proposed function boundaries concrete enough for code-level human
review while preserving current runtime behavior.

### Files

`lib/catalog/authority.sh`, `lib/update/profile.sh`, `lib/shim/shim.sh`, relevant
child contexts if needed to identify temporary scaffolding, and this plan.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high for call/ownership review; ordinary care for
the small shell edits. No delegation is required.

1. Move this plan from `notional` to `wip` only after explicit implementation
   authorization. Recheck worktree changes before touching source.
2. Add dormant POSIX helper stubs for the proposed new functions above.
   Document positional parameters, preconditions, success outputs, errors,
   global-state effects, and intended callers beside each stub.
3. Stubs return nonzero with a specific existing error convention; they must
   never report successful validation. No production caller invokes a stub.
   Mark them temporary and assign replacement to a subsequent chunk.
4. Record proposed signature changes to existing functions and the exact
   caller map in this plan. Do not alter live signatures or remove validation
   in this chunk. Consolidate obvious redundant proposed helpers now.
5. Capture a reproducible baseline before functional changes: same-profile and
   cross-profile activation dry-runs in disposable existing test fixtures,
   fixed catalog generations/profile selections, and at least three samples
   after a warmup. Record elapsed times and fixture/source identity. Avoid
   using the user's live activation or rebuilding their installed profile.
6. Trace/count full-validator invocations as diagnostic evidence, including
   preflight and under-lock paths. Keep diagnostics fixture-local; do not add
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
placement. Accept the sketch and authorize Chunk 2 separately. This acceptance
does not freeze private signatures or authorize all subsequent chunks.

## Chunk 2 — Reference helpers and explicit sync integrity

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
   provenance explicitly, capture the pin/snapshot, fully validate that chosen
   generation before staging, and fully revalidate the same pin after the
   existing catalog/activation/profile/registry locks and snapshot checks.
4. Preserve current strong profile helpers for now. This intermediate chunk
   may temporarily have redundant sync checks; it must not lose integrity
   when Chunk 3 removes the implicit ones.
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
before authorizing Chunk 3.

## Chunk 3 — Ordinary profile, shim, and AI-skill activities

### Goal

Make activation and ordinary profile/shim/AI-skill operations trust their pin
without losing profile-local validation or transactional safety.

### Files

`lib/profile/{management,state}.sh`, `lib/shim/shim.sh`,
`lib/ai-skill/ai-skill.sh`, `commands/shim.sh`, and mechanically required callers
in `lib/install/{profile,lifecycle}.sh`; `tests/lib/ai-skill-state.sh`,
`tests/commands/{profile,shim,ai-skill}.sh`, affected contexts, README, and plan.

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
   after staging copies, including shared install callers where signatures
   change. Do not turn them into an implicit full catalog audit.
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
   Document create/clone as intentionally incomplete until Chunk 4 removes
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
- [ ] Diagnostic call traces confirm ordinary paths use reference resolution;
      treat this as performance evidence, not a new negative-test invariant.
- [ ] Shell syntax, executable modes, inventory, and `git diff --check` pass.

### Human review gate

Review the exact safeguards retained, successful trusted-pin scenarios, and
activation timing change. Accept the documented partial lifecycle integration
and authorize Chunk 4 separately.

## Chunk 4 — Create/clone and shared materialization

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
   the explicit sync checks from Chunk 2 despite shared-helper relaxation.
4. Complete all staged-copy helper integrations and selected source safety
   checks. Remove any now-unused transitional stubs/helpers rather than keeping
   private compatibility paths.
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
- [ ] Sync and explicit verify still detect changed payload bytes despite all
      shared profile helpers now being lightweight.
- [ ] `./tests/test.sh --group lib-catalog --group commands-lifecycle-darwin-bootstrap --group commands-lifecycle-linux-bootstrap --group commands-lifecycle-isolated --group commands-lifecycle-linux-workflow --group commands-lifecycle-uninstall --group commands-lifecycle-control-sync --jobs 3` passes.
- [ ] Shell syntax, executable modes, inventory, and `git diff --check` pass.

### Human review gate

Review inherited trust across complete lifecycle flows, preserved bootstrap/sync
boundaries, and destructive-operation regressions. Authorize final acceptance
work only after accepting this chunk.

## Chunk 5 — Acceptance evidence and guidance audit

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
4. Rerun the Chunk 1 timing procedure against the final code with the same
   disposable state and workload. Report before/after medians, sample count,
   removed full-validation work, and remaining profile/engine costs. Demonstrate
   that unrelated catalog growth no longer drives activation validation time.
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
| Out-of-band catalog edits after validation | Create/shim may copy modified content under the original fingerprint. | Explicitly accepted by the user; document trusted immutability and sync/verify detection boundaries. |
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

Add a subsection for each executed chunk, including durable findings, changed
function hypotheses, verification results, and implications for future chunks.

## Session bootstrap

1. Read AGENTS.md, CONTRIBUTING.md, root CONTEXT.md, this plan's decisions,
   progress, lessons, and active chunk. Read child contexts for the chunk's
   changed paths plus its target files.
2. Inspect worktree state. Preserve unrelated changes. Discover this plan by
   its lifecycle location; do not create a duplicate copy.
3. Current state is initial plan review; implementation has not begun. Await
   explicit Chunk 1 authorization. On authorization, move the plan to `wip`
   before adding dormant signatures.
4. Keep full catalog validation at publication/bootstrap, explicit sync, and
   verify; keep ordinary profile work on lightweight trusted references.
   Preserve selected path, profile-local, engine, ownership, and transaction
   safeguards. Accepted out-of-band corruption risk must not be reopened as a
   reason to restore full checks everywhere.
5. Treat Chunk 1 APIs as revisable private implementation hypotheses. Update
   this plan and all callers for refinements; seek direction only for material
   behavioral divergence. Do not introduce a cache, schema change, public mode,
   language rewrite, or generated skill adapters.
6. Execute only the authorized chunk, verify it, update progress and lessons,
   surface every partial item, and stop at its human review gate.
