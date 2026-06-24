---
name: shimmy-create-tool
description: Create or extend a Shimmy tool kind and its concrete CLI versions. Use when adding a wrapped CLI, selecting its image strategy, adding a version track, or wiring tool-local metadata, runtime, tests, guide, and agent guidance.
---

# Shimmy Tool Creation

## Read first

1. Read `CONTRIBUTING.md`, `docs/prompt-shimmy-project.md`, and the context
   path from root to the target tool.
2. Inspect a comparable tool under `tools/` before introducing structure.
3. Check upstream documentation for required companion tools and choose the
   image strategy before editing. Ask the user when viable image or version
   choices materially differ.

## Model

- A kind is the stable user command, such as `jq` or `oc`.
- `tools/<kind>/tool.conf` declares the default concrete version and optional
  selector environment variable.
- `tools/<kind>/versions/<major.minor>/run.sh` owns all Podman, image, mount,
  credential, and local-build behavior.
- `commands/run-tool.sh <kind> ...` performs generic source dispatch. Do not
  put tool-specific runtime behavior in a dispatcher or shared core module.

## Required tool surface

Create or update the following as applicable:

- `tools/<kind>/tool.conf`, `guide.md`, `CONTEXT.md`, and `agent/SKILL.md`;
- `tools/<kind>/versions/<major.minor>/run.sh`, `smoke.conf`, and
  `CONTEXT.md`;
- `container/Containerfile` and its context only for local-build versions;
- `tools/<kind>/tests/` for behavior not covered by generic catalog tests.

Keep the runtime a small POSIX shell wrapper with `#!/bin/sh` and `set -eu`.
Mount `$PWD` at `/work` unless the tool's context documents an exception. Use
the shared Podman helper for platform selection. Shimmy-defined environment
variables must start with `SHIMMY_`.

When an image must work on both Linux `amd64` and macOS `arm64`, prefer a
fully qualified manifest-list digest supplied by the image publisher. Do not
pin an architecture-specific image digest or tag as the default: Podman must
select the matching platform image while the shared runtime helper retains
responsibility for `--platform`.

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
Do not add central tool-name, status-image, or refresh case lists. Follow the
existing catalog and lifecycle contracts until version-local refresh hooks
replace the remaining update logic.

## Validation

Run, as applicable:

```sh
./commands/run-tool.sh <kind> --preview-shim --help
./shimmy test
git diff --check
```

Use a live non-mutating `--version`, `version`, or `--help` smoke only after
Podman and the exact outer Shimmy wrapper command have the required approval.
For installed behavior, use a disposable install root and inspect
`shimmy status --format manifest` rather than relying on `command -v` alone.
