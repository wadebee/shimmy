# Multi-architecture image support

## Objective

Make multi-architecture image compatibility a framework contract for every
current and future Shimmy concrete version, whether that version runs an
externally supplied image directly or builds a local image from a version-owned
Containerfile.

The feature is complete when:

- every concrete version has one version-owned image configuration that
  declares how its default image is obtained and records support for Shimmy's
  required `linux/amd64` and `linux/arm64` platforms;
- every repository-owned external image or local-build base-image default is
  pinned to an immutable OCI image-index or Docker manifest-list digest whose
  descriptors include both required platforms;
- direct-image runtimes and local-build runtimes read their repository-owned
  defaults from that configuration instead of duplicating defaults in shell or
  Containerfiles;
- local build cache identity changes when image configuration or effective
  build arguments change;
- an opt-in, non-mutating command can verify configured remote indexes and
  report upstream-tag drift without pulling the target images;
- generic tests reject incomplete metadata, tag-only defaults,
  architecture-specific child-manifest digests, and platform declarations that
  omit a required platform;
- the runtime launcher detects both host OS and CPU architecture, normalizes
  `uname -m` aliases, and always supplies the matching native Linux image
  platform for supported Linux and Darwin hosts;
- deterministic resolver and runtime-preview tests cover Linux/amd64,
  Linux/arm64, Darwin/amd64, and Darwin/arm64, while native container smokes
  cover both distinct target platforms; and
- tool-creation guidance makes the same contract mandatory for future tools.

The feature does not:

- expand the image-platform set beyond `linux/amd64` and `linux/arm64` or add
  emulation for non-native execution;
- publish locally built images or assemble them into remote manifest lists;
- inspect configured target registries during ordinary tool execution,
  installation, status, or the default repository test suite;
- install or provision Podman, Skopeo, emulation, registry credentials, or
  registry authentication;
- guarantee that a user-supplied `SHIMMY_*_IMAGE` or `SHIMMY_*_BASE_IMAGE`
  override supports both platforms; or
- introduce a central tool-name/version case list or automatic image-update
  policy.

## Target layout and terminology

### Supported platform contract

`lib/runtime/podman.sh` remains the sole runtime platform selector and exposes
the complete required-platform list as shared data:

```text
linux/amd64
linux/arm64
```

It resolves the target from both `uname -s` and `uname -m` according to this
supported host matrix:

| Host OS | Normalized host architecture | Podman image platform |
| --- | --- | --- |
| Linux | `amd64` | `linux/amd64` |
| Linux | `arm64` | `linux/arm64` |
| Darwin | `amd64` | `linux/amd64` |
| Darwin | `arm64` | `linux/arm64` |

Architecture normalization maps `x86_64` and `amd64` to `amd64`, and maps
`aarch64` and `arm64` to `arm64`. An unreadable OS or architecture, an
unsupported OS, or an unsupported architecture fails with a diagnostic before
Podman is invoked; it must never silently fall back to `linux/amd64` or select
a non-native platform. Existing test-only host-OS injection gains equivalent
test-only architecture injection so every supported combination, alias, and
failure path can be exercised deterministically without changing the public
runtime interface.

In this plan:

- **required platform** means one of those two framework targets;
- **upstream reference** means the publisher tag used to discover and review
  updates or, when the publisher exposes the selected artifact only by digest,
  the same digest as the default reference;
- **default reference** means the immutable
  `registry/repository@sha256:<index-digest>` actually used by Shimmy;
- **index digest** means a digest resolving to either
  `application/vnd.oci.image.index.v1+json` or
  `application/vnd.docker.distribution.manifest.list.v2+json` and containing
  descriptors for both required platforms;
- **child-manifest digest** means a digest for only one platform and is invalid
  as a repository-owned default;
- **direct image** means the concrete runtime passes the configured external
  image directly to `podman run`; and
- **local build** means Shimmy builds one platform-specific cached image on the
  current host from a version-owned `container/` context. The local output is
  not itself required to be a manifest list, but every external base and every
  architecture-dependent build step must work for both required platforms.

An ARM descriptor with `architecture=arm64` and an optional `variant=v8`
satisfies `linux/arm64`. Non-runnable descriptors such as provenance or
attestation entries reported as `unknown/unknown` do not satisfy or invalidate
the required platform set.

The OCI image-index specification defines an index as descriptors for one or
more platform-specific manifests and defines the `os`, `architecture`, and
optional `variant` fields used by this contract:
<https://github.com/opencontainers/image-spec/blob/main/image-index.md>.

### Version-owned image configuration

Every `tools/<kind>/versions/<major.minor>/` directory owns a required
`image.conf`. It is metadata, not executable shell, and is read with the
repository's exact-key metadata readers.

Direct-image schema:

```text
shimmy_image_config_version=1
image_source=external
image_upstream_ref=registry.example/vendor/tool:<release-tag>
image_default_ref=registry.example/vendor/tool@sha256:<index-digest>
image_registry_access=public
image_platform=linux/amd64
image_platform=linux/arm64
```

Local-build schema:

```text
shimmy_image_config_version=1
image_source=local-build
image_context=container
image_local_repo=localhost/shimmy-<kind>-<version_with_underscores>
image_base_count=1
image_base_1_build_arg=SHIMMY_<TOOL_PREFIX>_BASE_IMAGE
image_base_1_upstream_ref=registry.example/base/image:<release-tag>
image_base_1_default_ref=registry.example/base/image@sha256:<index-digest>
image_base_1_registry_access=public
image_platform=linux/amd64
image_platform=linux/arm64
```

