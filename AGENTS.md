## Scope

This repository packages and makes common CLI tools available to your shell as small Bash shims that call `podman run`.

## Project Map

- Runtime shims live in `shims/`.
- Shared repo helpers live in `lib/repo/`.
- Installed shim helper libraries live in `lib/shims/`.
- Installation logic lives in `scripts/install-shimmy.sh`.
- Behavioral tests live in `scripts/test-shimmy.sh`.
- Contributor guidance lives in `CONTRIBUTING.md`.
- The reusable project prompt lives in `docs/prompt-shimmy-project.md`.

## Available Shim Skills

- Generic shim template: `docs/templates/generic-shim/`
- AWS shim: `shims/aws/`
- jq shim: `shims/jq/`
- ripgrep shim: `shims/rg/`
- Terraform shim: `shims/terraform/`

## Working Rules

- Read `CONTRIBUTING.md` before making repo changes.
- Follow the naming conventions in `CONTRIBUTING.md` for files, functions, and variables.
- Keep runtime shims as small Bash wrappers with `set -euo pipefail`.
- Mount `$PWD` to `/work` unless the shim has a documented reason not to.
- Use `<PREFIX>_IMAGE` for image override and `<PREFIX>_IMAGE_PULL=always` for pull policy.
- Update shim helper code, install script, tests, and README together when behavior changes.
- Treat Podman as an explicit dependency. Do not add Shimmy-side installation or provisioning steps for it.
- On macOS, remember the official Podman pkg installer may place the binary at `/opt/podman/bin/podman`. If automation cannot find `podman`, check that `/opt/podman/bin` is on `PATH`.
- When testing containers, use live Podman and non-mutating cli calls (eg: version or --help) to validate execution  
- Ensure runnable shell files keep executable bits.
