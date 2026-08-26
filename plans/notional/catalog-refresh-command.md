# Catalog Refresh Command

## Objective

Add a maintainer-only installed command:

```text
shimmy catalog refresh <tool@tag> [--dry-run]
```

The command refreshes mutable tag-backed runtime or base-image references for
one existing concrete catalog version. It resolves each current upstream tag to
an immutable top-level digest, verifies an accepted OCI index or Docker
manifest list with `linux/amd64` and `linux/arm64`, stages a complete valid
catalog candidate, and atomically updates only the selected version's
`image.conf` in the clean source checkout.

Success means:

- one exact existing `tool@tag` selector is required;
- public and explicitly authenticated image references use the active profile's
  exact Skopeo and jq runtimes, registry redirects, and secret boundary;
- every refreshable image record in the selected `image.conf` is handled as one
  all-or-nothing operation;
- the upstream tag is resolved and the resulting immutable reference is
  inspected for media type and both required platforms;
- a second tag resolution immediately before source mutation detects upstream
  movement during the operation;
- `--dry-run` performs the same discovery and validation without changing the
  checkout;
- successful mutation leaves a schema-valid, reviewable catalog-source diff
  and prints the remaining native-smoke, commit, and publication steps; and
- failure leaves the source checkout and installed catalog unchanged.

This change explicitly excludes:

- unqualified `tool` selectors;
- upstream release or version discovery;
- creation, cloning, or promotion of concrete tool versions;
- provider schemas, tool-local discovery hooks, semantic-version comparison,
  and prerelease policy;
- changing `tool_default_version`;
- copying or mirroring images between repositories;
- editing arbitrary tool documentation during refresh;
- Git staging, commits, pushes, catalog publication, profile synchronization,
  or shim synchronization; and
- claiming cross-platform runtime acceptance from index inspection alone.

Here, “ready to publish” means the command has produced a validated catalog
source candidate. The maintainer must still review the diff, update any
human-maintained documentation that duplicates the old digest, complete native
smokes, commit the source, and run `shimmy catalog publish`.

## Target layout and terminology

Primary implementation surface:

```text
commands/
  catalog.sh                 # parse and route `catalog refresh`
  help.sh                    # group/action help
lib/
  catalog/
    refresh.sh               # source-checkout refresh transaction
  images/
    images.sh                # shared reference/index inspection primitives
    catalog.sh               # active-profile dependency and cache lifecycle
tests/
  commands/
    catalog.sh               # public behavior and transaction coverage
    surface.sh               # exact help grammar
plugins/shimmy/skills/
  shimmy-catalog/SKILL.md    # canonical maintainer guidance
```

Definitions:

- **Selected version**: the existing `tools/<tool>/versions/<version>` named by
  the required selector.
- **Image record**: the external runtime (`runtime`) or a non-`scratch`
  local-build base (`base-N`) enumerated from that version's `image.conf`.
- **Refreshable record**: an image record whose upstream reference is a fully
  qualified mutable tag and whose upstream and configured-default logical
  repository are identical.
- **Immutable-only record**: an image record whose upstream reference already
  uses `@sha256:` and therefore exposes no tag from which a replacement can be
  discovered.
- **Candidate digest reference**: the refreshable record's logical repository
  combined with the newly resolved top-level digest.
- **Candidate catalog**: a temporary complete tracked catalog payload with only
  the selected `image.conf` replaced by its staged candidate.
- **Source refresh**: mutation of the checked-in worktree. It never mutates the
  installation-owned immutable catalog registry or a profile pin.

Expected human output for a changed record is structurally:

```text
REFRESH netcat@7.92 base-1
  upstream:  registry.access.redhat.com/ubi9/ubi-minimal:latest
  previous:  sha256:<old>
  candidate: sha256:<new>
  media:     <accepted-index-media-type>
  platforms: linux/amd64, linux/arm64
  access:    public

UPDATED tools/netcat/versions/7.92/image.conf
PUBLISHED no
```

A no-drift run succeeds without writing. A selector with no refreshable records
fails with exact `not-refreshable` guidance rather than implying that a newer
digest was checked.

## Recorded design decisions

1. The only accepted selector form is one positional `tool@tag`. Reject an
   empty selector, unqualified tool, multiple selectors, unsafe tokens, unknown
   tools, and unknown versions before network access or mutation.