Rules for schema version 1:

- `image_source` is exactly `external` or `local-build`.
- An external config has exactly one upstream/default/access triplet and no
  local-build keys.
- A local-build config has a relative `image_context`, a `localhost/` image
  repository, and a positive decimal `image_base_count`.
- Base entries are contiguous from 1 through `image_base_count`. Each entry has
  a POSIX-safe, `SHIMMY_`-prefixed build-argument name plus an
  upstream/default/access triplet.
- `image_registry_access` and each numbered equivalent are exactly `public` or
  `authenticated`.
- `scratch` is the only non-registry base allowed. It is declared with
  `image_base_N_default_ref=scratch`, omits upstream/access keys, and is treated
  as platform-neutral.
- All other defaults are fully qualified `@sha256:` references. Tags appear
  only in upstream-reference fields.
- `image_platform` may repeat, contains normalized `os/architecture` values,
  has no duplicates, and equals the shared required-platform set.
- Unknown keys, duplicate scalar keys, missing numbered keys, unsafe build-arg
  names, absolute/traversing contexts, and unsupported schema versions fail
  validation.

The numbered base schema supports future multi-stage Containerfiles that use
different base images without changing the configuration identity. A
multi-stage build that reuses one base and one build argument declares it only
once.

### Shared behavior

`lib/runtime/image.sh` owns safe image-config reads and local-build cache
inputs. It does not own tool names, version names, or publisher references.

- A direct runtime reads `image_default_ref` and applies its existing
  `SHIMMY_<TOOL_PREFIX>_IMAGE` override afterward.
- A local runtime passes each configured base default to its Containerfile as
  the declared build argument. An environment variable with the same name may
  override that base for the current build.
- Local Containerfiles declare their base `ARG` without a duplicate default.
- The local image hash covers the complete container context, `image.conf`,
  and the ordered effective build-argument vector. Changing a pinned base,
  source ref, version argument, or explicit base override therefore selects a
  different cached image in `auto` mode.
- Platform remains part of the local tag, so `linux/amd64` and `linux/arm64`
  builds cannot collide.
- Refresh hooks remain version-owned. `pull` still applies only to direct
  external images or explicit runtime-image overrides; `build` still applies
  only to local builds. Pulling a repository-owned default re-fetches its
  immutable digest; it does not advance the upstream tag. No shared
  tool/version switch is added.

The old `status.conf` image-only format is removed in the same atomic schema
transition. `commands/status.sh`, `commands/agent-preflight.sh`, catalog tests,
and any other consumer read `image.conf`; no forwarding parser or compatibility
alias remains.

### Live verification surface

Add a distinct image lifecycle command:

```text
shimmy images verify [--all | --shim <kind[@version]> ...]
                     [--public-only]
                     [--require-current-upstream]
                     [--format human|manifest]

./commands/images.sh verify --all [the same verification options]
```

Installed behavior defaults to the concrete versions recorded in the invoking
profile manifest. `--all` selects every catalog version. Repeated `--shim`
selects kinds or concrete versions with the same kind/version rules used by
install, update, and test. Source-checkout use requires `--all` or at least one
`--shim`, because there is no source profile identity.

The command:

1. validates every selected `image.conf` offline before network access;
2. invokes the catalog-default Skopeo concrete runtime to fetch each raw remote
   manifest without pulling target image layers;
3. parses the raw JSON through the catalog-default jq concrete runtime, so no
   host Skopeo or jq installation is introduced;
4. requires an accepted OCI-index or Docker-manifest-list media type and both
   required platform descriptors for every pinned default;
5. separately resolves each tag-form upstream reference and reports whether it
   still points to the pinned index digest; a digest-form upstream reference
   reports drift as `not-applicable`;
6. treats upstream drift as a visible warning by default and as a failure with
   `--require-current-upstream`;
7. uses the Skopeo shim's existing `SHIMMY_SKOPEO_AUTH_SECRET` opt-in for
   authenticated registries and never mounts host registry credentials by
   default;
8. fails authenticated entries when credentials are absent, except that
   `--public-only` reports them as explicitly skipped and succeeds if all
   public entries pass; and
9. returns nonzero for malformed metadata, an unreachable reference, an
   unexpected media type, a child-manifest digest, a missing required
   platform, failed authentication, or strict upstream drift.

Manifest-format output emits one stable line per checked reference with the
tool kind, version, role (`runtime` or `base-N`), configured digest, media type,
required-platform result, registry-access result, and upstream-drift result.
It must not print credential content or raw registry responses.

Skopeo is appropriate for this opt-in verification because it can inspect a
remote registry image without first pulling its layers and supports explicit
authentication: <https://github.com/podman-container-tools/skopeo>. Ordinary
execution continues to rely only on Podman's `--platform` behavior. Podman's
build documentation confirms that `--platform` selects the output and base
image platform and warns that non-native `RUN` instructions require external
emulation: <https://docs.podman.io/en/stable/markdown/podman-build.1.html>.

## Recorded design decisions

1. **The runtime selects the native architecture from both host OS and CPU.**
   Linux and Darwin each support normalized `amd64` and `arm64` hosts, mapping
   to the matching `linux/amd64` or `linux/arm64` image platform. Unsupported
   or unreadable combinations fail before Podman execution instead of using a
   potentially non-native default. The required image-platform set remains
   those two Linux targets.
