# Mike Farah yq tool

Status: source implementation validated; native Linux and installed acceptance pending.
Approved image choice: official external image, 2026-09-15.

## Scope and decisions

Add `tools/yq` with default concrete version `4.53`, containing upstream
v4.53.6. The user approved this addition in the sibling Shimmy source checkout
and accepted the official image's missing timezone database.

Use the normal version-owned runtime, image/smoke metadata, refresh hook,
canonical skill, guide, and tool tests. Register the tests and README guide
link through existing repository conventions. Shared runtime dispatch and
catalog schemas require no changes.

The wrapper keeps stdin open, mounts `$PWD` read-write at `/work`, forwards
arguments exactly, and uses shared native platform selection. It maps the
rootless engine user to the official image's UID/GID 1000, disables networking,
drops capabilities, and enables no-new-privileges. Writes require explicit
upstream flags or shell redirection; host credentials/env are not forwarded.

## Provenance and dependency evidence

Inspected 2026-09-15 through the active default profile's Skopeo wrapper:

```text
discovery: docker.io/mikefarah/yq:4.53.6
default: docker.io/mikefarah/yq@sha256:cfc4eee658595834ef304eadb0c3ea721f3b7cb6404ad8b7cb909cc5b5145b23
media type: application/vnd.oci.image.index.v1+json
required descriptors: linux/amd64, linux/arm64
access: public
config version label: 4.53.6
config revision: c14f446382944492701b16c1ddb48bb9dbe683e3
entrypoint: /usr/bin/yq
user: yq (UID/GID 1000 from upstream Dockerfile)
```

Successful metadata commands:

```sh
skopeo inspect --raw docker://docker.io/mikefarah/yq:4.53.6
skopeo inspect --format '{{.Digest}}' docker://docker.io/mikefarah/yq:4.53.6
skopeo inspect --config docker://docker.io/mikefarah/yq:4.53.6
skopeo inspect --raw docker://docker.io/mikefarah/yq@sha256:cfc4eee658595834ef304eadb0c3ea721f3b7cb6404ad8b7cb909cc5b5145b23
```

The [release](https://github.com/mikefarah/yq/releases/tag/v4.53.6),
[README](https://github.com/mikefarah/yq/blob/v4.53.6/README.md), and
[Dockerfile](https://github.com/mikefarah/yq/blob/v4.53.6/Dockerfile) establish
the standalone Go processor, official image, non-root identity, and omitted
timezone database. Normal data processing requires no companion CLI, plugin,
credentials, or runtime network access. The optional system operator can use
only container-installed commands; host companions are not dependencies.
[Podman documentation](https://docs.podman.io/en/stable/markdown/podman-run.1.html)
supports mapping the rootless caller to an image-specific UID/GID for bind mounts.

## Risks and safeguards

- Named-timezone operations need `tzdata`: document the approved official-image
  limitation; no runtime package installation.
- File updates can change workspace data: preserve explicit upstream write
  flags, document their effect, and scope agent execution approval to exact args.
- Host permissions and SELinux labeling are separate: map ownership without
  chowning files and document that enforcing hosts need compatible labels.
- Digest pins age: retain discovery metadata for explicit reviewed refresh;
  publication and profile adoption remain separate operations.
- Descriptor presence does not prove execution: require both native smokes.

## Validation

- [x] Source preview: `./commands/run-tool.sh yq --preview-shim --help` exited 0
  and rendered the pinned image, `linux/arm64`, workspace, stdin, mapped user,
  and isolation flags.
- [x] Skill packaging: the skill-creator `quick_validate.py tools/yq` exited 0
  (`Skill is valid!`). PyYAML 6.0.3 was installed only in a temporary venv for
  this check; no project or global Python dependencies changed.
- [x] Focused tests:
  `./tests/test.sh --group tools-yq --group lib-runtime --group lib-catalog --group runner`
  exited 0; all 34 tests passed. This includes source metadata/skill mapping,
  publication/rollback fixtures, POSIX syntax, executable modes, runner
  registration, and the two yq-specific contracts.
- [x] Complete suite: `./tests/test.sh` exited 0 with all 145 tests passing
  across 46 registered groups, using the default three-worker schedule.
  Catalog, profile, and installed-lifecycle scenarios use test-owned temporary
  repositories and fake engine state; these are not native Linux smoke evidence
  or changes to the real installed profile.
- [x] `git diff --check` and per-file `git diff --no-index --check` checks for
  new files completed without whitespace diagnostics. New-file comparison
  exit status 1 indicates added content and was accepted only with empty output.
- [x] Native Apple Silicon macOS arm64: approved outer wrapper
  `./commands/run-tool.sh yq --version` exited 0 and reported
  `yq (https://github.com/mikefarah/yq/) version v4.53.6` after pulling the exact
  pinned image. Host `uname -s`/`uname -m` reported `Darwin`/`arm64`.
- [x] Read-only fixture checks from an absolute temporary workspace, through
  `/Users/wade/Repos/Github/wadebee/shimmy/commands/run-tool.sh yq`:
  `.service.name 'config file.yaml'` returned `shimmy` from a mode-0600 file;
  `-o=json '.service' < 'config file.yaml'` returned the expected JSON object
  with `name: shimmy` and `enabled: true`. Both exited 0 and the input SHA-256
  remained `4daeee6b2e9c5965942b2af24afc1c15d8018ce637f728fe03610c09063df6d1`.
- [ ] Native Linux amd64 version-owned smoke. No native Linux host has been
  established in this session; cross-emulation is not a substitute. Run
  `./commands/run-tool.sh yq --version` there and record its host architecture,
  exit status, and v4.53.6 output. No reviewer-approved deferral is recorded.
- [ ] Installed catalog verification and disposable-profile adoption. The
  current published catalog does not contain yq; commit/publication and real
  profile changes are not authorized by the source-addition request.

Keep this plan in `wip` until outstanding native/installed acceptance is resolved.
