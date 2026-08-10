---
name: shimmy-create-tool
description: Create or extend a Shimmy tool kind and its concrete CLI versions. Use when adding a wrapped CLI, selecting its image strategy, adding a version track, or wiring tool-local metadata, runtime, tests, guide, and agent guidance.
---

# Shimmy Tool Creation

## Read first

- Read root `CONTEXT.md`, `CONTRIBUTING.md`, and
  `docs/prompt-shimmy-project.md`.
- Inspect a comparable tool under `tools/` before introducing structure.
- Use PLAN -> REVIEW -> ACT for image provenance, version, strategy, and other
  choices whose alternatives materially change the resulting tool.
- Record risks, assumptions, and adopted safeguards.
- Check upstream documentation for required companion tools and choose the
   image strategy before editing. Ask the user when viable image or version
   choices materially differ.

## Model

- A kind is the stable user command, such as `jq` or `oc`.
- `tools/<kind>/tool.conf` declares the default concrete version and optional
  selector environment variable.
- `tools/<kind>/versions/<major.minor>/run.sh` owns all Podman, image, mount,
  credential, and local-build behavior.
- `commands/run-tool.sh <kind> ...` performs generic source dispatch. Do not
  put tool-specific runtime behavior in a dispatcher or shared `lib/` module.

## Required tool surface

Create or update the following as applicable:

- `tools/<kind>/tool.conf`, `guide.md`, and `agent/SKILL.md`;
- `tools/<kind>/versions/<major.minor>/run.sh`, `smoke.conf`, `image.conf`,
  and `refresh.sh`;
- `container/Containerfile` and its context only for local-build versions;
- `tools/<kind>/tests/` for behavior not covered by generic catalog tests.

Keep the runtime a small POSIX shell wrapper with `#!/bin/sh` and `set -eu`.
Mount `$PWD` at `/work` unless the tool's guide or canonical skill documents an
exception. Use the shared Podman helper for platform selection. Shimmy-defined
environment variables must start with `SHIMMY_`.

Choose `image_source=external` for a suitable publisher image or
`image_source=local-build` for a version-owned build context. Every concrete
version owns exactly one valid `image.conf`. Repository defaults and every
non-`scratch` base must be fully qualified immutable top-level OCI-index or
Docker-manifest-list digests containing both `linux/amd64` and `linux/arm64`.
Keep mutable tags only in upstream discovery fields. Never pin an
architecture-specific child digest or duplicate a configured default in shell
or a Containerfile. Podman selects the native child through the shared runtime
helper's `--platform` value.

## Dependency and safety gate

Before adding a tool, identify required companion CLIs, plugins, credentials,
and network privileges from primary upstream documentation. If a required
dependency is neither bundled by the selected image nor available through the
requested design, stop and obtain a user decision. Do not silently rely on a
host-installed companion tool.

For security-sensitive capabilities, keep network access, privileges,
credentials, and write operations explicit opt-ins. Document the safe default
in the guide and the tool skill.

## Metadata and lifecycle

`tool.conf` is the source of truth for kind defaults and selectors. `smoke.conf`
is the source of truth for the concrete version's non-mutating smoke command.
`image.conf` is the source of truth for image strategy, immutable defaults,
registry access, local context/build arguments, and required platforms.
Do not add central tool-name, status-image, or refresh case lists. Follow the
existing catalog and lifecycle contracts until version-local refresh hooks
replace the remaining update logic.

For local builds, audit packages, install scripts, compiled dependencies, and
release archive URLs for both target architectures. A compatible base index is
necessary but not sufficient.

## Validation

Run, as applicable:

```sh
./commands/run-tool.sh <kind> --preview-shim --help
./commands/images.sh verify --shim <kind>@<version>
./tests/test.sh
git diff --check
```

Use a live non-mutating `--version`, `version`, or `--help` smoke only after
Podman and the exact outer Shimmy wrapper command have the required approval.
For installed behavior, use an absolute disposable `XDG_CONFIG_HOME` and inspect
`shimmy status --format manifest` rather than relying on `command -v` alone.
Feature acceptance requires the version-owned smoke on native Linux `amd64`
and native Apple Silicon macOS `arm64`; do not substitute cross-emulation.

For digest rotation, resolve the publisher tag to its top-level index, verify
both platforms and registry access, update only the affected `image.conf`,
confirm local cache identity changes when applicable, repeat both native
smokes, and retain the prior digest in git history/review notes for rollback.
