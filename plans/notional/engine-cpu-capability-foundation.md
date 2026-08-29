# Engine CPU Capability Foundation

## Objective

Without any backwards-compatibility guarantees, implement an engine-aware CPU compatibility foundation that prevents Shimmy
profile from adopting an image whose instruction-set requirements exceed the selected
Podman execution engine's observed capabilities.

Success means:

- agent skill discovery records evidence-backed CPU requirements for every credible image
  option without filtering the catalog by the discovery host;
- the catalog remains a host-independent superset of selectable image options;
- an engine owns a normalized observation of its effective execution
  capabilities;
- profile adoption resolves and persists a compatible image option before any
  image pull or local build;
- bootstrap applies the same resolution atomically to its default profile / default toolset pairing; and
- pre-existing profile, shim, catalog, engine, and bootstrap transaction guarantees
  remain intact unless no longer deemed necessary or beneficial by plan changes. 
- During the implementation the agent may encounter sections of logic and/or testing that is no longer relevant. 
The agent is authorized to remove this when certainty exists that doing so no longer protects invariants. When high-probability of dead-code exists but you are not certain, stop and interview user.   

This foundation does not implement per-tool routing across local, remote, GPU,
or emulated engines. It must leave an explicit extension boundary for that
future work without adding speculative GPU or remote-engine behavior now.

## Target layout and terminology

- **Image option**: one immutable Shimmy catalog tool version base-image choice for a concrete
  Adoption Selection, with platform descriptors, CPU requirements, provenance,
  registry access, and selection metadata.
- **CPU requirement**: the normalized minimum instruction-set contract for one
  image option on one OCI platform, plus evidence and confidence. Missing OCI
  CPU metadata is not evidence of baseline compatibility.
- **Engine capability observation**: normalized effective capabilities exposed
  to workloads by one exact Podman execution engine. This is distinct from the
  workstation CPU when the engine is a VM or remote backend.
- **Compatibility resolution**: the deterministic comparison of an image
  option's requirements with one engine observation.
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
4. Discovery remains host-independent and metadata-only. It retains all
   credible candidates, never pulls or runs them, and records CPU requirements
   from OCI declarations and authoritative publisher/base evidence.
5. CPU compatibility is a functional gate, separate from the discovery
   skill's weighted security-posture score.
6. Profile adoption owns image-option matching against the currently bound
   engine. Host-specific selection does not rewrite or narrow the retained
   catalog generation.
7. Every concrete tool version owns version-local image options. The tool
   release identity remains independent from the selected image/base, and no
   central implementation router or CPU-specific concrete-version labels are
   introduced.
8. CPU requirements live inline with each image option in the version-owned
   image manifest. Profile state persists only the selected option identity;
   no new digest or fingerprint is computed solely for CPU requirements or an
   engine capability observation.
9. The existing `tools/<tool>/versions/<version>/image.conf` becomes the sole
   schema-2 image manifest. It owns numbered version-local image options and
   their inline per-platform CPU requirements. The profile manifest adds only
   `image_selection=tool|version|option-id` records; no second image manifest
   or duplicated selected-image metadata is introduced.
10. This is a clean schema transition. Backward compatibility, compatibility
   readers, and in-place migration of profiles created by the prior contract
   are not required; those installations must be removed with the version that
   created them and bootstrapped fresh. Stale code may be removed.
11. Apply YAGNI to capability scope: implement the minimum CPU contract needed
   for correct image adoption, while preserving a clear schema-version
   extension point for future routing capabilities. Do not add speculative
   GPU, remote-engine, or emulation fields to this foundation.
12. The initial CPU contract is the cumulative x86-64 psABI level only. Image
    options and engine observations store one normalized `x86-64-v1` through
    `x86-64-v4` value; raw feature flags are transient probe input and are not
    persisted. Existing `linux/arm64` architecture compatibility remains
    unchanged by this foundation.
13. On macOS, profile creation's side-effect-free host preflight uses
    `sysctl -a | grep machdep.cpu` and normalizes the result as a transient
    provisioning ceiling. The host observation is not persisted as the engine
    level.
14. The actual compensated profile/engine creation transaction creates and
    starts the exact Podman machine, then runs `lscpu` through
    `podman machine ssh <exact-bound-machine>` and persists the normalized
    effective level in the engine record before the engine boundary is
    committed. Machine creation/start is not part of `--dry-run` or the
    side-effect-free preflight.
15. On Linux, the profile creation boundary runs local `lscpu` for the supported
    host-local rootless engine and persists the normalized effective level in
    the engine record.
