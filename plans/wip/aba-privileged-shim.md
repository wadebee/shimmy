# ABA privileged Shimmy tool

## Objective

Add one independently installable `aba` Shimmy tool, with concrete version label
`1.3`, backed by upstream ABA v1.3.4 at commit
`364c4c0faa743d57d04674d71eabd434b5ec17d5`. It must provide a harmless,
unprivileged `aba --help` path and an intentionally explicit route for ABA's
host-administrative operations.

Success means the tool uses a version-owned, reproducible local build, exposes
the current directory at `/work`, retains all normal Shimmy image and platform
contracts, and refuses operational commands before Podman unless the user has
expressly enabled every required privileged host capability and Shimmy's
verified rootful Podman connection. The wrapper must never implicitly mount host
credentials, state, home directories, or large mirror
archives.

Explicit exclusions:

- a published ABA OCI image, a moving `main` source build, catalog publication,
  profile synchronization, or a repository commit;
- automated cluster installation, registry installation, image mirroring,
  network mutation, credential use, or live ABA acceptance beyond its
  non-mutating `--help` smoke;
- automatic access to host `$HOME`, `$HOME/.aba`, `$HOME/.ssh`, pull secrets,
  KUBECONFIG, or Podman sockets;
- support for upstream's `abatui` companion command, direct Podman machine
  lifecycle, or any change to Shimmy's shared dispatcher/runtime/control-plane
  behavior.

## Target layout and terminology

`aba` is the stable public command. `1.3` is the Shimmy concrete version label;
`1.3.4` is the pinned upstream release. A *safe help invocation* is exactly
`aba --help` (and `aba -h` if upstream confirms that it is a help synonym). An
*operational invocation* is every other argument sequence, including no
arguments, because upstream starts an interactive, stateful workflow without
arguments.

```text
tools/aba/
|-- SKILL.md
|-- guide.md
|-- tests/
|   `-- aba.sh
|-- tool.conf
`-- versions/
    `-- 1.3/
        |-- container/
        |   `-- Containerfile
        |-- image.conf
        |-- refresh.sh
        |-- run.sh
        `-- smoke.conf
