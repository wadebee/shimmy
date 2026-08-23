# Image Retention Resilience

## Objective

Make fresh Shimmy bootstrap resilient to an upstream registry deleting a
previously reviewed image digest, without weakening immutable-image or
multi-platform guarantees.

Success means:

- the default-profile jq, rg, and Skopeo images are anonymously pullable by
  exact digest from public repositories controlled by the Shimmy repository
  owner;
- a reviewed upstream index is copied with its digest preserved and retained
  under a permanent tag before repository metadata adopts the mirror;
- bootstrap and profile/shim image-preparation failures name the exact tool,
  version, action, and configured default reference while preserving
  transaction rollback;
- an independent scheduled workflow detects missing bootstrap digests before
  users do, then a disposable bootstrap and installed `catalog verify` cover
  the public catalog;
- contributor guidance defines retained image bytes, rather than Git history
  alone, as the rollback requirement; and
- Shimmy never advances to a mutable upstream tag automatically.

This plan does not:

- mirror every non-baseline tool or authenticated Red Hat image in the first
  implementation;
- introduce a new image metadata schema or migrate every `image.conf`;
- add a runtime or bootstrap mutable-tag fallback;
- install or provision Podman;
- add automatic package deletion, automatic digest adoption, or an
  automatically merged rotation change; or
- rewrite the retained `plans/multi-architecture-manifest.md` history. This
  plan supersedes only its claim that a digest identifier in Git is itself a
  recoverable rollback artifact.

## Target layout and terminology

### Terms

- **Upstream discovery reference**: the publisher-owned tag or digest already
  recorded as `image_upstream_ref`. It is inspected for drift but is never an
  automatic runtime fallback.
- **Retained default reference**: `image_default_ref` pointing by digest to a
  Shimmy-controlled public GHCR package.
- **Retention tag**: a permanent GHCR tag of the form
  `retained-<version>-sha256-<64-hex-digest>`. Runtime still uses the digest;
  the tag keeps the manifest reachable and makes retention visible to
  maintainers.
- **Bootstrap baseline**: the hard-coded catalog-default jq, rg, and Skopeo
  versions selected by `shimmy_profile_baseline_render`.
- **Out-of-band baseline check**: a registry-manifest lookup performed with
  host Podman before Shimmy bootstrap, so a missing Skopeo image cannot prevent
  diagnosis.
- **Rotation**: a reviewed copy-and-metadata change. It is not tag following.

### GHCR authority

The baseline mirror repositories are:

```text
ghcr.io/wadebee/shimmy-jq
ghcr.io/wadebee/shimmy-rg
ghcr.io/wadebee/shimmy-skopeo
```

Each package is public and repository-associated. Anonymous exact-digest pull
is an acceptance requirement. GitHub documents that public GHCR container
packages support anonymous pulls and that a repository workflow can publish
with its scoped `GITHUB_TOKEN`:

- <https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry>
- <https://docs.github.com/en/packages/managing-github-packages-using-github-actions-workflows/publishing-and-installing-a-package-with-github-actions>

### Target repository additions

```text
.github/workflows/
  mirror-bootstrap-image.yml   # manual, reviewed, packages:write
  image-liveness.yml           # scheduled/read-only registry and bootstrap check
```

No general mirror command is added to the installed `shimmy` launcher. Mirror
publication is maintainer infrastructure, not an end-user lifecycle command.

## Recorded design decisions

1. Keep immutable top-level index digests. The incident exposed an availability
   ownership gap, not a reason to weaken content identity.
2. Mirror only the bootstrap baseline in this implementation. Scheduled
   verification covers every public catalog default and base; broader mirroring
   can be a later reviewed migration.
3. Use one public GHCR package per baseline tool. The repository owner controls
   package retention and Actions can publish without a long-lived personal
   token.
