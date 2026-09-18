# Remove catalog.conf from catalog authority

> Incorporated into [Simplify catalog authority and trust established profile
> pins](../notional/trust-profile-catalog-pins.md), Phase 1 / Chunk 1, with the
> final acceptance sweep in Chunk 6. The combined plan is authoritative. This
> document is retained as historical design input; its progress checklist and
> execution gates below are superseded. Its `wip` location does not authorize
> implementation, and no chunk is recorded as completed here. Update this link
> when the authoritative plan moves lifecycle directories.

## Objective

Remove `catalog.conf` from both the repository root and retained catalog
generations. Redefine the source catalog payload as `tools/` only, and redefine
retained generation layout as `generation.conf` plus `tools/`.

Success means:

- `catalog_content_fingerprint` is computed from `tools/` only, with the
  existing deterministic file ordering and executable-bit identity rules.
- Catalog parser metadata (`catalog_format`, `catalog_schema`) is no longer a
  payload file and no longer contributes to `catalog_content_fingerprint`.
- Retained generations remain immutable and self-describing through
  `generation.conf`.
- `registry.conf` remains the mutable current/previous selector over immutable
  generations.
- Profile pins, rollback, publication reuse, and control-plane separation keep
  their current semantics.
- The source repository no longer needs or validates a root `catalog.conf`.
- The installed retained-generation layout rejects `catalog.conf` and accepts
  only `generation.conf` and `tools/`.

Exclusions:

- no change to public command names or flags;
- no new catalog name, selector, or external catalog source;
- no profile-manifest format change;
- no migration or compatibility reader for historical retained layouts unless a
  later review explicitly adds one;
- no change to the rule that `generation.conf` stays outside the fingerprint;
- no change to Podman, profile activation, engine ownership, or tool runtime
  architecture.

This plan authorizes no implementation. Acceptance of one chunk does not
authorize later chunks.

## Target layout and terminology

After this change, use these terms consistently:

- **Catalog payload:** the source-authored catalog content whose bytes determine
  `catalog_content_fingerprint`. After the change this is `tools/` only.
- **Catalog parser metadata:** `catalog_format` and `catalog_schema`. After the
  change this is implementation-owned metadata rendered into `generation.conf`,
  not a payload file.
- **Generation metadata:** the retained per-generation metadata file
  `generation.conf`, containing parser metadata plus provenance.
- **Catalog content fingerprint:** the SHA-256 digest over `tools/` only.
- **Generation name:** `sha256-<hex>` derived from `catalog_content_fingerprint`.

Target source and installed layouts:

```text
<repo>/
  tools/

<config>/catalogs/default/
  registry.conf
  generations/
    sha256-<64 lowercase hex>/
      generation.conf
      tools/
```

Target `generation.conf` contract:

```text
catalog_format=shimmy-catalog
catalog_schema=1
catalog_source_commit=<40 lowercase hex>
catalog_content_fingerprint=sha256:<64 lowercase hex>
```

Order matters: readers and renderers should enforce an exact deterministic byte
format, as current metadata readers already do.

## Recorded design decisions

1. Treat `catalog.conf` as removable parser metadata, not durable payload
   content. After the cutover, the catalog payload is `tools/` only.
2. The reduced fingerprint scope is intentional: `catalog_content_fingerprint`
   must represent tool payload content only, not parser metadata.
3. Keep parser metadata out of the fingerprint. `generation.conf` remains
   outside fingerprint scope because it contains the fingerprint and provenance.
4. Preserve the current authority split: immutable generation metadata stays in
   `generation.conf`; mutable current/previous selection stays in `registry.conf`;
   profile pins remain independent of later publication or rollback.
5. Retained generations must remain self-describing. Even without a root
   `catalog.conf`, `generation.conf` must carry `catalog_format` and
   `catalog_schema` so a retained generation can be interpreted without source
   checkout context.
6. Source publication should stage only tracked `tools/` content from the clean,
   attached `main` commit.
7. Replace the current contract in place. Do not keep a dual source layout or a
   compatibility retained-generation layout by default. If historical state must
   be supported, that requires a separate reviewed migration decision.