16. Profile tool adoption is a separate lifecycle and trusts the established
    engine record. Bootstrap baseline adoption, profile sync, and shim add/sync
    compare image requirements with persisted engine metadata only; they do not
    rerun host discovery, `lscpu`, machine SSH, connection validation, or an
    engine smoke solely for CPU compatibility.
17. CPU observation is repeated only by a Shimmy-owned lifecycle that creates
    or replaces an engine boundary. Ordinary activation, tool adoption, sync,
    and runtime invocation do not re-probe it. This responsiveness boundary is
    intentional.
18. Bootstrap's baseline default toolset (currently `jq`, `rg`, and Skopeo but subject to change) is set is one atomic compatibility
    plan. All default selections must resolve before any baseline image is
    prepared, using the engine record established earlier in the same outer
    compensated bootstrap transaction.
19. Only the canonical management skills under `plugins/shimmy/skills/` may be
    changed. Active-profile copies and generated skill adapters remain untouched.
20. Full tool-to-engine routing is recorded separately in
    `plans/notional/TODO.md` and requires its own PLAN -> REVIEW -> ACT cycle.
21. Image CPU evidence has three explicit states. `confirmed` means an exact OCI
    declaration or authoritative publisher requirement applies to the selected
    image or image family. `inferred` means authoritative source/build lineage,
    a documented base-image requirement, or corroborated exact-image failure
    evidence establishes a credible requirement or lower bound. `unknown` means
    available evidence establishes no defensible normalized level. Absence of
    an OCI variant never implies `x86-64-v1`.
22. Inferred evidence remains visible and participates in compatibility
    assessment. A documented base requirement establishes a lower bound: it can
    prove incompatibility when that bound exceeds the engine, but does not by
    itself prove that the final image adds no stricter requirement.
23. The discovery skill owns the inference decision. It presents every
    inferable option with its normalized level or lower bound, evidence source,
    remaining uncertainty, and consequences, then interviews the user about
    which inferred options to retain or select. It never silently promotes an
    inference to confirmed evidence.
24. Profile tool adoption does not research evidence or interview the user. It
    reads only catalog-approved image options and the trusted engine record,
    then selects only an option for which the normalized requirement comparison
    returns compatible. Discovery evidence labels remain audit metadata rather
    than an adoption-time decision input.
25. An inferred option becomes eligible for the creation handoff and catalog
    inclusion only after the user specifically affirms that exact image option.
    Discovery carries the option identity, immutable digest, normalized
    requirement or lower bound, evidence source, `evidence=inferred`, and the
    explicit acceptance in its handoff. A generic acceptance of all inferred
    candidates is insufficient, and user acceptance does not relabel the
    evidence as confirmed.
26. A profile/engine creation transaction cannot commit a newly created engine
    without a valid normalized capability record for its architecture. Probe,
    parsing, normalization, or record-validation failure aborts creation and
    enters the existing compensated rollback path. This is a permanent Shimmy
    integrity invariant, and one authoritative negative test is explicitly
    approved to protect it. 
27. Reuse existing fingerprint-style sha capabilities when available instead of creating new ones.
28. Stop and interview user when a significant implementation path is unclear and cannot be reasonably inferred without additional design intent.

## Verified implementation inventory

This inventory is a verified planning baseline, not permission to ignore new
dependencies discovered during implementation.

- `plugins/shimmy/skills/shimmy-tool-discover/SKILL.md` currently proves OCI
  platform presence only, forbids runtime claims from metadata alone, and has
  no structured per-platform CPU fields in either handoff.
- `plugins/shimmy/skills/shimmy-create-tool/SKILL.md` treats a dual-architecture
  index plus native architecture smokes as its portability contract; it does
  not consume a CPU requirement.
- `lib/runtime/image.sh` schema 1 permits exactly one image strategy per
  concrete version and rejects unknown metadata keys. Supporting a catalog
  superset of CPU-differentiated options is therefore a coordinated schema
  transition, not a skill-only addition.
- `lib/runtime/podman.sh` normalizes OS/architecture to `linux/amd64` or
  `linux/arm64`; it does not determine x86-64 ISA levels.
- `lib/images/images.sh` and `shimmy catalog verify` validate index media type
  and required architecture descriptors only.
- Profile manifests record tool/version policy but no adopted image option or
  capability observation. Materialized tool versions are currently required to
  remain byte-identical to their catalog sources.
- `shim add`, `shim sync`, and profile sync already stage complete profile
  candidates and prepare images before manifest-last commit.
- Profile create and clone activate the target engine before image preparation.
- Fresh bootstrap materializes its candidate before creating a macOS VM, but
  activates and validates the exact engine before pulling/building baseline
  images. The current transaction therefore has a safe capability-probe seam
  immediately before baseline image preparation, though persisting the
  resulting selection requires a new profile-state transaction step.
