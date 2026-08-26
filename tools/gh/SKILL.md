---
name: shimmy-tool-gh
description: Guidance for using, changing, testing, and troubleshooting the GitHub CLI shim in this repository, including persistent authentication configuration and GH_* environment forwarding.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# GitHub CLI Shim

Use this skill when working with the GitHub CLI tool, its tests, its docs, or GitHub CLI usage through Shimmy.

## AI Agent Evidence Order

1. If the installed wrapper's safe outer-command prefix is already approved,
   run the actual requested operation with escalation on the first attempt. Do
   not first run a sandboxed Podman call or a version smoke.
2. Treat a sandbox-only unreachable, unknown, socket-denied, or
   `operation not permitted` result as `unverified from the sandbox`, not as an
   inactive profile. Retry the same wrapper operation through
   `shimmy-escalation` before profile inspection or fallback.
3. Use `shimmy-init` only if the escalated wrapper still proves a
   profile-affinity, engine, connection, or registry-projection failure. Never
   activate a profile automatically from sandbox-only evidence.
4. Approval scope: require the exact read-only or explicitly authorized GitHub
   operation. Do not persist a broad `gh` prefix because the wrapper forwards
   authentication and supports repository, issue, pull-request, and release writes.

## Files

- Tool metadata: `tools/gh/tool.conf`
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
and inspect the invoking profile with `shimmy profile status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate <name> --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate <name>` command. Running containers
require separate explicit confirmation before adding `--stop-running`. Shimmy's
control plane owns shared and isolated engine lifecycle; a missing recorded
machine is not recreated or adopted. Agents never run direct Podman machine
lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To inspect a named profile, use its
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>`.

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
- Optional CA mount: `SHIMMY_HOST_CA_BUNDLE` to
  `/tmp/shimmy-host-ca-bundle.pem:ro`
- Forwarded environment: `GH_*`; the container `GH_CONFIG_DIR` value always
  points at the mounted path; `SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem`
  is added only when the host bundle is configured
- Runtime mode: TTY only when stdin and stdout are terminals

## Change Rules

1. Keep the configuration mount writable so `gh auth login` persists authentication between container runs.
2. Do not create credentials or tokens automatically. Authentication is initiated explicitly by `gh auth login` or supplied through GitHub CLI's standard environment variables.
3. Keep archive installation inside `tools/gh/versions/2.94/container/Containerfile`; the version shim should only coordinate local image selection and runtime behavior.
4. Keep the local image tied to an official GitHub CLI release archive. Update the tool/version name, catalog, status, update behavior, docs, and tests together when changing versions.
5. Treat `GH_TOKEN` and other credentials as secrets; do not add them to logs, fixtures, or documentation examples.
6. Treat `SSL_CERT_FILE` as replacement-capable Go system-root file discovery.
   Preserve the exact read-only host-file mount and advise a combined public
   and corporate bundle when both trust sets are required.
7. Use non-mutating validation commands such as `gh --version`, `gh auth status`, `gh pr list`, and `gh repo view` unless the user explicitly requests a write.

## Validation

- Preview: `./commands/run-tool.sh gh --preview-shim --version`
- Direct smoke: `./commands/run-tool.sh gh --version`
- Auth inspection: `gh auth status`

## Learning Guidance

- Keep GitHub CLI authentication state in `GH_CONFIG_DIR` so it is independent of the image user's home directory.
- The local image must include `git`, because GitHub CLI uses it to discover and operate on local repositories.
- If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, use the Shimmy escalation workflow before falling back to a host-installed tool.
