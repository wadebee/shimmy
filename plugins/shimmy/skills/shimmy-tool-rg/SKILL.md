---
name: shimmy-tool-rg
description: Guidance for using, changing, testing, and troubleshooting the ripgrep shim in this repository, including stdin-friendly search behavior and rg image/version expectations.
---

# ripgrep Shim

Use this skill when working with `shims/rg`, its tests, its docs, or ripgrep usage through Shimmy.

## Files

- Runtime shim: `../../../shims/rg`
- User docs: `../../../docs/shims/rg.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_MODE=upstream <tool> --version` when validating the upstream profile. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: `docker.io/vszl/ripgrep:latest`
- Image override: `SHIMMY_RG_IMAGE`
- Pull override: `SHIMMY_RG_IMAGE_PULL=always`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work`
- No extra mounts or forwarded env var families
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Keep ripgrep as a filter/search-style shim with `-i`, not unconditional `-it`.
2. Do not add mounts or env forwarding without a clear ripgrep requirement.
3. Reconcile runtime, docs, README, and tests deliberately if changing the image or tag strategy.
4. Use non-mutating smoke checks such as `rg --version` or `rg --files`.
5. If the `rg` Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using `find`, `grep`, or host-installed search tools.
6. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/rg --version`
- Search/list smoke: `./shims/rg --files`
- Keep AI Agent approvals scoped to the exact dry-run wrapper prefix such as `["rg","--version"]` or `["./shims/rg","--version"]`.

## Learning Guidance

- Capture ripgrep-specific lessons here when they affect search/list behavior, ignore-file handling, image tags, stdin, or AI Agent search fallback policy.
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
