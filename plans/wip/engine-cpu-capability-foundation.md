# Engine CPU Capability Foundation

## Objective

Implement a clean-breaking, engine-aware CPU compatibility foundation that
prevents a Shimmy profile from adopting a catalog image option whose known
instruction-set requirements exceed the profile's bound Podman execution
engine.

Success means:

- agent skill discovery records an evidence state and, when defensible, a
  normalized CPU requirement or lower bound for every credible image option,
  without filtering candidates by the discovery host;
- the catalog remains a host-independent superset of selectable image options;
- every supported engine record owns a validated architecture observation and,
  for `linux/amd64`, one normalized effective x86-64 level;
- every installed tool version has exactly one profile-owned adoption selection
  that refers to an option in the profile's pinned catalog generation;
- bootstrap, profile create/clone/sync, and shim add/sync resolve the complete
  candidate selection set against the trusted bound-engine record before the
  first image pull or local build and commit the selections transactionally;
- installed runtimes consume the persisted selection without mutating or
  narrowing the retained catalog generation; and
- ownership, path-safety, locking, manifest-last, exact-machine proof,
  rollback, active-record, registry-projection, and skill-link invariants remain
  intact.

The clean transition removes compatibility readers, explicit migration paths,
fixtures, and documentation that exist only for installations created by the
prior contract. Other code or coverage may be removed only after its protected
behavior is mapped and shown to be obsolete. If that cannot be established
with high confidence, stop for user direction rather than deleting it.

This foundation does not implement per-tool routing across local, remote, GPU,
or emulated engines. It also does not guarantee compatibility for explicit
`SHIMMY_<TOOL>_IMAGE` or local-build base overrides, or for direct source-
checkout execution outside profile adoption. Those remain documented,
user-selected escape hatches. The foundation must leave an explicit extension
boundary for future routing without adding speculative GPU, remote-engine, or
emulation behavior now.

On macOS, bootstrap does not use `podman-machine-default` or any other pre-
existing machine as a temporary execution engine. Registry-policy staging is a
host-filesystem transaction, while capability observation and image
preparation occur only on the newly created Shimmy-owned `shimmy-default`.

## Target layout and terminology

- **Image option**: one stable, version-local choice for the complete runtime
  image strategy: either an immutable external runtime image or a local-build
  recipe with its selected immutable bases. It owns a safe option ID, platform
  descriptors, CPU requirement evidence, provenance, registry access, and
  deterministic catalog preference. An option is not merely one base record
  inside a multi-base build.
- **CPU requirement**: the normalized minimum instruction-set contract for one
  image option on one OCI platform, plus whether the value is an exact
  requirement, a lower bound, or unknown, and its evidence state/source.
  Missing OCI CPU metadata is not evidence of baseline compatibility.
- **Engine capability observation**: normalized effective capabilities exposed
  to workloads by one exact Podman execution engine, including the execution
  architecture. This is distinct from the workstation CPU when the engine is a
  VM or remote backend.
- **Compatibility resolution**: the deterministic comparison of an image
  option's platform requirement with one engine observation. Its result is
  `compatible`, `incompatible`, or `indeterminate`; selection eligibility for
  an indeterminate result remains an explicit policy decision.
- **Adoption selection**: the profile-owned, persisted image option chosen for
  a tool version after compatibility resolution.
- **Future engine route**: a later profile-owned tool-to-engine selection that
  may choose local native, remote architecture/GPU, or explicit emulation
  targets. It is not part of this plan.

Target ownership is:

```text
discovery/catalog  -> available image options and declared requirements
engine             -> observed effective execution capabilities
profile adoption   -> compatible option selection for the bound engine
runtime            -> selected immutable option on the current bound engine
future routing     -> tool-to-engine selection (deferred)
```

Target schema identities are independent:

```text
catalog.conf                         catalog_schema=1 (layout unchanged)
tools/<tool>/versions/<v>/image.conf shimmy_image_config_version=2
engines/<id>/engine.conf             shimmy_engine_version=2
profiles/<name>/install-manifest.txt shimmy_profile_manifest_version=3
profiles/<name>/engine-binding.conf  shimmy_engine_binding_version=1 (unchanged)
```

The profile manifest contains exactly one lexically ordered
`image_selection=<tool>|<version>|<option-id>` record for every
`shim_version` record and no selection for an unmaterialized version. Installed
version directories remain byte-identical to their pinned catalog sources; the
selection record, not a rewritten `image.conf`, supplies the profile-specific
choice.

### Normalized x86-64 levels

The initial CPU compatibility contract uses only the cumulative x86-64 psABI
microarchitecture levels. Image and engine manifests store the normalized
level, never the raw flag set.

| Level | Required capabilities |
| --- | --- |
| `x86-64-v1` | CMOV, CX8, FPU, FXSR, MMX, OSFXSR, SCE, SSE, SSE2 |
| `x86-64-v2` | All v1 capabilities plus CMPXCHG16B, LAHF-SAHF, POPCNT, SSE3, SSE4.1, SSE4.2, SSSE3 |
| `x86-64-v3` | All v2 capabilities plus AVX, AVX2, BMI1, BMI2, F16C, FMA, LZCNT, MOVBE, OSXSAVE |
| `x86-64-v4` | All v3 capabilities plus AVX512F, AVX512BW, AVX512CD, AVX512DQ, AVX512VL |

Levels v3 and v4 require the corresponding extended register state to be
enabled by the execution environment, not merely physical instruction support.
Other CPU flags remain outside this foundation unless a future capability plan
demonstrates a concrete tool requirement.

## Recorded design decisions

1. The objective is the full CPU-capability foundation, not a discovery-skill-
   only correction.
2. Engine capabilities are a first-class ownership concept because a future
   Shimmy topology may route ordinary, architecture-specific, GPU, and
   emulated tools to different engines.