4. Preserve the complete multi-platform index and its digest with Skopeo
   `copy --all --preserve-digests`. Skopeo documents that `--all` copies the
   list and its instances and `--preserve-digests` fails when exact preservation
   is impossible:
   <https://github.com/containers/skopeo/blob/main/docs/skopeo-copy.1.md>.
5. Keep `image_upstream_ref` on the publisher repository and change only
   `image_default_ref` to the retained GHCR repository. Existing verification
   compares the upstream and configured digest independently, so no image
   schema change is necessary.
6. Initial publication and every later mirror copy are external mutations and
   require explicit authorization. Creating or reviewing the workflow does not
   authorize dispatching it, changing package visibility, or pushing images.
7. Mirror workflow inputs are constrained to a catalog tool/version and an
   exact source digest. Source repository and destination package are derived
   from tracked metadata and the fixed GHCR authority; arbitrary copy sources
   or destinations are not accepted.
8. The mirror workflow uses minimal `contents: read` and `packages: write`
   permissions, an ephemeral auth file, the workflow `GITHUB_TOKEN`, and no
   persisted broad registry credential.
9. Never delete a `retained-*` tag as part of rotation. The old digest is a
   rollback artifact only after its mirrored index and children remain
   anonymously reachable.
10. The bootstrap baseline is a permanent availability boundary: its catalog
    defaults must be external, public, digest-pinned references in the exact
    `ghcr.io/wadebee/shimmy-<tool>` repository. One authoritative validation
    and test may reject an unretained baseline.
11. Image-preparation diagnostics report facts Shimmy knows. They use the
    category `image-preparation-failed` and include tool, version, action, and
    configured reference; they do not misclassify every network/authentication
    failure as upstream deletion. Podman's underlying error remains visible.
12. No automatic retry against `image_upstream_ref` is added. Existing explicit
    `SHIMMY_<TOOL>_IMAGE` overrides remain user-controlled and outside the
    repository-default guarantee; they are not a bootstrap recovery policy.
13. The scheduled workflow first checks the three baseline digest manifests
    with host Podman, then performs a fresh disposable bootstrap on attached
    local `main`, and finally runs the installed profile's
    `shimmy catalog verify --public-only --format manifest`. This intentionally
    avoids depending exclusively on the Skopeo image to determine whether that
    same image is available.
14. The liveness workflow runs daily, on manual dispatch, and on relevant pull
    requests. A failed workflow is the initial alerting mechanism; automatic
    issue creation and automatic digest-rotation pull requests are excluded.
15. Normal offline tests remain registry-independent. Live registry and
    disposable-bootstrap checks belong to the dedicated workflow and explicit
    acceptance runs.
16. Authenticated catalog images remain explicitly skipped by
    `--public-only`; their credentialed liveness policy is a separate future
    decision.

## Sizing estimate

The expected implementation size is **4 chunks** across approximately **4–5
focused implementation sessions**. Overall reasoning effort is **high** because
the work crosses external registry ownership, bootstrap transaction behavior,
CI, and canonical contributor guidance.

| Chunk | Expected reasoning | Relative size | Primary difficulty |
|---|---|---:|---|
| 1. Retained mirror and baseline cutover | High | Large | Exact OCI-index preservation, external GHCR state, atomic reference cutover, native acceptance |
| 2. Baseline invariant and diagnostics | High | Medium | Shared bootstrap/profile/shim failure flow and rollback-safe errors |
| 3. Scheduled liveness workflow | Medium–high | Medium | Avoiding the Skopeo self-dependency while exercising a clean attached-main bootstrap |
| 4. Governance and final integration | Medium | Medium | Keeping docs, canonical skills, templates, tests, and historical terminology consistent |

Chunk 1 may require two sessions if GHCR package creation/visibility must be
performed by the maintainer between repository work and anonymous-pull
acceptance. That external coordination must be recorded as `[~]` and blocks
the Chunk 1 gate until completed.

## Verified implementation inventory

This is the verified baseline, not permission to ignore dependencies found
during implementation.

### Producers and policy