- The Skopeo 1.22 local build currently uses UBI 10. Red Hat documents that
  RHEL/UBI 10 x86_64 images require x86-64-v3, while the current metadata and
  guide claim only `linux/amd64`/`linux/arm64` compatibility.
- OCI image-index platform metadata can declare an amd64 `variant`, but the
  platform descriptor and variant are optional and the general `features`
  field is reserved. Absent metadata cannot be treated as proof of x86-64-v1.
- Podman on macOS and Windows executes through a Linux VM, and hypervisors can
  mask x86 capabilities. Arbitrary remote Podman backends can also differ from
  the client workstation, but Shimmy does not currently support their routing.

Authoritative technical references:

- <https://access.redhat.com/support/policy/rhel-container-compatibility>
- <https://developers.redhat.com/articles/2024/01/02/exploring-x86-64-v3-red-hat-enterprise-linux-10>
- <https://github.com/opencontainers/image-spec/blob/v1.1.1/image-index.md>
- <https://docs.podman.io/en/stable/markdown/podman-machine.1.html>
- <https://docs.podman.io/en/stable/markdown/podman-machine-ssh.1.html>

## Unresolved

1. **Unknown image policy.** Decide whether an image whose normalized CPU
   requirement remains unknown stays reportable but unselectable in discovery,
   or may be explicitly accepted despite providing no comparable catalog
   requirement.
2. **Selection policy and UX.** Decide how profile adoption resolves ties among
   multiple catalog-approved compatible options.
3. **Clone and sync semantics.** Decide whether profile clone preserves or
   re-resolves host-specific image selections from the trusted target-engine
   record and how profile sync handles a catalog option that disappears or
   gains stricter requirements. Neither lifecycle performs a live CPU probe.
4. **Current Skopeo correction.** Decide whether this plan must add a compatible
    Skopeo image option for x86-64-v1/v2 engines as the first production
    acceptance case.

## Progress Checklist

- [ ] Chunk 1 — Define and validate image-option and engine-capability schemas.
- [ ] Chunk 2 — Integrate compatibility resolution with bootstrap and profile/shim adoption transactions.
- [ ] Chunk 3 — Update discovery/creation skills, catalog verification, tool metadata, and user guidance.
- [ ] Chunk 4 — Complete focused, lifecycle, generated-artifact, and native acceptance verification.

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

## Chunk 1 — Capability and image-option contracts

### Goal

Introduce one coherent schema unit for catalog image requirements, engine
observations, profile selections, and compatibility comparison.

### Files

Primary areas: `lib/runtime/`, `lib/catalog/`, `lib/engine/`, `lib/profile/`,
`lib/shim/`, catalog fixtures, and corresponding library tests.

### Implementation requirements and suggested reasoning level

High reasoning: update every producer, consumer, validator, renderer, fixture,
fingerprint boundary, and profile/catalog transaction affected by the chosen
schema. Preserve exact ownership and manifest-last guarantees. Do not add
tool-name or implementation-name dispatch tables.

### Verification checklist

- [ ] Schema-valid catalog options, normalized engine observations, and profile selections round-trip deterministically.
- [ ] Compatibility comparison gives deterministic results for every supported requirement/capability state.
- [ ] Catalog generations remain host-independent and content-addressed.
- [ ] Existing ownership, path-safety, and integrity invariants remain covered once in their authoritative tests.

### Human review gate

Confirm the schema expresses the agreed ownership boundaries without embedding
future routing behavior or silently changing existing compatibility policy.

## Chunk 2 — Capability-aware adoption lifecycle

### Goal

Resolve the complete image plan against the bound engine before image
preparation in bootstrap, create/clone, sync, and shim add/sync, then persist
the chosen options transactionally.

### Files

Primary areas: `lib/install/`, `lib/update/`, `lib/shim/`, `lib/profile/`,
`lib/engine/`, `commands/`, and command/lifecycle tests.

### Implementation requirements and suggested reasoning level

High reasoning: establish the normalized engine level only in the compensated
engine-creation lifecycle, then let tool-adoption lifecycles resolve every
required option from that trusted record before pulling/building any image.
Integrate selection persistence with existing compensation. Preserve exact
created-machine proof, workload guards, active-record ordering, skill-link
compensation, manifest-last commits, and side-effect-free dry runs.

### Verification checklist

- [ ] Bootstrap resolves `jq`, `rg`, and Skopeo before the first image preparation.
- [ ] Profile/engine creation establishes the normalized level with host preflight and post-start engine validation at the agreed boundaries.
- [ ] The authoritative creation-boundary test proves that an invalid or unavailable capability observation prevents commit and enters existing compensation.
- [ ] Profile create/clone/sync and shim add/sync resolve against the correct trusted engine record without a live CPU or connection probe during tool adoption.
- [ ] A compatible option is materialized and consumed by runtime without mutating the catalog generation.
- [ ] Injected transaction failures restore the prior valid profile and retain ambiguous engine journals according to existing policy.