2. **All repository-owned defaults are immutable index digests.** A tag alone
   is insufficient because it can move to a single-platform or different
   artifact after review. An upstream tag remains metadata for discovery and
   drift reporting when the publisher provides one; a digest-only publisher
   artifact uses that digest as both upstream and default reference.
3. **Both OCI indexes and Docker manifest lists are accepted.** Both formats
   represent the required platform descriptor set. A single-platform manifest
   is rejected even if it happens to match the contributor's current host.
4. **Image policy stays version-owned.** Shared code validates and consumes a
   schema but contains no publisher, tool, version, digest, or registry case
   list.
5. **Direct and local-build shims share one metadata identity.** Their schemas
   differ only where their lifecycles differ. The framework does not pretend
   that a local per-platform cache is a remote multi-architecture index.
6. **`image.conf` replaces `status.conf`; it does not supplement it.** The
   transition updates every producer and consumer together so two image
   descriptions cannot drift.
7. **Configured defaults are the runtime source of truth.** Direct-image
   defaults leave `run.sh`; local base defaults leave Containerfiles. User
   overrides retain their current names and precedence.
8. **Effective build arguments participate in local cache identity.** Digest
   rotation and overrides must not silently reuse an image built from different
   inputs. Existing explicit `IMAGE_BUILD=always` controls remain available
   for forced rebuilds.
9. **Ordinary runs do not contact a registry just to validate metadata.**
   Offline validation is mandatory; live remote validation is explicit because
   it needs network access, can encounter rate limits, and may require secrets.
10. **User overrides remain an escape hatch outside the default guarantee.**
    They are passed with the already selected `--platform`; a bad override
    fails naturally in Podman. Shimmy does not add per-run remote inspection.
11. **Authenticated registries stay explicit.** The feature reuses the Skopeo
    secret opt-in and does not provision Red Hat or other registry credentials.
12. **Local-build portability includes build steps, not only bases.** Native
    builds and non-mutating smokes for both target architectures are acceptance
    requirements. Architecture-specific archives must select the target
    architecture and must not pin an `amd64` or `arm64` artifact
    unconditionally.
13. **Remote verification is not part of the default test suite.** Fixture-
    driven parser and metadata tests run by default. Registry verification is
    an explicit contributor/release operation and may later be scheduled only
    on a pre-provisioned runner with appropriate public/private access.
14. **The current audited digests are the migration baseline.** If an upstream
    tag moves before implementation, keep the recorded immutable digest unless
    it is unavailable or fails a required smoke. A proposed upgrade to the new
    tag is a separate reviewed change, not a silent plan substitution.
15. **`shimmy update --pull` stops being an implicit tag upgrade for
    repository defaults.** It ensures the configured immutable image is
    present. Upstream drift is discovered by `images verify`; adopting the new
    digest is a reviewed version-owned metadata change. A user-supplied runtime
    image override retains its existing pull behavior.

## Verified implementation inventory

This is the verified planning baseline from 2026-08-09. It is not permission
to ignore new dependencies discovered during implementation.

### Current framework

- `lib/runtime/podman.sh` currently inspects only `uname -s`: it maps every
  Linux host to `linux/amd64`, every Darwin host to `linux/arm64`, and unknown
  hosts to `linux/amd64`. Every current runtime passes that result with
  `--platform`, so Linux/arm64 and Darwin/amd64 currently select the wrong
  architecture and unsupported hosts silently receive an unsafe default.
- `lib/runtime/image.sh` builds and caches local images per platform, but its
  current hash covers only files below `container/`; effective build arguments
  outside that context do not affect cache identity.
- `status.conf` is currently the only common image metadata. It contains an
  external tag or `local-build:container` but cannot express an immutable
  default digest, base images, registry access, or supported platforms.
- `commands/status.sh` and `commands/agent-preflight.sh` consume
  `status.conf`; `tests/lib/catalog.sh` requires it.
- Installation copies the complete `tools/` tree into each flat profile, so a
  sibling `image.conf` and the catalog-default Skopeo/jq concrete runtimes are
  available to installed management commands without changing the profile
  manifest schema.
- Refresh remains correctly delegated to each concrete version's
  `refresh.sh`: eight direct-image versions implement `pull`; twelve local-
  build versions implement `build`.
- The default GitHub Actions workflow is Linux-only and removes host jq to
  exercise Shimmy's jq. It does not provide a macOS Podman runner and must not
  provision one as part of this feature; deterministic injected OS/architecture
  tests cover the Darwin resolver branches in the default suite.

### Audited direct images

Live Skopeo inspection confirmed that every public tag below currently resolves
to an index containing both required platforms. The migration target is the
immutable top-level index digest returned by that inspection.

