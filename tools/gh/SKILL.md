---
name: shimmy-tool-gh
description: Guidance for using, changing, testing, and troubleshooting the GitHub CLI shim in this repository, including persistent authentication configuration and GH_* environment forwarding.
---

# GitHub CLI Shim

Use this skill when working with the GitHub CLI tool, its tests, its docs, or GitHub CLI usage through Shimmy.

## Files

- Kind metadata: `tools/gh/tool.conf`
- Concrete runtime: `tools/gh/versions/2.94/run.sh`
- User guide: `tools/gh/guide.md`
- Tests: `tools/gh/tests/gh.sh`
- Image context: `tools/gh/versions/2.94/container/Containerfile`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `gh` normally
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

For source validation, use `./commands/run-tool.sh gh --preview-shim --version`
or the concrete `tools/gh/versions/2.94/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: locally built `localhost/shimmy-gh-2_94:<image-input-hash>-<platform>` from version-owned `image.conf` and `container/`
- Image override: `SHIMMY_GH_IMAGE`
- Build override: `SHIMMY_GH_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_GH_IMAGE_PULL=always`
- Base image override: `SHIMMY_GH_BASE_IMAGE`, defaulting to `docker.io/library/alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce`
- GitHub CLI release override: `SHIMMY_GH_VERSION`, defaulting to `2.94.0`
- Host config: `GH_CONFIG_DIR`, defaulting to `$HOME/.config/gh`
- Container config: `/home/gh/.config/gh`, set through `GH_CONFIG_DIR`
- Mounts: `$PWD` to `/work` and the host config directory read-write to the container config directory
- Forwarded environment: `GH_*`; the container `GH_CONFIG_DIR` value always points at the mounted path
- Runtime mode: TTY only when stdin and stdout are terminals

## Change Rules

1. Keep the configuration mount writable so `gh auth login` persists authentication between container runs.
2. Do not create credentials or tokens automatically. Authentication is initiated explicitly by `gh auth login` or supplied through GitHub CLI's standard environment variables.
3. Keep archive installation inside `tools/gh/versions/2.94/container/Containerfile`; the version shim should only coordinate local image selection and runtime behavior.
4. Keep the local image tied to an official GitHub CLI release archive. Update the kind/version name, catalog, status, update behavior, docs, and tests together when changing versions.
5. Treat `GH_TOKEN` and other credentials as secrets; do not add them to logs, fixtures, or documentation examples.
6. Use non-mutating validation commands such as `gh --version`, `gh auth status`, `gh pr list`, and `gh repo view` unless the user explicitly requests a write.

## Validation

- Preview: `./commands/run-tool.sh gh --preview-shim --version`
- Direct smoke: `./commands/run-tool.sh gh --version`
- Auth inspection: `gh auth status`

## Learning Guidance

- Keep GitHub CLI authentication state in `GH_CONFIG_DIR` so it is independent of the image user's home directory.
- The local image must include `git`, because GitHub CLI uses it to discover and operate on local repositories.
- If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, use the Shimmy escalation workflow before falling back to a host-installed tool.