3. This plan is foundation-only. It does not add remote-engine lifecycle,
   per-tool multi-engine dispatch, GPU discovery, or emulation policy.
4. This is a clean transition. `image.conf` becomes schema 2, the engine record
   becomes schema 2, and the profile manifest becomes schema 3. The top-level
   catalog layout and engine-binding schemas remain at 1 because their owned
   structure does not change. No reader accepts both old and new forms.
5. Installations created by the prior contract must be removed with the version
   that created them and bootstrapped fresh. The `admin engine migrate`
   compatibility command, unbound-profile fallback, `legacy-isolated` binding
   mode, dual-read branches, forwarding guidance, fixtures, and tests are
   removed together; no negative test is added merely to prove their absence.
6. Apply YAGNI to capability scope: implement the minimum CPU contract needed
   for correct image adoption while preserving explicit schema-version
   extension points. Do not add speculative GPU, remote-engine, emulation, or
   arbitrary raw-feature fields.
7. The initial CPU contract is the cumulative x86-64 psABI level only.
   `linux/amd64` image requirements and engine observations use normalized
   `x86-64-v1` through `x86-64-v4`; raw feature flags are transient probe input
   and are never persisted. `linux/arm64` remains platform-compatible without
   introducing an ARM feature-level comparison; its exact record encoding is
   unresolved below.
8. On amd64 macOS, the side-effect-free creation preflight uses
   `sysctl -a | grep machdep.cpu` and normalizes the result only as a transient
   provisioning ceiling. It neither creates/starts a machine nor persists that
   host observation as the engine capability.
9. The compensated macOS engine-creation lifecycle writes durable intent and
   exact created-identity evidence before destructive authority, creates and
   starts the exact machine, then runs `lscpu` through
   `podman machine ssh <exact-machine>` to observe the guest architecture and,
   on amd64, its CPU flags. Only after parsing and normalizing that execution-
   environment result may it publish the final schema-2 engine record and commit
   the engine boundary. The lifecycle phase order must change rather than
   publishing a capability-less final engine record before start.
10. On Linux, fresh bootstrap validates the supported host-local rootless
    engine, runs local `lscpu`, and publishes the normalized observation in the
    shared engine record. Linux creates no machine.
11. A fresh engine boundary cannot commit without a schema-valid capability
    observation for its architecture. Probe, parsing, normalization, or record-
    validation failure enters the existing compensated rollback path. This is
    a permanent integrity invariant, and one authoritative negative test is
    explicitly approved to protect it.
12. CPU observation occurs only when a Shimmy-owned lifecycle creates a fresh
    engine boundary. Activation, profile/shim adoption, sync, runtime
    invocation, status, and dry-run do not refresh it. Adoption trusts the
    persisted record and does not add a connection check or engine smoke solely
    for CPU compatibility. This plan adds no engine-replacement command; any
    future replacement lifecycle must re-observe the engine and re-resolve every
    bound profile atomically before it publishes the replacement boundary.
13. Discovery remains host-independent and metadata-only. It retains all
    credible candidates, never pulls or runs them, and records CPU evidence
    from OCI declarations and authoritative publisher, source, build, or base-
    image evidence.
14. CPU compatibility is a functional gate, separate from the discovery
    skill's weighted security-posture score.
15. Every concrete tool version owns one schema-2 `image.conf` containing one
    or more complete version-local image options. The tool release identity
    remains independent from the chosen option; no central implementation
    router or CPU-specific concrete-version label is introduced.
16. CPU requirements live inline with each image option. Profile state persists
    only `tool|version|option-id`; it does not duplicate digests, sources,
    requirements, evidence, or registry metadata. No new digest or fingerprint
    is computed solely for a CPU requirement or engine observation; existing
    whole-file and catalog fingerprints continue to cover those bytes.
17. Image evidence has three states. `confirmed` means an exact OCI declaration
    or authoritative publisher requirement applies to the option or image
    family. `inferred` means authoritative lineage, a documented base
    requirement, or corroborated exact-image failure evidence establishes a
    credible exact requirement or lower bound. `unknown` means no defensible
    normalized level is established. Absence of an OCI variant never implies
    `x86-64-v1`.
18. Requirement relation and evidence confidence are separate. A lower bound
    above the engine proves `incompatible`; a lower bound at or below the
    engine remains `indeterminate` because the final image may add a stricter
    requirement. An exact normalized requirement can yield `compatible` or
    `incompatible`. The policy for selecting any remaining indeterminate option
    is unresolved below.
19. The discovery skill owns inference. It presents every inferable option with
    its normalized exact value or lower bound, evidence source, remaining
    uncertainty, and consequences, then interviews the user. It never silently
    promotes an inference to confirmed evidence.
20. An inferred option enters the creation handoff and catalog only after the
    user specifically affirms that exact option. The handoff carries its stable
    option identity, immutable digest or local-build inputs, normalized exact
    value/lower bound, evidence source, `evidence=inferred`, and explicit
    acceptance. Generic acceptance of all inferred candidates is insufficient,
    and acceptance does not relabel the evidence.
21. Profile adoption performs no research or interview. It reads only the
    pinned catalog's approved options and the trusted bound-engine record, then
    applies the recorded deterministic selection policy. Evidence labels remain
    audit metadata; requirement relation affects the comparison result.
22. Profile adoption owns image-option matching. Host-specific selections do
    not rewrite or narrow retained catalog generations, and materialized
    version directories remain byte-identical to the catalog.
23. The profile manifest contains exactly one selection for every materialized
    `shim_version`. Pure profile-state validation proves cardinality and
    referential integrity against the pinned catalog. The adoption transaction
    separately proves compatibility against the trusted bound-engine record
    before preparation and commit. Runtime helpers require and resolve the
    persisted selection without re-probing or reselecting; missing, duplicate,
    cross-version, or nonexistent option identities invalidate the profile
    before execution.