8. Preserve publication reuse semantics: equivalent `tools/` content across
   later commits reuses the retained generation and its original generation
   metadata. Management-skill-only changes and other non-`tools/` changes remain
   publication no-ops.
9. Preserve deterministic metadata rendering. `generation.conf` readers must
   reject extra keys, missing keys, reordered keys, malformed values, and
   unterminated or non-text files just as strictly as current metadata readers.
10. Keep POSIX shell architecture, existing file ownership boundaries, and
    canonical skill handling unchanged. Do not create repository `.agents` skill
    adapters or change installed profile copies as a planning shortcut.
11. Because this is one schema/layout transition, implementation Chunk 1 is
    intentionally broad and atomic across source, retained layout, and direct
    consumers. Avoid temporary intermediate states that leave the repository or
    test suite internally inconsistent.

## Verified implementation inventory

Planning baseline established from inspected source on 2026-09-18. This is a
verified baseline, not permission to ignore newly discovered dependencies.

| Surface | Verified behavior and planned treatment |
| --- | --- |
| `catalog.conf` | Root file currently contains only `catalog_format=shimmy-catalog` and `catalog_schema=1`; no other repository payload metadata lives there. Remove it. |
| `lib/catalog/catalog.sh` | Payload fingerprinting currently hashes `catalog.conf` and `tools/`; payload validation requires a regular root `catalog.conf` with only `catalog_format` and `catalog_schema`. Refactor to validate `tools/` directly and fingerprint `tools/` only. |
| `lib/catalog/state.sh` | Owns generation-name rendering, registry render/read, and generation metadata render/read. Extend generation metadata format to include parser metadata while keeping exact byte-deterministic validation. |
| `lib/install/catalog.sh` | Publication stages tracked `catalog.conf` and `tools/`, computes the fingerprint, then writes `generation.conf`. Change staging to `tools/` only and synthesize the expanded generation metadata. |
| `lib/catalog/authority.sh` | Retained-generation validation currently allows exactly `catalog.conf`, `generation.conf`, and `tools/`. Change the accepted layout to `generation.conf` plus `tools/` and keep full payload validation/fingerprint comparison strong. |
| `lib/profile/state.sh` | Profile-state validation compares profile pin metadata against `generation.conf`. It does not require `catalog.conf` directly, so it should mainly need updated generation-metadata readers. |
| `tests/lib/catalog.sh` | Covers payload validation, lifecycle publication, no-op reuse, rollback, legacy-content rejection, and corruption by editing `catalog.conf`. Update fixtures and corruption proofs to target the new retained layout and metadata contract. |
| `tests/lib/profile-state.sh` | Builds minimal retained generations by rendering `registry.conf` and `generation.conf` directly. Update the metadata helper expectations here. |
| `tests/lib/codec.sh` | Contains a fixed fingerprint vector that currently depends on `catalog.conf`. Replace it with a `tools/`-only vector. |
| `tests/support.sh` | Copy-on-write probe currently uses `catalog.conf` as the probe source. Point it at another stable repository file. |
| `tests/lib/ai-skill-state.sh`, `tests/commands/{catalog,shim,lifecycle}.sh` | Read or compare `generation.conf` bytes. They will need metadata-format updates but should not require root payload-file changes. |
| `README.md`, `CONTRIBUTING.md`, `CONTEXT.md`, `lib/catalog/CONTEXT.md`, `lib/install/CONTEXT.md` | Current documentation says the catalog payload is `catalog.conf` plus `tools/` and retained generations contain `catalog.conf`, `generation.conf`, and `tools/`. Update to the new contract in the same reviewable scope as the code change or the immediate follow-up chunk. |

No inspected source path requires `catalog.conf` for anything other than
payload validation, staging, fingerprint scope, retained layout validation, or
supporting tests/docs.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Atomic catalog contract cutover
- [ ] Chunk 2 — Documentation, acceptance sweep, and historical guidance alignment

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

## Chunk 1 — Atomic catalog contract cutover

### Goal

