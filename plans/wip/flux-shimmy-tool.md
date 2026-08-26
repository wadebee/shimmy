# Flux CLI Shimmy tool

## Objective

Add one independently installable `flux` Shimmy tool with concrete version
label `2.9`, backed by Flux CLI v2.9.4. Success means the tool uses Flux's
official immutable multi-platform CLI image, runs on native `linux/amd64` and
`linux/arm64`, preserves stdin and interactive prompting, exposes the current
directory at `/work`, provides explicit read-only kubeconfig passthrough,
supports the documented Git-provider inputs, and opts into Shimmy's exact-file
host CA passthrough.

Explicit exclusions:

- Flux controller installation, cluster bootstrapping, or other live cluster
  mutation as part of repository verification;
- automatic mounts of host `~/.kube`, `~/.ssh`, SSH-agent sockets, registry
  credentials, or other host credential directories beyond the one exact
  kubeconfig file explicitly selected by the user;
- a local-build image, Flux plugin installation, controller image mirroring,
  Podman provisioning, or shared runtime/catalog schema changes; and
- publication to the immutable default catalog, profile synchronization, or a
  repository commit unless separately requested.

## Target layout and terminology

`flux` is the stable public command. `2.9` is the concrete Shimmy version
label, and v2.9.4 is the pinned upstream Flux release.

```text
tools/flux/
|-- SKILL.md
|-- guide.md
|-- tests/
|   `-- flux.sh
|-- tool.conf
`-- versions/
    `-- 2.9/
        |-- image.conf
        |-- refresh.sh
        |-- run.sh
        `-- smoke.conf
```

Tool discovery remains metadata-driven. The only shared test-runner changes
are registration and worker assignment for the focused `tools-flux` group.

## Recorded design decisions

1. Use `image_source=external` with discovery tag
   `ghcr.io/fluxcd/flux-cli:v2.9.4` and immutable top-level default
   `ghcr.io/fluxcd/flux-cli@sha256:5260c79fb1b744c78755d98bcb271971c93e4ea214623c3f9f96ff59536d0398`.
   Planning-time Skopeo inspection verified a Docker manifest list containing
   native `linux/amd64` and `linux/arm64` descriptors. The official image also
   bundles `kubectl`, so no required companion CLI is missing.
2. Declare `tool_default_version=2.9`, no selector environment variable, and
   `version --client` as the non-mutating, cluster-independent smoke command.
3. Keep `run.sh` as POSIX shell using `lib/runtime/image.sh`, the shared native
   platform helper, external-image metadata resolution, source preview, and
   `shimmy_podman_run_or_preview`. Support `SHIMMY_FLUX_IMAGE` and
   `SHIMMY_FLUX_IMAGE_PULL=always`; do not duplicate the pinned default in the
   runtime.
4. Preserve the official image's `flux` entrypoint and non-root
   `65534:65534` user. Mount `$PWD` read-write at `/work`, set `/work` as the
   working directory, keep stdin open, and add a TTY only when stdin and
   stdout are terminals. Do not override the image user or remap ownership.
5. Add explicit kubeconfig passthrough with the host-only Shimmy control
   `SHIMMY_FLUX_KUBECONFIG=/absolute/path/to/config`. Require one absolute,
   readable regular file, mount that exact file read-only at
   `/tmp/shimmy-flux-kubeconfig`, and set only
   `KUBECONFIG=/tmp/shimmy-flux-kubeconfig` in the container. Do not pass
   `SHIMMY_FLUX_KUBECONFIG` into the container and do not auto-discover or mount
   all of `$HOME/.kube`. When this control is unset, users may still place a
   kubeconfig below the current directory and pass
   `--kubeconfig=/work/<path>` explicitly.
6. Forward only other upstream environment inputs with an established Flux CLI
   contract: `FLUX_NS_FOLLOWS_KUBE_CONTEXT`, `GITHUB_TOKEN`, `GITLAB_TOKEN`,
   and `BITBUCKET_TOKEN`. Environment forwarding passes names through Podman
   without printing secret values.
