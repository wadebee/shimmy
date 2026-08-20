---
name: shimmy-tool-oc
description: Use and maintain the OpenShift CLI Shimmy tool.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# OpenShift CLI Shim

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
4. Approval scope: require the exact informational or explicitly authorized
   OpenShift command, context, and resource arguments. Do not persist a broad
   `oc` prefix because authenticated commands can mutate cluster resources.

Read `CONTEXT.md`, `CONTRIBUTING.md`, and
`tools/oc/guide.md`.
`SHIMMY_OC_VERSION` selects a supported local-build version; metadata defaults
to 4.20. Each version's `image.conf` owns its authenticated Red Hat
manifest-list digest and passes it to the Containerfile. Preserve those index
digests so the shared runtime helper can select the native platform from host
OS and CPU.
Use `oc --help` for non-network smoke checks across supported versions.

## Corporate / proxy / airgapped environments

- **Use a strict Shimmy redirect for `registry.redhat.io`.** Configure the
  invoking profile with `shimmy profile redirect --prefix registry.redhat.io
  --location <physical-registry/path>`, then activate or restart that profile.
  The replacement location has no configured upstream fallback.
- **Copy images and signatures together where possible.** If the physical registry does
  not contain Red Hat signatures, a permissive `policy.json` entry is required
  for that host. A minimal example:

  ```json
  {
    "default": [{ "type": "insecureAcceptAnything" }],
    "transports": {
      "docker": {
        "your-mirror-host": [{ "type": "insecureAcceptAnything" }]
      }
    }
  }
  ```

- **Expect strict failure, not fallback.** If the physical endpoint is
  unavailable or missing the digest, the pull fails rather than contacting
  `registry.redhat.io`.
- **Manually validate redirected pulls before relying on the shim.** Use explicit
  pulls such as `podman --log-level=debug pull mirror-host/path/to/image@sha256:…`
  to confirm that the physical endpoint is used and that blobs and signatures are present.
- **If oc image pulls fail from an Agent, inspect registry and policy errors.**
  Check Podman logs for signature or policy failures and verify that the
  corporate mirror contains the required image digests and signatures.
- **Coordinate with registry administrators.** Ensure that required oc images
  and signatures are mirrored for long-term secure use in proxy or airgapped
  environments.

The oc skill should surface redirect and signature-policy issues when image
pulls fail and offer actionable diagnostics (for example: suggest checking the
active profile redirect, testing a direct physical-endpoint pull with debug
logging, and reviewing `policy.json` for that host).