24. Bootstrap's current baseline (`jq`, `rg`, and Skopeo, subject to future
    catalog change) is one atomic compatibility plan. Every baseline selection
    resolves from the engine record before the first pull/build, and all are
    persisted in the same outer compensated bootstrap transaction.
25. Profile create/clone, profile sync, and shim add/sync stage a complete
    selection set and resolve every changed or retained version before the
    first image preparation and before manifest-last commit. No lifecycle may
    leave an installed version with a stale or absent selection.
26. Explicit `SHIMMY_<TOOL>_IMAGE` and local-build base overrides remain
    user-owned runtime escape hatches and are documented as bypassing catalog
    adoption compatibility. Source checkout preview/execution has no profile
    selection and uses the schema-2 manifest's deterministic catalog-preferred
    option; it is outside the profile-adoption guarantee.
27. Only canonical management skills under `plugins/shimmy/skills/`, canonical
    tool skills, guides, and generic templates may change. Active-profile copies
    and generated skill adapters remain untouched.
28. Full tool-to-engine routing remains recorded separately in
    `plans/notional/TODO.md` and requires its own PLAN -> REVIEW -> ACT cycle.
29. Reuse existing SHA-256 fingerprint helpers when a whole-file or content
    identity is required instead of introducing a CPU-specific digest format.
30. macOS bootstrap never adopts or uses `podman-machine-default` or another
    pre-existing machine for registry setup, capability observation, image
    pulls, or local builds. It may read existing machine/connection state only
    as required by the established collision and restoration safeguards. The
    private default-profile candidate supplies the registry-policy bytes for a
    provisional shared-engine projection; the projection records the eventual
    canonical `profiles/default/registries.conf` authority path and its
    fingerprint separately from that temporary byte-source path. Bootstrap
    creates and starts only the exactly proven Shimmy-owned `shimmy-default`,
    observes it, resolves selections, and prepares images there. Candidate
    commit then publishes the same-fingerprint registry policy and the complete
    manifest last, validates the final authority/projection relationship, and
    only then commits the outer bootstrap transaction.
31. Stop and interview the user when a significant implementation path remains
    unclear and cannot be safely inferred from these decisions.

## Verified implementation inventory

This inventory is a verified planning baseline, not permission to ignore new
dependencies discovered during implementation.

- `plugins/shimmy/skills/shimmy-tool-discover/SKILL.md` currently proves OCI
  platform presence only, forbids runtime claims from metadata alone, and has
  no structured per-platform CPU fields in either handoff.
- `plugins/shimmy/skills/shimmy-create-tool/SKILL.md` treats a dual-architecture
  index plus native architecture smokes as its portability contract; it does
  not consume a CPU requirement.
- `plugins/shimmy/skills/shimmy-tool-local-build/SKILL.md`,
  `plugins/shimmy/skills/shimmy-catalog/SKILL.md`, and
  `docs/templates/generic-shim/` also describe the schema-1 single-strategy
  contract and are required consumers of the cutover; the original plan omitted
  them.
- `lib/runtime/image.sh` schema 1 permits exactly one image strategy per
  concrete version and rejects unknown metadata keys. Supporting a catalog
  superset of CPU-differentiated options is therefore a coordinated schema
  transition, not a skill-only addition.
- The catalog currently contains 24 concrete `image.conf` manifests: 12
  external-image strategies and 12 local-build strategies. Every one must move
  to schema 2 in the atomic cutover, even when its only defensible CPU evidence
  is `unknown`; changing only selected tools would make the catalog invalid.
- `lib/runtime/podman.sh` normalizes OS/architecture to `linux/amd64` or
  `linux/arm64`; it does not determine x86-64 ISA levels. It also directly
  validates installed profile-manifest version 2 during runtime affinity, so
  the profile schema bump affects runtime state validation as well as the
  manifest reader/renderer.
- `lib/images/images.sh` and `shimmy catalog verify` validate index media type
  and required architecture descriptors only.
- Profile manifests record tool/version policy but no adopted image option.
  `lib/install/manifest.sh`, `lib/profile/state.sh`, `lib/install/profile.sh`,
  `lib/shim/shim.sh`, fixtures, and status renderers are direct profile-manifest
  producers or consumers. Materialized tool versions are currently required to
  remain byte-identical to their catalog sources.
- Every external runtime calls `shimmy_image_external_default_read`; every
  local-build runtime routes its defaults through the shared image helper.
  Existing per-tool `SHIMMY_<TOOL>_IMAGE` and base-image overrides bypass those
  defaults. `commands/run-tool.sh` executes source versions without a profile
  manifest, so source selection and explicit overrides require a documented
  boundary rather than an implicit profile lookup.
- Engine records are strict schema 1 and are currently published before a new
  macOS machine is started. The creation journal already retains exact created-
  identity and ownership evidence, allowing the final engine record to move
  after start/probe without weakening rollback proof.
- The current compatibility surface includes `admin engine migrate`, unbound
  schema-2 profile fallback, `legacy-isolated` binding mode, dual-read runtime,
  activation, registry, status, help, documentation, and tests. The clean-
  transition decision requires removing this whole surface together rather
  than retaining an unobservable migration path.
- `shim add`, `shim sync`, and profile sync already stage complete profile
  candidates and prepare images before manifest-last commit.
- Shim add/sync and profile sync currently prepare candidate images before
  acquiring their commit locks. The selection resolver must therefore snapshot
  and later revalidate the exact engine record and catalog/profile authority,
  just as those lifecycles already revalidate manifest/catalog fingerprints.