7. Call `shimmy_podman_ca_bundle_prepare SSL_CERT_FILE` before Podman
   preflight. When configured, mount the exact readable absolute
   `SHIMMY_HOST_CA_BUNDLE` file read-only at
   `/tmp/shimmy-host-ca-bundle.pem` and pass only
   `SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem` into the container.
   `SHIMMY_HOST_CA_BUNDLE` remains host-only.
8. Document Go's replacement-capable system-root behavior: users requiring
   both public and corporate trust must supply a combined bundle. Explicit
   Flux `--ca-file`, Kubernetes certificate-authority settings, and other
   client-specific TLS configuration can take precedence. Runtime CA
   passthrough does not configure Podman's trust when pulling the Flux image.
9. Do not mount host Kubernetes credential directories or SSH credentials
   automatically. The exact kubeconfig file mount is an explicit opt-in;
   project-local inputs may instead be placed below the current directory and
   referenced through `/work/...`. Provider token flows use the explicitly
   forwarded variables. This keeps credential exposure opt-in and visible.
10. Treat Flux as security-sensitive: many commands can mutate Git repositories
   or Kubernetes clusters and provider tokens may be stored in cluster
   Secrets during bootstrap. The canonical tool skill requires exact command,
   context, and resource approval for agent use and permits persistent approval
   only for the client-only version smoke.
11. Add positive preview coverage for image/pull selection, workspace and I/O
    shape, exact kubeconfig and host CA mounts, and upstream environment names.
    Add the lowest-cost assertion that an unsafe or unreadable kubeconfig path
    fails before Podman as a durable credential-mount boundary; do not add
    generic absence/rejection tests.

## Verified implementation inventory

- `CONTEXT.md`, `CONTRIBUTING.md`, and `docs/prompt-shimmy-project.md` define
  self-contained tool metadata and forbid central tool routing maps.
- `tools/go/` and `tools/terraform/` establish the external-image, pull-refresh,
  workspace, preview-test, and `SSL_CERT_FILE` host-CA patterns.
- `tools/oc/` establishes Kubernetes path caveats and explicit kubeconfig CA
  precedence for a Go CLI; Flux needs a stronger exact-file mount because
  cluster interaction is a primary command path for this shim.
- `tests/test.sh` explicitly sources tool-local tests; `tests/runner.sh` owns
  canonical group registration and bounded worker assignment. `tests/CONTEXT.md`
  applies to both shared test files.
- `README.md` owns the manually maintained tool-guide index.
- Flux's current CLI documentation identifies official Docker Hub and GHCR
  images containing both `flux` and `kubectl`. Upstream bootstrap documentation
  identifies `GITHUB_TOKEN`, `GITLAB_TOKEN`, and `BITBUCKET_TOKEN` as supported
  credential inputs, demonstrates mounting a kubeconfig into the official CLI
  image, and documents file-based Kubernetes/Git TLS options.
- Flux v2.9.4 is the current upstream release as of 2026-08-26. The inspected
  image configuration identifies version 2.9.4, entrypoint `flux`, Alpine CA
  certificates, bundled `kubectl`, and user `65534:65534`.
- The worktree was clean during planning, and no existing notional, work-in-
  progress, or completed plan represented this objective. This inventory is a
  verified baseline, not permission to ignore newly discovered dependencies.

## Unresolved

None.

## Progress Checklist

- [x] Chunk 1 - Add, document, and verify the Flux CLI tool.

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

## Chunk 1 - Add, document, and verify the Flux CLI tool

### Goal

Leave the repository with a schema-valid, independently installable Flux CLI
tool whose runtime, image lifecycle, documentation, canonical agent guidance,
and focused tests conform to existing Shimmy contracts.

### Files

Primary change surface:

- `tools/flux/tool.conf`
- `tools/flux/guide.md`
- `tools/flux/SKILL.md`
- `tools/flux/tests/flux.sh`
- `tools/flux/versions/2.9/run.sh`
- `tools/flux/versions/2.9/image.conf`
- `tools/flux/versions/2.9/smoke.conf`
- `tools/flux/versions/2.9/refresh.sh`
- `tests/test.sh`
- `tests/runner.sh`
- `tests/lib/runner.sh`
- `README.md`
- this plan, moved to `plans/wip/flux-shimmy-tool.md` before implementation

A need to change a dispatcher, shared runtime, catalog schema, install/profile
behavior, or Podman lifecycle is a material divergence and must return to
review.

### Implementation requirements and suggested reasoning level

Use high reasoning for the runtime's credential, path, user, and CA boundaries;
the remaining metadata, documentation, and test registration are mechanical.

1. Create the complete tool/version layout atomically with schema-1 metadata,
   the immutable public image reference, both required platforms, and
   executable `run.sh`, `refresh.sh`, and focused test entrypoint.
2. Implement the runtime exactly as recorded above: external image helper,
   platform selection, always-open stdin, conditional TTY, `/work` mount,
   exact-file kubeconfig validation and mapping, explicit upstream environment
   names, and exact-file host CA mapping.
3. Make `refresh.sh pull` execute the version-owned client-only smoke with
   `SHIMMY_FLUX_IMAGE_PULL=always`; keep `build` a successful no-op.
4. Write `guide.md` with install/use examples, image and pull settings,
   `SHIMMY_FLUX_KUBECONFIG` usage and project-local alternatives, token
   forwarding, CA precedence, non-root workspace implications, security
   cautions, and validation commands.
5. Write canonical `SKILL.md` with required overwrite warning, exact agent
   approval boundary, installed/source invocation guidance, current runtime
   contract, host CA semantics, and non-mutating smoke guidance. Do not create
   generated `.agents/skills/` content.
6. Register the focused test in `tests/test.sh` and `tests/runner.sh`, assigning
   the lightweight group consistently with comparable tool groups. Add the
   Flux guide alphabetically to `README.md`.
7. If the upstream tag no longer resolves to the recorded digest or required
   platforms at implementation time, stop and report the drift instead of
   silently rotating the pin.

### Verification checklist

- [x] `./commands/run-tool.sh flux --preview-shim version --client` rendered
      the pinned image, native `linux/arm64` platform, `/work` workspace,
      always-open stdin, and exact arguments. A PTY-backed preview also added
      only `-t` alongside `-i`.
- [x] The focused configured preview used placeholder provider variables, an
      exact temporary host kubeconfig, image override/pull, and a temporary
      host CA file. It rendered only environment names, both read-only mounts,
      `KUBECONFIG=/tmp/shimmy-flux-kubeconfig`, and
      `SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem` without secret values.
- [x] A relative `SHIMMY_FLUX_KUBECONFIG` failed with the stable absolute,
      readable-file diagnostic before the fake Podman executable was called.
- [x] `./tests/test.sh --group tools-flux` passed all 3 focused tests.
- [x] Runner, catalog, shim lifecycle, and AI-skill materialization coverage
      passed in the complete default bounded-parallel suite.
- [x] Skopeo reinspection confirmed that the v2.9.4 discovery tag still
      resolves to
      `sha256:5260c79fb1b744c78755d98bcb271971c93e4ea214623c3f9f96ff59536d0398`
      and its Docker manifest list contains native `linux/amd64` and
      `linux/arm64` descriptors.
- [x] The version-owned `flux version --client` smoke succeeded through live
      Podman on native Apple Silicon macOS `arm64` and reported `flux: v2.9.4`.
      `refresh.sh pull` also force-pulled the pinned image and completed the
      same client-only smoke.
- [~] Native Linux `amd64` was unavailable on this workstation. The image
      descriptor is present, but native execution remains unproven; require
      that smoke on a Linux `amd64` reviewer or CI host before publication.
