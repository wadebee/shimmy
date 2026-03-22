# Shimmy Project Prompt

Use the prompt below when generating a new shim or revising an existing shim in this repository.

## Copyable Prompt

Create or update a shim in the `shimmy` repository. This project exposes common CLI tools through small Bash wrappers that execute `podman run`, so users can call containerized tools as if they were locally installed.

Constraints:

- Read `CONTRIBUTING.md` before making repo changes.
- Follow the naming conventions in `CONTRIBUTING.md` for files, functions, and variables.
- Put the runtime wrapper in `shims/<tool>`.
- Use Bash with `#!/usr/bin/env bash`.
- Read the default image from `<PREFIX>_IMAGE`.
- Support `<PREFIX>_IMAGE_PULL=always` by adding `--pull=always` to `podman run`.
- For tools that are not already published as container images, add `images/<tool>/Containerfile` and build a local Podman image on demand instead of embedding install steps in the runtime wrapper.
- Mount `$PWD` to `/work` with `-v "$PWD":/work -w /work`.
- Choose `-it` for interactive CLIs and `-i` for filter-style CLIs.
- Add extra mounts only when the tool needs them, and guard them with existence checks.
- Forward env vars with `-e PREFIX_*` patterns only when the tool needs them.
- Use `Containerfile` naming for custom image build contexts.
- Keep image-build logic in the shared shim helper library so custom-image shims rebuild only when the build context changes.
- End with `exec podman run --rm ... "$IMAGE" "$@"`.
- Update `scripts/install-shimmy.sh` because it enumerates shim names explicitly.
- Update `scripts/test-shimmy.sh` with needed assertions against prerequisite `podman` installation.
- Update `README.md` so the default image, env vars, mounts, and examples stay accurate.
- Keep the `Included Shims` table in `README.md` sorted alphabetically by Tool name whenever you add or rename entries.
- Keep runnable shell files executable.

Deliverables:

1. The runtime shim.
2. Any `images/<tool>/Containerfile` assets required for custom-built images.
3. Installer updates if the shim set or shared shim helper assets changed.
4. When creating container tests, use Podman and non-mutating cli calls (eg: version or --help) to validate container.
5. README updates.
6. A short explanation of mounts, env forwarding, pull policy, and local image build behavior when applicable.

## Repo Anatomy

- `shims/` contains one Bash wrapper per tool.
- `images/` contains `Containerfile` build contexts for shims that need locally built images.
- `lib/shims/` contains reusable installed helper scripts that shims source at runtime.
- `lib/repo/` contains sourced helpers for repo-level wrapper and lifecycle scripts.
- `scripts/install-shimmy.sh` installs a fixed list of shim names by symlink or copy.
- `scripts/test-shimmy.sh` runs Podman-backed smoke tests against non-mutating CLI commands.
- `.envrc` adds `shims/` to `PATH` for local direnv usage.
- `.github/workflows/test.yml` runs the shell test suite in CI.

## Known Findings From The Scan

- The repo currently tracks shell scripts without executable bits, so direct execution fails unless the mode is corrected.
- The Terraform shim currently forwards `TF_VARS_*`, not the more common `TF_VAR_*`. Treat that as an explicit compatibility decision unless you are intentionally changing it.