- Profile create and clone commit the new profile candidate before creating an
  isolated engine and before target-engine image preparation. Fresh bootstrap
  likewise commits the default profile candidate before creating the macOS VM.
  The implementation must stage manifest-less materialization privately,
  establish/resolve the target engine, render the complete selected manifest,
  validate it, and only then expose the manifest-last profile candidate. Merely
  inserting a comparison before the existing pull/build call is insufficient.
- `shimmy_engine_projection_prepare` currently uses one profile registry path
  both as the bytes it reads and as the canonical authority path persisted in
  projection state. Bootstrap/new-engine staging needs these roles separated:
  read and fingerprint the private candidate file while recording the eventual
  final profile path, then prove that the published file has the same
  fingerprint before outer commit.
- Existing bootstrap policy deliberately refuses to adopt a pre-existing
  machine and names its owned macOS shared engine `shimmy-default`. Using
  Podman's conventional `podman-machine-default` even temporarily would expand
  ownership, workload-interruption, connection-restoration, CPU-authority, and
  VM-local image-storage scope without solving the host-file staging
  dependency.
- The Skopeo 1.22 external runtime image currently uses UBI 10. Red Hat
  documents that RHEL/UBI 10 x86_64 images require x86-64-v3, while the current
  metadata and guide claim only `linux/amd64`/`linux/arm64` compatibility.
- OCI image-index platform metadata can declare an amd64 `variant`, but the
  platform descriptor and variant are optional and the general `features`
  field is reserved. Absent metadata cannot be treated as proof of x86-64-v1.
- Podman on macOS and Windows executes through a Linux VM, and hypervisors can
  mask x86 capabilities. Arbitrary remote Podman backends can also differ from
  the client workstation, but Shimmy does not currently support their routing.
- `plans/wip/hybrid-podman-engine-lifecycle.md` has all implementation chunks
  applied but still awaits final human acceptance, and
  `plans/wip/shared-machine-rollback.md` is implemented and awaiting review.
  Both overlap the engine creation/rollback files in this plan. ACT must not
  begin until those review gates are resolved or the user explicitly
  supersedes them; this plan does not rewrite their historical evidence.

Authoritative technical references:

- <https://access.redhat.com/support/policy/rhel-container-compatibility>
- <https://developers.redhat.com/articles/2024/01/02/exploring-x86-64-v3-red-hat-enterprise-linux-10>
- <https://github.com/opencontainers/image-spec/blob/v1.1.1/image-index.md>
- <https://docs.podman.io/en/stable/markdown/podman-machine.1.html>
- <https://docs.podman.io/en/stable/markdown/podman-machine-start.1.html>
- <https://docs.podman.io/en/stable/markdown/podman-machine-ssh.1.html>

## Unresolved

1. **ARM64 record encoding.** A capability record is mandatory for every engine,
   but the normalized feature contract is x86-only. Choose whether
   `linux/arm64` records use an explicit `cpu_level=not-applicable` sentinel or
   omit the level field under an architecture-specific schema branch.
   Recommended: require `architecture=linux/arm64` plus the explicit sentinel;
   this preserves canonical record shape and proves that omission is not probe
   failure.
2. **Indeterminate image policy.** Decide whether an `unknown` requirement, or
   an inferred lower bound that does not exceed the engine, remains reportable
   and catalog-valid but unselectable, or may become adoption-eligible through
   an explicit per-option risk acceptance. Recommended: keep both catalog-valid
   but unselectable; allow accepted inferred *exact* requirements to compare
   normally. This is fail-closed but may make some existing tools unavailable
   until stronger evidence or an alternative option is added. Also decide
   whether incompatible/indeterminate unselectability is a permanent adoption-
   integrity invariant that approves one lowest-cost authoritative negative
   proof. Recommended: yes, with no command-specific duplicates.
3. **Deterministic selection policy and UX.** Decide how adoption chooses among
   multiple eligible compatible options. Recommended: schema 2 requires a
   unique positive catalog preference per option and rejects ties; adoption
   chooses the eligible option with the smallest preference value and reports
   the chosen option in dry-run/status output. This preserves discovery's
   explicit user-reviewed ordering instead of inventing host-time security
   ranking.
4. **Clone and sync semantics.** Decide whether clone preserves or re-resolves
   selections and how sync handles an option that disappears, changes identity,
   or gains a stricter requirement. Recommended: clone always re-resolves the
   complete selection set against the target engine record; sync re-resolves
   against the new pinned catalog and aborts before pull/commit when no eligible
   option exists, leaving the prior profile byte-valid. Neither lifecycle
   performs a live CPU probe.
5. **Current Skopeo correction.** Decide whether this plan must add a Skopeo
   option compatible with x86-64-v1/v2 as the first production multi-option
   acceptance case, or may retain only the current UBI 10 v3 option and fail
   bootstrap cleanly on older engines. Recommended: add and natively verify a
   compatible option so the baseline demonstrates both selection branches;
   discovery must identify the exact image rather than assuming a UBI 9 family
   is functionally equivalent.
6. **Refresh option targeting.** A multi-option manifest makes “refresh this
   version” ambiguous. Decide how a refresh invocation selects the owned option
   whose external digest or local-build inputs may change. Recommended: require
   an explicit safe option ID whenever a version has multiple options, permit
   omission only for a single-option manifest, and reject a target that does not
   belong to the concrete version. Refresh must not infer from the active
   profile because canonical catalog maintenance is host-independent.

## Progress Checklist

- [x] Chunk 1 — Remove obsolete migration/dual-read compatibility as one clean cut.
- [ ] Chunk 2 — Publish schema-2 engine capability observations at engine-creation boundaries.
- [ ] Chunk 3 — Atomically cut over image options, profile selections, runtime consumption, and every adoption lifecycle.
- [ ] Chunk 4 — Exercise the production Skopeo case and close documentation and acceptance.

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

## Provisional implementation chunks

These chunks will become decision-complete only after every unresolved item is
resolved through the interview.