Implement the schema/layout transition that removes `catalog.conf` from source
and retained generations, expands `generation.conf` to carry parser metadata,
and updates all direct code and test consumers required to leave the repository
internally coherent.

### Files

Primary change surface:

- `<repo>/catalog.conf` (delete)
- `<repo>/lib/catalog/catalog.sh`
- `<repo>/lib/catalog/state.sh`
- `<repo>/lib/catalog/authority.sh`
- `<repo>/lib/install/catalog.sh`
- `<repo>/lib/profile/state.sh`
- `<repo>/tests/lib/catalog.sh`
- `<repo>/tests/lib/profile-state.sh`
- `<repo>/tests/lib/codec.sh`
- `<repo>/tests/lib/ai-skill-state.sh`
- `<repo>/tests/commands/catalog.sh`
- `<repo>/tests/commands/shim.sh`
- `<repo>/tests/commands/lifecycle.sh`
- `<repo>/tests/support.sh`

This list identifies the primary surface, not permission to ignore newly
required files discovered during implementation.

### Implementation requirements

1. Define authoritative catalog parser metadata in code, with one canonical
   constant location reused by validators and metadata renderers.
2. Change source payload validation to require a safe `tools/` tree and tool
   metadata/skill invariants without requiring a root `catalog.conf`.
3. Change content fingerprint rendering so the manifest enumerates only regular
   files under `tools/`, preserving lexical order and executable-bit identity.
4. Change publication staging to archive only tracked `tools/` from the clean,
   attached `main` commit.
5. Expand `shimmy_catalog_generation_metadata_render` and
   `shimmy_catalog_generation_metadata_read` to include parser metadata plus the
   existing source commit and content fingerprint, with an exact deterministic
   render/read round trip.
6. Keep generation naming unchanged: derive generation directory names only from
   `catalog_content_fingerprint`.
7. Change retained-generation layout validation to accept exactly
   `generation.conf` and `tools/`, and reject `catalog.conf` or other legacy
   direct entries.
8. Preserve strong generation integrity validation: a validated generation must
   still require safe paths, valid `tools/` content, metadata/directory-name
   agreement, and a recomputed `tools/` fingerprint match.
9. Update tests and fixtures in the same chunk so the repository finishes with
   passing low-level and direct-consumer coverage for the new layout.
10. Replace corruption tests that currently mutate `catalog.conf` with an
    equivalent lowest-cost proof against either `generation.conf` or a file
    below `tools/`, depending on the invariant being tested.
11. Update helper fixtures such as the copy-on-write probe to stop depending on
    a deleted root file.
12. Remove the deleted file from tracked source only after all readers,
    validators, fixtures, and publication paths have been updated in the same
    chunk.

### Verification checklist

- [ ] `tests/lib/catalog.sh` passes and proves the new retained layout,
      publication reuse, rollback, and corruption handling.
- [ ] `tests/lib/profile-state.sh` passes and proves expanded `generation.conf`
      round-trip and profile-pin agreement.
- [ ] `tests/lib/codec.sh` passes with an updated `tools/`-only fingerprint vector.
- [ ] `tests/lib/ai-skill-state.sh` passes if touched by the metadata format change.
- [ ] `tests/commands/catalog.sh`, `tests/commands/shim.sh`, and
      `tests/commands/lifecycle.sh` pass for any assertions that read or compare
      `generation.conf`.
- [ ] No remaining source path in `<repo>/lib` or `<repo>/tests` requires or
      references root or generation-local `catalog.conf`.
- [ ] The repository is coherent after deleting `<repo>/catalog.conf`:
      publication, validation, and profile-pin readers all use the new contract.

### Human review gate

Confirm that this chunk preserves the intended authority model:

- fingerprint scope is `tools/` only by design;
- parser metadata lives only in code constants and `generation.conf`;
- retained generations remain self-describing and immutable;
- no compatibility reader or migration path was introduced implicitly.

## Chunk 2 — Documentation, acceptance sweep, and historical guidance alignment

### Goal

Align repository guidance with the new contract and run the broader acceptance
checks needed to prove the cutover did not regress catalog/profile lifecycle
behavior outside the low-level tests.