| Concrete version | Upstream reference | Target default reference |
| --- | --- | --- |
| `aws@2.31` | `public.ecr.aws/aws-cli/aws-cli:2.31.21` | `public.ecr.aws/aws-cli/aws-cli@sha256:40033dc921634b1073094712ea8237869bc857cd7ddc2571896ec9b14ef97ae8` |
| `gcloud@573.0` | `gcr.io/google.com/cloudsdktool/google-cloud-cli:573.0.0-stable` | `gcr.io/google.com/cloudsdktool/google-cloud-cli@sha256:f5fae73a6f1c60b58a1150ff76771a43620891d4dd74abc527c8eca0d544b385` |
| `go@1.26` | `docker.io/library/golang:1.26.4` | `docker.io/library/golang@sha256:f96cc555eb8db430159a3aa6797cd5bae561945b7b0fe7d0e284c63a3b291609` |
| `jq@1.8` | `ghcr.io/jqlang/jq:1.8.1` | `ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91` |
| `nmap@7.98` | `docker.io/instrumentisto/nmap:7.98-r2` | `docker.io/instrumentisto/nmap@sha256:96f6ed194519b62421a1a1c57809e65a7f94d2aa1c8c25676f247e5e148c0827` |
| `rg@15.1` | `docker.io/vszl/ripgrep:latest` | `docker.io/vszl/ripgrep@sha256:3e12f460f714b3c4ab27f4dbad8b7eda7b8184050c46c15f95eb0f2f53b5818c` |
| `skopeo@1.22` | `quay.io/skopeo/stable:latest` | `quay.io/skopeo/stable@sha256:c7d3c512612f52805023cd38351081dad7e2729fc13d14b701e47c7c8bdd6615` |
| `terraform@1.15` | `docker.io/hashicorp/terraform:1.15.6` | `docker.io/hashicorp/terraform@sha256:adae45661e45d3c88beef071ee1277b4621cea73517aae7f0844657c8e85f641` |

### Audited local builds

There are twelve local-build versions and seven distinct public base tags plus
three authenticated Red Hat digest references. Live inspection confirmed both
required platforms for every public base. The two OPNsense versions and the GH
and Task versions intentionally reuse a digest because each pair names the
same publisher release artifact.

| Concrete version(s) | Upstream base | Target base default |
| --- | --- | --- |
| `gdrive@0.2` | `docker.io/library/node:22-alpine` | `docker.io/library/node@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32` |
| `gh@2.94`, `task@3.45` | `docker.io/library/alpine:3.22` | `docker.io/library/alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce` |
| `logmine@0.1` | `docker.io/library/golang:1.22` | `docker.io/library/golang@sha256:1cf6c45ba39db9fd6db16922041d074a63c935556a05c5ccb62d181034df7f02` |
| `netcat@7.92` | `registry.access.redhat.com/ubi9/ubi-minimal:latest` | `registry.access.redhat.com/ubi9/ubi-minimal@sha256:dd334afa72444fa46238fcf9e6bd399245adf746378735348cf84b9dfdca38f1` |
| `opnsense-mcp-admin@1.0`, `opnsense-mcp-read-only@0.4` | `docker.io/library/python:3.13-slim` | `docker.io/library/python@sha256:9662417aace5ae7b8e2609cce472b72a8958e134ba372808abe9cc1a0c0125e6` |
| `tessl@0.1` | `docker.io/library/node:25` | `docker.io/library/node@sha256:78839ac448c23517f8eab2e8f7943d9b4f73979eb7f8bed2c73dbf72ff869e7b` |
| `textual@8.2` | `docker.io/library/python:3.13-slim-bookworm` | `docker.io/library/python@sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8` |

The existing OC defaults are already version-local index digests and remain
the migration targets:

| Concrete version | Authenticated target base default |
| --- | --- |
| `oc@4.18` | `registry.redhat.io/openshift4/ose-cli-rhel9@sha256:16c25aadbd5f564a7c5f1508470f734d676a411b89bd98b307001619d1a5338f` |
| `oc@4.20` | `registry.redhat.io/openshift4/ose-cli-rhel9@sha256:61136a31003a378aae4039be61cfe10f3d2b60399f08a5325233826deb569383` |
| `oc@4.22` | `registry.redhat.io/openshift4/ose-cli-rhel9@sha256:83541f26b665963dea277a7f893725f4a1812b0550d07404f1429ed8da6b3bb2` |