- [x] The complete default `./tests/test.sh` suite passed all 142 tests with
      its bounded parallel runner.
- [x] POSIX parsing, executable modes, the eight-file Flux inventory,
      `refresh.sh build`, and `git diff --check` passed.

### Execution notes

- Initial focused integration exposed a weak literal registry-count assertion.
  The assertion duplicated structural registry validation and coupled every
  intentional group addition to an unrelated fixture update, so it was
  removed. `tests/lib/runner.sh` remains in the change surface, and the
  corrected runner group passed all 15 tests.
- One complete-suite attempt was interrupted after an overly short timeout.
  Its retained artifacts showed active profile and lifecycle progress, so the
  suite was rerun with a sufficient allowance and passed all 142 tests.
- No catalog publication, profile synchronization, commit, or push was
  performed.

### Human review gate

The reviewer confirms the tool layout, immutable image provenance, runtime
credential/path/CA boundaries, focused and integration results, and the
disposition of any unavailable native Linux acceptance evidence. No catalog
publication, profile adoption, commit, or push follows implicitly.

## Risk register

- **Credential exposure:** Flux bootstrap consumes powerful provider tokens
  and can persist them in cluster Secrets. Mitigation: forward only documented
  names, never render values, mount only the explicitly selected exact
  kubeconfig file, mount no host credential directories, and require exact
  agent approval for mutating commands.
- **Trust replacement:** `SSL_CERT_FILE` can replace public roots. Mitigation:
  document combined bundles and explicit client-specific precedence.
- **Image-pull/runtime trust confusion:** the runtime CA bundle cannot help
  Podman pull the image. Mitigation: document this boundary explicitly.
- **Non-root bind permissions:** the official image runs as 65534, so host
  permissions still govern writes under `/work`. Mitigation: preserve upstream
  least privilege, document the constraint, and avoid ownership-changing
  runtime flags without separate review.
- **Architecture acceptance:** this workstation can provide native macOS
  `arm64` evidence but not native Linux `amd64`. Mitigation: keep Linux smoke
  as an explicit acceptance item and surface it as partial if no native runner
  is available.
- **Upstream drift:** the mutable v2.9.4 tag could be republished. Mitigation:
  pin the inspected index and fail review on drift.

## Lessons learned

### Initial

- Flux publishes a suitable official CLI image, so a local build would add
  provenance and maintenance cost without supplying a missing dependency.
- A useful containerized Flux CLI needs the kubeconfig contents, not merely a
  forwarded host pathname; an explicit exact-file mount preserves utility
  without exposing the entire host Kubernetes configuration directory.
- Host CA passthrough is a Flux runtime TLS input; it must not be described as
  image-pull trust or as overriding explicit kubeconfig/Git CA configuration.
- The official image intentionally runs as non-root and bundles `kubectl`;
  both properties should be preserved rather than rebuilt away.

### Implementation

- Multi-argument smoke metadata must be read line-by-line by refresh hooks;
  sourcing a `smoke.conf` containing repeated `smoke_arg` keys would retain
  only the final argument.
- Test-group additions require matching registry and worker-assignment entries,
  but should not require updating a literal count derived from that registry.
  Existing syntax, uniqueness, assignment-completeness, ordering-boundary, and
  lifecycle-mapping assertions provide stronger diagnostics.
- The non-TTY preview provides a stable automated proof of always-open stdin;
  a PTY-backed source preview separately confirmed conditional `-t` behavior.

## Session bootstrap

Read `AGENTS.md`, `CONTEXT.md`, `CONTRIBUTING.md`,
`docs/prompt-shimmy-project.md`, `tests/CONTEXT.md`, this plan, and the
comparable `tools/go/`, `tools/terraform/`, and `tools/oc/` files. Move this
plan from `notional` to `wip` before editing implementation files. Execute only
Chunk 1, preserve the official non-root external-image design and exact-file
kubeconfig and host CA contracts, update progress and lessons with verification
evidence, and stop at the human review gate.