### Files

Primary change surface:

- `<repo>/README.md`
- `<repo>/CONTRIBUTING.md`
- `<repo>/CONTEXT.md`
- `<repo>/lib/catalog/CONTEXT.md`
- `<repo>/lib/install/CONTEXT.md`
- Any narrow historical plan cross-references whose wording would otherwise
  instruct future agents to recreate `catalog.conf` as current behavior.

### Implementation requirements

1. Update all current-facing documentation to describe:
   - source payload = `tools/` only;
   - retained generation layout = `generation.conf` + `tools/`;
   - `catalog_content_fingerprint` scope = `tools/` only;
   - parser metadata location = `generation.conf` and implementation constants.
2. Preserve historical plans as historical records; only add narrow alignment
   notes where future-agent guidance would otherwise recreate the removed file as
   current behavior.
3. Recheck command/help/docs wording so it does not imply that `catalog.conf`
   still exists at repository root or in retained generations.
4. Run a broader regression sweep focused on catalog and profile lifecycle
   behavior after the contract cutover.

### Verification checklist

- [ ] `README.md`, `CONTRIBUTING.md`, and current context files consistently
      describe the new contract.
- [ ] No current guidance instructs future work to stage, validate, or retain
      `catalog.conf` as a live contract artifact.
- [ ] Relevant broader regression commands pass for catalog/profile lifecycle
      behavior after Chunk 1.
- [ ] Historical plan edits, if any, are narrow cross-references rather than
      rewriting historical design records.

### Human review gate

Confirm that the repository's live guidance now matches the implemented
contract and that any retained historical references are clearly historical,
not active instructions.

## Risk register

- **Atomic-cutover scope:** The change touches low-level metadata readers,
  publication, and multiple tests at once. Mitigation: keep Chunk 1 broad and
  self-contained rather than introducing temporary mixed layouts.
- **Hidden fixture dependence on `catalog.conf`:** Some tests may use the file
  indirectly. Mitigation: grep for remaining references after code changes and
  treat test-helper updates as part of Chunk 1, not follow-up cleanup.
- **Accidental compatibility introduction:** A dual-reader could silently retain
  unsupported historical state. Mitigation: review generated code paths and test
  only the new layout unless the user later requests explicit migration work.
- **Documentation drift:** Historical docs and plans may reintroduce the removed
  layout in future sessions. Mitigation: complete Chunk 2 immediately after the
  atomic code cutover and add narrow alignment notes only where necessary.

## Lessons learned

### Initial

- The current root `catalog.conf` carries only parser metadata, not per-
  generation identity or provenance.
- The user explicitly wants `catalog_content_fingerprint` to shrink so it covers
  `tools/` only; this is a design requirement, not an accidental side effect.
- The higher-level authority boundaries worth preserving are generation
  immutability, mutable registry selection, and independent profile pins; they
  do not require `catalog.conf` to remain as a separate file.
- Because `catalog.conf` affects source payload validation, retained-generation
  layout validation, publication staging, fingerprint vectors, and helper
  fixtures, the low-level cutover should be implemented as one atomic chunk.

## Session bootstrap

For the next implementation session:

1. Stay in ACT only if the user explicitly approves Chunk 1 of this plan.
2. Read `<repo>/AGENTS.md`, `<repo>/CONTEXT.md`, `<repo>/lib/CONTEXT.md`,
   `<repo>/lib/catalog/CONTEXT.md`, `<repo>/lib/install/CONTEXT.md`, this plan,
   and Chunk 1 target files before editing.
3. Treat these boundaries as non-negotiable unless the user reopens them:
   - fingerprint scope is `tools/` only;
   - `generation.conf` remains outside fingerprint scope;
   - no compatibility reader/migration by default;
   - POSIX shell architecture remains.
4. Execute only Chunk 1 first. Do not start Chunk 2 until Chunk 1 is verified
   and explicitly accepted.
5. After implementation, update the Progress Checklist and Lessons learned,
   summarize verification results including any `[~]` items, and stop at the
   Chunk 1 human review gate.
