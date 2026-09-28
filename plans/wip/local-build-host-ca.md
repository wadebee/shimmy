# Universal host CA bundle support

## Objective

Allow an end user to supply `SHIMMY_HOST_CA_BUNDLE` to any Shimmy container:

- every local-build image receives it during build when it names a readable,
  nonempty regular file; and
- every external or local-build runtime receives the same file through a stable
  read-only mount.

For a runtime with a documented native CA file variable, set that mapping to
the stable path. For a runtime without a documented mapping, set
`SSL_CERT_FILE` to the stable path as a compatibility fallback. The raw host
control variable and host path are never forwarded as container environment
variables.

Success conditions:

- Disabled, empty, invalid-path, and zero-byte inputs add neither build nor
  runtime CA arguments.
- All 28 concrete runtime wrappers mount a present bundle at
  `/tmp/shimmy-host-ca-bundle.pem:ro`, with one documented native mapping or
  the `SSL_CERT_FILE` fallback.
- All fourteen local-build contexts receive a secret only when the bundle is
  present and consume it before build-time network work.
- Local-image cache identities, tags, and labels are identical whether a
  bundle is disabled or present, so portable cached images are not fragmented
  by user trust configuration.
- No host path, control variable value, or certificate contents are logged,
  forwarded, embedded in cache identity, or intentionally retained in image
  layers.

Explicit exclusions:

- No host trust discovery, PEM/cryptographic parsing, certificate merging,
  TLS-verification bypass, or modification of base-image digest pinning.
- No assertion that every application honors `SSL_CERT_FILE`; it is the
  requested fallback when no documented application-native file setting is
  available.
- No live build without separate explicit authorization and a running Podman
  engine.

## Target layout and terminology

A **present bundle** is the user-selected contract: `SHIMMY_HOST_CA_BUNDLE`
names an absolute, readable regular file with nonzero length. This is a
presence check, not PEM or certificate-chain validation. A malformed nonempty
file may cause the native image trust refresh or application TLS initialization
to fail.

```text
SHIMMY_HOST_CA_BUNDLE=/host/path/bundle.pem
  |
  +-- local build only
  |     --secret id=shimmy-host-ca-bundle,src=/host/path/bundle.pem
  |     Containerfile secret mount -> native trust refresh -> remove anchor
  |
  `-- every runtime
        -v /host/path/bundle.pem:/tmp/shimmy-host-ca-bundle.pem:ro
        -e <documented native CA variable>=/tmp/shimmy-host-ca-bundle.pem
        or -e SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem
```

The **stable path** is `/tmp/shimmy-host-ca-bundle.pem`. The **native mapping**
is an implementation-specific documented CA environment variable (for example
`AWS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS`, or
`CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE`). The **fallback mapping** is
`SSL_CERT_FILE` when no native mapping is documented. In both cases the raw
`SHIMMY_HOST_CA_BUNDLE` value remains host-only: forwarding it would expose a
host path that does not exist in the container.

## Recorded design decisions

1. The user has directed universal support: all local-build and external-image
   runtimes participate, not merely the previously verified CA-aware set.
2. Runtime exposure always uses the stable read-only mount. Known documented
   native mappings take precedence; otherwise use `SSL_CERT_FILE`. Do not add
   both mappings unless a tool's documentation establishes that combination.
3. Existing version runtimes with native mappings retain them. Their explicit
   mappings must appear after any wildcard environment forwarding.
4. The common local-image helper appends the fixed build secret
   `id=shimmy-host-ca-bundle,src=<path>` only for a present bundle. It validates
   the path with the existing host-CA rules and a nonempty check.
5. A build secret must not influence local-image cache identity, image tag,
   input-hash label, stale cleanup reference, or image metadata. The local
   image produced with and without a bundle deliberately has the same cache
   reference; normal `auto` mode will reuse a cached image rather than rebuild
   it just because the bundle changes.
6. Consequently, build-time trust is guaranteed only when Podman actually
   performs a local build (first build, `SHIMMY_<TOOL>_IMAGE_BUILD=always`, or
   cache eviction). The runtime mount remains available independently for
   every invocation.
7. Each local Containerfile consumes the optional secret in a single
   secret-mounted layer, uses its distribution-native trust refresh, then
   removes the copied anchor in that layer. A missing secret is a successful
   no-op. Multi-stage contexts cover every stage with network activity.
8. ABA's prior single-tool required-secret implementation is not a design
   constraint. Replace, simplify, or remove it as required by the universal
   capability; retain only behavior independently justified by the broader
   contract. ABA's runtime mapping participates under the same rules as every
   other container.
9. Shimmy does not parse a certificate chain. The term “CA bundle” describes
   caller intent; the supported predicate is a nonempty file.

## Verified implementation inventory

### Shared producers and consumers

- `lib/runtime/podman.sh:350-391` already provides
  `shimmy_podman_ca_bundle_prepare`. It resets three output scalars; validates
  one requested native environment variable; reads `SHIMMY_HOST_CA_BUNDLE`;
  validates an absolute, readable regular file; and renders the existing stable
  path `/tmp/shimmy-host-ca-bundle.pem` plus the selected native assignment.
  Existing opted-in wrappers use those scalars to add the conditional runtime
  mount and `-e` arguments. This is the primary reuse seam: extend it only for
  the missing nonempty predicate and universal mapping policy rather than
  creating competing CA path/argument helpers.
- `lib/runtime/image.sh` owns local build options, identity rendering,
  reference rendering, ensure, and stale cleanup. It currently accepts caller
  supplied `--secret` options and deliberately renders only a secret id into
  identity. New build-secret handling must reuse that option path and preserve
  identity independence.
- `tools/aba/versions/1.3/run.sh` and its Containerfile are an existing
  build-time reference only: ABA prepares existing runtime CA values, passes a
  build secret, then refreshes Fedora trust from a secret mount. It was
  designed for a single-tool-only scope, so it must not define the universal
  architecture or preserve its required-secret behavior by default. The reuse
  audit may replace, simplify, or remove its tool-specific logic once the
  broader contract has an equivalent or better shared path.
- `shimmy_podman_run_or_preview` only previews or executes an already-complete
  argument vector. The 28 runtime wrappers currently construct their own
  `podman run` arguments; universal mounting therefore requires a shared
  runtime-argument insertion seam or coordinated wrapper updates.

### Existing mappings

Sixteen concrete runtimes already call `shimmy_podman_ca_bundle_prepare` with
native mappings: AWS, gcloud, npx, gdrive, Tessl, Go, Terraform, gh, Task,
all three `oc` versions, Skopeo, Flux, ABA, and OPNsense MCP read-only.

Twelve remaining runtime wrappers must be inventoried and receive the fallback
`SSL_CERT_FILE` mapping unless their tool documentation identifies a native
mapping: Bats, community-ansible-dev-tools, jq, jv, keepassxc, logmine,
netcat, nmap, OPNsense MCP admin, rg, Textual, and yq.

### Local-build contexts

Fourteen local-build Containerfiles require coordinated optional-secret use:

- `tools/aba/versions/1.3/container/Containerfile`
- `tools/gdrive/versions/0.2/container/Containerfile`
- `tools/gh/versions/2.94/container/Containerfile`
- `tools/jv/versions/6.0/container/Containerfile`
- `tools/logmine/versions/0.1/container/Containerfile`
- `tools/netcat/versions/7.92/container/Containerfile`
- `tools/oc/versions/{4.18,4.20,4.22}/container/Containerfile`
- `tools/opnsense-mcp-admin/versions/1.0/container/Containerfile`
- `tools/opnsense-mcp-read-only/versions/0.4/container/Containerfile`
- `tools/task/versions/3.45/container/Containerfile`
- `tools/tessl/versions/0.1/container/Containerfile`
- `tools/textual/versions/8.2/container/Containerfile`

`README.md`, affected canonical tool guides, and canonical tool skills are
documentation consumers. `tests/lib/runtime.sh` owns host-CA helper coverage;
tool tests own each preview contract.

This inventory is a verified baseline, not permission to omit newly discovered
callers or generated/runtime paths.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Audit and record reusable existing CA behavior.
- [ ] Chunk 2 — Add only missing shared universal runtime and build preparation.
- [ ] Chunk 3 — Wire all runtimes and local-build Containerfiles.
- [ ] Chunk 4 — Document and verify behavior.

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

## Chunk 1 — Reuse audit and implementation boundary

### Goal

Verify and record the existing CA capability before changing production code,
so later chunks extend it rather than duplicating it.

### Files

- `lib/runtime/podman.sh`
- `lib/runtime/image.sh`
- `tools/aba/versions/1.3/run.sh`
- `tools/aba/versions/1.3/container/Containerfile`
- Every current caller of `shimmy_podman_ca_bundle_prepare`
- This retained plan

### Implementation requirements

1. Make no production code or tool configuration change in this chunk.
2. Trace `shimmy_podman_ca_bundle_prepare` from its output scalars through all
   callers. Record which validation, stable-path, mount, assignment, preview,
   redaction, and wildcard-ordering behaviors are reusable as-is.
3. Trace `shimmy_local_image_build_options_append`, identity rendering,
   reference rendering, ensure, and stale cleanup. Record precisely whether
   one shared optional `--secret` can cover all callers without changing image
   identity.
4. Trace ABA's secret creation and Fedora Containerfile trust refresh as one
   reference implementation. Classify each part as reusable only when it serves
   the universal contract; otherwise explicitly plan to replace, simplify, or
   remove it. Do not retain ABA-specific required-secret or call structure
   merely for compatibility with the earlier single-tool scope.
5. Record the resulting minimum-delta design in `Lessons learned / Chunk 1`:
   name each existing function or argument pattern to reuse, each missing
   capability to add, and each duplicate path explicitly prohibited.
6. Re-read the inventory after tracing and adjust later chunk files only where
   confirmed evidence requires it; do not infer a new abstraction before the
   audit establishes a concrete gap.

### Verification checklist

- [ ] Existing shared-helper and ABA call paths are documented with exact
  producer, consumer, and output-variable roles.
- [ ] The plan's later requirements distinguish reuse from new code, including
  the cache-identity invariant.
- [ ] `git diff --check` passes and no production source changes exist.

### Human review gate

Confirm the recorded reuse map and minimum-delta boundaries before authorizing
new shared behavior in Chunk 2.

## Chunk 2 — Shared universal CA preparation

### Goal

Prepare only the missing optional build and runtime CA arguments without
changing local image cache identity, reusing the Chunk 1-confirmed helpers.

### Files

- `lib/runtime/podman.sh`
- `lib/runtime/image.sh`
- `tests/lib/runtime.sh` and the existing lowest-level image-helper test owner

### Implementation requirements

1. Modify `shimmy_podman_ca_bundle_prepare` rather than creating a second
   host-CA parser or stable-path renderer: extend it only to distinguish
   disabled/invalid/zero-byte from present inputs, preserve paths with spaces
   and symlinked parents, and retain the current no-content-logging guarantee.
2. Reuse its existing output-scalar and conditional-argument pattern where it
   is sufficient. Add a POSIX-safe shared runtime insertion seam only for the
   demonstrated universal-wrapper gap; do not create parallel CA mount or
   assignment state, and do not use shell arrays, `eval`, or whitespace
   splitting.
3. Reuse `shimmy_local_image_build_options_append` and its existing secret
   validation path for the optional fixed build secret. Do not add it to
   identity rendering or any image reference/hash/label path.
4. Ensure reference rendering, ensure, and stale cleanup remain exactly
   consistent and that changing only a bundle cannot alter a local image ref.
5. Preserve preview output correctness: it shows the runtime mount/assignment
   but never build-secret source, host CA contents, or raw control variable.

### Verification checklist

- [ ] POSIX syntax checks pass for changed shell files.
- [ ] Focused helper tests pass for disabled, zero-byte, valid path-with-spaces,
  runtime argument construction, and unchanged image reference across changed
  bundle contents.
- [ ] Focused tests prove no host path or contents occur in cache identity;
  preview displays only the approved runtime mount and assignment.

### Human review gate

Confirm the host-only control-variable boundary, universal runtime argument
API, and deliberate cache portability behavior before accepting the chunk.

## Chunk 3 — Runtime and Containerfile adoption

### Goal

Apply the universal runtime contract to all concrete versions and conditional
build-time trust installation to all local-build contexts.

### Files

- Every concrete `tools/*/versions/*/run.sh` identified by the runtime
  inventory.
- Every local-build Containerfile listed above.
- `tools/aba/versions/1.3/run.sh` for removal of its duplicate build-secret
  construction.
- Affected tool tests.

### Implementation requirements

1. Keep all sixteen documented native mappings and add the stable mount to
   each. Verify mapping order after wildcard environment forwarding.
2. Audit each of the twelve fallback wrappers for a documented native mapping
   before using `SSL_CERT_FILE`; record the result in its guide/skill. Apply
   fallback only where no mapping is documented.
3. Ensure all 28 wrappers have exactly one conditional mount and exactly one
   selected CA environment assignment when the bundle is present, and neither
   when disabled/zero-byte.
4. Before editing each Containerfile, inspect its `image.conf` base and use the
   verified native trust-anchor/refresh mechanism. Put optional secret use
   before every build-stage network operation, preserve architecture/source
   pins, and remove anchor copies within the same layer.
5. Migrate ABA from its `required=true` special secret to the common optional
   secret while preserving its privilege gates and runtime behavior.
6. Add positive preview assertions to existing tool tests. Add one lowest-cost
   authoritative proof of disabled compatibility and secret/path redaction;
   do not duplicate generic rejection tests.

### Verification checklist

- [ ] Every changed executable shell file passes `/bin/sh -n` and retains its
  executable mode.
- [ ] Selected affected tool groups pass using default bounded parallelism.
- [ ] Static inventory tests prove all 28 runtimes have universal conditional
  CA treatment and all 14 local-build Containerfiles consume the common secret
  before network work.
- [ ] Full source-only test suite passes.

### Human review gate

Confirm every tool has either a documented native mapping or the requested
`SSL_CERT_FILE` fallback, all local build stages receive trust correctly, and
image identities remain independent of user CA configuration.

## Chunk 4 — Documentation and acceptance evidence

### Goal

Document the universal surface and complete source-only plus authorized native
acceptance evidence.

### Files

- `README.md`
- Affected `tools/*/guide.md` and `tools/*/SKILL.md`
- `plans/wip/local-build-host-ca.md`

### Implementation requirements

1. Document the stable runtime mount, native-mapping/fallback selection,
   build-secret behavior, nonempty-file predicate, host-only raw variable, and
   the explicit cache portability rule.
2. Explain that normal cached local images are not rebuilt when the bundle
   changes; users who need refreshed build-time trust must explicitly rebuild
   with the tool's documented `SHIMMY_<TOOL>_IMAGE_BUILD=always` setting.
3. Do not claim PEM validation, universal application support, automatic trust
   merging, or retention of certificates in final image layers.
4. Run a live native build and non-mutating smoke only after explicit user
   authorization. Record native Linux amd64 and Apple Silicon arm64 evidence or
   an explicit approved deferral.
5. Update progress and lessons before the review gate.

### Verification checklist

- [ ] `./tests/test.sh` passes with default bounded parallelism.
- [ ] `git diff --check` passes.
- [ ] Source preview verifies disabled and enabled runtime behavior without
  exposing CA contents or a raw host variable.
- [ ] If authorized, native local build plus non-mutating smoke succeeds on
  Linux amd64 and macOS arm64, or an explicit deferral is recorded.

### Human review gate

Confirm user documentation accurately describes the universal contract and
cache portability tradeoff, and accept or explicitly defer native live-build
acceptance.

## Risk register

- **Fallback compatibility:** not all tools honor `SSL_CERT_FILE`. Mitigation:
  use documented native mappings first and state fallback limitations.
- **Malformed nonempty file:** selected input contract can cause a trust-refresh
  or TLS initialization failure. Mitigation: document it and fail visibly.
- **Portable cache versus fresh build trust:** cache identity deliberately does
  not vary with the bundle, so an existing image may lack newly supplied
  build-time trust. Mitigation: document explicit rebuild mode; runtime trust
  remains current on every invocation.
- **Base-image divergence:** trust paths vary by distribution and stage.
  Mitigation: inspect each pinned base and do not mechanically apply one
  command to every Containerfile.
- **Secret persistence:** separate copy/remove layers leak anchors. Mitigation:
  one secret-mounted layer copies, refreshes, and removes.

## Lessons learned

### Initial

- Runtime CA support previously covered only 16 of 28 concrete wrappers and
  used tool-specific mappings.
- All local-image construction routes converge in `lib/runtime/image.sh`, but
  runtime command construction remains distributed among wrappers.
- The prior plan incorrectly made CA bundle content a cache-identity input.
  The corrected design intentionally preserves cache/tag portability.

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, applicable child
contexts, this plan, and the active chunk's files. Implement only the
explicitly accepted chunk. Preserve POSIX shell constraints, the host-only raw
variable boundary, and the cache-identity independence from CA configuration.
Stop at the chunk's human review gate.
