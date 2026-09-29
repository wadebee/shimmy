# Universal host CA bundle support

## Objective

Complete the already-implemented universal `SHIMMY_HOST_CA_BUNDLE` capability so
its security boundary, regression coverage, and canonical documentation match
runtime behavior.

A present bundle is an absolute, readable, nonempty regular host file. Every
concrete runtime mounts it read-only at
`/tmp/shimmy-host-ca-bundle.pem` and receives exactly one selected assignment:
a documented native variable where available, otherwise `SSL_CERT_FILE`.
Every remaining local-build context receives the same bundle as the optional
`shimmy-host-ca-bundle` build secret before its network operations. The raw
control variable, host pathname, and contents remain host-only.

Success conditions:

- Invalid bundle validation diagnostics do not disclose the supplied host path.
- The completed suite reflects the OpenShift external-image migration and
  passes with the default bounded parallel runner.
- README and every canonical tool guide and skill accurately describe the
  universal contract, including each tool's selected mapping and the
  local-build cache portability rule.
- Existing runtime and local-build behavior is preserved: local image identity,
  tag, label, stale-cleanup reference, and cache reuse do not vary by bundle
  presence or contents.

Explicit exclusions:

- No PEM parsing, certificate discovery/merging, TLS-verification bypass, or
  base-image pin changes.
- No live build or runtime smoke without separate explicit authorization.
- No attempt to make applications that ignore `SSL_CERT_FILE` accept the
  bundle.

## Target layout and terminology

```text
SHIMMY_HOST_CA_BUNDLE=/absolute/host/bundle.pem
  |
  +-- runtime: -v <host>:/tmp/shimmy-host-ca-bundle.pem:ro
  |            -e <native mapping or SSL_CERT_FILE>=/tmp/shimmy-host-ca-bundle.pem
  |
  `-- local build only: --secret id=shimmy-host-ca-bundle,src=<host>
                         Containerfile native trust refresh before network work