- `tools/jq/versions/1.8/image.conf`,
  `tools/rg/versions/15.1/image.conf`, and
  `tools/skopeo/versions/1.22/image.conf` own the three baseline upstream and
  default references.
- `lib/runtime/image.sh` strictly validates external defaults as qualified
  SHA-256 references and accepts an upstream and default repository that differ.
- `lib/install/profile.sh::shimmy_profile_baseline_render` owns the exact
  jq/rg/Skopeo baseline and is the appropriate enforcement point for retained
  baseline authority.
- Each version-local `refresh.sh` forces the configured image pull and smoke
  during bootstrap/profile preparation.

### Consumers and failure boundaries

- `lib/install/lifecycle.sh` calls profile image preparation before the initial
  profile is committed and owns compensated bootstrap cleanup.
- `lib/install/profile.sh::shimmy_profile_images_prepare` currently returns a
  failed refresh without setting a detailed lifecycle error.
- `lib/shim/shim.sh::shimmy_shim_images_prepare` already reports the tool and
  version, but omits action and configured reference.
- `commands/bootstrap.sh` reports `SHIMMY_PROFILE_LIFECYCLE_ERROR` and otherwise
  falls back to a generic `bootstrap failed` message.

### Verification and CI

- `lib/images/images.sh` performs cached Skopeo raw/digest inspection and jq
  index parsing.
- `lib/images/catalog.sh` already reports `pinned-reference-unreachable`,
  required-platform failures, and upstream drift, but requires the active
  profile's jq and Skopeo runtimes.
- `.github/workflows/test.yml` runs only on push, pull request, and manual
  dispatch; it has no schedule or live bootstrap/catalog verification.
- `tests/commands/catalog.sh` provides offline remote-response fixtures.
- `tests/lib/catalog.sh` owns the baseline selection proof.
- `tests/commands/lifecycle.sh` owns public bootstrap success and compensated
  failure cleanup.
- `tests/commands/shim.sh` already has an image-preparation failure scenario
  that can carry the richer diagnostic assertion.

### Guidance and generated-source boundaries

- `CONTRIBUTING.md`, `docs/podman.md`, `docs/testing.md`,
  `docs/prompt-shimmy-project.md`, `docs/templates/generic-shim/`,
  `plugins/shimmy/skills/shimmy-create-tool/SKILL.md`, and
  `plugins/shimmy/skills/shimmy-tool-local-build/SKILL.md` define the live image
  and rotation contract.
- `tools/jq/SKILL.md`, `tools/rg/SKILL.md`, and the three tool guides contain
  baseline default-image references that must move with `image.conf`.
- Generated `.agents/skills/` copies are outside scope and must not be edited.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Publish retained baseline mirrors and atomically cut defaults over to GHCR.
- [ ] Chunk 2 — Enforce retained baseline authority and add rollback-safe image-preparation diagnostics.
- [ ] Chunk 3 — Add independent scheduled liveness, disposable bootstrap, and public catalog verification.
- [ ] Chunk 4 — Propagate the retention/rotation contract and complete integration verification.

Active chunk: **Chunk 1**.

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

## Chunk 1 — Retained mirror and baseline cutover

Expected reasoning: **high**.

### Goal

Create the constrained maintainer mirror workflow, establish the three public
GHCR packages, and change all baseline default references only after exact
anonymous digest access has been proven. Leave fresh bootstrap operational on
both supported native architectures.

### Files

- `.github/workflows/mirror-bootstrap-image.yml` (new)
- `tools/jq/versions/1.8/image.conf`
- `tools/rg/versions/15.1/image.conf`
- `tools/skopeo/versions/1.22/image.conf`
- `tools/jq/guide.md`, `tools/jq/SKILL.md`
- `tools/rg/guide.md`, `tools/rg/SKILL.md`
- `tools/skopeo/guide.md`
- `docs/podman.md`
- mechanical reference expectations in `tests/commands/lifecycle.sh`

### Implementation requirements