## Chunk 1 — Clean-transition compatibility removal

### Goal

Remove the now-obsolete engine migration and dual-read compatibility surface so
the CPU schemas can be introduced against one strict fresh-install state.

### Files

Primary areas: `commands/admin.sh`, `commands/help.sh`, `lib/engine/`,
`lib/profile/`, `lib/runtime/podman.sh`, `lib/registries/`, `lib/install/`,
`lib/update/`, affected command/library/lifecycle tests, `README.md`,
`BOOTSTRAP.md`, `commands/README.md`, `docs/podman.md`,
`docs/ARCHITECTURE.md`, root/child `CONTEXT.md` files, and canonical management
guidance that still exposes migration.

### Implementation requirements and suggested reasoning level

High reasoning: treat compatibility removal as one public-contract unit.

- Remove `shimmy admin engine migrate [--dry-run]` from parsing, help, surface
  documentation, and status advice while retaining read-only engine status for
  the strict current registry.
- Remove unbound-profile engine fallback, `legacy-isolated`, installation
  migration-state branching, and dual-read activation/runtime/registry logic.
  A supported profile must have one valid binding to one valid engine record.
- Remove migration-only forwarding paths, fixtures, and tests together. Retain
  tests for ownership ambiguity, unsafe paths, collisions, transactional
  rollback, external engine preservation, and unknown options when those
  protect current invariants.
- Update bootstrap/install/profile/update validation and all applicable
  contexts/docs to describe fresh strict engine state only. Do not add a
  compatibility reader or in-place conversion under a different name.
- Do not add negative coverage merely to prove the removed command or fields
  remain absent.

### Verification checklist

- [x] Fresh bootstrap, strict bound-profile status/activation, shared and
  isolated create/clone, sync, runtime affinity, and uninstall remain
  operational without any migration state.
- [x] Engine/profile state tests positively prove the strict binding and record
  contract; retained ownership, path-safety, collision, rollback, and external-
  preservation invariants still have one authoritative proof each.
- [x] Public help, README/Bootstrap/Podman/architecture guidance, contexts, and
  canonical management guidance contain no current instruction to migrate or
  dual-read an old installation; historical retained plans remain untouched.
- [x] Relevant independent test groups pass with default bounded parallelism,
  followed by syntax, executable-mode, context-tree, and `git diff --check`
  validation.

### Human review gate

Confirm that only obsolete compatibility behavior was removed and that current
engine ownership, routing, activation, and destructive safeguards remain
observable before changing the engine-record schema.

Accepted and verified by the user on 2026-08-29. Chunk 2 remains unauthorized.

## Chunk 2 — Engine capability observation boundary

### Goal

Introduce normalized CPU detection and schema-2 engine records, publishing an
effective execution-environment observation only at fresh engine creation.

### Files

Primary areas: a narrow `lib/engine/capability.sh` module (or an equivalently
narrow engine-owned module), `lib/engine/state.sh`, `lib/engine/podman.sh`,
`lib/engine/lifecycle.sh`, `lib/engine/registry.sh`, `lib/install/lifecycle.sh`,
`lib/profile/` status/preflight consumers, installed asset inventories,
engine/profile-activation/lifecycle tests, and applicable contexts/docs.

### Implementation requirements and suggested reasoning level

High reasoning: the engine record is an atomic schema/transaction transition.

- Implement POSIX-shell normalization of transient `lscpu`/`sysctl` flags to
  cumulative x86-64 v1-v4, including required OS-enabled extended state for v3
  and v4. Reject malformed, contradictory, or insufficient probe output rather
  than guessing a level.
- Render/read/validate only schema-2 engine records. Record the normalized
  execution platform and the resolved architecture-specific CPU value selected
  in Unresolved item 1; never persist the raw flag set or host preflight.
- On amd64 macOS, run the side-effect-free `sysctl` ceiling before machine
  mutation. On actual shared/isolated creation, keep journal-first exact
  identity proof, start the machine, observe the guest architecture through
  `podman machine ssh <exact-name>`, collect `lscpu` flags there only for amd64,
  then publish the final engine record before engine commit. On Apple Silicon,
  record the observed guest architecture using the resolved ARM64 encoding
  without inventing an x86 level.
- On Linux fresh bootstrap, validate the local rootless engine, run local
  `lscpu` on amd64 (or use the resolved ARM64 encoding), and publish the shared
  record before profile/image adoption.
- Preserve lifecycle journals as the rollback authority while the final engine
  record is not yet published. Capability failure after machine start must
  remove only an exactly proven newly created machine or retain the existing
  ambiguous journal/root for recovery.
- Shared profile create/clone, ordinary activation/status, tool adoption, sync,
  and runtime must read but never refresh the observation. An isolated create
  or isolated clone observes its newly created target.
- Keep `profile create/clone --dry-run` side-effect free. For a proposed new
  isolated engine, report host-preflight results as a provisional ceiling, not
  as a committed engine observation or guaranteed final selection.

### Verification checklist

- [ ] Normalization fixtures cover the cumulative v1-v4 success cases and
  architecture-specific record form without persisting raw flags.
- [ ] Schema-2 engine records round-trip canonically and every fresh
  Darwin/Linux engine producer and consumer uses only the new schema.
- [ ] macOS shared and isolated creation publish no final engine record before
  start/probe; successful creation records the exact machine observation before
  engine commit.
- [ ] The one approved authoritative negative test proves probe/parse/record
  failure prevents engine commit and enters exact existing compensation.
- [ ] Activation, status, shared profile creation, sync, shim mutation, and
  runtime do not invoke `sysctl`, `lscpu`, machine SSH, or connection validation
  solely to refresh CPU state.
- [ ] Isolated dry-run remains non-mutating and clearly labels its ceiling as
  provisional.