### Human review gate

Confirm lifecycle ordering, persisted selection ownership, and rollback evidence
before changing discovery guidance or production tool options.

## Chunk 3 — Discovery, creation, verification, and catalog adoption

### Goal

Make the management skills and catalog tooling produce and consume the new CPU
contracts, and supply production options needed to exercise the feature.

### Files

Primary areas: `plugins/shimmy/skills/shimmy-tool-discover/`,
`plugins/shimmy/skills/shimmy-create-tool/`, `lib/images/`, `commands/catalog.sh`,
selected `tools/` metadata/guides, contributor docs, and focused tests.

### Implementation requirements and suggested reasoning level

High reasoning: preserve discovery's no-pull/no-run boundary; distinguish
declared, documented, inferred, and unknown CPU requirements; keep every
credible catalog option visible; keep compatibility separate from security
ranking; and update both handoff producer and consumer in one contract change.

### Verification checklist

- [ ] Discovery reports per-platform CPU requirements, evidence, compatibility status, and structured handoff fields.
- [ ] Creation consumes the handoff without losing or inventing capability facts.
- [ ] Catalog verification reports requirement metadata and preserves remote-inspection limits.
- [ ] Production tool metadata demonstrates both a newer ISA requirement and a compatible fallback when approved.
- [ ] Canonical skills validate, and active-profile/generated copies remain untouched.

### Human review gate

Confirm user-facing option reporting, evidence labels, and production catalog
choices before broad acceptance testing.

## Chunk 4 — Acceptance and documentation closure

### Goal

Validate the complete feature across supported architecture and lifecycle paths
and align all contributor/user documentation.

### Files

Primary areas: focused library/command tests, lifecycle scenarios, tool smokes,
`README.md`, `commands/README.md`, `docs/`, `CONTRIBUTING.md`, and this plan.

### Implementation requirements and suggested reasoning level

High reasoning: prefer positive observable acceptance. Add negative coverage
only for user-approved durable invariants. Keep remote registry checks outside
the default offline suite and use native non-mutating tool smokes where
available.

### Verification checklist

- [ ] Focused schema, runtime, engine, profile, shim, catalog, and lifecycle groups pass with bounded parallelism.
- [ ] Shell syntax, executable modes, catalog inventory, and `git diff --check` pass.
- [ ] Native Linux amd64 and Apple Silicon arm64 acceptance outcomes are recorded; any unavailable native lane is surfaced as partial rather than silently replaced by emulation.
- [ ] Bootstrap demonstrates capability-aware baseline adoption before image preparation.
- [ ] Documentation distinguishes current single-engine execution from deferred multi-engine routing.

### Human review gate

Confirm all acceptance evidence, partial items, risks, and documentation before
marking the plan complete.

## Risk register

- **Schema identity expansion:** multiple options and profile selections affect
  every catalog/profile producer and consumer. Mitigation: implement the schema
  as one review unit and inventory all fingerprints, fixtures, validators, and
  rollback paths.
- **False compatibility:** OCI descriptors often omit ISA levels. Mitigation:
  never equate absent metadata with baseline support; retain evidence and
  confidence and apply the approved unknown policy.
- **Probe correctness:** raw CPU flags can be incomplete, hypervisor-masked, or
  OS-disabled. Mitigation: prefer a normalized execution-environment result,
  retain its source, and test cumulative x86-level rules rather than checking
  only AVX/AVX2/FMA.
- **Bootstrap partial state:** macOS needs a running new VM before it can be
  observed. Mitigation: probe after exact engine activation but before image
  preparation, using current lifecycle compensation for failures.
- **State drift:** an engine changed outside Shimmy could expose capabilities
  that differ from its trusted record. Mitigation: treat Shimmy's compensated
  engine creation/replacement lifecycle as the authority boundary and refresh
  the normalized level only there; do not add adoption-time or per-run probes.
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
  seam for observing the actual macOS VM.

## Session bootstrap

Resume in PLAN. Read `AGENTS.md`, root `CONTEXT.md`, `CONTRIBUTING.md`, this
plan, and the contexts for every candidate change path. Preserve the confirmed
foundation-only boundary: catalog requirements, engine CPU observations,
profile adoption selection, and current bound-engine runtime only. Continue
the user interview until `## Unresolved` says `None`, then complete the plan
self-check and stop for initial review. Do not enter ACT without explicit
approval; when approved, move this file to `plans/wip/` before implementation
and stop at every chunk's human review gate.
