# Shimmy Project Prompt

Use the prompt below when generating a new shim or revising an existing shim in this repository.

## Copyable Prompt

Create or update a shim in the `shimmy` repository. This project exposes common CLI tools through small Bash wrappers that execute `podman run`, so users can call containerized tools as if they were locally installed.

Constraints:

- Put the runtime wrapper in `shims/<tool>`.
- Use Bash with `#!/usr/bin/env bash`.
- Read the default image from `<PREFIX>_IMAGE`.
- Support `<PREFIX>_IMAGE_PULL=always` by adding `--pull=always` to `podman run`.
- Mount `$PWD` to `/work` with `-v "$PWD":/work -w /work`.
- Choose `-it` for interactive CLIs and `-i` for filter-style CLIs.
- Add extra mounts only when the tool needs them, and guard them with existence checks.
- Forward env vars with `-e PREFIX_*` patterns only when the tool needs them.
- End with `exec podman run --rm ... "$IMAGE" "$@"`.
- Update `scripts/install-shimmy.sh` because it enumerates shim names explicitly.
- Update `scripts/test-shimmy.sh` with needed assertions against prerequisite `podman` installation.
- Update `README.md` so the default image, env vars, mounts, and examples stay accurate.
- Keep runnable shell files executable.

Deliverables:

1. The runtime shim.
2. Installer updates if the shim set changed.
3. When creating container tests, use Podman and non-mutating cli calls (eg: version or --help) to validate container.  
README updates.
5. A short explanation of mounts, env forwarding, and pull policy.

## Repo Anatomy

- `shims/` contains one Bash wrapper per tool.
- `scripts/install-shimmy.sh` installs a fixed list of shim names by symlink or copy.
- `scripts/test-shimmy.sh` creates a fake `podman` binary and asserts the exact argv each shim emits.
- `.envrc` adds `shims/` to `PATH` for local direnv usage.
- `.github/workflows/test.yml` runs the shell test suite in CI.

## Known Findings From The Scan

- The repo currently tracks shell scripts without executable bits, so direct execution fails unless the mode is corrected.
- The Terraform shim currently forwards `TF_VARS_*`, not the more common `TF_VAR_*`. Treat that as an explicit compatibility decision unless you are intentionally changing it.
