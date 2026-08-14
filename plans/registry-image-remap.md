# Registry Image Remap Plan

## Objective

Add an opt-in Shimmy registry-remap layer for corporate environments where the
Podman engine cannot reach public registries and its registry configuration
cannot be managed centrally. A user-managed mapping will translate the registry
portion of Shimmy-owned image references before Podman or the image verifier
uses them, while preserving the repository path, tag or digest, platform
selection, and existing image-override interfaces.

Success means that a logical repository default such as
`docker.io/bats/bats@sha256:<digest>` can be consumed as
`docker.my-corp-repo.com/bats/bats@sha256:<same-digest>` by direct runtimes,
local-build base images, refresh operations, and `shimmy images verify`, without
changing any checked-in `image.conf` or allowing fallback to the public
registry.

Podman's native `registries.conf` remains the preferred solution when operators
control the engine. Its `prefix` and `location` fields already provide logical-
to-physical reference redirection; a `[[registry.mirror]]` is not sufficient for
a strict no-public-access policy because Podman tries the primary location after
the mirrors. The Shimmy feature is a portable fallback for Shimmy-managed image
references, not a replacement for Podman registry, TLS, authentication, or
signature-policy administration. See the authoritative
[containers-registries.conf documentation](https://github.com/containers/image/blob/main/docs/containers-registries.conf.5.md)
and [Podman configuration documentation](https://docs.podman.io/en/latest/markdown/podman.1.html).

Explicit exclusions:

- Do not change repository defaults from immutable digests to tags.
- Do not change `image.conf` schema version 1 or store corporate endpoints in
  catalog metadata.
- Do not rewrite explicit `SHIMMY_<TOOL>_IMAGE` or
  `SHIMMY_<TOOL>_BASE_IMAGE` overrides; those values already identify an
  operator-selected physical image.
- Do not generate, install, edit, or remove Podman `registries.conf`,
  `policy.json`, certificate, or credential files.
- Do not add registry credentials, TLS-disable switches, public-registry
  fallback, generic HTTP proxy handling, or automatic profile/startup state.
- Do not rewrite arbitrary image arguments passed by a user to tools such as
  Skopeo; only Shimmy-owned metadata references are in scope.

## Target layout and terminology

- **Logical image reference**: the upstream, fully qualified reference retained
  in version-owned `image.conf` and shown by metadata-oriented commands.
- **Physical image reference**: the effective reference passed to Podman or the
  Skopeo verifier after an optional registry mapping.
- **Registry map**: an external, user-owned data file selected by
  `SHIMMY_IMAGE_REGISTRY_MAP_FILE`. It maps one exact logical registry host to
  one physical registry or registry/path prefix.
- **Explicit image override**: an existing tool-specific runtime or base-image
  environment value. Overrides remain physical references and bypass the map.

The versioned, non-executable map format is:

```text
shimmy_image_registry_map_version=1
registry_map=docker.io|docker.my-corp-repo.com
registry_map=ghcr.io|docker.my-corp-repo.com/ghcr
```

The caller opts in explicitly:

```sh
export SHIMMY_IMAGE_REGISTRY_MAP_FILE=/absolute/path/to/registry-map.conf
```

Resolution is one pass and has no fallback:

```text
explicit tool/base override --------------------------> use verbatim
repository-owned logical ref
  -> map file unset or source registry not matched ---> use logical ref
  -> exact source registry matched -------------------> target prefix + original path/tag/digest
```

For example, the mapping `docker.io|docker.my-corp-repo.com` transforms:

```text
docker.io/bats/bats@sha256:0123...cdef
docker.my-corp-repo.com/bats/bats@sha256:0123...cdef
```

The same transformation applies to a discovery tag used by explicit image
verification, but repository runtime defaults remain digest-pinned.

## Recorded design decisions

1. Prefer Podman `registries.conf` when the engine is administratively
   configurable. Use `location` remapping, rather than a mirror with fallback,
   when policy forbids any direct public-registry request. On macOS and Windows,
   Podman documents that engine registry configuration belongs inside the Podman
   machine, which is one reason a Shimmy-side fallback can still be useful; see
   [Podman troubleshooting](https://github.com/containers/podman/blob/main/troubleshooting.md).
2. Add one new Shimmy-defined interface:
   `SHIMMY_IMAGE_REGISTRY_MAP_FILE`. It must name an absolute, readable regular
   file. Shimmy will not discover a default path, persist the variable, copy the
   file into a profile, or own its lifecycle.
3. Treat the map as data, not shell. Require exactly one
   `shimmy_image_registry_map_version=1`, at least one `registry_map` record,
   and no unknown keys or malformed non-comment lines. Blank lines and lines
   beginning with `#` are allowed.
4. Parse each `registry_map` value as exactly `source|target`. Require a unique
   source registry in every record. The source is an exact fully qualified
   registry host with optional port and no path. The target is a fully qualified
   registry host with optional port and optional safe repository-prefix path;
   schemes, tags, digests, empty/traversing path segments, trailing slashes, and
   unsafe characters are rejected.
5. Match only the first registry component of a fully qualified image
   reference. Matching is exact and does not treat `docker.io.example.com` as
   `docker.io`. Apply at most one mapping; never recursively remap a target.
6. Preserve every byte after the logical registry separator, including the
   complete repository path and `:tag` or `@sha256:<digest>`. Validate the
   rewritten result with the existing tag/digest reference validators before
   returning it.
7. Resolution precedence is fixed:
   (a) a non-empty tool-specific runtime/base override is used verbatim;
   (b) otherwise the validated repository-owned default is mapped when its
   source registry has a record; and (c) otherwise the logical default is used
   unchanged. Existing `IMAGE_PULL=always` and `IMAGE_BUILD=always` semantics do
   not change.
8. Apply the map to all repository-owned external runtime defaults and all
   non-`scratch` local-build base defaults through `lib/runtime/image.sh`.
   `scratch` remains unchanged. Because mapped base references are effective
   build arguments, they remain part of local image cache identity; changing,
   adding, or removing a relevant mapping selects a different local cache tag.
9. Apply the same map to both pinned defaults and discovery refs enumerated by
   `lib/images/images.sh`. `shimmy images verify` therefore inspects the
   corporate route and compares the tag visible through that route with the
   pinned digest. Under a caching proxy, `upstream=current|moved` describes the
   route-visible tag, not an independently contacted public publisher.
10. Do not rewrite arbitrary Skopeo command arguments. A direct user command
    such as `skopeo inspect docker://...` remains explicit input; operators may
    use Skopeo/Podman native registry configuration for that separate workflow.
11. Keep `shimmy status` metadata-oriented: it continues to show the logical
    checked-in default and does not become dependent on external map-file
    availability. `--preview-shim` is the supported way to observe an effective
    physical runtime reference.
12. Fail an invalid selected map before pull, build, run, or Skopeo inspection.
    A local-build runtime may already have completed its non-mutating Podman
    preflight before resolving build inputs; it must still fail before any image
    or container mutation.
13. Do not add upstream fallback. If the physical reference is absent,
    unauthenticated, untrusted, or does not serve the pinned digest, propagate a
    failure. Never retry the logical public reference and never substitute the
    discovery tag for a missing digest.
14. Authentication, private CA trust, and signature policy remain external.
    Podman credentials must cover the physical registry. Image verification of
    a public logical image through an authenticated corporate endpoint may use
    the existing `SHIMMY_SKOPEO_AUTH_SECRET`; no credentials are inferred or
    mounted by default.
15. Preserve catalog and installed-profile identity. No catalog schema,
    profile manifest, installer request, launcher flag, tool selector, or
    generated shell-init format changes. Installed profiles gain the behavior
    when their materialized shared runtime is updated through the existing
    install/update transaction.

## Verified implementation inventory

This is the verified planning baseline, not permission to ignore newly
discovered dependencies during implementation.

- The repository currently owns 21 non-`scratch` pinned image defaults across
  seven logical registries: `docker.io`, `ghcr.io`, `quay.io`, `gcr.io`,
  `public.ecr.aws`, `registry.access.redhat.com`, and `registry.redhat.io`.
- Nine external-image runtimes obtain repository defaults through
  `shimmy_image_external_default_read` in `lib/runtime/image.sh`.
- Twelve local-build runtimes obtain configured base defaults through
  `shimmy_local_image_ensure`, which renders effective build arguments and
  includes them in local cache identity.
- All current runtime and base-image overrides are selected in version-owned
  `run.sh` files before, or instead of, the shared default path. No per-tool
  runtime edit is required to preserve override precedence.
- `lib/images/images.sh` independently reads raw `image_upstream_ref`,
  `image_default_ref`, and numbered local-base equivalents, then invokes the
  catalog-default containerized Skopeo runtime. It must opt into the shared
  resolver explicitly or verification will bypass the new route.
- Direct refresh hooks invoke their runtime with `IMAGE_PULL=always`; local
  refresh hooks invoke the same shared local-build path. Both inherit the map
  without a new update-command interface.
- `commands/status.sh` and `commands/agent-preflight.sh` validate raw metadata.
  Their current ownership and output semantics do not require a mapping change.
- Installation materializes `lib/runtime/` and selected tool version trees into
  each profile. Existing install/update lifecycle tests are the relevant proof
  that the changed helper reaches installed profiles atomically.
- `tools/oc/SKILL.md` currently recommends Podman `registries.conf` for
  corporate routing. That remains the primary recommendation but needs the
  strict `location` versus fallback-mirror distinction and the new Shimmy
  fallback documented.
- The worktree was clean before this plan file was created.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Implement and verify opt-in registry image remapping (active only after explicit approval)

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

## Chunk 1 — Registry image remapping

### Goal

Deliver one coherent, backward-compatible registry-map interface that covers
every Shimmy-owned runtime default, local-build base, refresh path, and remote
image-verification reference, with fail-closed validation and complete user and
contributor guidance.

### Files

Primary implementation and context:

- `lib/runtime/image.sh`
- `lib/runtime/CONTEXT.md`
- `lib/images/images.sh`
- `lib/images/CONTEXT.md`

Behavioral tests and test context:

- `tests/lib/catalog.sh`
- `tests/lib/CONTEXT.md`
- `tests/commands/images.sh`
- `tests/commands/CONTEXT.md`
- Relevant installed lifecycle/update tests if discovery shows the current
  materialization coverage does not exercise the changed helper

User, operator, and contributor guidance:

- `README.md`
- `docs/podman.md`
- `CONTRIBUTING.md`
- `CONTEXT.md`
- `AGENTS.md`
- `docs/prompt-shimmy-project.md`
- `docs/templates/generic-shim/AGENTS.md`
- `docs/templates/generic-shim/SKILL.md`
- `plugins/shimmy/skills/shimmy-create-tool/SKILL.md`
- `tools/oc/SKILL.md`
- `tools/skopeo/guide.md` and `tools/skopeo/SKILL.md` only where needed to
  distinguish verifier-owned mapped refs from explicit Skopeo arguments

Expected unchanged surfaces that must still be inspected during execution:

- `tools/*/versions/*/image.conf`
- `tools/*/versions/*/run.sh`
- `tools/*/versions/*/refresh.sh`
- `commands/status.sh`
- `commands/agent-preflight.sh`
- `install.sh` and `lib/install/`
- Profile and catalog manifest schemas

The files list identifies the primary surface; newly discovered required files
remain in scope when necessary to keep the feature atomic.

### Implementation requirements

1. Add internal registry-map file readers and validators to
   `lib/runtime/image.sh`, plus one public action-first resolver named
   `shimmy_resolve_image_ref_registry_map`.
2. Read `SHIMMY_IMAGE_REGISTRY_MAP_FILE` only when resolving a repository-owned
   ref. If it is unset, return the original ref byte-for-byte. If an explicit
   runtime/base override bypasses the shared default resolver, do not inspect or
   validate the map file.
3. Require an absolute readable regular-file path and validate the complete
   schema before selecting a match. Report the file and offending line or
   record in errors without printing credentials or unrelated environment
   values.
4. Enforce the recorded version, record, endpoint, uniqueness, exact-match,
   one-pass, and rewritten-reference validation rules. An unused malformed
   record invalidates the selected map; do not accept a partially valid policy.
5. Route `shimmy_image_external_default_read` through the resolver after
   `image.conf` validation.
6. In `shimmy_local_image_build_args_append`, resolve each configured
   non-`scratch` base default only when its declared build-argument override is
   empty. Preserve explicit base overrides verbatim. Ensure the mapped effective
   value is the one written to the ordered build-argument vector and therefore
   hashed into local image identity.
7. In `shimmy_images_config_records_print`, resolve each logical pinned default
   and discovery ref before writing the inspection record. Keep metadata
   validation first, preserve record roles/access classification, and ensure
   invalid mapping fails before the Skopeo runtime is called.
8. Keep inspection caching keyed by effective physical refs. If separate
   logical records resolve to the same physical ref, perform one remote
   inspection and reuse it while still emitting one result per logical record.
9. Preserve existing output schemas. Document that drift is evaluated through
   the selected route; do not rename existing manifest fields or expose the map
   path in stable machine-readable results.
10. Preserve existing per-tool image/base overrides, pull/build flags,
    `scratch`, platform selection, local stale cleanup, preview quoting,
    authentication gating, public-only skipping, and non-mapped behavior.
11. Do not add per-tool registry variables or edit every version runtime. The
    shared helper and verifier are the ownership boundaries for this feature.
12. Document both recommended operating modes with digest-pinned examples:
    native Podman `prefix`/`location` remapping when the engine is managed, and
    `SHIMMY_IMAGE_REGISTRY_MAP_FILE` when a Shimmy-side physical-reference
    rewrite is required. Explicitly warn that Podman mirror entries can fall
    back, mapped targets may need their own credentials/CA/signature policy,
    and mapped tag-drift results reflect the proxy's view.
13. Update contributor and tool-creation guidance so future runtimes consume
    repository defaults only through the shared helper and do not duplicate
    mapping logic. Keep `.agents/skills/` generated adapters unchanged.
14. Verify installation/update propagation through existing materialization
    behavior. Modify installer code only if current copy/transaction logic does
    not already include the shared helper; do not add a new install flag or
    profile-owned policy file.

### Verification checklist

- [ ] With `SHIMMY_IMAGE_REGISTRY_MAP_FILE` unset, every existing default,
  preview, verifier fixture, install/update test, and output schema remains
  unchanged.
- [ ] Parser tests accept comments, blank lines, multiple unique records,
  registry ports, and target path prefixes.
- [ ] Parser tests reject missing/unreadable/relative files, empty maps,
  unsupported or duplicate versions, unknown keys, malformed records, duplicate
  sources, schemes, tags/digests in endpoints, traversal/empty segments,
  trailing slashes, and unsafe characters.
- [ ] Resolver tests prove exact source-host matching, non-matches,
  path/tag/digest preservation, one-pass behavior, target-prefix insertion, and
  post-rewrite validation.
- [ ] A direct-image preview maps a repository default by digest, preserves
  `--platform`, and keeps `IMAGE_PULL=always`; an explicit runtime image
  override remains byte-for-byte unchanged even when the map is malformed.
- [ ] A local-build preview maps every configured non-`scratch` base default;
  changing the relevant mapping changes local cache identity, an identical map
  is stable, `scratch` is unchanged, and an explicit base override bypasses the
  map and determines cache identity.
- [ ] Catalog-wide preview coverage proves all nine direct and twelve
  local-build versions still consume the shared paths and no version-owned
  duplicate mapping logic appears.
- [ ] Image-verifier fixtures prove both pinned default and discovery-tag calls
  use effective mapped refs, mapped-ref cache deduplication remains correct,
  authentication/public-only behavior is preserved, and malformed mapping
  produces zero Skopeo calls.
- [ ] `shimmy status` continues to show logical catalog metadata, while
  `--preview-shim` shows the effective physical runtime ref.
- [ ] Disposable installed-profile tests prove install and update materialize
  the changed helper atomically without manifest or shell-init schema changes.
- [ ] All runnable shell files pass `dash -n` and retain executable modes.
- [ ] `./tests/test.sh` passes with no mapping and with the new focused mapping
  cases.
- [ ] On native Linux `amd64` and Apple Silicon macOS `arm64`, a corporate test
  map succeeds for one direct runtime, one local-build runtime, and
  `shimmy images verify --shim <mapped-tool>` while public registry access is
  blocked. Record `[~]` with the exact remaining host/environment if either
  native corporate acceptance run is unavailable; surface it for explicit
  deferral rather than silently treating fixture coverage as live acceptance.
- [ ] Corporate acceptance confirms the physical registry serves the exact
  pinned digest and that no tag fallback or logical public-registry retry
  occurs.

### Human review gate

Reviewers must confirm the map schema and precedence are acceptable, all
automated checks pass, logical metadata and digest immutability remain intact,
no direct-upstream fallback was introduced, and every native corporate
acceptance item is either complete or explicitly dispositioned as a surfaced
partial verification item. Stop after this review; there is no later chunk.

## Risk register

- **Duplicating Podman policy**: a Shimmy ref rewrite lacks Podman's mature
  longest-prefix, mirror ordering, and logical-identity behavior. Mitigation:
  keep native `registries.conf` primary, make the Shimmy feature explicit and
  exact-host-only, and direct complex policies back to Podman.
- **Logical identity and signatures**: direct rewriting makes the corporate
  host the physical image identity and may change signature-policy scope.
  Mitigation: preserve digests, never disable policy, and document that
  corporate CA/signature configuration remains an operator prerequisite.
- **Authenticated corporate proxy for public metadata**: `image.conf` may mark
  an upstream as public even when the mapped endpoint authenticates.
  Mitigation: retain explicit `SHIMMY_SKOPEO_AUTH_SECRET`, document that it may
  be required for mapped public refs, and never infer host credentials.
- **Stale proxy tags**: drift checks can only observe the mapped proxy's cached
  tag. Mitigation: state the route-visible semantics and keep runtime execution
  pinned to the unchanged digest.
- **Repository collisions**: two source registries mapped to one target without
  distinct target prefixes can collide. Mitigation: allow target prefixes,
  show separate-prefix examples, and make the operator responsible for the
  corporate proxy's repository layout.
- **Digest not served by proxy**: some proxy products may expose tags but not
  the requested manifest-list digest. Mitigation: fail closed and require the
  proxy to serve the exact digest; never downgrade to `:latest`.
- **Partial integration**: runtime execution could map while image verification
  still contacts a logical registry. Mitigation: keep runtime and verifier
  changes in one chunk with call-log assertions for both paths.
- **External policy lifecycle**: deleting or changing the user-owned map can
  alter future physical resolution. Mitigation: no profile ownership claim,
  absolute explicit selection, complete validation per use, and cache identity
  based on effective local-build inputs.

## Lessons learned

### Initial

- Podman already distinguishes logical `prefix` from physical `location`; that
  is the standards-based answer when engine configuration is available.
- Podman mirror entries normally fall back to the primary location, which is
  incompatible with a strict no-public-access guarantee unless the primary is
  also remapped or blocked externally.
- Shimmy's central default readers cover all current runtime defaults and local
  bases, but remote verification independently enumerates refs and must be
  updated in the same atomic change.
- Keeping corporate routes outside `image.conf` preserves portable catalog
  identity and immutable upstream provenance.
- Effective mapped base arguments already fit the local cache-identity model;
  no separate cache key or manifest migration is needed.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, this complete plan,
   `lib/CONTEXT.md`, `lib/runtime/CONTEXT.md`, `lib/images/CONTEXT.md`,
   `tests/CONTEXT.md`, `tests/lib/CONTEXT.md`, and
   `tests/commands/CONTEXT.md`.
2. Recheck the worktree and the verified inventory, then inspect
   `lib/runtime/image.sh`, `lib/images/images.sh`, their current consumers, and
   the listed test and documentation targets. Treat newly discovered
   dependencies as additions to the inventory, not permission to change the
   recorded design.
3. The active scope is Chunk 1 only. The non-negotiable boundaries are:
   immutable checked-in digests, explicit-map opt-in, exact one-pass registry
   matching, explicit override precedence, no upstream fallback, no credential
   or Podman-policy provisioning, no schema/profile/install flag changes, and
   no edits to generated `.agents/skills/` adapters.
4. Implement and verify Chunk 1, update its checklist and Lessons learned, and
   stop at its human review gate. Surface every `[~]` native acceptance item
   with its impact and proposed disposition.
