---
name: shimmy-tool-flux
description: Use and maintain the Flux CLI Shimmy tool, including exact-file kubeconfig and host CA passthrough, provider-token forwarding, and security-sensitive cluster or Git operations.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Flux CLI Shim

Use this skill for Flux CLI work through Shimmy and for changes to
`tools/flux/`. Read `CONTEXT.md`, `CONTRIBUTING.md`, and
`tools/flux/guide.md` before repository changes.

## AI Agent Evidence Order

1. If the installed wrapper's exact safe outer-command prefix is already
   approved, run that operation with escalation on the first attempt.
2. Treat sandbox-only Podman reachability failures as `unverified from the
   sandbox`. Retry the same wrapper operation through `shimmy-escalation`
   before profile inspection or fallback.
3. Use `shimmy-init` only when the escalated wrapper proves a profile,
   connection, engine, or registry-projection failure. Never activate a
   profile from sandbox-only evidence.
4. Require approval for the exact Flux command, Kubernetes context, namespace,
   Git repository, and resource arguments. Do not persist a broad `flux`
   prefix: Flux commands can mutate clusters and Git repositories, and
   bootstrap can persist provider tokens in Kubernetes Secrets.
5. Persistent approval is acceptable only for the client-only smoke prefix
   `flux version --client`.

## Installed and source workflows

With the installed active profile selected on `PATH`, invoke `flux` normally
and inspect the invoking profile with
`shimmy profile status --format manifest`.

Before switching profiles, use the absolute installed launcher for
`profile status`, then `profile activate <name> --dry-run`, and request separate
approval for the exact `profile activate <name>` command. Require another
confirmation before adding `--stop-running`. Source the selected profile's
`shell-init.sh` only after activation; agent calls do not retain earlier shell
sourcing.

For source validation, use:

```sh
./commands/run-tool.sh flux --preview-shim version --client
./tests/test.sh --group tools-flux
```

Do not use removed repository `shims/` paths or create generated
`.agents/skills/` content.

## Current runtime contract

- Version: Flux CLI v2.9.4 under concrete Shimmy label `2.9`.
- Image: official immutable multi-platform image from
  `tools/flux/versions/2.9/image.conf`.
- Image controls: `SHIMMY_FLUX_IMAGE` and
  `SHIMMY_FLUX_IMAGE_PULL=always`.
- Runtime: official `flux` entrypoint and non-root `65534:65534` user, stdin
  always open, TTY only when stdin and stdout are terminals.
- Workspace: `$PWD` mounted read-write at `/work`; host permissions govern
  writes by UID/GID 65534.
- Kubeconfig: only an explicitly selected absolute readable
  `SHIMMY_FLUX_KUBECONFIG` file is mounted read-only at
  `/tmp/shimmy-flux-kubeconfig`; the container receives only the corresponding
  `KUBECONFIG` assignment.
- Provider inputs: `FLUX_NS_FOLLOWS_KUBE_CONTEXT`, `GITHUB_TOKEN`,
  `GITLAB_TOKEN`, and `BITBUCKET_TOKEN` are forwarded by name when set.
- No automatic host kube directory, SSH directory, SSH-agent socket, registry
  credential, controller, or plugin setup.

When `SHIMMY_HOST_CA_BUNDLE` is configured, the runtime mounts that one host
file read-only and sets `SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem`. Go can
treat this as a replacement for public system roots, so advise a combined
bundle when both public and corporate trust are required. Explicit Flux,
Kubernetes, or Git client CA configuration can take precedence. This runtime
setting does not configure Podman image-pull trust.

## Validation

Use `flux version --client` as the non-mutating, cluster-independent smoke.
Feature acceptance requires that version-owned smoke on native Linux `amd64`
and Apple Silicon macOS `arm64`; cross-emulation is not acceptance.
