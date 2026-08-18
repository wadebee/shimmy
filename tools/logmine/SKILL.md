---
name: shimmy-tool-logmine
description: Use and maintain the Logmine Shimmy tool.
---

# Logmine Shim

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
4. Approval scope: require the exact Logmine command and input paths. Do not
   persist a broad prefix because the wrapper mounts the current project
   read-write and its minimal skill does not establish a read-only CLI contract.

Read `CONTEXT.md`, `CONTRIBUTING.md`, and
`tools/logmine/guide.md`.
Preserve local-image behavior and minimal host-integration mounts. The default
source ref is the immutable commit recorded in the Containerfile because the
upstream repository publishes no tags; verify a replacement ref before
rotation.