- [ ] Focused engine, activation, bootstrap, lifecycle, syntax, modes, context,
  and diff checks pass with bounded parallelism where independent.

### Human review gate

Confirm normalized record bytes, probe sources, post-start publication order,
dry-run semantics, and exact rollback evidence before using the observation to
gate profile adoption.

## Chunk 3 — Atomic image-option and profile-selection cutover

### Goal

Cut over every image-schema producer/consumer and every profile-adoption
lifecycle in one review unit so all installed versions have valid, compatible,
transactionally persisted selections before image preparation.

### Files

Primary areas: `lib/runtime/image.sh`, `lib/runtime/podman.sh`, `lib/catalog/`,
`lib/images/`, `lib/install/manifest.sh`, `lib/install/profile.sh`,
`lib/install/lifecycle.sh`, `lib/engine/projection.sh`,
`lib/engine/registry.sh`, `lib/profile/`, `lib/shim/`, `lib/update/profile.sh`,
`commands/catalog.sh`, `commands/profile.sh`, `commands/shim.sh`, status
renderers, all 24 `tools/*/versions/*/image.conf` files and affected runtimes,
refresh hooks/guides/skills, `plugins/shimmy/skills/shimmy-tool-discover/`,
`shimmy-create-tool/`, `shimmy-tool-local-build/`, `shimmy-catalog/`,
`docs/templates/generic-shim/`, contributor/project guidance, catalog/profile/
runtime/shim/lifecycle tests and fixtures, and every applicable context.

### Implementation requirements and suggested reasoning level

Very high reasoning: this intentionally large chunk is one image/profile schema
identity transition. Do not split its producers, consumers, validators,
fixtures, transaction boundaries, or generated shell behavior across review
gates.

- Define strict schema-2 numbered option records for complete external and
  local-build strategies. Require safe stable option IDs, both current
  platforms, immutable runtime/base defaults, registry access, evidence state
  and source, exact/lower-bound/unknown relation, normalized amd64 requirement
  where known, and the resolved unique catalog preference. Keep the top-level
  catalog schema at 1.
- Convert all 24 production manifests in the same cutover; schema 1 is no longer
  readable. Preserve local-build context hashing, override argument behavior,
  stale cleanup, platform tagging, and remote verification for every selected
  option.
- Implement a pure deterministic compatibility/selection resolver using only a
  validated schema-2 engine record and pinned schema-2 image manifests. Apply
  the resolved policies for indeterminate options and ordering without
  tool-name cases or host-time security scoring.
- Bump only the profile manifest to schema 3 and add exactly one lexically
  ordered `image_selection` for every `shim_version`. Keep pure profile-state
  validation responsible for selection cardinality, tool/version ownership,
  option existence, and catalog pin; make the adoption resolver validate engine
  compatibility before preparation/commit. Keep materialized version trees
  byte-identical to their catalog sources.
- Make installed runtime helpers require the profile's persisted option and
  resolve its external reference or local-build inputs from the copied
  `image.conf`. Source checkout preview/execution uses the catalog-preferred
  option. Preserve explicit image/base overrides and document that they bypass
  adoption compatibility.
- Update every profile manifest producer/consumer, direct runtime affinity
  version check, status/dry-run output, fixture, and generated artifact. Inspect
  and exercise rendered wrapper/manifest output rather than relying only on
  renderer source.
- For macOS bootstrap and a new isolated create/clone, keep the entire
  materialized profile candidate private and initially omit its final manifest.
  Extend projection preparation to accept separate validated byte-source and
  eventual canonical-authority paths: read/fingerprint the candidate's
  `registries.conf`, render the provisional engine projection against the
  future final profile path, and expose no partial profile root. Establish and
  observe the exactly created target engine; resolve the complete selection
  set; render and validate the selected manifest inside the private candidate;
  and prepare images through a candidate-aware API that reads that exact
  manifest without installed-profile affinity. Under the existing locks,
  revalidate the engine/catalog/candidate fingerprints, commit candidate assets
  with the manifest last, prove the published registry file matches the
  projection's recorded authority and fingerprint, and only then commit the
  outer transaction. Never use a pre-existing Podman machine for this sequence.
- For shared create/clone, profile sync, shim add, and shim sync, snapshot the
  bound schema-2 engine record and catalog/profile authority, resolve and render
  the complete resulting selection set in the private candidate before the
  first pull/build, and revalidate those exact authorities under existing locks
  before manifest-last commit. Apply the resolved clone/sync semantics from
  Unresolved item 4.
- Bootstrap must resolve `jq`, `rg`, and Skopeo as one set before preparing any
  baseline image. A single ineligible baseline option aborts before the first
  pull/build and enters existing outer compensation.
- Preserve discovery's no-pull/no-run boundary; distinguish confirmed,
  inferred exact, inferred lower-bound, and unknown evidence; keep credible
  options visible; obtain exact per-option acceptance for inference; and update
  discovery handoff plus create-tool consumer together.
- Make catalog verify enumerate every option and report declared platform/CPU
  metadata alongside remotely observable OCI descriptor evidence without
  treating omitted variant metadata as v1 proof. Refresh must update only the
  explicitly targeted option's owned references, using the interface resolved
  in Unresolved item 6, and preserve other option records.
- Update contributor docs, project prompt, generic templates, canonical skills,
  tool guides/skills, and contexts in the same schema cutover. Never edit
  active-profile or generated skill copies.

### Verification checklist

- [ ] All 24 schema-2 image manifests validate; catalog generations remain
  host-independent, content-addressed, and free of host-specific selections.
- [ ] External and local-build options round-trip deterministically, selected
  local image cache identity changes with effective option/build inputs, and
  source previews render the catalog-preferred option.