For each OC base, `image_base_N_upstream_ref` initially equals the pinned
digest because the existing repository and catalog evidence do not identify a
stable tag for the selected build. Drift is therefore `not-applicable`; the OC
guide retains the [Red Hat Ecosystem Catalog entry](https://catalog.redhat.com/software/containers/openshift4/ose-cli-rhel9/6528096620ebdcf82af4cbf9)
as the publisher discovery source. Red Hat identifies the manifest-list digest
as the recommended cross-architecture identifier and distinguishes it from a
single-architecture image digest.

Unauthenticated live inspection of those three references correctly failed
with the Red Hat registry's login requirement. Existing OC configuration,
tests, guide, context, and agent skill identify them as publisher-supplied
manifest-list digests, but Chunk 3 requires authenticated verification before
feature acceptance.

The local Containerfile audit found two explicit architecture-dependent
download paths:

- `gh@2.94` maps `x86_64` to `amd64` and `aarch64` to `arm64` before selecting
  the official release archive.
- `task@3.45` performs the equivalent mapping for its release archive.

The remaining local builds use the selected base's package manager, language
toolchain, or existing CLI executable. A compatible base index is necessary
but not sufficient; native builds and smokes remain required because packages,
install scripts, and compiled dependencies can still differ by platform.

## Unresolved

None.

## Progress Checklist

Active chunk: Chunk 2 implemented and verified, pending human review.

- [x] Chunk 1 — Add native host-architecture selection, introduce the image
  configuration contract, and atomically migrate every current concrete
  version and consumer. Implementation and verification are complete.
- [x] Chunk 2 — Add opt-in live index verification with explicit
  authentication and deterministic parser coverage. The public live run
  verified every public pinned index, skipped all three authenticated OC
  entries, and reported one non-strict upstream-tag drift for Netcat.
- [ ] Chunk 3 — Complete native target-platform acceptance, rotation guidance,
  and future-tool guardrails.

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

## Chunk 1 — Native platform and image-contract migration

### Goal

Make runtime platform selection native to the detected host OS and CPU, create
the version-owned image schema, make it the runtime and management source of
truth, pin all current defaults to the audited index digests, and remove the
obsolete image-only status schema without changing tool-specific mounts,
credentials, arguments, or override names.

### Files

Primary change surface:

- `lib/runtime/podman.sh`, `lib/runtime/image.sh`, and their nearest contexts;
- `lib/catalog/catalog.sh` and `lib/catalog/CONTEXT.md`;
- `commands/status.sh`, `commands/agent-preflight.sh`, and
  `commands/CONTEXT.md`;
- every `tools/*/versions/*/image.conf` (new), `run.sh`, `refresh.sh`, current
  `status.conf` (removed), version `CONTEXT.md`, and local-build
  `container/Containerfile`/`CONTEXT.md`;
- tool-local tests where defaults or architecture-specific downloads need
  focused assertions, including replacement of the OC-only manifest-list
  special case with generic coverage;
- `tests/lib/catalog.sh`, `tests/lib/runtime.sh`, `tests/lib/update.sh`,
  `tests/commands/status.sh`, `tests/commands/agent-preflight.sh`, and their
  contexts;
- `CONTEXT.md`, `CONTRIBUTING.md`, `tools/CONTEXT.md`, `docs/podman.md`,
  `docs/testing.md`, and `docs/prompt-shimmy-project.md`; and
- tool guides and canonical skills whose documented default changes from a tag
  or Containerfile default to image configuration plus a pinned digest.

### Implementation requirements

1. Add shared exact-key readers and validators for the schema above. Validation
   must reject partial or ambiguous metadata before a runtime, status command,
   refresh hook, or live verifier consumes it.
2. Update `lib/runtime/podman.sh` to resolve both host OS and architecture from
   `uname -s` and `uname -m`. Normalize `x86_64`/`amd64` to `amd64` and
   `aarch64`/`arm64` to `arm64`; support all four Linux/Darwin combinations in
   the target matrix; fail diagnostically before Podman for unreadable or
   unsupported values; expose the required image-platform list; and preserve
   every current `--platform` call site. Add a test-only architecture input
   parallel to `SHIMMY_TEST_OS`, with no user-facing platform override.
3. Add one complete `image.conf` to all 20 concrete version directories using
   the audited defaults in this plan. Mark the OC base entries
   `authenticated`; mark the audited public entries `public`.
4. Migrate all eight direct runtimes to read their default from
   `image_default_ref`. Preserve each existing `SHIMMY_*_IMAGE` and
   `SHIMMY_*_IMAGE_PULL=always` interface; for repository defaults, pulling now
   re-fetches the pinned digest rather than advancing a mutable tag.
5. Migrate all twelve local runtimes and refresh hooks to shared configured-
   build helpers. Preserve runtime image overrides, base-image override names,
   source/version build arguments, build modes, local repositories, preview
   output, and stale-cleanup ownership.
6. Remove default values from local Containerfile base `ARG` declarations.
   Always supply configured or overridden base values from the runtime/helper.
   Do not move source/version defaults out of a Containerfile unless they must
   become explicit effective build inputs for cache correctness.
7. Make the local image hash cover the sorted context content, exact
   `image.conf` content, and ordered effective build-argument vector. Preserve
   the platform suffix and labels; update label names only if their old
   `context-hash` meaning would become false.
8. Ensure stale cleanup derives the same current image reference as ensure/build
   for identical configuration and effective arguments. A changed digest or
   override must not delete the newly selected image as stale.
9. Delete every `status.conf` and update every consumer in the same chunk.
   `shimmy status` retains its existing human semantics: direct versions show
   their pinned default reference and local versions show the resolved local
   build-context path. Do not change the installed manifest format.
10. Replace `commands/agent-preflight.sh`'s local-build detection with
    `image_source=local-build` and preserve its preview-only approval behavior
    for local builds.
11. Replace the OC-only default-digest test with generic catalog assertions for
    every version. Keep focused OC checks only for OC-specific version mapping,
    authentication documentation, or behavior not covered generically.
12. Add negative metadata fixtures or disposable test directories covering:
    missing/duplicate keys, unknown schema versions, tag-only defaults,
    malformed/architecture-specific digest references, missing platforms,
    unsafe contexts/build-arg names, noncontiguous bases, illegal source-key
    combinations, and `scratch` handling.
13. Add local-cache tests proving that configuration changes, build-argument
    order/value changes, and platform changes alter the cache reference while
    identical inputs remain stable.
14. Update nearby contexts and user/contributor documentation in the same
    change. Do not regenerate `.agents/` or plugin skills in this chunk; the
    canonical cross-tool creation guidance is finalized and exported in Chunk
    3 after the runtime contract has passed review.

### Verification checklist

- [x] Every concrete version has exactly one valid schema-version-1
  `image.conf`; no `status.conf` remains.
- [x] Every non-`scratch` repository-owned default contains a fully qualified
  `@sha256:` reference and every configured platform list equals the two
  required platforms.
- [x] Resolver tests cover Linux/amd64, Linux/arm64, Darwin/amd64, and
  Darwin/arm64; cover all accepted `uname -m` aliases; and prove unreadable or
  unsupported OS/architecture values fail without selecting a fallback.
- [x] Runtime preview integration proves every current concrete version passes
  `--platform linux/amd64` for Linux/amd64 and Darwin/amd64 and
  `--platform linux/arm64` for Linux/arm64 and Darwin/arm64.
- [x] No direct runtime or local Containerfile retains a duplicated
  repository-owned default tag/digest.
- [x] Direct default previews render the configured digest; runtime image
  overrides and pull policies still render their supplied values.
- [x] Local default previews remain platform-separated; base/source/version
  overrides change cache identity deterministically without requiring
  `IMAGE_BUILD=always`.
- [x] `shimmy status` and agent-preflight behavior pass for source and
  disposable installed profiles with no installed-manifest schema change.
- [x] Metadata failure tests reject every malformed case before mutation or
  registry access.
- [x] `gh` and `task` retain target-aware `amd64`/`arm64` release selection;
  no local build contains an unconditional architecture-specific artifact.
- [x] All runnable shell files pass `/bin/sh -n` and retain executable bits.
- [x] `./tests/test.sh` passes all 86 tests after repairing the pre-existing
  `.agents` manifest fingerprints to describe the unchanged compatibility
  adapter directories. No adapter or plugin skill content was regenerated.
- [x] `git diff --check` passes and unrelated worktree changes remain
  untouched.

### Human review gate

Confirm the four-combination native platform matrix and fail-closed behavior,
that `image.conf` is the correct long-lived ownership boundary, that the status
schema was removed atomically, that all audited digests and override contracts
are accurate, and that the broader local-cache key is an acceptable behavior
change. Do not begin Chunk 2 without explicit acceptance.

## Chunk 2 — Opt-in remote index verification

### Goal

Add a non-mutating, metadata-driven management command that proves pinned
defaults are multi-architecture indexes, reports upstream drift, and supports
authenticated registries without adding implicit credential access.

### Files

Primary change surface:

- `commands/images.sh`, `commands/CONTEXT.md`, and `commands/README.md`;
- a narrow reusable parser/selection module below `lib/` with its own
  `CONTEXT.md` and parent link;
- `lib/install/launcher-template.sh`;
- `tests/commands/images.sh`, `tests/commands/CONTEXT.md`, `tests/test.sh`, and
  committed OCI/Docker raw-manifest fixtures under a context-owned test-data
  directory;
- installed lifecycle/management tests that assert command availability and
  profile binding;
- `README.md`, `docs/podman.md`, and `docs/testing.md`; and
- this plan's progress and lessons sections.

### Implementation requirements

1. Implement the exact `shimmy images verify` and source-checkout CLI described
   above. Reuse catalog kind/version selection functions; do not add a command-
   local tool/version case list.
2. Installed default selection reads only concrete versions recorded in the
   invoking profile manifest. Source mode has no implicit profile and requires
   explicit selection.
3. Resolve the catalog-default Skopeo and jq concrete runtimes through catalog
   metadata. Invoke their version runtimes directly from the enclosing source
   or installed profile root; do not depend on host commands or PATH-selected
   external binaries.
4. Use Skopeo `inspect --raw` for pinned refs and normal digest inspection for
   tag-form upstream refs. Treat digest-form upstream refs as drift
   `not-applicable`. Preserve `SHIMMY_SKOPEO_AUTH_SECRET`; do not add host
   auth-file mounts, inline credentials, or secret logging.
5. Parse both accepted index media types, platform variants, duplicate
   descriptors, and unrelated `unknown/unknown` descriptors. Reject a plain
   image manifest, malformed JSON, absent/empty descriptor lists, and a missing
   required platform.
6. Deduplicate identical configured references for network inspection while
   still emitting one result per tool/version/role. Shared bases such as Alpine
   and Python must not cause redundant registry requests.
7. Define stable human and manifest output, error categories, and exit status
   as specified in the target layout. A skipped authenticated entry under
   `--public-only` is visible and never mislabeled as verified.
8. Treat upstream-ref drift as warning by default and failure only under
   `--require-current-upstream`. Never rewrite `image.conf` automatically.
9. Keep the default repository test suite offline with respect to target
   registries. Exercise parsing, selection, deduplication, output, and failure
   handling with committed raw JSON fixtures and controlled command inputs.
   Run separate live checks only in the explicit verification items below.
10. Add the `images` launcher entry atomically with help text, installed
    command tests, profile-root validation, and docs.

### Verification checklist

- [x] Fixture tests accept OCI indexes and Docker manifest lists containing
  both required platforms, including `arm64/v8` and unrelated attestations.
- [x] Fixture tests reject single manifests, child digests, malformed JSON,
  missing platforms, and unsupported media types with stable nonzero results.
- [x] Selection tests cover installed defaults, `--all`, repeated `--shim`,
  unknown kinds/versions, source mode, and duplicate remote refs.
- [x] Authentication tests prove that missing credentials fail normally,
  `--public-only` reports explicit skips, and no output includes secret values.
- [x] Drift tests cover matching, moved, unreachable, and digest-only upstream
  refs plus both strict/non-strict exit behavior.
- [x] Disposable installed profiles expose `shimmy images verify --help` and
  reject profile/location selectors consistently with other commands.
- [x] An explicit live `--public-only --all` run verifies every public pinned
  digest from Chunk 1 without pulling target image layers.
- [x] The same live run reports the three authenticated OC bases as skipped,
  not passed.
- [x] `./tests/test.sh`, `/bin/sh -n` for new/changed shell, executable-bit
  checks, and `git diff --check` pass.

### Human review gate

Confirm the public command shape, profile/source selection semantics, output
contract, authentication boundary, and public live-verification results.
Explicitly decide whether any upstream drift discovered during this chunk is a
separate upgrade or an accepted pinned snapshot. Do not begin Chunk 3 without
explicit acceptance.

## Chunk 3 — Native target acceptance and future guardrails

### Goal

Prove every current version on both distinct native target architectures,
complete the digest-rotation and contributor workflow, and propagate the
reviewed host-detection and image contracts to canonical/generated
tool-creation guidance.

### Files

Primary change surface:

- `CONTRIBUTING.md`, `README.md`, `docs/podman.md`, `docs/testing.md`, and
  `docs/prompt-shimmy-project.md`;
- `docs/templates/generic-shim/AGENTS.md` and
  `docs/templates/generic-shim/SKILL.md`;
- `agent/core/shimmy-create-tool/SKILL.md`,
  `agent/core/shimmy-tool-local-build/SKILL.md`, and their contexts;
- affected tool guides/canonical skills where native validation finds a
  tool-specific requirement;
- regenerated `.agents/skills/`, `plugins/shimmy/skills/`, and their checked-in
  target manifests using the repository's explicit skills workflow;
- skill fingerprint and context-tree tests; and
- this plan's progress, verification notes, and lessons sections.

### Implementation requirements

1. Run full authenticated `images verify --all` with an explicitly selected
   Podman secret for Red Hat registry access. Record pass/fail evidence without
   recording credential values or raw auth state.
2. On a native Linux `amd64` host, build each of the twelve default local
   images and run its version-owned non-mutating smoke. Run each of the eight
   direct images with its version-owned smoke and configured
   `--platform linux/amd64`.
3. On a native Apple Silicon macOS host with a running Podman machine, repeat
   all twenty smokes/builds with `--platform linux/arm64`. Use the Shimmy
   escalation workflow for exact outer wrapper approvals in AI-agent
   environments.
4. Confirm the default-suite resolver and runtime-preview matrix from Chunk 1
   still covers Linux/amd64, Linux/arm64, Darwin/amd64, and Darwin/arm64. The
   two native smoke hosts prove the two distinct container architectures; the
   deterministic preview matrix proves both supported host OS branches select
   the correct native target without requiring four physical CI hosts.
5. Do not substitute cross-emulated success for either native acceptance run.
   Podman documents that non-native Containerfile `RUN` instructions require
   separately provisioned emulation, which Shimmy does not own.
6. If a local build fails on only one platform, fix the version-owned
   Containerfile/runtime and its focused tests/docs within this chunk. Do not
   weaken the global platform contract, silently select an architecture-
   specific child digest, or provision host emulation.
7. Document the rotation procedure: locate the publisher tag, resolve the
   top-level index digest, verify both platforms and registry access, update
   only the affected version's `image.conf`, confirm cache-key change, build or
   pull as appropriate, run native smokes, and retain the prior digest as the
   rollback reference in git history/review notes.
8. Update the generic template, project prompt, canonical create-tool skill,
   and local-build skill so every future version must use shared native
   OS/architecture selection, choose `external` or `local-build`, create
   `image.conf`, use an index digest, validate bases and architecture-specific
   artifacts, and run the explicit verifier.
9. Generate compatibility-adapter and plugin skills only from the reviewed
   canonical sources. Update target manifests/fingerprints with the normal
   explicit skills command and verify semantic parity, not only matching
   checksums.
10. Do not add an always-on remote registry job to the default workflow. If a
   later scheduled workflow is desired, require a separately reviewed,
   pre-provisioned runner/authentication design.

### Verification checklist

- [ ] Full authenticated remote verification passes all direct defaults and
  local bases, including all three OC digests.
- [ ] All eight direct-image smokes pass on native Linux `amd64` and native
  macOS/Apple Silicon `arm64`.
- [ ] All twelve local images build and their version-owned smokes pass on both
  native platforms.
- [ ] The resolver/runtime-preview suite passes all four supported host
  OS/architecture combinations and proves unsupported combinations fail before
  Podman invocation.
- [ ] GH and Task select the matching official release archive on both
  platforms; language/package-manager builds produce runnable target binaries.
- [ ] A digest rotation changes only the affected configured input and local
  cache identity; the prior digest remains recoverable from git history.
- [ ] Contributor docs, project prompt, generic template, canonical creation
  skills, tool-specific guidance, and generated/plugin copies describe the same
  contract.
- [ ] Skill fingerprint tests and semantic source/generated comparison pass.
- [ ] `./tests/test.sh`, the repository context-tree test, executable-bit
  checks, `/bin/sh -n`, and `git diff --check` pass after any native-failure
  fixes and guidance generation.
- [ ] This plan records platform, command, result, failures, approved deferrals,
  and durable lessons without credentials or unnecessary registry payloads.

### Human review gate

Confirm the complete authenticated/public manifest evidence, both native-host
acceptance matrices, any platform-specific fixes, rotation workflow, and
canonical/generated guidance parity. Only this acceptance completes the
multi-architecture image-support feature.

## Risk register

| Risk | Impact | Mitigation |
| --- | --- | --- |
| A configured digest is a child manifest rather than an index. | One supported host works while the other cannot pull/run. | Require accepted index media type plus both descriptors in metadata review and live verification. |
| Host architecture is ignored, mis-normalized, or unreadable. | Linux/arm64 or Darwin/amd64 runs the wrong image, or an unsupported host receives a misleading default. | Resolve both `uname` values centrally, normalize explicit aliases, fail closed, and preview every concrete runtime across the four supported host combinations. |
| A publisher tag moves after planning. | The tag no longer identifies the reviewed artifact. | Runtime uses the recorded immutable digest; drift is reported and upgrades require separate review. |
| Users expect `update --pull` to advance `latest` or another mutable tag. | Digest pinning appears to stop tool updates. | Document that pull ensures the pinned artifact, expose upstream drift explicitly, and require reviewed `image.conf` rotation for upgrades. |
| A registry requires authentication. | Public-only automation cannot prove the default and may produce false confidence. | Mark access in metadata, fail visibly without auth, support explicit Skopeo Podman secrets, and require authenticated OC acceptance. |
| Registry rate limits or outages block verification. | Remote verification is partial despite valid code. | Keep default tests fixture-driven, deduplicate refs, mark the item `[~]`, preserve exact failure evidence, and retry only at the reviewer's direction. |
| A multi-architecture base hides architecture-specific build steps. | Local image builds or binaries fail on one platform. | Audit Containerfiles and require native build plus smoke on both platforms. |
| Build arguments are absent from cache identity. | A rotated base or override silently reuses stale output. | Include ordered effective build inputs and image config in the cache hash and test ensure/cleanup symmetry. |
| Broad schema migration leaves mixed readers or writers. | Status, preflight, installed profiles, or refresh behavior diverges. | Treat `image.conf` creation, all producer/consumer updates, and `status.conf` removal as one atomic Chunk 1 review unit. |
| Runtime verification adds latency or credential exposure. | Normal CLI use slows down or leaks external state. | Make registry verification an explicit command, retain secret-only auth, and never inspect on ordinary run/install/status/test paths. |
| Generated skill copies overwrite richer guidance. | Canonical policy is lost or adapters drift semantically. | Update canonical sources first, compare existing adapter guidance semantically, then regenerate and verify manifests. |
| Existing dirty worktree changes overlap docs/tests. | User work is overwritten or accidentally included. | Recheck status/diffs before every chunk, preserve unrelated edits, and stop for direction on an unavoidable overlap. |

## Lessons learned

### Initial

- The original OC work implemented one valid local-build example but did not
  establish a framework contract. Direct vendor/community images are an equal
  part of the required design.
- All 15 publicly inspectable current direct/base tags resolve to OCI indexes
  or Docker manifest lists containing both required platforms as of the
  planning audit. The three OC defaults need Red Hat registry credentials for
  repeatable live proof.
- Platform selection is already centralized, but it currently selects by OS
  alone. Native host-architecture detection, version-owned image identity,
  generic validation, immutable defaults, and cross-platform acceptance are
  all required parts of this feature.
- Local-build support has two independent compatibility layers: the external
  base index and the commands/artifacts executed during the build.
- Current local cache identity excludes effective build arguments, so digest
  rotation must address caching rather than rely on documentation telling users
  to force a rebuild.
- Installation copies the complete tools tree, allowing a profile-local image
  verifier to use catalog-default Skopeo and jq runtimes without making them
  host dependencies or baseline user commands.

### Chunk 1

- A version-owned `image.conf` can drive direct runtimes, local builds, status,
  preflight, cache identity, and future registry verification without adding a
  central tool/version case list.
- Local build correctness requires one effective build-argument pipeline for
  reference rendering, ensure/build, and stale cleanup. Hashing exact metadata,
  sorted context content, and the ordered effective argument vector prevents a
  rotated digest or override from silently reusing the old image.
- Fail-closed native platform selection can be covered deterministically across
  both supported host OS branches and CPU aliases without contacting Podman.
- Installed status output must capture and check metadata-rendering status
  before printing; nesting a failing renderer directly inside `printf` masks
  its exit status in POSIX shell.
- The checked-in `.agents` manifest incorrectly used two-file canonical/plugin
  fingerprints for all twenty one-file compatibility adapters. Recomputing
  only the target-owned manifest repaired the baseline without regenerating
  adapter or plugin content and restored the ordinary 86-test suite.

### Chunk 2

- A registry-inspection child must receive `/dev/null` explicitly when the
  verifier itself is iterating records on standard input. Otherwise Podman can
  consume the remaining selection even when Skopeo does not logically need
  input; the controlled runtime now models that behavior as a regression test.
- One catalog-resolved Skopeo runtime and one jq runtime are sufficient for
  source and installed verification. Keeping raw and digest inspection caches
  keyed by mode plus exact reference avoids duplicate registry requests while
  retaining one result for every version-owned role.
- The public live check verified all seventeen public result roles and visibly
  skipped the three authenticated OC bases. The Netcat pinned index remains
  valid for both required platforms, but its `latest` upstream tag has moved;
  accepting that pinned snapshot or scheduling a separate digest rotation is a
  Chunk 2 review decision.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, root `CONTEXT.md`, `CONTRIBUTING.md`, this complete plan,
   and the `plan-review-act` skill.
2. Read every context on the path to the active chunk's files and inspect the
   current diffs before editing. The planning baseline had unrelated user
   changes in `README.md`, `tests/CONTEXT.md`, `tests/context-tree.sh`, and
   deleted historical plans; do not assume that state remains unchanged or
   discard it.
3. Preserve these non-negotiable boundaries: POSIX shell, shared native
   OS/architecture Podman platform selection with fail-closed unsupported-host
   behavior, version-owned image policy, no central tool/version cases, no
   implicit Podman/auth provisioning, no ordinary-run registry inspection, and
   unchanged tool-specific override/mount/credential behavior.
4. Active implementation target is Chunk 2, which is implemented and verified
   pending human review. Recheck its recorded evidence and stop at its human
   review gate; do not begin Chunk 3.
5. Do not start Chunk 3 without explicit acceptance of the preceding
   chunk, including the disposition of every `[~]` item.