2. `refresh` is an installed `shimmy catalog` action and must run from the
   normalized repository root through an installed profile launcher. It uses
   that installation's active profile solely for trusted jq/Skopeo execution,
   authentication, engine affinity, and registry policy.
3. Require an attached local `main` whose `HEAD` equals `refs/heads/main`, a
   valid current catalog payload, and a completely clean tracked and untracked
   worktree before acquiring refresh authority. The successful non-dry run is
   expected to leave only the selected `image.conf` dirty.
4. Add a checkout-scoped exclusive refresh lock using a validated Git-owned
   lock path rather than installation catalog locks or an untracked worktree
   file. Revalidate checkout identity, branch, HEAD, cleanliness, selected-file
   fingerprint, and lock ownership immediately before mutation. A stale or
   ambiguous lock fails with remediation; it is never silently stolen.
5. Reuse the existing active-profile jq and Skopeo dependency rules from
   `catalog verify`. Do not use host-selected jq/Skopeo, mount host auth files,
   reveal secret names or values in diagnostics, or bypass active registry
   redirects. Preserve `SHIMMY_SKOPEO_AUTH_SECRET` as the only registry-auth
   selection.
6. Process every image record in the selected version. Immutable-only records
   are reported as skipped when at least one refreshable record exists. If none
   are refreshable, fail without mutation. `scratch` remains non-record data.
7. For a refreshable record, require the tag upstream and existing default
   digest to use the same logical repository. A repository mismatch indicates
   a mirror or retention boundary and fails without mutation; `refresh` never
   changes repositories or assumes the upstream digest exists in a retained
   mirror.
8. Resolve each tag with Skopeo's digest inspection, validate one lowercase
   `sha256:` digest, construct the immutable candidate reference, inspect that
   exact reference with `--raw`, and parse it with the existing accepted-index
   jq filter. Never validate platforms from tag content after resolution and
   never accept a child image manifest.
9. Deduplicate identical tag and immutable-reference inspections while still
   reporting every affected role. Preserve the configured `public` or
   `authenticated` access classification. Missing explicit authentication for
   any authenticated refreshable record fails the complete operation before a
   source candidate is applied.
10. Resolve every selected tag a second time after candidate validation and
    immediately before mutation. Any changed, malformed, or unreachable result
    fails the entire operation as `upstream-moved-during-refresh`.
11. Rewrite only the matching `image_default_ref` or
    `image_base_N_default_ref` scalar values in the selected `image.conf`.
    Preserve key order, unrelated bytes, file mode, upstream references,
    registry-access policy, build arguments, and platform declarations.
12. Stage tracked `catalog.conf`, `tools/`, and `plugins/shimmy/skills/` from the
    captured `HEAD`, replace the staged selected `image.conf`, and validate the
    complete candidate with the canonical catalog validator before worktree
    mutation. Do not validate only the rewritten file.
13. Apply one regular-file transaction with original fingerprint/mode evidence,
    post-write full-catalog validation, and exact rollback on injected or real
    failure. Never modify the installed immutable catalog registry as part of
    this transaction.
14. `--dry-run` performs checkout, active-profile, auth, remote inspection,
    second-resolution, rewrite, and complete candidate validation, but does not
    acquire mutation authority or change the checkout. Human output uses
    `WOULD UPDATE`; no separate `--apply`, `--force`, `--publish`,
    `--public-only`, or multi-selector option is added.
15. When every refreshable tag already resolves to its configured digest,
    return success, report `CURRENT` records, and leave the checkout byte-for-
    byte unchanged.
16. The command updates authoritative image metadata only. It lists exact
    `guide.md` or `SKILL.md` paths under the selected tool that still contain a
    replaced full digest reference as `REVIEW` items, but does not perform
    heuristic Markdown rewriting.
17. Successful mutation prints the selected path, changed roles, explicit
    `PUBLISHED no`, documentation review findings, native Linux `amd64` and
    Apple Silicon `arm64` smoke requirements, and the separate commit followed
    by `shimmy catalog publish` workflow.
18. Keep `catalog verify` behavior and output stable. Factor only the minimum
    active-runtime, cache, immutable-reference inspection, and index-parsing
    primitives needed by both commands.

## Verified implementation inventory

- `commands/catalog.sh` currently accepts only `status`, `tools`, `verify`,
  `publish`, and `rollback`; its cleanup trap already owns image-cache,
  filesystem-transaction, catalog-lifecycle, and lock cleanup.
