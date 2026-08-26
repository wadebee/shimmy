---
name: shimmy-tool-skopeo
description: Use and maintain the Skopeo Shimmy tool.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Skopeo Shim

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
4. Approval scope: require the exact Skopeo operation, image references,
   destinations, and auth-secret selection. Do not persist a broad prefix
   because Skopeo can authenticate, copy, sync, and delete registry content.

Read `CONTEXT.md`, `CONTRIBUTING.md`, and
`tools/skopeo/guide.md`. The concrete runtime is
`tools/skopeo/versions/1.22/run.sh`; preserve explicit registry auth
secret mounting and avoid default host credential mounts. A valid active
installed profile mounts its authoritative strict redirect policy read-only;
profiles with no activation omit it, while mismatched, damaged, stale, unsafe,
connection-overridden, or registry-overridden state fails closed. Policy
mounting does not provide credentials, corporate CA trust, or signature
policy. An explicitly configured `SHIMMY_HOST_CA_BUNDLE` is mounted read-only
at `/tmp/shimmy-host-ca-bundle.pem` and exposed only as `SSL_CERT_FILE`.
Treat this Go system-root mechanism as replacement-capable: advise a combined
public and corporate bundle when both are required, and preserve the precedence
of registry-specific `certs.d` configuration and `--cert-dir`.
