---
name: shimmy-tool-tessl
description: Use and maintain the Tessl Shimmy tool.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Tessl Shim

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
4. Approval scope: require the exact Tessl command and arguments. Do not
   persist a broad prefix because Tessl mounts authentication state and can
   modify projects, install or publish artifacts, and access network services.

Read `CONTEXT.md`, `CONTRIBUTING.md`, and
`tools/tessl/guide.md`. Keep local-image behavior in the concrete
runtime.