- `commands/help.sh`, `commands/README.md`, root `README.md`, and
  `tests/commands/surface.sh` jointly define and verify the installed command
  grammar and help-before-state behavior.
- `lib/images/images.sh` already validates image configuration records, resolves
  tags through Skopeo, caches inspections, validates digest syntax, and parses
  the two accepted multi-platform index media types with jq.
- `lib/images/catalog.sh` already proves the active profile and catalog pin,
  resolves exact materialized jq/Skopeo runtimes, preserves registry policy and
  authentication, and implements verification result categories. Its current
  setup is verify-specific and needs a narrow reusable seam for refresh.
- `lib/runtime/image.sh` is the canonical schema-1 image configuration parser.
  It supports external runtime records and one or more local-build base records,
  validates fully qualified tag/digest references, and requires both target
  platforms in metadata.
- `lib/catalog/catalog.sh` validates a complete source/catalog payload,
  tool/version structure, canonical skills, executable modes, smoke metadata,
  image metadata, and local-build contexts.
- `lib/install/catalog.sh` provides the publication-only clean-main validation
  and Git-archive staging pattern. Refresh needs analogous source validation but
  must intentionally leave a dirty source file rather than advance catalog
  authority.
- `lib/install/transaction.sh` handles regular-file replacement and rollback
  but requires installation lock semantics. The refresh transaction should
  reuse its evidence/rollback principles without misclassifying a source
  checkout write as an installation catalog mutation.
- `tests/commands/catalog.sh` already supplies offline fake jq/Skopeo runtimes,
  raw index fixtures, digest responses, access controls, drift cases, and clean
  Git catalog fixtures. These should be extended rather than creating remote
  checks in the default suite.
- `tests/commands/image-fixtures/` already covers accepted OCI/Docker indexes,
  single manifests, malformed documents, and missing platforms.
- Catalog/tool digest strings are sometimes duplicated in tool guides and
  skills, and at least one current guide is already stale. Therefore refresh
  reports exact old-reference matches for review instead of claiming that
  arbitrary prose can be safely regenerated.
- Profile control materialization copies all of `lib/`, so a new
  `lib/catalog/refresh.sh` needs command/bootstrap sourcing and inventory tests
  but no separate per-profile asset allowlist entry.
- No existing plan represents this narrowed command. The notional image-
  retention plan addresses retained registry bytes and explicitly excludes
  automatic digest adoption; this command remains a maintainer-reviewed source
  rotation and does not weaken that boundary.

This inventory is the verified baseline, not permission to ignore dependencies
discovered during implementation.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Implement and verify the single-version catalog refresh command.

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

## Chunk 1 — Existing-version image digest refresh

### Goal

Deliver the complete `shimmy catalog refresh <tool@tag> [--dry-run]`
workflow with offline behavioral coverage, source transaction safety, public
documentation, and explicit live/native acceptance boundaries. Leave all
version discovery and publication behavior unchanged.

### Files

Primary change surface:

- `commands/catalog.sh`
- `commands/help.sh`
- `commands/README.md`
- `lib/catalog/refresh.sh` (new)
- `lib/images/images.sh`
- `lib/images/catalog.sh`
- `tests/commands/catalog.sh`
- `tests/commands/surface.sh`
- `README.md`
- `docs/podman.md`
- `docs/testing.md`
- `docs/prompt-shimmy-project.md`
- `plugins/shimmy/skills/shimmy-catalog/SKILL.md`
- any directly affected source/inventory assertions discovered while
  implementing

Do not edit generated copies under `.agents/skills/`.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: **high**. The implementation combines remote
identity resolution with a local source transaction and must preserve both
registry and Git authority boundaries.

1. Add exact group and action help for the new positional-selector grammar.
   Help must render before installed-state validation and explain source-only
   mutation, clean-main requirements, `--dry-run`, authentication, immutable-
   upstream/mirror limitations, native smokes, and separate publication.
2. Add strict parsing in `commands/catalog.sh`. Accept exactly one positional
   `tool@tag` and optional single `--dry-run` in either documented order;
   reject all other arguments before calling the refresh library.
3. Introduce `lib/catalog/refresh.sh` with narrow source-checkout preflight,
   Git-owned lock, staged-payload, rewrite, revalidation, commit, rollback, and
   output responsibilities. Keep tool-specific behavior out of this module.