```

A **native mapping** is a documented application-specific variable:
`AWS_CA_BUNDLE`, `CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE`, or
`NODE_EXTRA_CA_CERTS`. The **fallback mapping** is `SSL_CERT_FILE`.
A **local-build context** is a concrete version whose `image.conf` has
`image_source=local-build`; there are currently eleven after the three OpenShift
tracks changed to external images.

## Recorded design decisions

1. `shimmy_podman_ca_bundle_prepare` remains the one host-side validator and
   renderer. It must not emit `SHIMMY_HOST_CA_BUNDLE`'s value in diagnostics.
2. Do not introduce another CA mount, secret, identity, or mapping helper.
   `lib/runtime/image.sh` continues to append the fixed build secret only for a
   present bundle and intentionally omits that secret from identity output.
3. Runtime wrappers retain exactly one explicit mapping after any wildcard
   forwarding. The native mappings are AWS, gcloud, and Node-based gdrive/npx/
   Tessl; all other current runtimes use the requested `SSL_CERT_FILE`
   fallback.
4. OpenShift 4.18, 4.20, and 4.22 are external authenticated Red Hat images.
   Their source preview and agent-preflight smoke are `oc --help`; test
   expectations must assert the current pull behavior rather than the retired
   local-build behavior.
5. The no-host-path diagnostic rule is a durable secret-redaction boundary and
   receives one lowest-cost shared-helper proof, rather than repeated
   tool-specific rejection tests.
6. Documentation describes invalid inputs as rejected before runtime/build
   argument construction, not merely omitted. It must not claim that ABA's
   bundle is required or that its content changes cache identity.

## Verified implementation inventory

- All 26 concrete runtimes invoke `shimmy_podman_ca_bundle_prepare`. There are
  no remaining wrappers without a conditional runtime mount and assignment.
- Eleven local-build contexts consume `shimmy-host-ca-bundle`: ABA, gdrive, gh,
  jv, logmine, netcat, both OPNsense MCP tools, task, Tessl, and Textual.
  OpenShift is no longer local-build.
- The shared helper currently violates the documented host-path redaction rule:
  its invalid-relative and invalid-file diagnostics interpolate the supplied
  path in `lib/runtime/podman.sh`.
- `README.md` contains uncommitted universal documentation. It is directionally
  correct but its table still presents only the former opted-in subset.
- Only 14 of 26 canonical tool guides and skills currently mention the host CA
  capability. ABA documentation is stale: it says the value is required and
  that its content is hashed for cache identity.
- The default source-only suite was run on 2026-09-29. It failed only because
  `tests/commands/agent-preflight.sh` and `tests/commands/shim.sh` retain
  OpenShift local-build expectations after commit `916c730`; the observed
  behavior is `oc --help` and `image|oc|4.18|pull`.

This inventory is a verified baseline, not permission to omit newly discovered
consumers.

## Unresolved

None.

## Progress Checklist

- [x] Shared universal CA validation and optional build-secret preparation.
- [x] Runtime wrapper adoption and local-build Containerfile adoption.
- [ ] Chunk 3 — Close redaction and OpenShift migration regression gaps.
- [ ] Chunk 4 — Document all runtime mappings and local-build behavior.
- [ ] Chunk 5 — Execute final source and authorized native acceptance.

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

## Chunk 3 — Redaction and OpenShift regression repair

### Goal

Enforce the host-path redaction boundary and restore source-suite expectations
to the current OpenShift external-image implementation.

### Files

- `lib/runtime/podman.sh`
- `tests/lib/runtime.sh`
- `tests/commands/agent-preflight.sh`
- `tests/commands/shim.sh`
- Any directly affected source-preview test

### Implementation requirements

1. Replace diagnostics that interpolate `SHIMMY_HOST_CA_BUNDLE` with fixed,
   actionable validation messages that disclose only the violated contract.
2. Extend the existing lowest-level runtime helper test to positively establish
   the invalid-input error class and assert the durable redaction boundary for
   one sentinel pathname. Preserve valid, zero-byte, and path-with-spaces
   coverage.
3. Update the agent-preflight expectation to the metadata-owned `oc --help`
   smoke command.
4. Update shim lifecycle image-log assertions from OpenShift `build` to
   `pull`, retaining the positive evidence that selected OC tracks are prepared
   through their current image source.
5. Do not change OpenShift image metadata, runtime mapping, or Containerfiles;
   their conversion is already complete.

### Verification checklist

- [ ] `./tests/test.sh --group lib-runtime --group commands-agent-preflight --group commands-shim --group tools-oc` passes using the default bounded schedule.
- [ ] `/bin/sh -n lib/runtime/podman.sh` passes.
- [ ] The focused helper test proves an invalid sentinel path is absent from its diagnostic.
- [ ] `git diff --check` passes.

### Human review gate

Confirm validation no longer reveals user host paths and the repaired tests
prove the retained external OpenShift behavior without reinstating a local
build expectation.

## Chunk 4 — Canonical documentation completion

### Goal

Make the universal user and agent documentation complete, precise, and
consistent with the implementation.

### Files

- `README.md`
- `tools/*/guide.md`
- `tools/*/SKILL.md`
- This plan

### Implementation requirements

1. Preserve and refine the existing uncommitted README section. Replace the
   former “opted-in” table with a complete mapping inventory or a concise
   mapping classification that accounts for all 26 concrete runtimes.
2. Document the shared input predicate, stable runtime path, host-only raw
   control variable, one selected native/fallback assignment, and the
   `SSL_CERT_FILE` limitation in each canonical guide and skill where that
   information is relevant to using or changing the tool.
3. Add the local-build secret, no-layer-retention, and cache-portability rule to
   the eleven local-build tools. State that an explicit
   `SHIMMY_<TOOL>_IMAGE_BUILD=always` rebuild is needed to refresh build-time
   trust after cache creation.
4. Correct ABA's obsolete required-input and content-hash statements. Correct
   OC references to the prior local Containerfile or build behavior.
5. Keep OPNsense read-only's separate curl preflight behavior documented as an
   additional tool-specific capability, not a universal effect.
6. Do not add generated `.agents/skills` content or duplicate canonical skills.

### Verification checklist

- [ ] Documentation inventory identifies every tool guide and skill with its actual mapping and local/external image status.
- [ ] Source previews for one native-mapped runtime, one fallback runtime, and one local-build runtime show the expected mount and assignment without the raw control variable.
- [ ] `./tests/test.sh` passes with the default bounded parallel runner.
- [ ] `git diff --check` passes.

### Human review gate

Confirm all user-facing and canonical agent guidance accurately describes the
universal contract and cache tradeoff, with no obsolete ABA or OC claims.

## Chunk 5 — Final acceptance evidence

### Goal

Record final source evidence and, only if explicitly authorized, native
local-build and non-mutating runtime smoke evidence.

### Files

- `plans/wip/local-build-host-ca.md`

### Implementation requirements

1. Run the complete source-only suite and record its result.
2. Run live builds and non-mutating smokes only after user authorization and
   outer-wrapper approval. Record native Linux amd64 and native Apple Silicon
   macOS arm64 evidence, or an explicit reviewer-approved deferral.
3. Update this plan's progress and lessons before the final review gate.

### Verification checklist

- [ ] `./tests/test.sh` passes.
- [ ] `git diff --check` passes.
- [ ] Native acceptance is recorded for both hosts or explicitly deferred by the reviewer.

### Human review gate

Accept the completed capability and the stated disposition of native acceptance.

## Risk register

- **Host path disclosure:** validation output can leak a sensitive directory
  layout. Mitigation: fixed diagnostics and one shared redaction proof.
- **Fallback compatibility:** `SSL_CERT_FILE` is not universally honored.
  Mitigation: document native mappings first and state the fallback limit.
- **Cache portability:** changing a bundle does not rebuild an existing local
  image. Mitigation: document explicit build-always mode; runtime mounting is
  still refreshed per invocation.
- **Native trust variation:** base images use different trust stores. Mitigation:
  retain current distribution-specific Containerfile layers and require native
  acceptance before claiming live-build support.

## Lessons learned

### Initial

- The shared optional build secret is intentionally excluded from local-image
  identity, while runtime mount exposure is re-evaluated on every invocation.
- The OpenShift external-image migration invalidated two adjacent command-test
  assumptions; neither failure indicates a CA runtime regression.
- Existing canonical documentation represents only the pre-universal opt-in
  capability and cannot be treated as a complete mapping inventory.

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root and applicable child `CONTEXT.md`
files, this plan, and the active chunk's target files. Begin with Chunk 3 only
when explicitly authorized. Preserve POSIX shell constraints, the host-only
raw-variable and cache-identity boundaries, and the currently uncommitted
README work. Stop at the chunk's human review gate.