```

The privileged boundary uses the following controls:

| Control | Purpose | Container mapping |
| --- | --- | --- |
| `SHIMMY_ABA_PRIVILEGED=1` | Explicitly permits ABA's privileged container mode. | prerequisite for `--privileged` |
| `SHIMMY_ABA_NETWORK=host` | Explicitly permits host networking. | `--network host` |
| `SHIMMY_PODMAN_PRIVILEGED=1` | Explicitly selects Shimmy's verified rootful Podman connection for the operational invocation. | `--connection "$SHIMMY_PODMAN_PRIVILEGED_CONNECTION"`, then `--privileged` |
| `SHIMMY_ABA_SSH_KEY=/absolute/file` | Optional exact SSH private-key input. | read-only `/tmp/shimmy-aba-ssh-key` |
| `SHIMMY_ABA_PULL_SECRET=/absolute/file` | Optional exact Red Hat pull-secret input. | read-only `/work/.pull-secret.json` |
| `SHIMMY_ABA_MIRROR_DATA_DIR=/absolute/directory` | Optional explicitly selected large mirror/archive storage. | read-write `/work/mirror/data` |
| `SHIMMY_ABA_IMAGE` | Full local-image override. | runtime image selection |
| `SHIMMY_ABA_IMAGE_PULL=always` | Pull an override before use. | `--pull=always` |
| `SHIMMY_ABA_IMAGE_BUILD=always` | Rebuild the local image. | local-image lifecycle |
| `SHIMMY_ABA_BASE_IMAGE` | Compatible UBI9 base override for a local build. | build argument |

The caller's workspace is always the container `/work`. The image uses
`HOME=/work`, so ABA's state resides under the project-local `/work/.aba` rather
than in an automatically mounted host home directory. The workspace's
`mirror/mirror.conf` is the only supported mirror configuration path; no
separate host configuration-file mount is provided.

## Recorded design decisions

1. Build locally from the upstream release commit, not from a mutable external
   tool image. Upstream publishes a source Containerfile rather than a
   release-specific OCI image, and its documented container workflow is marked
   work in progress. The Shimmy Containerfile will fetch only the recorded
   immutable commit and contain its own required runtime packages.
2. Pin `registry.access.redhat.com/ubi9/ubi:latest` as the discovery reference
   and `registry.access.redhat.com/ubi9/ubi@sha256:a4b9ec09b1e790a53ef25b7777c539976abe519248264298e5194dcbceac8c31`
   as the configured base. Planning-time Skopeo metadata inspection proved this
   is a top-level Docker manifest list with `linux/amd64` and `linux/arm64`
   descriptors. The implementation must re-inspect the exact digest and stop
   if its media type or required platforms differ.
3. Retain upstream's required RPM inventory in the version-owned Containerfile,
   audit each package on both required architectures, and run ABA directly from
   the checked-out source. Do not run upstream `install`: it installs files,
   creates user configuration, and can invoke package installation. Ensure the
   image entrypoint executes the pinned repository's ABA script and never
   performs upstream self-update/install behavior.
4. `tool.conf` uses `tool_default_version=1.3`, no selector variable, and
   `--help` as the only smoke argument. `refresh.sh build` builds and cleans up
   stale local images; `refresh.sh pull` is a successful no-op because this is
   a source-built image rather than a pulled default.
5. Keep `run.sh` POSIX-shell with `set -eu`, `lib/runtime/image.sh`, the shared
   native platform helper, local-image identity lifecycle, source preview, and
   `shimmy_podman_run_or_preview`. It conditionally allocates a TTY only when
   both standard input and output are terminals and otherwise preserves stdin.
6. The safe help path is unprivileged: it mounts only `$PWD:/work`, sets workdir
   and `HOME=/work`, and runs the pinned image with `--help`. It must not create
   project state, mount credentials, add host networking, grant capabilities,
   select a rootful connection, or add a pull-secret/mirror-data/SSH mount.
7. Every other invocation must fail before the ordinary Podman preflight unless
   **all three** controls are present: `SHIMMY_ABA_PRIVILEGED=1`,
   `SHIMMY_ABA_NETWORK=host`, and `SHIMMY_PODMAN_PRIVILEGED=1`. Reject any
   other values with a stable diagnostic. After those gates pass, require
   `shimmy_podman_privileged_connection_require`; it must select and verify a
   rootful connection, which the runtime passes with `--connection
   "$SHIMMY_PODMAN_PRIVILEGED_CONNECTION"`. Add exactly `--privileged` and
   `--network host`. Do not forward any gate variable or connection value into
   the container. This reflects upstream's documented host-registry workflow,
   preserves Shimmy's privileged-connection boundary, and prevents a misleading
   partial or rootless operational mode.
8. Treat each optional sensitive path as an independently validated exact host
   resource. SSH key and pull secret must be absolute, readable regular files;
   the mirror-data path must be an absolute, existing writable directory. Do
   not forward their Shimmy variable names or values into the container. Mount
   only their fixed destinations and never mount `$HOME`, `$HOME/.ssh`,
   `$HOME/.aba`, or arbitrary parent directories.
9. For the exact SSH-key feature, document that the user supplies ABA's
   supported key argument referring to `/tmp/shimmy-aba-ssh-key`. Do not mount
   `known_hosts`; upstream's generated SSH configuration disables strict host
   key checking, which is a material security risk that the guide and canonical
   skill must make explicit.
10. For the exact pull-secret feature, document that it is only available to an
    already-authorized privileged invocation and appears at the upstream
    expected `/work/.pull-secret.json` path. Never log its contents. If absent,
    ABA may use public/offline workflows only to the extent upstream supports
    them.
11. Restrict operational documentation to Linux RHEL/CentOS Stream/Fedora
    bastions. `--network host` on macOS Podman applies to the VM, not the macOS
    host, so macOS is limited to build/help smoke validation and is not an ABA
    host-operation target. The image itself remains dual-platform to satisfy
    Shimmy's catalog policy.
12. Classify ABA as high impact. It can install and uninstall registries,
    mirror substantial image data, alter firewall/system state through sudo,
    interact with SSH hosts, and create, upgrade, or delete OpenShift clusters
    and VMs. Its tool skill must require explicit approval for the exact ABA
    command, every sensitive mount, `SHIMMY_ABA_PRIVILEGED=1`,
    `SHIMMY_ABA_NETWORK=host`, `SHIMMY_PODMAN_PRIVILEGED=1`, the selected
    rootful connection, and the actual external target. Persistent approval is
    suitable only for the unprivileged `aba --help` smoke.
13. Add positive preview tests for the safe help shape and a fully explicit
    operational invocation, including an explicitly supplied privileged
    connection. Add focused pre-Podman rejection tests for missing/invalid ABA
    gates and unsafe exact-secret/path inputs. Separately prove that a supplied
    non-rootful connection prevents `podman run` after the shared helper's
    necessary rootful-verification probe. These are security invariants approved
    by the user; do not add generic negative coverage.

## Verified implementation inventory

- `CONTEXT.md`, `CONTRIBUTING.md`, and `docs/prompt-shimmy-project.md` require
  self-contained tool versions, immutable multi-platform image bases, shared
  native platform selection, `/work` mounts, and no central tool routing.
- `tools/oc/` and `tools/gdrive/` establish the version-owned local-build,
  metadata, refresh, host-CA, preview, and focused tool-test patterns.
  `tools/flux/` establishes an exact sensitive-file validation/mount pattern.
- `tests/runner.sh` contains the canonical tool group registry and bounded
  worker assignment. `README.md` owns the alphabetized guide table. The
  complete test suite verifies tool inventories and metadata.
- Upstream ABA v1.3.4 is the latest stable release as of 2026-09-25. The
  release tag resolves to commit `364c4c0faa743d57d04674d71eabd434b5ec17d5`.
  Its source is Apache-2.0 licensed and actively maintained.
- Upstream's current/release Containerfile uses UBI9 and installs its required
  RPMs. Its documented `build/aba-run.sh` requires `--privileged`, `--network
  host`, writeable state and image data, a host SSH directory, and a host
  mirror configuration. Its build README explicitly says the container path is
  work in progress and identifies an `nmstate` limitation.
- Upstream documents RHEL 8/9/10, CentOS Stream 8/9/10, or Fedora; sudo/root;
  Internet access as appropriate; and a Red Hat pull secret for registry
  workflows. It downloads/manages `oc`, `oc-mirror`, and `openshift-install`
  itself, so no host-installed companion CLI may be silently assumed.
- The worktree was clean when planning began. This inventory is a verified
  baseline, not permission to ignore dependencies discovered during execution.

## Unresolved

None.

## Progress Checklist

- [~] Chunk 1 — Add, document, and source-verify the ABA privileged Shimmy
  tool. Focused preview, security-boundary, metadata, shell-syntax, executable-mode,
  and UBI manifest-list checks passed. Full-suite, installed-catalog, and native live
  smoke acceptance remain unverified; the source checkout has not been published to
  the installed catalog, the native macOS host is unavailable, and the full suite
  produced no progress output before the locally started verification was stopped.

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

## Chunk 1 — Add and verify the ABA tool

### Goal

Leave the repository with a schema-valid, independently installable ABA 1.3
Shimmy tool. Its local image, runtime privilege boundary, sensitive-mount
controls, canonical agent guidance, user guide, focused tests, runner
registration, and README index must agree.

### Files

Primary change surface:

- `tools/aba/tool.conf`
- `tools/aba/guide.md`
- `tools/aba/SKILL.md`
- `tools/aba/tests/aba.sh`
- `tools/aba/versions/1.3/run.sh`
- `tools/aba/versions/1.3/image.conf`
- `tools/aba/versions/1.3/smoke.conf`
- `tools/aba/versions/1.3/refresh.sh`
- `tools/aba/versions/1.3/container/Containerfile`
- `tests/test.sh`
- `tests/runner.sh`
- `README.md`
- `plans/wip/aba-privileged-shim.md`

A need to alter the generic dispatcher, shared runtime, catalog schema,
install/profile behavior, Podman lifecycle, or registry redirects is a material
divergence and must return to review.

### Implementation requirements

1. Create the full tool/version layout with schema-valid metadata, the exact
   base digest and both required platforms, executable runtime and refresh
   files, and no generated `.agents/skills` material.
2. Implement the Containerfile from the pinned ABA release commit. Preserve the
   upstream package requirements where supported; ensure the build invokes no
   unpinned branch/tag checkout and no upstream self-installer. Use a fixed
   ABA entrypoint that provides `--help` without state mutation.
3. Implement the runtime exactly as recorded: standard workspace/TTY behavior,
   local-image override/build behavior, safe help, operational three-control
   gate, verified rootful connection selection, precise optional path
   validation, and the fixed sensitive-file/data mount destinations. Do not
   make the helper preflight or preview bypass the ABA gate. After the gates
   pass, only the shared rootful helper may probe/select the privileged
   connection; do not duplicate its verification or change the default
   connection.
4. Write `refresh.sh` according to the local-build convention and avoid a
   runtime pull for the default local image. A full image override may use its
   documented pull control.
5. Write `guide.md` with source/release/base provenance; tool installation and
   use; exact variables; workspace state behavior; explicitly selected
   credential/data inputs; Linux-only operational scope; the upstream
   container/nmstate limitation; host-key-verification risk; a warning about
   destructive commands; and approved validation commands.
6. Write canonical `SKILL.md` with required overwrite warning, source and
   installed invocation guidance, actual agent approval boundaries, safe smoke
   instruction, state/mount mapping, and the restriction against persistent
   authorization for operational ABA commands.
7. Add positive preview coverage proving the unprivileged help path and a
   completely configured operational path, including an explicitly supplied
   `SHIMMY_PODMAN_PRIVILEGED_CONNECTION` rendered as `--connection`. Add
   security-invariant assertions that missing or invalid ABA gates, missing or
   invalid `SHIMMY_PODMAN_PRIVILEGED`, and unsafe SSH-key, pull-secret, or
   mirror-data paths fail before fake Podman execution. Separately prove that a
   non-rootful configured connection may be probed by the shared helper but
   prevents fake `podman run`. Ensure tests never contain actual secrets or
   execute ABA operations.
8. Register the focused `tools-aba` test in `tests/test.sh` and in both the
   group registry and bounded worker-assignment registry in `tests/runner.sh`.
   Add ABA alphabetically to the README guide index.
9. Before committing metadata, remotely inspect the recorded UBI digest with
   Skopeo and reconfirm the top-level manifest-list media type and required
   Linux architectures. If it differs, stop for digest-rotation review rather
   than silently changing the plan.

### Verification checklist

- [ ] `./commands/run-tool.sh aba --preview-shim --help` renders the native
  platform, workspace, entrypoint image, and no privileged/network/sensitive
  mounts.
- [ ] A configured source preview with all three gates, an explicitly supplied
  rootful connection name, and disposable exact fixture paths renders
  `--connection`, the supplied connection name, `--privileged`, `--network host`,
  the fixed SSH and pull-secret read-only targets, the selected mirror-data
  mount, `HOME=/work`, and no secret value or host-home-directory mount.
- [ ] Focused tests prove missing/invalid ABA gates and unsafe sensitive paths
  fail before fake Podman execution, while a non-rootful configured connection
  is rejected by the shared verification probe before fake `podman run`.
- [ ] `./tests/test.sh --group tools-aba` passes.
- [ ] `./commands/run-tool.sh aba --preview-shim --help` and `shimmy catalog
  verify --tool aba@1.3 --format manifest` pass after the metadata is complete.
- [ ] `./tests/test.sh` passes using its default bounded parallel schedule.
- [ ] `sh -n` passes for all new shell files; executable modes, source tool
  inventory, and `git diff --check` pass.
- [ ] A version-owned `aba --help` smoke is run through live Podman only after
  exact outer-wrapper approval, on native Linux `amd64` and native Apple
  Silicon macOS `arm64`. The macOS record must explicitly state it validates
  build/help only, not host-operation support.

### Human review gate

Review the privileged runtime command shape, selected rootful connection, all
mounted paths and values, pre-Podman gate diagnostics, source/base provenance,
operational-scope caveats, and native smoke records. Confirm that high-impact
ABA operations remain explicitly opt-in and do not use the normal rootless
connection before accepting the chunk.

## Risk register

| Risk | Safeguard |
| --- | --- |
| ABA can alter host networking, registries, clusters, VMs, and disk state. | Require all three explicit controls for operational commands, select only a verified rootful connection, and require exact-operation authorization in agent guidance. |
| Host SSH and Red Hat credentials could be overexposed. | Mount only opt-in, absolute readable regular files at fixed read-only targets; never mount user homes/directories. |
| Multi-gigabyte mirror archives could be accidentally exposed or mutated. | Require an explicit existing writable mirror-data directory; mount no default archive path. |
| Upstream's documented container workflow is experimental and nmstate is known not to work in its UBI container. | Document the limitation prominently; do not claim operational compatibility from help/build verification. |
| Upstream may self-update or install packages. | Run the pinned in-image source directly, do not invoke its installer, and inspect the resulting entrypoint during implementation. |
| UBI or source dependencies could change or fail on one required architecture. | Pin the UBI manifest-list digest, audit packages, verify metadata remotely, and require native smokes on both hosts. |
| `--network host` has different semantics on macOS Podman. | Limit operational support to Linux RHEL-family bastions; macOS acceptance is help/build-only. |

## Lessons learned

### Initial

- ABA is a high-impact bastion administration workflow, not merely a remote
  OpenShift client. It must not be presented as a routine unprivileged CLI.
- Upstream requires privileged mode and host networking for its supported
  container workflow; Shimmy must also use its separately verified rootful
  Podman connection so the operational mode has truthful host-administrative
  semantics. A partial, rootless, or one-flag mode would be insecure and
  misleading.
- Project-local `HOME=/work` provides persistence without automatic host-home
  access, while exact optional mounts keep keys, pull secrets, and large image
  data visible and deliberate.

### Chunk 1

- The recorded UBI digest remains a Docker manifest list with `linux/amd64` and
  `linux/arm64` descriptors; remote inspection also reported s390x and ppc64le.
- Source previews must classify `--preview-shim --help` as safe help before
  applying the operational gate. The runtime removes preview controls only for
  classification and leaves them for the shared preview renderer.
- The installed active catalog does not yet contain the uncommitted source tool,
  so installed `shimmy catalog verify --tool aba@1.3 --format manifest` cannot
  verify it before the explicitly excluded publication/adoption lifecycle.

## Session bootstrap

Read `AGENTS.md`, `CONTEXT.md`, `CONTRIBUTING.md`,
`docs/prompt-shimmy-project.md`, this plan, the ABA upstream v1.3.4 source
materials cited above, and comparable local-build tool files before acting.
The active scope is Chunk 1 only. Preserve the recorded three-control
privilege/rootful-connection gate, project-local state, fixed exact credential
mount semantics, release/base pins, and Linux-only operational scope. Re-check
the worktree and image metadata before editing. Execute the verification
checklist, update this plan's progress and lessons, then stop at the human
review gate for explicit acceptance.
