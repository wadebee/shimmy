---
name: shimmy-escalation
description: Request narrow AI-agent approvals for Shimmy wrappers that invoke Podman. Use when a wrapper is blocked by sandboxing or when Podman works directly but an exact outer wrapper command needs approval.
---

# Shimmy Escalation

## Principle

Approvals apply to the outer command. Approval for `podman info` does not
approve a wrapper that invokes Podman internally. Request the smallest
non-mutating wrapper prefix, for example `['rg', '--version']` or
`['./commands/run-tool.sh', 'jq', '--version']`.

## Workflow

1. For an installed shim, identify the activated profile with `shimmy status
   --format manifest`. Skip this step for source-only validation in a checkout
   without an activated installation.
2. For an installed shim, invoke its normal command name, such as `rg` or
   `jq`; do not use its resolved installation path.
3. For source validation, use `./commands/run-tool.sh <kind> ...` or the
   concrete `tools/<kind>/versions/<version>/run.sh` runtime.
4. Confirm direct engine availability with `podman info` only when needed.
5. If direct Podman works but the wrapper fails, request approval for the
   exact harmless wrapper smoke command. Do not broaden approval to arbitrary
   Podman or shell commands.

`./commands/agent-preflight.sh` reports repository and activated-wrapper
approval prefixes. It can inspect Podman state; use `--smoke` only after the
corresponding wrapper prefixes are approved.

## Safety

- Prefer `--version`, `version`, or `--help` smokes.
- Do not install Podman or initialize a machine.
- If the engine itself is unavailable, use the initialization workflow and
  request user remediation before starting or creating anything.
- To test `upstream`, first activate its absolute
  `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/bin/shimmy`
  launcher; do not add a profile selector to the wrapper command.
