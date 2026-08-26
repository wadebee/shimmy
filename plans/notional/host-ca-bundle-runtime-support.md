# Shimmy Host CA Bundle Runtime Support

## Objective

Add the host-side runtime input `SHIMMY_HOST_CA_BUNDLE=/absolute/path/to/bundle.pem` and make every currently retained, positively verified CA-aware concrete implementation opt in from its version-owned `run.sh`.

Success means:

- An unset or empty control variable leaves every implementation's Podman command unchanged.
- A configured bundle is validated as an absolute, readable regular file before any Podman invocation.
- Only that exact file is mounted read-only at `/tmp/shimmy-host-ca-bundle.pem`.
- Each opted-in implementation receives its verified native file-based CA environment assignment; `SHIMMY_HOST_CA_BUNDLE` itself is never passed into the container.
- Paths containing spaces and paths with symlinked components remain safe and are not canonicalized.
- Preview output shows the mount and native environment assignment.
- Existing broad environment forwarding cannot replace Shimmy's container path.
- Documentation explains that native runtimes differ between additive and replacement trust semantics, so users may need a combined public and corporate bundle.

Explicit exclusions:

- No automatic host trust discovery, Keychain inspection, trust-store directory mount, certificate installation, bundle merging, TLS-verification bypass, privilege escalation, or writable CA mount.
- No Tool Specification, Implementation Specification, Profile Declaration, declarative CA metadata, `tool.conf`, `image.conf`, `ca.conf`, `runtime.conf`, or profile-manifest change.
- No persistence of host CA paths into installed catalog state, profiles, generated catalogs, or generated `.agents/skills/` copies.
- No speculative opt-in for implementations without a verified, safe file-based mechanism.
- No changes to the user's untracked `docs/ARCHITECTURE.md` future-architecture draft.

## Target layout and terminology

`SHIMMY_HOST_CA_BUNDLE` is a host-only Shimmy control variable. The shared helper prepares three shell variables for an explicitly opted-in version runtime:

```text
SHIMMY_HOST_CA_BUNDLE=/host/path/company.pem
        |
        v
lib/runtime/podman.sh
  shimmy_podman_ca_bundle_prepare NATIVE_CA_ENV
        |
        +-- SHIMMY_PODMAN_CA_BUNDLE_SOURCE=/host/path/company.pem
        +-- SHIMMY_PODMAN_CA_BUNDLE_TARGET=/tmp/shimmy-host-ca-bundle.pem
        `-- SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT=NATIVE_CA_ENV=/tmp/shimmy-host-ca-bundle.pem
        |
        v
tools/<tool>/versions/<version>/run.sh
  -v /host/path/company.pem:/tmp/shimmy-host-ca-bundle.pem:ro
  -e NATIVE_CA_ENV=/tmp/shimmy-host-ca-bundle.pem
