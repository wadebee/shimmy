---
name: shimmy-tool-local-build
description: Create, change, test, or troubleshoot a Shimmy concrete version that builds a local Podman image from a tool-owned container context.
---

# Shimmy Local Image Builds

## Layout

A local-build concrete version owns its build context:

```text
tools/<kind>/versions/<major.minor>/
  run.sh
  smoke.conf
  container/Containerfile
```

`run.sh` uses `lib/runtime/image.sh` to build or reuse the local image. Keep
image naming, hash labels, and platform selection in the shared helper; do not
copy image-cache logic into a tool runtime.

## Rules

- Keep every build argument and image override under the `SHIMMY_` prefix.
- Default to the cached local image; use a documented
  `SHIMMY_<TOOL>_IMAGE_BUILD=always` opt-in for rebuilds.
- Place tool-specific source or base-image overrides in the version runtime
  and document them in the guide and tool skill.
- Keep `Containerfile` dependencies pinned where reproducibility matters.
- Preserve `$PWD:/work`, shared platform resolution, and non-mutating preview
  behavior.

## Validation

Use preview first:

```sh
./commands/run-tool.sh <kind> --preview-shim --help
```

Use a live build only with explicit user authorization and a running Podman
engine. Exercise it with a non-mutating tool command, then run `./tests/test.sh`
and `git diff --check`.