4. Refactor the existing image-verification helpers only enough to expose
   active-profile jq/Skopeo setup, cache setup/cleanup, tag digest resolution,
   immutable raw-index inspection, and accepted-platform parsing to refresh.
   Preserve verification selection, output, exit status, deduplication, and
   error categories.
5. Resolve records from the source checkout's selected `image.conf`, not the
   installed catalog generation. Resolve jq and Skopeo only from the validated
   active profile, retaining its registry redirects and optional auth secret.
6. Produce one candidate per refreshable role, enforcing access, repository
   equality, digest syntax, exact immutable-reference reachability, accepted
   media type, and both platform descriptors. Accumulate all results before
   deciding whether any source mutation is allowed.
7. Treat a mixed tag/digest configuration predictably: report immutable-only
   roles as skipped, refresh all tag-backed roles atomically, and fail when the
   configuration contains no refreshable roles. Do not invent an upstream tag
   for an immutable-only record.
8. Render the candidate `image.conf` by replacing only the unique default-ref
   scalar for each changed role. Revalidate it with the canonical image schema,
   retain its mode, and prove unrelated bytes are preserved through focused
   fixture assertions.
9. Build a complete temporary catalog candidate from captured tracked `HEAD`
   content, replace the selected candidate file, and run canonical payload
   validation before any worktree mutation. Ensure temporary paths and cleanup
   are exact and safe.
10. Re-resolve all tags, recheck source authority and original file evidence,
    and commit a single regular-file change only when every result remains
    identical. Validate the actual checkout after the write; restore the exact
    prior file and report rollback state on failure.
11. Scan only `tools/<tool>/guide.md` and `tools/<tool>/SKILL.md` for exact full
    old default references that were replaced. Report matching paths for manual
    review without editing them or treating their current absence as an error.
12. Extend the existing catalog-command fixture rather than adding network to
    the default suite. The fake Skopeo runtime must support ordered digest
    responses so tag movement between initial resolution and precommit
    re-resolution is observable.
13. Add positive acceptance for an external runtime tag and a local-build base
    tag, including dry-run, changed-role output, candidate catalog validity,
    exact one-file diff, preserved bytes/mode, and no-op current behavior.
14. Add the lowest-cost durable-invariant assertions for authenticated access,
    repository mismatch, immutable-only selection, malformed digest,
    unsupported/single-manifest media, missing platform, tag movement,
    dirty/moved source authority, injected post-write failure, and exact
    rollback. Reuse existing fixtures and scenarios rather than duplicating
    generic rejection coverage.
15. Update canonical maintainer guidance and command references together.
    Explicitly state that index verification does not replace native runtime
    acceptance and that publication requires reviewed documentation, a commit,
    and a separate `catalog publish`.
16. Preserve POSIX shell, executable modes, installed control-asset behavior,
    manifest secret redaction, catalog publication/rollback behavior, and the
    existing no-central-tool-routing constraint.

### Verification checklist

- [ ] `./tests/test.sh --group commands-catalog --group commands-surface --group lib-catalog --group lib-runtime --jobs 3` passes.
- [ ] Offline fixtures prove external-runtime and local-build-base refresh,
      dry-run parity, all-role atomicity, exact candidate refs, accepted media,
      both platforms, no-op behavior, and one-file source mutation.
- [ ] Integrity/security fixtures prove no mutation for missing auth,
      repository mismatch, immutable-only input, malformed/unreachable
      candidate, single manifest, missing platform, tag race, dirty or moved
      checkout, and injected commit/rollback failure.
- [ ] Existing `catalog verify`, `publish`, and `rollback` command scenarios
      retain byte/exit semantics outside intentional help additions.
- [ ] A disposable clean-main checkout dry-runs and applies
      `shimmy catalog refresh netcat@7.92` against the live registry when the
      upstream tag is reachable; the resulting diff is limited to its
      `image.conf` and the candidate catalog validates. Do not apply the live
      rotation to the maintainer's primary checkout as acceptance setup.
- [ ] If the live Netcat candidate differs, build and run the version-owned
      non-mutating smoke on native Linux `amd64` and native Apple Silicon macOS
      `arm64`. Record either both results or a reviewer-approved `[~]` deferral;
      index inspection alone is not acceptance.
