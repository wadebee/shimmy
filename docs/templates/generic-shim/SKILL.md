---
name: shimmy-generic-shim-template
description: Template for a Shimmy CLI tool backed by Podman.
---

# Generic Shimmy tool template

Read root `CONTEXT.md`, `CONTRIBUTING.md`, and the guide and canonical skill
for the closest existing tool. Create one self-contained `tools/<tool>/`
directory.

## Required structure

```text
tools/<tool>/
  tool.conf
  guide.md
  SKILL.md
  versions/<major.minor>/
    run.sh
    smoke.conf
    image.conf
    container/Containerfile  # only for local builds
```

`tool.conf` must retain `shim_name=<tool>` for manifest compatibility and add:

```text
tool_default_version=<major.minor>
tool_selector_env=<SHIMMY_SELECTOR_ENV or empty>
```

`run.sh` receives the original CLI argument vector unchanged, uses
`lib/runtime/podman.sh`, mounts `$PWD:/work`, and supports
`--preview-shim`. Use `lib/runtime/image.sh` for local build contexts after
setting `SHIMMY_RUNTIME_DIR` to `lib/runtime`.

Choose `image_source=external` when a usable publisher image exists or
`image_source=local-build` for a version-owned container context. Complete the
matching schema in `image.conf`. Pin every repository default and non-`scratch`
base to an immutable top-level OCI index or Docker manifest-list digest with
`linux/amd64` and `linux/arm64`; keep publisher tags as upstream discovery
references only. Do not duplicate defaults in `run.sh` or a `Containerfile`.

Audit packages and downloaded artifacts for both target architectures. Run
`./commands/images.sh verify --shim <tool>@<version>`, the preview suite, and
the version-owned smoke on native Linux `amd64` and Apple Silicon macOS
`arm64`. Cross-emulated builds do not satisfy native acceptance.

The catalog discovers tool metadata automatically. Do not add central catalog,
status, or update case statements. Add focused metadata and preview validation
to `tests/` and run `./tests/test.sh`.