1. Add a manual-only workflow with `contents: read` and `packages: write`.
   Accept a safe catalog tool, concrete version, and exact 64-hex source
   digest. Resolve the upstream repository from the selected tracked
   `image.conf`; reject arbitrary source/destination repository inputs.
2. Derive the destination as `ghcr.io/wadebee/shimmy-<tool>` and the permanent
   tag as `retained-<version>-sha256-<digest>`. Validate every derived shell
   value before registry use.
3. Use an ephemeral registry auth file and `GITHUB_TOKEN`; clean it on every
   exit path. Do not print credentials or accept a personal access token.
4. Inspect the exact upstream digest as an accepted OCI index or Docker
   manifest list containing `linux/amd64` and `linux/arm64` before copying.
5. Copy with `--all --preserve-digests`. Inspect the destination and require
   its top-level digest and required platform descriptors to match before
   reporting success.
6. Do not overwrite or delete older `retained-*` tags. Re-dispatching the exact
   same tool/version/digest must be idempotent.
7. With separate explicit authorization, publish the current reviewed jq and
   rg indexes and the newly reviewed Skopeo index. Skopeo's obsolete missing
   digest must not be copied or treated as recoverable.
8. Configure all three packages as public and associated with this repository.
   Prove anonymous exact-digest inspection before editing defaults. If package
   visibility or publication requires maintainer UI work, mark the chunk `[~]`
   and stop; do not substitute authenticated acceptance.
9. Change only each `image_default_ref` repository/digest as required. Preserve
   the publisher `image_upstream_ref` so drift remains observable. Update the
   corresponding guides and canonical tool skills in the same change.
10. Preserve current image override and forced-pull behavior. Do not add a tag
    fallback or registry redirect dependency to bootstrap.
11. Record the exact source digest, retained destination digest, permanent tag,
    media type, platform descriptors, reported tool version, and native smoke
    evidence in this plan's Chunk 1 lessons/verification notes.

### Verification checklist

- [ ] Workflow permissions, validated inputs, auth-file cleanup, exact source
  derivation, fixed destination derivation, and no-delete behavior are reviewed.
- [ ] `skopeo copy --all --preserve-digests` succeeds for jq, rg, and the newly
  selected Skopeo index; source and destination top-level digests match.
- [ ] Anonymous inspection of each GHCR digest succeeds and proves accepted
  index media type plus both required platform descriptors.
- [ ] Each permanent retention tag resolves to the same top-level digest.
- [ ] Source previews for jq, rg, and Skopeo render the GHCR digest defaults
  while explicit `SHIMMY_<TOOL>_IMAGE` overrides still win.
- [ ] `./tests/test.sh --group tools-jq --group tools-rg --group tools-skopeo
  --group commands-lifecycle --jobs 3` passes.
- [ ] Fresh disposable bootstrap and baseline non-mutating smokes pass on native
  Linux `amd64`.
- [ ] Fresh disposable bootstrap and baseline non-mutating smokes pass on native
  Apple Silicon macOS `arm64`.
- [ ] Shell syntax, executable modes, workflow review, and `git diff --check`
  pass.

### Human review gate

Confirm the three GHCR packages are public, retained tags and exact digests are
anonymous, digest preservation evidence is recorded, the new Skopeo artifact
is acceptable, and both native bootstrap results pass. External publication or
visibility left `[~]` blocks acceptance and Chunk 2.

## Chunk 2 — Baseline invariant and preparation diagnostics

Expected reasoning: **high**.

### Goal

Make retained GHCR authority a durable bootstrap-baseline invariant and provide
specific failure context without changing rollback or adopting mutable content.

### Files

- `lib/install/profile.sh`
- `lib/install/lifecycle.sh`
- `lib/shim/shim.sh`
- `tests/lib/catalog.sh`
- `tests/commands/lifecycle.sh`
- `tests/commands/shim.sh`
- relevant `CONTEXT.md` files if implementation findings require clarification

### Implementation requirements

