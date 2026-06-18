# Shimmy Project Prompt

Use the prompt below when generating a new shim or revising an existing shim in this repository.

## Copyable Prompt

Create or update a shim in the `shimmy` repository. This project exposes common CLI tools through small POSIX shell wrappers that execute `podman run`, so users can call containerized tools as if they were locally installed.

Constraints:

- Read `CONTRIBUTING.md` before making repo changes.
- Follow the naming conventions in `CONTRIBUTING.md` for files, functions, and variables.
- Create a user-facing kind dispatcher in `shims/<kind>` and put runtime Podman behavior in a concrete version shim named `shims/<kind>_<major>_<minor>`.
- Every kind must have at least one concrete version and exactly one default version mapping in `lib/repo/shimmy-catalog.sh`.
- For existing one-version tools, discover the underlying tool's real major.minor version before naming the first concrete version.
- Use the terms Kind and Version for this dispatch model. Do not use Family or Variant for these relationships.
- Use POSIX shell with `#!/bin/sh` and `set -eu`.
- Do not propose or implement Go, Rust, Python, or other language rewrites for Shimmy core behavior or runtime shims unless the user explicitly asks to leave the POSIX shell architecture.
- Read the default image from `SHIMMY_{TOOL_PREFIX}_IMAGE`.
- Support `SHIMMY_{TOOL_PREFIX}_IMAGE_PULL=always` by adding `--pull=always` to `podman run`.
- Use the `SHIMMY_` prefix for every Shimmy-defined user-facing environment variable, including image overrides, pull or build flags, opt-in behavior switches, and secret-name selectors.
- Use non-`SHIMMY_` env vars only for upstream-defined pass-through configuration such as `AWS_*`, `TF_VAR_*`, or a tool's documented native variables.
- For tools that are not already published as container images, add `images/<kind>_<major>_<minor>/Containerfile` and build a local Podman image on demand from the version shim instead of embedding install steps in the kind dispatcher.
- Source the shared Podman helper and pass `--platform "$SHIMMY_PODMAN_PLATFORM"` to `podman run`. The helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS.
- Mount `$PWD` to `/work` with `-v "$PWD":/work -w /work`.
- Choose `-it` for interactive CLIs and `-i` for filter-style CLIs.
- Add extra mounts only when the tool needs them, and guard them with existence checks.
- Forward env vars with `-e PREFIX_*` patterns only when the tool needs them.
- Add small preflight checks for required upstream configuration when a missing or unreachable value would otherwise fail inside the container. For URL-based services, validate the URL shape and document a non-mutating reachability check such as `curl`.
- Support the global self-contained `--preview-shim` flag by using the shared Podman helper's preview-aware preflight and final run helpers. The flag may appear anywhere in the tool arguments, is consumed by Shimmy, and prints the shell-quoted `podman run` command without contacting Podman, pulling images, building images, or running a container.
- Decide and state the image strategy before implementation: remote image or local build context. Preserve the existing strategy when refining a shim unless there is a concrete defect or the user explicitly asks to switch.
- Use `Containerfile` naming for custom image build contexts.
- Keep image-build logic in the shared shim helper library so custom-image shims rebuild only when the build context changes.
- For local-build shims, pass documented base/source override environment variables as `--build-arg` values to `shimmy_local_image_ensure`, document when `SHIMMY_{TOOL_PREFIX}_IMAGE_BUILD=always` is needed, and wire status/update to local image refs and `--build`.
- End concrete version shims with `shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm --platform "$SHIMMY_PODMAN_PLATFORM" ... "$IMAGE" "$@"`.
- Add new installable kind names, version names, version labels, and default mappings to `lib/repo/shimmy-catalog.sh` because `shimmy install --shim <kind>` validation and `shimmy status --available` derive supported names from that catalog.
- Treat Podman as an explicit dependency. Do not add install or provisioning steps for it in Shimmy code, tests, or CI.
- On macOS, account for the official Podman pkg installer path `/opt/podman/bin/podman` when documenting or validating the dependency.
- When running repo commands from an AI Agent, invoke them directly with non-login shell execution such as `exec_command` `login=false` unless profile or startup-file behavior is explicitly under test. Do not use `bash -lc` or login shells for Shimmy commands unless needed.
- Use Shimmy tools when available. If a Shimmy-backed tool exists for a task and the wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, do not silently fall back to host tools for the same capability. Use the `shimmy-escalation` workflow and request approval for the exact outer wrapper command prefix. For search or listing work, if `rg` is available as a Shimmy shim and fails, request approval for the needed `rg` wrapper prefix before using alternatives such as `find`, `grep`, or host-installed search tools. Use a non-shim fallback only after the user explicitly approves it, preferably with the phrase `fallback approved`.
- For activated installed shims, invoke the normal tool name such as `rg` or `jq`; do not call the resolved installed shim path. Use `./shims/<tool>` only when intentionally testing the repo-local wrapper file.
- In AI Agent environments, approvals are evaluated on the outer command. If `podman info` succeeds but a Shimmy wrapper still reports that Podman is unreachable, use the `shimmy-escalation` workflow. For availability smoke checks, request approval for the exact dry-run command prefix such as `["rg","--version"]` or `["./shims/rg","--version"]`; approval for `["podman", "info"]` alone is not enough.
- Update `scripts/test-shimmy.sh` with live Podman-based assertions against prerequisite `podman` installation.
- Add `shims/<kind>.conf` for the dispatcher and `shims/<kind>_<major>_<minor>.conf` for each concrete version. Use one `smoke_arg=` line per argv item; do not put multiple shell words on one line. Use `smoke_env=KEY=value` only for non-secret selector or test-mode values needed by the smoke command.
- For every kind/version addition, add dispatcher default tests, selector error tests when a selector exists, installed smoke-config/status tests, and update pull/build assertions for the concrete version shims.
- Update `scripts/status-shimmy.sh` so installed status shows the default image, dispatcher description, or local image reference instead of `unknown`.
- Update `scripts/update-shimmy.sh` when adding a remote-image shim that supports `SHIMMY_{TOOL_PREFIX}_IMAGE_PULL=always` or a local-build shim that supports `SHIMMY_{TOOL_PREFIX}_IMAGE_BUILD=always`.
- Update `README.md` so the default image, env vars, mounts, and examples stay accurate.
- Keep the `Included Shims` table in `README.md` sorted alphabetically by Tool name whenever you add or rename entries.
- Create or update `.agents/skills/shimmy-tool-<tool>/SKILL.md` for new or materially changed shims, then install it into the repo skills manifest with `./shimmy skills install --target repo shimmy-tool-<tool>` unless the user chooses another target.
- Keep runnable shell files executable.
- Before finishing, run `git diff --check`, inspect `git diff --summary` for executable-bit and deletion surprises, run focused tests, and do a final `rg` or `git grep` scan over `README.md`, `docs/`, `shims/`, `scripts/`, `lib/repo/`, and `.agents/skills/`.

