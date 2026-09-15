---
name: shimmy-tool-jv
description: Guidance for using, changing, testing, and troubleshooting the jv JSON Schema validator shim pinned to upstream CLI release v6.0.3.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# jv Shim

Use this skill when working with the jv JSON Schema validator, its local-build
image, tests, docs, or Shimmy usage.

## Files

- Tool metadata: `tools/jv/tool.conf`
- Concrete runtime: `tools/jv/versions/6.0/run.sh`
- Local image: `tools/jv/versions/6.0/container/Containerfile`
- User guide: `tools/jv/guide.md`
- Tests: `tools/jv/tests/jv.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`

## Current Behavior

- Upstream CLI: official `jv-v6.0.3` release assets
- Concrete Shimmy version: `6.0`
- Image strategy: local build from the pinned multi-platform Alpine base
- Image override: `SHIMMY_JV_IMAGE`
- Rebuild override: `SHIMMY_JV_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_JV_IMAGE_PULL=always`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work`

## Change Rules

1. Keep the image build pinned to an explicit upstream jv release.
2. Preserve the `-i` stdin mode and `/work` mount for schema and instance files.
3. Keep image build and source-version changes in the concrete version directory.
4. Use non-mutating smoke checks such as `jv --version`.
5. Do not add host-installed Go or other companion-tool dependencies; the local
   image supplies the official compiled jv release binary.

## Validation

- Preview: `./commands/run-tool.sh jv --preview-shim --version`
- Runtime smoke: `./commands/run-tool.sh jv --version`
- Installed smoke: `shimmy shim test jv@6.0`

## Learning Guidance

- The upstream CLI is versioned independently from the jsonschema library.
- No maintained upstream jv container image is required; Shimmy installs the
  tagged platform release asset using the repository's pinned Alpine base.
