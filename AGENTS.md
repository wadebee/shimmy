## Scope

This repository packages and makes common CLI tools available to your shell as small Bash shims that call `podman run`.

## Project Map

- Runtime shims live in `shims/`.
- Installation logic lives in `scripts/install-shimmy.sh`.
- Behavioral tests live in `scripts/test-shimmy.sh`.
- The reusable project prompt lives in `docs/prompt-shimmy-project.md`.

## Available Shim Skills

- Generic shim template: `docs/templates/generic-shim/`
- AWS shim: `shims/aws/`
- jq shim: `shims/jq/`
- ripgrep shim: `shims/rg/`
- Terraform shim: `shims/terraform/`

## Working Rules

- Keep runtime shims as small Bash wrappers with `set -euo pipefail`.
- Mount `$PWD` to `/work` unless the shim has a documented reason not to.
- Use `<PREFIX>_IMAGE` for image override and `<PREFIX>_IMAGE_PULL=always` for pull policy.
- Update runtime code, install script, tests, and README together when behavior changes.
- When testing containers, use Podman and non-mutating cli calls (eg: version or --help) to validate execution  
- Ensure runnable shell files keep executable bits.
