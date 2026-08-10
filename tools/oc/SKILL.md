---
name: shimmy-tool-oc
description: Use and maintain the OpenShift CLI Shimmy tool.
---

# OpenShift CLI Shim

Read `CONTEXT.md`, `CONTRIBUTING.md`, and
`tools/oc/guide.md`.
`SHIMMY_OC_VERSION` selects a supported local-build version; metadata defaults
to 4.20. Each version's `image.conf` owns its authenticated Red Hat
manifest-list digest and passes it to the Containerfile. Preserve those index
digests so the shared runtime helper can select the native platform from host
OS and CPU.
Use `oc --help` for non-network smoke checks across supported versions.

## Corporate / proxy / airgapped environments

- **Use a working `registries.conf` mirror for `registry.redhat.io`.** Corporate
  registry mirrors must be configured in `/etc/containers/registries.conf` so
  Podman pulls the oc image from the proxy registry instead of the upstream
  Red Hat registry.
- **Mirror images and signatures together where possible.** If the mirror does
  not contain Red Hat signatures, a permissive `policy.json` entry is required
  for the mirror host. A minimal example:

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

- **Be aware of Podman mirror fallback.** If the mirror is misconfigured or
  missing blobs, Podman may fall back to the upstream registry, which can be
  blocked by strict signature policy.
- **Manually validate mirror pulls before relying on the shim.** Use explicit
  pulls such as `podman --log-level=debug pull mirror-host/path/to/image@sha256:…`
  to confirm that the mirror is used and that blobs and signatures are present.
- **If oc image pulls fail from an Agent, inspect registry and policy errors.**
  Check Podman logs for signature or policy failures and verify that the
  corporate mirror contains the required image digests and signatures.
- **Coordinate with registry administrators.** Ensure that required oc images
  and signatures are mirrored for long-term secure use in proxy or airgapped
  environments.

The oc skill should surface mirror and signature-policy issues when image pulls
fail and offer actionable diagnostics (for example: suggest checking
`registries.conf`, testing a direct mirror pull with debug logging, and
reviewing `policy.json` for the mirror host).
