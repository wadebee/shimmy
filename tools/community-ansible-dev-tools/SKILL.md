---
name: shimmy-tool-community-ansible-dev-tools
description: Use and maintain the community-ansible-dev-tools Shimmy tool, including its multi-command Ansible development environment, explicit SSH and git credential mounts, and nested-Podman opt-in.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Community Ansible Development Tools Shim

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
4. Approval scope: require the exact bundled command and arguments. Approve
   SSH-agent, git-config, alternate workdir, and nested-Podman opt-ins
   separately; never persist a broad development-environment prefix.

## Files

- Tool metadata: `tools/community-ansible-dev-tools/tool.conf`
- Concrete runtime: `tools/community-ansible-dev-tools/versions/26.7/run.sh`
- Image metadata: `tools/community-ansible-dev-tools/versions/26.7/image.conf`
- User guide: `tools/community-ansible-dev-tools/guide.md`
- Tests: `tools/community-ansible-dev-tools/tests/community-ansible-dev-tools.sh`
- Repository suite: `tests/test.sh`

## Current Behavior

- Default release: `v26.7.2`, pinned to the multi-platform index in `image.conf`.
- Command model: no arguments starts the image's `zsh`; other arguments select any bundled command; shim `--version` maps to `adt --version`.
- Working mount: `$PWD` to the upstream image's `/workdir`, read-write, unless `--mount-workdir /absolute/host/path` overrides the host source.
- Runtime mode: stdin stays open and a TTY is allocated only when stdin and stdout are terminals.
- Credentials: SSH-agent and host git-config mounts are separate explicit opt-ins.
- Nested Podman: publisher-documented capabilities, `/dev/fuse`, host user namespace, root user, and unconfined security options are one explicit opt-in.
- Platform: the shared Podman helper selects native `linux/amd64` or `linux/arm64`.

## Change Rules

1. Preserve arbitrary bundled-command execution; this image is a development environment rather than a single executable image.
2. Keep `/workdir` as the documented exception to Shimmy's normal `/work` mount unless upstream changes its working directory, and keep any override limited to selecting the host path mounted there.
3. Keep SSH-agent, git-config, and nested-Podman behavior disabled by default and validate every opt-in value.
4. Validate local workdir overrides and opt-in syntax before Podman preflight so local request errors remain deterministic when the engine is unavailable.
5. Do not mount `$HOME/.ssh` or registry credentials implicitly.
6. Keep the git-config mount read-only and the SSH socket mount limited to the existing `SSH_AUTH_SOCK` path.
7. Do not add a fixed Podman container name; short-lived shim invocations must remain parallel-safe.
8. When rotating the release, verify that the selected top-level digest still contains both required platforms and that `latest` identifies the intended released stream.

## Validation

- Preview: `./commands/run-tool.sh community-ansible-dev-tools --preview-shim --version`
- Mount override preview: `./commands/run-tool.sh community-ansible-dev-tools --preview-shim --mount-workdir /absolute/host/path ansible-playbook -i inventory.ini hello.yaml`
- Credential preview: `SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AGENT=1 SSH_AUTH_SOCK=/example/agent.sock ./commands/run-tool.sh community-ansible-dev-tools --preview-shim ansible --version`
- Nested-Podman preview: `SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN=1 ./commands/run-tool.sh community-ansible-dev-tools --preview-shim --version`
- Image verification: `./commands/images.sh verify --shim community-ansible-dev-tools@26.7`
- Native smoke: `./commands/run-tool.sh community-ansible-dev-tools --version`

## Learning Guidance

- The upstream image declares `/workdir` and defaults to an interactive `zsh`, so the shim must preserve both instead of forcing one bundled Ansible executable as its entrypoint.
- Upstream's command-line container example grants broad permissions for nested Podman. Those permissions are not required for ordinary Ansible linting or playbook execution and remain opt-in in Shimmy.
- Remote-target SSH access can use agent forwarding without exposing private-key files; keep failures explicit when the requested agent socket is absent.