```

Terms used in this plan:

- **control variable**: `SHIMMY_HOST_CA_BUNDLE`, interpreted only by the host wrapper.
- **native CA environment variable**: the implementation/runtime-specific variable passed explicitly to the application container.
- **opt-in**: the concrete version's `run.sh` calls the shared helper with one verified native CA variable and conditionally appends the prepared mount and environment arguments.
- **replacement-capable**: a native mechanism that may replace normal trust-file discovery rather than augmenting the built-in/public roots.

## Recorded design decisions

1. The shared function is named `shimmy_podman_ca_bundle_prepare` and accepts exactly one native CA environment-variable name.
2. The stable container path is `/tmp/shimmy-host-ca-bundle.pem`; implementations do not choose their own target.
3. The helper resets all three output variables at the start of every call. It validates the native variable name as `[A-Za-z_][A-Za-z0-9_]*` without `eval`, including when the feature is disabled.
4. Unset and empty `SHIMMY_HOST_CA_BUNDLE` are identical disabled states and return success with all output variables empty.
5. A non-empty bundle path must start with `/`, satisfy `-f`, and satisfy `-r`. Validation preserves the supplied spelling and accepts symlinked path components. It does not resolve, copy, parse, print, or merge the bundle.
6. Invalid bundle errors use the contract form `ERROR: SHIMMY_HOST_CA_BUNDLE must name an absolute readable CA bundle file: <path>` and return failure while the caller's `set -e` terminates before Podman preflight, image inspection/build, or execution.
7. The helper returns prepared scalar values, not whitespace-delimited Podman arguments. Every `run.sh` uses the existing POSIX conditional-argument pattern so a source path containing spaces remains one argument.
8. Every opted-in runtime calls the helper after sourcing `lib/runtime/image.sh` and before any Podman preflight or local-image ensure operation.
9. The explicit native assignment appears after any broad inheritance such as `-e AWS_*`, `-e CLOUDSDK_*`, or `-e GH_*`, so a host-native path cannot override the stable container path.
10. `SHIMMY_HOST_CA_BUNDLE` is never exported by Shimmy and is never forwarded with `-e`; only the explicit native assignment is emitted.
11. Existing application-level CA flags or configuration can still take precedence according to that application's native behavior. Shimmy does not attempt to defeat an explicit user/application override.
12. The installed profile already copies the complete shared `lib/` tree and selected concrete version directory. Therefore the shared helper and version runtime changes materialize through existing install/catalog behavior without manifest or installer schema changes.
13. Documentation will distinguish Node's additive `NODE_EXTRA_CA_CERTS` behavior from replacement-capable or implementation-defined behavior for AWS, Google Cloud CLI, Go, and HTTPX. No automatic merge is added.
14. The current `README.md` has user edits. Implementation must hand-merge the CA documentation without replacing or reverting those edits.

## Verified implementation inventory

The repository currently retains 23 concrete version directories. Fourteen implementations across twelve tools qualify for opt-in:

| Tool implementation | Native assignment | Verified basis and semantic note |
| --- | --- | --- |
| AWS CLI `2.31` | `AWS_CA_BUNDLE` | AWS CLI documents a file-valued CA bundle environment variable; treat it as a custom/replacement-capable bundle. |
| Google Cloud CLI `573.0` | `CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE` | `core/custom_ca_certs_file` is an official property and Cloud SDK maps properties to `CLOUDSDK_SECTION_PROPERTY`; explicit assignment must follow `CLOUDSDK_*`. |
| npx `24.18` | `NODE_EXTRA_CA_CERTS` | The concrete image runs Node 24; Node documents this PEM file as extending built-in roots and reading it at process startup. |
| gdrive `0.2` | `NODE_EXTRA_CA_CERTS` | The pinned implementation launches its committed JavaScript with Node and uses the normal Node TLS stack for Google APIs. |
| Tessl `0.1` | `NODE_EXTRA_CA_CERTS` | The image entrypoint is the npm-distributed Node CLI. Node's documented startup hook is the available file-based mechanism; application code that explicitly supplies a `ca` option can override it. |
| Go `1.26` | `SSL_CERT_FILE` | The Go command performs module and toolchain HTTPS through Go's standard trust pool; `crypto/x509` documents the environment override on Unix. |
| Terraform `1.15` | `SSL_CERT_FILE` | The pinned Terraform release is Go-based and its core/provider processes inherit the standard Go trust-file override; supplied bundles must be suitable for replacement-capable behavior. |
| GitHub CLI `2.94` | `SSL_CERT_FILE` | The exact release uses go-gh's `http.DefaultTransport`, which uses Go's standard trust pool. |
| Task `3.45` | `SSL_CERT_FILE` | Remote Taskfile HTTP in this Go release uses the standard Go trust pool. The newer Task-specific `--cacert` interface is not backported or injected. |
| OpenShift CLI `4.18`, `4.20`, `4.22` | `SSL_CERT_FILE` | Each `oc` binary uses the Go/client-go TLS path and system roots when kubeconfig or CLI arguments do not supply explicit CA data. |
| Skopeo `1.22` | `SSL_CERT_FILE` | Skopeo/containers-image uses Go TLS system roots when no registry-specific cert directory is supplied. Existing `--cert-dir`/`certs.d` behavior remains available and can take precedence. |
| OPNsense MCP read-only `0.4` | `SSL_CERT_FILE` | The exact pinned source constructs `httpx.AsyncClient(..., verify=True/False)` without a custom SSL context; HTTPX honors `SSL_CERT_FILE` when trust is enabled. Host curl preflight must receive the same host bundle through `--cacert` when `OPNSENSE_VERIFY_SSL=true`. |

Authoritative evidence used for the mappings:

- AWS CLI environment variables: <https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html>
- Google Cloud CLI properties and environment mapping: <https://docs.cloud.google.com/sdk/docs/properties> and <https://docs.cloud.google.com/sdk/gcloud/reference/config/list>
- Node `NODE_EXTRA_CA_CERTS`: <https://nodejs.org/docs/latest/api/cli.html#node_extra_ca_certsfile>
- Go system roots: <https://go.dev/pkg/crypto/x509/> and <https://go.dev/src/crypto/x509/root_unix.go>
- GitHub CLI v2.94 client and its pinned go-gh transport: <https://github.com/cli/cli/blob/v2.94.0/api/http_client.go> and <https://github.com/cli/go-gh/blob/v2.13.0/pkg/api/http_client.go>
- HTTPX environment trust: <https://www.python-httpx.org/environment_variables/#ssl_cert_file> and pinned read-only client source <https://github.com/lucamarien/opnsense-mcp-server/blob/8ddb99a2a99102abc084b5e605aaba1c05c2ff56/src/opnsense_mcp/api_client.py>
- Skopeo's separate registry-specific certificate mechanism: <https://github.com/containers/image/blob/main/docs/containers-certs.d.5.md>
- Ncat's mode-specific trust-file option: <https://nmap.org/book/ncat-man.html>

Nine implementations remain unchanged after audit:

| Implementation | Reason for no opt-in |
| --- | --- |
| Bats `1.14`, jq `1.8`, ripgrep `15.1` | No outbound TLS client or native CA-consumption path in the wrapped command. |
| Logmine `0.1`, Textual `8.2` | Current concrete commands do not expose a verified outbound TLS trust path requiring this runtime input. |
| Nmap `7.98` | Nmap's scan/runtime surface has no general file-based CA environment hook. |
| Netcat/Ncat `7.92` | `--ssl-trustfile` is CLI-only, meaningful with `--ssl-verify`, and replaces defaults; injecting it into every invocation would change argument semantics and requires separate design. |
| Community Ansible Development Tools `26.7` | The implementation is a heterogeneous multi-command environment; no single file variable is an authoritative CA hook for all bundled applications. |
| OPNsense MCP admin `1.0` | The pinned client explicitly builds `ssl.create_default_context(cafile=certifi.where())`, bypassing `SSL_CERT_FILE`; supporting it requires an upstream/configuration design rather than a misleading mount. |

Primary shared change surface:

- `lib/runtime/podman.sh`
- `tests/lib/runtime.sh`

Primary opted-in version runtimes and tests:

- `tools/aws/versions/2.31/run.sh`, `tools/aws/tests/aws.sh`
- `tools/gcloud/versions/573.0/run.sh`, `tools/gcloud/tests/gcloud.sh`
- `tools/npx/versions/24.18/run.sh`, `tools/npx/tests/npx.sh`
- `tools/gdrive/versions/0.2/run.sh`, `tools/gdrive/tests/gdrive.sh`
- `tools/tessl/versions/0.1/run.sh`, `tools/tessl/tests/tessl.sh`
- `tools/go/versions/1.26/run.sh`, `tools/go/tests/go.sh`
- `tools/terraform/versions/1.15/run.sh`, `tools/terraform/tests/terraform.sh`
- `tools/gh/versions/2.94/run.sh`, `tools/gh/tests/gh.sh`
- `tools/task/versions/3.45/run.sh`, `tools/task/tests/task.sh`
- `tools/oc/versions/{4.18,4.20,4.22}/run.sh`, `tools/oc/tests/oc.sh`
- `tools/skopeo/versions/1.22/run.sh`, `tools/skopeo/tests/skopeo.sh`
- `tools/opnsense-mcp-read-only/versions/0.4/run.sh`, `tools/opnsense-mcp-read-only/tests/opnsense-mcp-read-only.sh`

Documentation consumers are `README.md` and the canonical `guide.md` and `SKILL.md` files for each opted-in tool. The inventory is the verified baseline, not permission to ignore a newly discovered required dependency while executing a chunk.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Add and verify the shared CA-bundle preparation contract.
- [ ] Chunk 2 — Opt in AWS, Google Cloud CLI, and Node implementations.
- [ ] Chunk 3 — Opt in verified Go trust-pool implementations.
- [ ] Chunk 4 — Opt in OPNsense read-only, finish cross-cutting documentation, and run regressions.

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

## Chunk 1 — Shared runtime preparation

### Goal

Add a narrow, tested helper that turns one explicit host path and one verified native variable name into safe scalar values for existing POSIX Podman argument construction. This chunk intentionally exposes no user-visible tool support yet.

### Files

- `lib/runtime/podman.sh`
- `tests/lib/runtime.sh`

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high, because quoting, validation order, and failure-before-Podman behavior form a security boundary.

1. Add `shimmy_podman_ca_bundle_prepare` near the other shared argument-preparation helpers.
2. Reset `SHIMMY_PODMAN_CA_BUNDLE_SOURCE`, `SHIMMY_PODMAN_CA_BUNDLE_TARGET`, and `SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT` before validating either input.
3. Validate the parameter with POSIX `case` patterns; accept only `[A-Za-z_][A-Za-z0-9_]*`. Do not use `eval`, indirect expansion, arrays, or shell-specific syntax.
4. Treat `${SHIMMY_HOST_CA_BUNDLE:-}` as disabled when empty. Otherwise require absolute path, regular file, and current-user readability, preserving the original path spelling.
5. Set the fixed target and construct `<native-name>=/tmp/shimmy-host-ca-bundle.pem` as data only.
6. Keep all failures concise, on stderr, and free of file contents.
7. Add direct helper tests for disabled/reset state, a valid path containing spaces, a path through a symlinked parent, a malformed native variable name, and invalid relative/missing/directory/unreadable bundle inputs. Make the unreadable fixture conditional only if the executing account can make `-r` false; do not create a root-only false failure.
8. Register the tests in `test_lib_runtime_run` without duplicating equivalent generic rejection coverage elsewhere.

### Verification checklist

- [ ] `/bin/sh -n lib/runtime/podman.sh tests/lib/runtime.sh` succeeds.
- [ ] `./tests/test.sh --group lib-runtime` passes.
- [ ] A valid source path with spaces is retained byte-for-byte in `SOURCE`, and the exact target and environment assignment are produced.
- [ ] Disabled preparation clears stale values and emits no CA state.
- [ ] Malformed native names and invalid configured bundles fail with the intended concise errors and never print bundle contents.
- [ ] No non-plan repository file outside this chunk is changed.

### Human review gate

Confirm the helper API, validation boundary, error text, POSIX quoting strategy, and intentionally unused intermediate capability before accepting Chunk 1.

## Chunk 2 — AWS, Google Cloud CLI, and Node opt-ins

### Goal

Make the application-specific AWS/Google mappings and the Node runtime family consume the shared capability without changing their disabled behavior, credentials, mounts, image handling, or command semantics.

### Files

- `tools/aws/versions/2.31/run.sh`, `tools/aws/tests/aws.sh`, `tools/aws/guide.md`, `tools/aws/SKILL.md`
- `tools/gcloud/versions/573.0/run.sh`, `tools/gcloud/tests/gcloud.sh`, `tools/gcloud/guide.md`, `tools/gcloud/SKILL.md`
- `tools/npx/versions/24.18/run.sh`, `tools/npx/tests/npx.sh`, `tools/npx/guide.md`, `tools/npx/SKILL.md`
- `tools/gdrive/versions/0.2/run.sh`, `tools/gdrive/tests/gdrive.sh`, `tools/gdrive/guide.md`, `tools/gdrive/SKILL.md`
- `tools/tessl/versions/0.1/run.sh`, `tools/tessl/tests/tessl.sh`, `tools/tessl/guide.md`, `tools/tessl/SKILL.md`

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high, primarily for environment ordering and preserving wrapper-specific preflights.

1. Call the helper with `AWS_CA_BUNDLE`, `CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE`, or `NODE_EXTRA_CA_CERTS` as recorded in the inventory, before Podman preflight/local-image activity.
2. Add the read-only `-v` pair and explicit `-e` pair through separate conditional arguments immediately before the runtime image.
3. In AWS, place `AWS_CA_BUNDLE=...` after `-e AWS_*`. In gcloud, place `CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE=...` after `-e CLOUDSDK_*` and retain the explicit `CLOUDSDK_CONFIG` and `HOME` mappings. Test relative ordering with a POSIX `case` assertion, not a whitespace split.
4. Preserve npx's entrypoint and package confirmation boundary, gdrive's OAuth credential/port behavior, Tessl's config mount/resource limits, and every current image override.
5. Extend each existing preview-contract test using one fixture bundle whose host path contains spaces. Assert the exact `:ro` mount and native assignment.
6. Use AWS as the lowest-cost authoritative proof that the control variable itself is absent, an unset/empty feature produces no CA arguments, and an invalid configured path fails before a fake Podman executable is called.
7. Update only canonical guides and tool skills. Explain Node additive semantics and the explicit-`ca` caveat; describe AWS and gcloud as custom/replacement-capable mechanisms.

### Verification checklist

- [ ] `/bin/sh -n` succeeds for all changed runtime and test scripts.
- [ ] `./tests/test.sh --jobs 3 --group tools-aws --group tools-gcloud --group tools-npx --group tools-gdrive --group tools-tessl` passes.
- [ ] Each enabled preview contains exactly one read-only bundle mount and its recorded native environment assignment.
- [ ] AWS and gcloud explicit assignments render after their wildcard inheritance arguments.
- [ ] AWS proves disabled compatibility, host-control-variable isolation, path-with-spaces safety, and failure before Podman.
- [ ] Updated guides and canonical skills state the mapping and trust semantics without claiming automatic merging.

### Human review gate

Confirm all five mappings, wildcard precedence, preview output, credential/mount preservation, and documentation semantics before accepting Chunk 2.

## Chunk 3 — Go trust-pool opt-ins

### Goal

Wire `SSL_CERT_FILE` into every retained network-capable implementation positively verified to use Go's standard trust pool.

### Files

- `tools/go/versions/1.26/run.sh`, `tools/go/tests/go.sh`, `tools/go/guide.md`, `tools/go/SKILL.md`
- `tools/terraform/versions/1.15/run.sh`, `tools/terraform/tests/terraform.sh`, `tools/terraform/guide.md`, `tools/terraform/SKILL.md`
- `tools/gh/versions/2.94/run.sh`, `tools/gh/tests/gh.sh`, `tools/gh/guide.md`, `tools/gh/SKILL.md`
- `tools/task/versions/3.45/run.sh`, `tools/task/tests/task.sh`, `tools/task/guide.md`, `tools/task/SKILL.md`
- `tools/oc/versions/4.18/run.sh`, `tools/oc/versions/4.20/run.sh`, `tools/oc/versions/4.22/run.sh`, `tools/oc/tests/oc.sh`, `tools/oc/guide.md`, `tools/oc/SKILL.md`
- `tools/skopeo/versions/1.22/run.sh`, `tools/skopeo/tests/skopeo.sh`, `tools/skopeo/guide.md`, `tools/skopeo/SKILL.md`

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high, because the group shares a runtime hook but has distinct application overrides and host-integration contracts.

1. Call `shimmy_podman_ca_bundle_prepare SSL_CERT_FILE` before Podman preflight/local-image activity in each concrete version.
2. Add the prepared mount and explicit environment assignment through the same safe conditional pattern used in Chunk 2.
3. Keep Terraform's `AWS_*`/`TF_VAR_*`, GitHub CLI's `GH_*` and persistent config, Task's host path/home/tmp/socket behavior, all three `oc` version tracks, and Skopeo's auth secret and active-profile registry projection unchanged.
4. Extend existing preview tests with a path-containing-spaces bundle. The `oc` test must prove all three retained versions opt in, not only the default track.
5. Update each canonical guide and skill. State that `SSL_CERT_FILE` changes Go system-root file discovery, may act as a replacement, and does not override explicit kubeconfig CA data, Terraform provider-specific CA configuration, Task's future/version-specific `--cacert`, or Skopeo registry `certs.d`/`--cert-dir` settings.
6. Correct Skopeo documentation that currently says Shimmy cannot mount corporate CA trust, while retaining the distinction between this exact-file opt-in and its registry-specific certificate directories.

### Verification checklist

- [ ] `/bin/sh -n` succeeds for all changed runtime and test scripts.
- [ ] `./tests/test.sh --jobs 3 --group tools-go --group tools-terraform --group tools-gh --group tools-task --group tools-oc --group tools-skopeo` passes.
- [ ] Every enabled preview contains the exact read-only mount and `SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem`.
- [ ] All three OpenShift version previews contain the CA mapping.
- [ ] Existing config, credential, registry-policy, host-coupling, and version-dispatch assertions still pass.
- [ ] Documentation accurately states application-specific override precedence and replacement-capable semantics.

### Human review gate

Confirm the verified Go consumer set, all three OpenShift tracks, application override caveats, and preservation of each wrapper's existing host/security contracts before accepting Chunk 3.

## Chunk 4 — OPNsense read-only and cross-cutting acceptance

### Goal

Complete the only qualifying implementation whose host-side reachability preflight also performs TLS, document the overall user contract, and verify the integrated feature.

### Files

- `tools/opnsense-mcp-read-only/versions/0.4/run.sh`
- `tools/opnsense-mcp-read-only/tests/opnsense-mcp-read-only.sh`
- `tools/opnsense-mcp-read-only/guide.md`
- `tools/opnsense-mcp-read-only/SKILL.md`
- `README.md`
- Any earlier chunk file requiring a narrowly scoped correction discovered by integrated verification; record the divergence before editing it.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high, because host curl and container HTTPX must agree without changing the existing verification default.

1. Prepare `SSL_CERT_FILE` before URL/curl/Podman preflight and before local-image inspection/build.
2. Keep `OPNSENSE_VERIFY_SSL` behavior unchanged. When it is `true` and a host bundle is configured, pass `--cacert "$SHIMMY_PODMAN_CA_BUNDLE_SOURCE"` to the host curl preflight using safe conditional arguments. When verification is `false`, retain the existing `--insecure` behavior and document that the CA bundle has no effect until verification is enabled.
3. Add the same read-only mount and explicit container `SSL_CERT_FILE` assignment used by the Go consumers. Do not alter secrets, write defaults, URL normalization, timeouts, or MCP stdio behavior.
4. Extend preview coverage for the mount/environment mapping. Add a fake-curl preflight scenario that proves the exact host path remains one `--cacert` argument when verification is enabled; do not perform a live firewall request.
5. Update the canonical guide and skill with a private-CA example that sets both `SHIMMY_HOST_CA_BUNDLE` and `OPNSENSE_VERIFY_SSL=true`.
6. Hand-merge a concise `README.md` section describing the global host control variable, stable container path, exact-file/read-only security boundary, opted-in tool/mapping table, and replacement-bundle limitation. Preserve the user's existing README changes.
7. Confirm excluded tools remain untouched. Do not add absence-only tests for forbidden metadata files; the reviewed diff is the lowest-cost proof of that architectural boundary.

### Verification checklist

- [ ] `/bin/sh -n tools/opnsense-mcp-read-only/versions/0.4/run.sh tools/opnsense-mcp-read-only/tests/opnsense-mcp-read-only.sh` succeeds.
- [ ] `./tests/test.sh --jobs 3 --group lib-runtime --group tools-opnsense-mcp-read-only` passes.
- [ ] The OPNsense preview shows the exact read-only mount and container `SSL_CERT_FILE` assignment.
- [ ] Fake curl receives one `--cacert` plus the original host path when verification is true, and existing `--insecure` behavior remains unchanged when false.
- [ ] `./tests/test.sh` passes with its default bounded parallel execution; rerun only failures serially when diagnosing an order-sensitive failure.
- [ ] `git diff --check` passes.
- [ ] Review of `git diff --name-only` confirms no `tool.conf`, `image.conf`, manifest/profile schema, new metadata layer, generated `.agents/skills/`, excluded implementation, or `docs/ARCHITECTURE.md` change.
- [ ] README, canonical guides, and canonical tool skills agree on the input, mappings, opt-in scope, and semantic limitation.

### Human review gate

Confirm integrated behavior, full-suite results, the OPNsense verification interaction, documentation accuracy, preservation of pre-existing README edits, and the final diff scope. Acceptance authorizes no further work; final plan completion still requires explicit human acceptance.

## Risk register

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Native wildcard inheritance wins over Shimmy's path | The container receives a host-only path that does not exist. | Render the explicit mapping after wildcards and assert ordering for AWS/gcloud. |
| Unsafe shell argument construction | Paths containing spaces split or are evaluated. | Keep prepared values scalar, use two conditional arguments per Podman option, quote expansions, and prohibit `eval`. |
| Validation happens after Podman/image work | Invalid authorization input can trigger engine access or builds first. | Call preparation before every Podman preflight and local-image ensure; prove with a fake Podman scenario. |
| A custom bundle removes public roots | Public services fail after private-CA support is enabled. | Document per-runtime semantics and require users to provide a combined bundle when the native mechanism replaces defaults. |
| A generic runtime hook is misleading for an app that replaces trust itself | Mount appears configured but application ignores it. | Limit opt-in to the verified inventory; exclude OPNsense admin and document explicit application overrides. |
| OPNsense host curl and container trust diverge | Preflight fails even though the container would trust the firewall, or vice versa. | Feed the same host bundle to curl with `--cacert` only when verification is enabled, then mount/map it for HTTPX. |
| Broad multi-tool change obscures regressions | Existing credential, profile, or version behavior is accidentally changed. | Split by mechanism family, extend existing preview contracts, run focused groups at each gate, then the full suite. |
| Existing user README edits are overwritten | User work is lost. | Inspect the dirty diff again in Chunk 4 and hand-merge only the CA documentation section. |

## Lessons learned

### Initial

- `lib/runtime/image.sh` already sources `lib/runtime/podman.sh`, so version runtimes need no second shared-helper source path.
- Profile materialization copies the whole shared `lib/` tree and selected concrete version directory; runtime support belongs there and requires no manifest schema change.
- Preview quoting already keeps one shell argument visible as one quoted token, making it the primary acceptance surface for paths containing spaces.
- AWS, gcloud, and GitHub CLI already inherit broad environment prefixes, so explicit native CA assignments must be placed later.
- Node's hook is additive, while Go/HTTPX and application-specific bundle settings can replace normal trust-file discovery.
- OPNsense read-only uses HTTPX's normal trust path, but OPNsense admin pins an explicit certifi context and must remain excluded.
- Task `3.45` predates its application-specific `--cacert`; its qualifying mechanism is the Go runtime trust-file hook, not a backport of newer CLI behavior.
- Ncat and Skopeo expose specialized CA interfaces, but only Skopeo also has a verified safe standard-root path suitable for the shared environment helper. Ncat's flag-only mode requires separate design.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, `lib/CONTEXT.md`, `lib/runtime/CONTEXT.md`, `tests/CONTEXT.md`, and `tests/lib/CONTEXT.md` before touching shared runtime or tests.
2. Read this plan completely, then read the active chunk's listed runtime, tests, guides, and canonical tool skills. Tool directories have no child `CONTEXT.md` files.
3. Recheck `git status --short` and the README diff. Preserve the user's modified `README.md` and untracked `docs/ARCHITECTURE.md`.
4. The non-negotiable target is one exact host file, mounted read-only at `/tmp/shimmy-host-ca-bundle.pem`, with explicit concrete-version opt-in and no metadata/profile architecture.
5. Move this plan from `plans/notional/` to `plans/wip/` before changing implementation files, then execute only the currently approved chunk.
6. Active chunk at initial review: Chunk 1. Stop at its human review gate and update this plan's checklist and lessons before reporting.
