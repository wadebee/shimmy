---
name: shimmy-generic-shim-template
description: Template for a context-first Shimmy CLI tool backed by Podman.
---

# Generic Shimmy tool template

Read root `CONTEXT.md`, `tools/CONTEXT.md`, and the closest existing tool.
Create one self-contained `tools/<kind>/` directory.

## Required structure

```text
tools/<kind>/
  CONTEXT.md
  tool.conf
  guide.md
  agent/SKILL.md
  versions/<major.minor>/
    CONTEXT.md
    run.sh
    smoke.conf
    container/Containerfile  # only for local builds
```

`tool.conf` must retain `shim_name=<kind>` for manifest compatibility and add:

```text
tool_default_version=<major.minor>
tool_selector_env=<SHIMMY_SELECTOR_ENV or empty>
```

`run.sh` receives the original CLI argument vector unchanged, uses
`lib/runtime/podman.sh`, mounts `$PWD:/work`, and supports
`--preview-shim`. Use `lib/runtime/image.sh` for local build contexts after
setting `SHIMMY_RUNTIME_DIR` to `lib/runtime`.

The catalog discovers tool metadata automatically. Do not add central catalog,
status, or update case statements. Add focused metadata and preview validation
to `tests/` and run `./tests/test.sh`.