1. Extend baseline validation at `shimmy_profile_baseline_render` so jq, rg,
   and Skopeo catalog defaults are external, public, exact digest references in
   `ghcr.io/wadebee/shimmy-<tool>`. Use the existing image validator for digest
   syntax and platform declarations; do not create a second generic parser.
2. Treat this check as the one authoritative negative proof of the permanent
   baseline retention boundary. Do not duplicate generic rejection assertions
   in every tool test.
3. When profile/bootstrap image preparation fails, set
   `SHIMMY_PROFILE_LIFECYCLE_ERROR` to a stable message containing
   `image-preparation-failed`, tool, version, action (`pull` or `build`), and
   configured external reference or a truthful local-build label.
4. Apply the same factual fields to `SHIMMY_SHIM_ERROR` for shim add/sync image
   preparation. Keep the version-local refresh output visible before the
   summary.
5. Preserve candidate cleanup, manifest-last commit, profile isolation, active
   record, registry projection, startup compensation, and unrelated user skill
   state on all failures.
6. Do not inspect or retry `image_upstream_ref` during preparation and do not
   infer `manifest unknown` from an undifferentiated pull failure.
7. Add the lowest-cost assertions to the existing shim image-failure and
   failed-bootstrap/lifecycle scenarios. Reuse one failed-bootstrap setup to
   prove both the diagnostic and compensated cleanup.

### Verification checklist

- [ ] Baseline rendering succeeds for the three retained GHCR defaults and one
  authoritative altered-baseline fixture proves the permanent boundary fails
  before image preparation.
- [ ] Existing shim image-preparation failure reports tool, version, action,
  and reference while preserving the prior profile state.
- [ ] Bootstrap image-preparation failure reports the same context and removes
  all new installation state while preserving unrelated user state.
- [ ] `./tests/test.sh --group lib-catalog --group commands-shim --group
  commands-lifecycle --jobs 3` passes.
- [ ] Relevant shell syntax, executable modes, and `git diff --check` pass.

### Human review gate

Confirm the baseline namespace rule is intentionally permanent, diagnostics do
not promise an unproven cause, and all existing transaction/ownership guarantees
remain intact. Acceptance authorizes neither the CI workflow nor later docs.

## Chunk 3 — Scheduled liveness and disposable bootstrap

Expected reasoning: **medium–high**.

### Goal

Detect baseline digest loss independently of the Skopeo runtime, exercise a
real clean bootstrap daily, and verify every publicly inspectable catalog image
after bootstrap.

### Files

- `.github/workflows/image-liveness.yml` (new)
- `.github/workflows/test.yml` only if path filters or shared workflow behavior
  must be coordinated
- `docs/testing.md`
- `BOOTSTRAP.md` and/or `README.md` for maintainer-facing failure ownership

### Implementation requirements

1. Add daily `schedule`, `workflow_dispatch`, and narrow relevant
   `pull_request` triggers. Use concurrency cancellation and minimal
   `contents: read` permissions; grant no package write permission.
2. On the ephemeral runner, derive each baseline default version from
   `tool.conf` and exact default reference from its `image.conf`. Validate the
   expected GHCR repository before using the value.
3. Run host `podman manifest inspect` on all three exact baseline refs before
   invoking Shimmy. This step is the explicit bootstrap-dependency exception to
   normal Shimmy-wrapper preference.
4. Attach the checkout to local `main` at the workflow commit, keep it clean,
   use an absolute disposable `XDG_CONFIG_HOME`, and execute
   `./bootstrap.sh --no-startup` without modifying persistent runner startup
   state.
5. Use the exact installed default-profile launcher to run status, shim list,
   jq/rg/Skopeo non-mutating smokes, and
   `catalog verify --public-only --format manifest`.
6. Preserve the verifier's warning semantics for moved upstream tags; liveness
   fails for missing/invalid pinned defaults and malformed/missing platforms,
   not merely because an upstream tag moved unless strict drift is explicitly
   selected in a later decision.
