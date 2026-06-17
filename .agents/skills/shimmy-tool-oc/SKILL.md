---
name: shimmy-tool-oc
description: Guidance for using, changing, testing, and troubleshooting the multi-version OpenShift CLI (oc) shims in this repository, including SHIMMY_OC_VERSION dispatch, per-track local-build images, and KUBECONFIG forwarding.
---

# OpenShift CLI (oc) Multi-Version Shim

Use this skill when working with `shims/oc`, the versioned `oc_4_xx` shims, their tests, docs, or oc usage through Shimmy.

## Files

- Dispatcher shim: `../../../shims/oc`
- Versioned shims: `../../../shims/oc_4_18`, `../../../shims/oc_4_20`, `../../../shims/oc_4_22`
- Shim configs: `../../../shims/oc_4_18.conf`, `../../../shims/oc_4_20.conf`, `../../../shims/oc_4_22.conf`
- User docs: `../../../docs/shims/oc.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- Status and update: `../../../scripts/status-shimmy.sh`, `../../../scripts/update-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `oc version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_PROFILE_ACTIVE=upstream oc version` when validating the upstream profile. Use repo-local paths such as `./shims/oc_4_20` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Dispatcher command: `oc`
  - Reads `SHIMMY_OC_VERSION` (required, `major.minor` such as `4.18`, `4.20`, `4.22`).
  - Maps `4.18` → `oc_4_18`, `4.20` → `oc_4_20`, `4.22` → `oc_4_22`.
  - Prints a clear error when `SHIMMY_OC_VERSION` is missing or unsupported.
- Versioned shims (per-track local-build images):
  - `oc_4_18`: builds a local image from `images/oc_4_18/Containerfile` using `shimmy_local_image_ensure`, with optional `SHIMMY_OC_4_18_IMAGE` override and `SHIMMY_OC_4_18_IMAGE_BUILD` (`auto`/`always`).
  - `oc_4_20`: builds from `images/oc_4_20/Containerfile`, optional `SHIMMY_OC_4_20_IMAGE` override, `SHIMMY_OC_4_20_IMAGE_BUILD`.
  - `oc_4_22`: builds from `images/oc_4_22/Containerfile`, optional `SHIMMY_OC_4_22_IMAGE` override, `SHIMMY_OC_4_22_IMAGE_BUILD`.
- Runtime mode:
  - Uses Shimmy's shared Podman helper for platform selection and `--preview-shim` support.
  - Mounts `$PWD` to `/work` and uses `-w /work`.
  - Adds `-it` only when stdin and stdout are terminals.
  - Forwards `KUBECONFIG` into the container when set.

## Change Rules

1. Preserve the `SHIMMY_OC_VERSION` selector contract; do not change the variable name when adding new tracks.
2. Keep per-track image env vars (`SHIMMY_OC_4_xx_IMAGE`, `SHIMMY_OC_4_xx_IMAGE_BUILD`) and local-build behavior aligned between shims, docs, status, and update scripts.
3. Avoid adding implicit kubeconfig mounts beyond `KUBECONFIG` forwarding unless the task explicitly calls for them.
4. When extending to new tracks (for example, `5.1`), add a new `oc_5_1` shim, `.conf`, dispatcher mapping, catalog entry, status description, and update `--pull` behavior together.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shims, docs, tests, installer behavior, status/update scripts, and README together when behavior changes.

## Validation

- Direct smoke for versioned shims:
  - `./shims/oc_4_20 version`
  - `./shims/oc_4_18 version`
  - `./shims/oc_4_22 version`
- Dispatcher smoke (from an activated profile):
  - `export SHIMMY_OC_VERSION=4.20; oc version`
- Preview mode (no Podman engine contact):
  - `export SHIMMY_OC_VERSION=4.20; oc --preview-shim version`
- Shimmy tests:
  - `./scripts/test-shimmy.sh --shim oc_4_20`
  - `./scripts/test-shimmy.sh --shim oc_4_18`
  - `./scripts/test-shimmy.sh --shim oc_4_22`

## Learning Guidance

- Capture oc-specific lessons here when they affect version dispatch, image selection, or KUBECONFIG usage.
- Promote reusable multi-version shim design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