- [ ] Compatibility fixtures cover exact compatible/incompatible, lower-bound
  incompatible/indeterminate, unknown, ARM64, and deterministic option-ordering
  outcomes required by the resolved policies. If Unresolved item 2 approves a
  negative invariant proof, keep one authoritative lowest-cost proof rather than
  duplicating rejection scenarios across commands.
- [ ] Schema-3 profile manifests have exactly one valid selection per installed
  version; materialized versions remain byte-identical to their catalog sources
  and installed runtime consumes the persisted option.
- [ ] Bootstrap resolves its complete baseline before the first preparation;
  create/clone/sync and shim add/sync resolve against the correct snapshotted
  engine without a live CPU probe and preserve manifest-last rollback.
- [ ] macOS bootstrap/new-isolated staging exposes no partial profile root;
  provisional projection reads the private candidate policy but records the
  future canonical path, final publication proves the same fingerprint, and no
  operation uses `podman-machine-default` as a temporary execution engine.
- [ ] Injected failure before preparation, after preparation, after asset
  replacement, and during active/skill reconciliation restores the prior valid
  profile or the documented recoverable new-profile journal/root.
- [ ] Isolated dry-run shows provisional ceiling-based candidates without
  claiming a final engine selection; shared dry-run uses the trusted existing
  engine record and remains non-mutating.
- [ ] Discovery reports and hands off requirement relation/evidence without
  filtering by its host; creation consumes the handoff without inventing or
  relabeling facts.
- [ ] Catalog verify reports each option and preserves remote-inspection,
  authentication, registry-policy, and no-mutation boundaries; refresh changes
  only its exact explicitly targeted option.
- [ ] Canonical skills/templates/guides validate, rendered shell artifacts are
  parsed and exercised, generated/active-profile copies remain untouched, and
  focused independent groups pass with bounded parallelism.

### Human review gate

Confirm the atomic schema bytes, every converted manifest, selection results,
transaction ordering/rollback, provisional-to-canonical registry projection,
source/override boundary, discovery handoff, and catalog reporting before
native production acceptance.

## Chunk 4 — Production case and acceptance closure

### Goal

Exercise the chosen Skopeo production policy, validate the complete feature
across supported architectures and lifecycles, and close user documentation.

### Files

Primary areas: `tools/skopeo/versions/1.22/image.conf`, its runtime/refresh hook,
guide/skill/tests, any approved alternative option metadata, focused and full
lifecycle/tool acceptance, `README.md`, `BOOTSTRAP.md`, `commands/README.md`,
`docs/`, `CONTRIBUTING.md`, canonical management/tool guidance, contexts, and
this plan.

### Implementation requirements and suggested reasoning level

High reasoning: treat the current UBI 10 v3 requirement as a production fact
and apply the resolved Skopeo decision without claiming equivalence for an
unverified fallback.

- If an older-level Skopeo option is approved, use discovery evidence to add its
  exact immutable identity, explicit preference, requirement/evidence, entrypoint
  contract, registry behavior, and native acceptance. If no fallback is
  approved, document and exercise clean baseline refusal below v3 only if the
  adoption-integrity proof in Unresolved item 2 was approved; do not weaken the
  comparison.
- Demonstrate the selected Skopeo branch through ordinary bootstrap/adoption
  and its non-mutating version-owned smoke. Do not use cross-emulation as native
  acceptance.
- Align user/operator docs with strict fresh bootstrap, engine observation
  authority, provisional isolated dry-run, profile-owned selections, catalog
  evidence, source/override bypasses, and deferred multi-engine routing.
- Prefer positive observable acceptance. Add no negative coverage beyond the
  user-approved engine-capability commit invariant, the single adoption-
  integrity proof if approved in Unresolved item 2, and already authoritative
  security/ownership boundaries.
- Keep remote registry checks outside the default offline suite. Run focused
  groups while closing issues, then the default full suite with its bounded
  parallel runner; rerun only failures serially when diagnosis requires it.

### Verification checklist

- [ ] The current Skopeo UBI 10 option is recorded as x86-64-v3 and is selected
  only on a compatible amd64 engine.
- [ ] The resolved v1/v2 policy is demonstrated: either an exact compatible
  Skopeo option is selected and smoked, or bootstrap refuses before any image
  preparation with the incompatible baseline reported.
- [ ] Focused schema, runtime, engine, profile, shim, catalog, and lifecycle
  groups plus the default full suite pass with bounded parallelism.
- [ ] Shell syntax, executable modes, context tree, catalog inventory, canonical
  skills/templates, generated artifact identity, and `git diff --check` pass.
- [ ] Native Linux amd64 and Apple Silicon arm64 acceptance outcomes are
  recorded; an unavailable native lane is marked `[~]` with impact and next
  action rather than replaced by emulation.
- [ ] Bootstrap demonstrates engine observation, complete baseline resolution,
  and selection persistence before the first image preparation.
- [ ] Documentation distinguishes profile adoption from explicit overrides and
  direct source execution, and current bound-engine selection from deferred
  multi-engine routing.

### Human review gate

Confirm all acceptance evidence, partial items, risks, and documentation before
marking the plan complete.

## Risk register

- **Overlapping WIP lifecycle plans:** engine creation, migration, and rollback
  state are still awaiting human acceptance in retained WIP plans. Mitigation:
  treat their acceptance or explicit supersession as an ACT prerequisite and
  do not rewrite their historical evidence from this plan.
- **Clean-transition scope:** removing only the public migration command while
  retaining dual-read branches or `legacy-isolated` state would create
  unreachable compatibility code. Mitigation: inventory and remove the entire
  producer/consumer/docs/test surface as Chunk 1, retaining only independently
  current ownership and safety invariants.
- **Schema identity expansion:** multiple options and profile selections affect
  all 24 manifests and every catalog/profile/runtime producer and consumer.
  Mitigation: keep the image/profile cutover as one intentionally large review
  unit and inventory all fingerprints, fixtures, validators, generated shell,
  and rollback paths.