Deliverables:

1. The kind dispatcher and concrete version shim.
2. Any `images/<kind>_<major>_<minor>/Containerfile` assets required for custom-built images.
3. Kind and version shim configs with non-mutating smoke arguments and any non-secret smoke environment.
4. Catalog, status, update, and installer/lifecycle updates when the shim set, image behavior, or shared helper assets changed.
5. When creating container tests, use live Podman and non-mutating cli calls (eg: version or --help) to validate container.
6. README and docs updates.
7. Quick-start setup guidance for required environment variables, secrets, and preflight checks.
8. A shim-specific agent skill for new or materially changed shims.
9. A short explanation of mounts, env forwarding, pull policy, and local image build behavior when applicable.
10. The kind/version integration checklist should be complete: dispatcher config, default version mapping, version configs, optional selector behavior, status/update behavior, tests, docs, skill manifest, and executable bits.

## Repo Anatomy

- `shims/` contains user-facing kind dispatchers and concrete version shims.
- `images/` contains versioned `Containerfile` build contexts for shims that need locally built images.
- `lib/shims/` contains reusable installed helper scripts that shims source at runtime.
- `lib/repo/` contains sourced helpers for repo-level wrapper and lifecycle scripts.
- `.agents/skills/` contains shim-specific AI contributor guidance.
- `lib/repo/shimmy-catalog.sh` defines supported kind names, concrete versions, version labels, and default versions.
- `scripts/install-shimmy.sh` installs requested catalog-supported kind names into a default XDG-style install root.
- `scripts/test-shimmy.sh` runs live Podman-backed smoke tests against non-mutating CLI commands. Hard dependency on availability of Podman installation (outside Shimmy project)
- `scripts/status-shimmy.sh` reports installed and available shims, including image descriptions.
- `scripts/update-shimmy.sh` refreshes installed shims and handles remote image pulls or local image rebuilds.
- `.github/workflows/test.yml` runs the shell test suite in CI.

## Known Findings From The Scan

- Runnable shell files in `shims/` and `scripts/` are already executable; preserve those modes when adding or updating them.
- The Terraform shim forwards `TF_VAR_*` alongside `AWS_*`. Keep tests and docs aligned if you change Terraform env forwarding.
- Shim config `smoke_arg=` values are not shell-split by `shimmy test`. Use repeated `smoke_arg=` lines for multi-argument smoke commands, and use `smoke_env=KEY=value` only for non-secret selector variables.