7. Keep authenticated references visibly skipped and document that limitation.
8. Do not put remote checks into `./tests/test.sh`, create issues automatically,
   rotate metadata, or write registry state.

### Verification checklist

- [ ] Pull-request/manual execution proves the host baseline checks run before
  bootstrap and name the failed tool/reference when a fixture branch supplies
  an unreachable digest.
- [ ] A successful live run completes disposable bootstrap, baseline smokes,
  and public catalog verification on Linux `amd64`.
- [ ] The workflow uses attached clean local `main`, an absolute disposable
  config root, exact installed launcher paths, and no startup-file mutation.
- [ ] Workflow permissions are read-only and authenticated image skips are
  visible in manifest output.
- [ ] Existing `.github/workflows/test.yml` and the default offline suite remain
  unchanged unless a discovered integration dependency requires a focused
  update.
- [ ] Workflow YAML review and `git diff --check` pass; the GitHub Actions run
  itself is the live acceptance evidence.

### Human review gate

Confirm the scheduled run is enabled, its failure is operationally visible,
the Skopeo self-dependency is broken by the first check, and no workflow has
write authority or automatic rotation behavior.

## Chunk 4 — Governance and final integration

Expected reasoning: **medium**.

### Goal

Make the new availability/rollback requirement canonical across contributor
instructions, templates, skills, and user documentation, then complete the full
repository verification gate.

### Files

- `CONTEXT.md`
- `CONTRIBUTING.md`
- `README.md`
- `BOOTSTRAP.md`
- `docs/podman.md`
- `docs/testing.md`
- `docs/prompt-shimmy-project.md`
- `docs/templates/generic-shim/SKILL.md`
- `docs/templates/generic-shim/AGENTS.md`
- `plugins/shimmy/skills/shimmy-create-tool/SKILL.md`
- `plugins/shimmy/skills/shimmy-tool-local-build/SKILL.md`
- any canonical source/test inventory found to render or validate those assets
- this plan's progress, verification notes, and lessons

### Implementation requirements

1. State explicitly that immutable identity and byte retention are separate:
   Git history retains a digest identifier but is not a rollback store.
2. Document the baseline GHCR ownership rule, permanent tags, no-delete rule,
   manual mirror authorization, exact digest preservation, public anonymous
   proof, and scheduled liveness ownership.
3. Define rotation in this order: inspect exact publisher index; review version,
   media type, platforms, and access; mirror with digest preservation; prove
   destination access; update metadata; run native smokes; retain the prior
   mirrored tag.
4. Preserve the general rule that all defaults are immutable multi-platform
   index digests. For non-baseline images, require liveness verification and an
   explicit availability assessment without falsely claiming they are already
   mirrored.
5. State that a new tool proposed for the bootstrap baseline must obtain a
   retained public mirror before it can join the baseline. Ordinary tools do
   not silently become baseline dependencies.
6. Keep canonical skill headers exact. Do not edit generated `.agents/skills/`
   copies; validate canonical bundle semantics instead.
7. Do not mechanically rewrite accurate corporate registry redirect/mirror
   terminology, which has a separate ownership and runtime-routing meaning.
8. Run focused checks first, then the full default suite once using its bounded
   parallel runner. Rerun only failures serially.

### Verification checklist

- [ ] Live guidance consistently distinguishes identity, availability,
  retention tags, upstream discovery, mirroring, rotation, and rollback.
- [ ] Canonical create/local-build skills and generic templates contain the
  same requirements without claiming all current images are mirrored.
- [ ] Canonical skill header/fingerprint and semantic source checks pass.
- [ ] Focused affected groups pass with `--jobs 3` where two or more groups are
  selected.
- [ ] `./tests/test.sh` passes once with default bounded parallel execution.
- [ ] All runnable shell files pass `/bin/sh -n` and retain executable modes.
- [ ] Context-tree, catalog inventory, final installed asset inventory, and
  `git diff --check` pass.