- **False compatibility:** OCI descriptors often omit ISA levels. Mitigation:
  never equate absent metadata with baseline support; separate exact, lower-
  bound, and unknown relations, retain evidence, and apply the approved
  indeterminate policy.
- **Probe correctness:** raw CPU flags can be incomplete, hypervisor-masked, or
  OS-disabled. Mitigation: prefer a normalized execution-environment result,
  retain its source, and test cumulative x86-level rules rather than checking
  only AVX/AVX2/FMA.
- **ARM64 ambiguity:** a mandatory record with an x86-only level can conflate
  unsupported architecture probing with failure. Mitigation: resolve and test
  an explicit architecture-specific record form before Chunk 2.
- **Bootstrap/new-profile partial state:** macOS needs a running new VM and
  projected registry policy before final capability and selection can be
  known, while the profile must remain unpublished. Mitigation: keep all
  profile assets private, separate the projection's candidate byte source from
  its future canonical authority path, fingerprint both, use only the exactly
  created target engine, publish the complete candidate manifest last, validate
  final authority, and retain current outer compensation.
- **Dry-run overclaim:** an isolated dry run can see only the host ceiling, not
  the future VM's effective flags. Mitigation: label results provisional and
  rerun resolution from the persisted engine record inside the actual
  transaction.
- **State drift:** an engine changed outside Shimmy could expose capabilities
  that differ from its trusted record. Mitigation: treat fresh compensated
  engine creation as the current authority boundary and do not add adoption-
  time or per-run probes. A future replacement feature must re-observe and
  transactionally re-resolve all profiles bound to that engine.
- **Concurrent authority drift:** sync and shim mutation currently prepare
  images before acquiring commit locks. Mitigation: snapshot the engine record,
  catalog generation, and profile manifest, then revalidate all three under the
  established lock hierarchy before manifest-last commit.
- **Override bypass:** explicit image/base overrides and source execution cannot
  be validated against a persisted adoption selection. Mitigation: keep them
  outside the guarantee, preserve explicit opt-in, and document the bypass at
  runtime and user-guidance boundaries.
- **Premature routing abstraction:** GPU, remote, and emulation requirements
  can turn a CPU fix into a dispatcher redesign. Mitigation: define an
  extensible capability boundary but implement only CPU matching against the
  currently bound engine.

## Lessons learned

### Initial

- Architecture membership (`linux/amd64`) is not proof of microarchitecture
  compatibility; RHEL/UBI 10 is a concrete x86-64-v3 counterexample.
- The catalog/profile split is necessary: requirements are catalog facts,
  whereas compatibility is resolved for an execution engine during adoption.
- The future local/remote/GPU/emulation topology supplies business value for
  engine-owned capability observations, but does not justify implementing
  multi-engine routing in this foundation.
- Bootstrap already has a safe post-engine-activation, pre-image-preparation
  seam for observing the actual macOS VM, but the current engine record is
  written before start and the new profile manifest is committed before that
  seam; both orderings must change rather than merely inserting a comparison.
- The manual evidence decisions require a three-way compatibility result.
  An inferred lower bound below the engine cannot prove compatibility, while a
  lower bound above the engine can prove incompatibility.
- A mandatory capability record must define a positive ARM64 representation;
  otherwise Apple Silicon bootstrap cannot satisfy the same invariant as
  amd64.
- The image/profile schema cutover cannot be safely split between producers and
  consumers without adding a prohibited temporary compatibility reader. It is
  therefore one intentionally large implementation chunk.
- The repository currently has 24 image manifests, not only the baseline three;
  a clean schema-2 catalog transition must convert and validate all of them.
- Source checkout execution and explicit image/base overrides do not carry a
  profile adoption selection and must be described as explicit boundaries of
  the guarantee.
- Registry-policy staging is a host-file dependency, not a reason to borrow an
  external Podman machine. Separating provisional bytes from their eventual
  canonical path preserves a private candidate and keeps capability/image state
  on the target engine that will actually run the profile.

### Chunk 1

- Commit `d7ca62f` removed the obsolete engine migration command, unbound and
  legacy binding paths, migration-only registry and activation behavior, and
  their obsolete fixtures and tests as one coordinated compatibility cut.
- Strict engine binding, ownership, collision, rollback, external-engine
  preservation, lifecycle, runtime-affinity, and uninstall behavior remain
  represented by the retained implementation and positive test coverage.
- Current help, contributor context, architecture, bootstrap, Podman,
  registry, installation, and canonical management-skill guidance now describe
  only the strict fresh-install contract.
- The user accepted Chunk 1 after verification on 2026-08-29. No partial
  verification items remain, and Chunk 2 was not started.

## Session bootstrap

Resume in PLAN. Read `AGENTS.md`, root `CONTEXT.md`, `CONTRIBUTING.md`, this
plan, and the contexts for every candidate change path. Read the status and
remaining review gates in `plans/wip/hybrid-podman-engine-lifecycle.md` and
`plans/wip/shared-machine-rollback.md`; do not enter ACT while either overlapping
plan remains unaccepted unless the user explicitly supersedes it. Preserve the
foundation-only boundary: clean strict engine state, catalog CPU requirements,
engine observations, profile adoption selections, and current bound-engine
runtime only. On macOS, never use `podman-machine-default` or another pre-
existing machine as a temporary bootstrap engine; stage registry bytes from
the private candidate and perform all engine-local work on the newly owned
target. Continue the user interview until `## Unresolved` says `None`,
then replace the provisional label and complete the plan self-check. Chunk 1 is
accepted and verified. Do not execute Chunk 2 until the unresolved decisions
are closed and the user explicitly authorizes that chunk; stop at every chunk's
human review gate.