- [ ] `./tests/test.sh` passes with default bounded parallel execution after
      focused groups.
- [ ] All changed shell files pass `/bin/sh -n`; executable modes, context-tree
      links, installed asset inventory, canonical skill validation, and
      `git diff --check` pass.

### Human review gate

Confirm the selector grammar, clean-main and active-profile authority, exact
one-file source mutation, auth/redirect preservation, mirror refusal,
tag-race handling, rollback evidence, stable verify/publish behavior,
documentation guidance, and disposition of both native-host smoke results.
Acceptance authorizes no additional version-discovery or publication work.

## Risk register

| Risk | Impact | Mitigation |
| --- | --- | --- |
| An upstream tag moves between resolution and source update. | The committed digest is not the candidate that was reviewed. | Resolve once, inspect the exact immutable ref, then resolve again immediately before mutation and fail on any difference. |
| A configured default uses a retained mirror while discovery uses a publisher repository. | Rewriting the default could bypass retention or point at bytes absent from the mirror. | Require identical logical repositories; report a mirror/retention boundary and do not copy or rewrite repositories. |
| Authentication or profile redirects are bypassed. | Private credentials, corporate routing, or isolation policy is violated. | Use only active-profile materialized Skopeo/jq, its mounted redirect policy, and explicit secret selection; redact secret diagnostics. |
| Index presence is mistaken for runtime acceptance. | A candidate publishes but fails natively on one architecture. | Print and document both native-smoke gates; record partial verification explicitly. |
| The checkout changes concurrently. | Unrelated maintainer work is overwritten or a candidate is applied to a different HEAD. | Require a clean source, hold a Git-owned refresh lock, fingerprint the file, and revalidate branch/HEAD/status immediately before one-file commit. |
| A write or post-write validation fails. | The catalog source is left partially changed or invalid. | Use exact backup/fingerprint/mode evidence, validate the full candidate first, and restore/verify the prior file on any commit failure. |
| Documentation contains a copied digest. | Runtime metadata is correct while human guidance becomes stale. | Report exact old-reference matches in the selected guide/skill and require maintainer review; do not heuristically rewrite prose. |
| Skopeo refresh depends on the currently installed Skopeo runtime. | A missing uncached old Skopeo runtime can prevent refreshing its own source definition. | State the dependency explicitly; use an already operational active-profile Skopeo or repair/sync the profile through existing lifecycle authority. Do not add host fallback. |

## Lessons learned

### Initial

- Existing image metadata already provides everything required for qualified
  digest refresh; version discovery was the source of provider and provenance
  complexity.
- The safe candidate is the immutable reference created from the resolved tag
  digest, not the mutable tag's raw response.
- Upstream and default repositories may intentionally diverge under retained
  mirroring, so digest substitution must not silently cross repository
  ownership boundaries.
- Catalog verification and source refresh share registry inspection mechanics
  but have different authorities: verify reads an immutable installed
  generation, while refresh deliberately writes a clean source checkout.
- Full catalog validation before mutation and tag/source revalidation before
  commit are both required; either alone leaves a race or integration gap.
- Exact digests duplicated in prose cannot be regenerated safely without a
  separate documentation contract, so refresh should report them rather than
  expand into heuristic document editing.

## Session bootstrap

For a fresh implementation session:

1. Read repository `AGENTS.md`, root `CONTEXT.md`, `CONTRIBUTING.md`,
   `commands/CONTEXT.md`, `lib/CONTEXT.md`, `lib/catalog/CONTEXT.md`,
   `lib/images/CONTEXT.md`, `tests/CONTEXT.md`, `tests/commands/CONTEXT.md`,
   `tests/commands/image-fixtures/CONTEXT.md`, and this plan.
2. Read `docs/prompt-shimmy-project.md`, the canonical
   `plugins/shimmy/skills/shimmy-catalog/SKILL.md`, and the current files named
   by Chunk 1.
3. Recheck `git status`; preserve unrelated work, including unrelated notional
   plans, and do not edit generated `.agents/skills/` copies.
4. Keep the target limited to `shimmy catalog refresh <tool@tag>
   [--dry-run]`. Do not add unqualified selectors, providers, version creation,
   default promotion, mirroring, commits, or publication.
5. Implement only Chunk 1, update its checklist and lessons with verification
   evidence, and stop at its human review gate.