- [ ] Current live GHCR baseline inspection, the scheduled workflow result, and
  both native baseline smoke records remain valid at final review.

### Human review gate

Confirm all four chunks are complete, no partial verification is hidden, the
full suite and live evidence pass, and the documented operational owner accepts
GHCR retention and workflow-failure response responsibility. Only then may the
plan be marked complete.

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| GHCR package is published private or loses public visibility. | Fresh anonymous bootstrap fails despite retained bytes. | Block cutover on anonymous exact-digest inspection; scheduled workflow continuously rechecks it. |
| Copy rewrites the manifest/index. | Reviewed upstream digest no longer identifies runtime bytes. | Require `--all --preserve-digests` and equality of source/destination top-level digests. |
| A maintainer deletes a retention tag/package. | Historical rollback and possibly current bootstrap disappear. | Permanent `retained-*` convention, no-delete workflow, public liveness alert, documented ownership. |
| Mirror workflow becomes an arbitrary registry-copy primitive. | Repository token or package namespace can be abused. | Derive source/destination from validated catalog metadata and fixed owner; accept only exact digest input. |
| Skopeo pin disappears and prevents `catalog verify`. | Normal verifier cannot diagnose its own missing runtime. | Host Podman checks the three baseline manifests before disposable bootstrap. |
| Upstream tag moves between discovery and copy. | An unreviewed artifact is mirrored. | Workflow accepts an exact digest, not a mutable tag; re-inspect evidence immediately before authorization. |
| Baseline mirror hard-codes a personal namespace. | Repository transfer requires coordinated package migration. | Treat `ghcr.io/wadebee/shimmy-*` as an explicit permanent invariant for this repository; plan a separate schema/authority migration before any transfer. |
| Daily full public verification is rate-limited or transiently unavailable. | False alarm or missed signal. | Keep exact result categories, allow manual rerun, and never auto-rotate from a failed check. |
| Only Linux CI is continuously available. | arm64 descriptor exists but runtime regression is undetected. | Retain native Apple Silicon smoke as a required cutover/final gate; metadata checks do not replace it. |
| Authenticated images are skipped. | A non-baseline private digest may disappear unnoticed. | Make skips visible and retain explicit credentialed manual verification; broader policy remains excluded. |

## Lessons learned

### Initial

- The 2026-08 Skopeo failure was a real registry-side loss of the configured
  top-level digest; jq and rg pulled successfully and the current Skopeo tag
  still exposed both required platforms.
- A digest provides content identity only while some registry retains its
  manifest and blobs. A Git commit containing the digest cannot restore them.
- Shimmy already separates mutable upstream discovery from immutable defaults,
  so a retained mirror can be adopted without an image schema transition.
- Bootstrap validates and prepares jq, rg, and Skopeo before committing the
  profile; this is the correct transactional boundary but currently lacks
  enough failure context.
- `catalog verify` already classifies pinned unreachability and platform shape,
  but its active-profile Skopeo dependency requires an out-of-band baseline
  check.
- The normal workflow is offline and unscheduled, so current correctness can
  pass while remote bootstrap availability silently decays.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, root `CONTEXT.md`, `CONTRIBUTING.md`, this complete plan,
   and every child `CONTEXT.md` on the path to the active chunk's files.
2. Read the current versions of all files listed for the active chunk and check
   `git status` before editing. Preserve unrelated user work.
3. Reverify current upstream and GHCR state because registry facts are unstable;
   do not replace recorded design decisions with a mutable fallback.
4. The non-negotiable boundaries are POSIX shell, Podman as an explicit
   dependency, immutable top-level multi-platform digests, no automatic tag
   advancement, no generated `.agents/skills/` edits, and explicit authorization
   for every external GHCR write or package-visibility mutation.
5. Active work begins at the first unchecked chunk in **Progress Checklist**.
   Execute only that chunk, update checklist/lessons/evidence, surface every
   `[~]` item, and stop at its human review gate.
