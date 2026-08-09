# Multi-architecture manifest-list defaults

## Status

Exploration plan. No generic manifest-list framework is implemented by this
plan.

## Context

The OpenShift CLI tracks use fully qualified Red Hat manifest-list digests as
their local-build base images. A manifest list is architecture-neutral: Podman
selects the matching image for Shimmy's existing `linux/amd64` or
`linux/arm64` runtime platform. This avoids pinning an `amd64`, `arm64`, or
other architecture-specific image digest as the default.

This approach may apply to future local-build Shimmy tools when an upstream
publisher supplies a stable, multi-architecture manifest-list digest. It must
remain a version-local image decision; it is not an excuse to hardcode
architecture selection in a tool shim.

## Goals

- Define when a local-build version should prefer a manifest-list digest over
  a tag or an architecture-specific digest.
- Keep image references version-local in `container/Containerfile` or another
  version-owned metadata file.
- Preserve `lib/runtime/podman.sh` as the sole platform-selection mechanism.
- Give tool authors a repeatable validation and documentation workflow.

## Non-goals

- Do not create a global image registry, central tool/version case list, or
  automatic image-refresh policy.
- Do not replace a publisher's required registry authentication with Shimmy
  provisioning logic.
- Do not reuse a digest across separate tool versions unless the publisher
  explicitly identifies the same release artifact for both.

## Research checklist

- [ ] Inventory local-build tool versions and their current base-image
  references.
- [ ] Identify publishers that expose immutable multi-architecture manifest
  lists, including supported platform declarations and authentication
  requirements.
- [ ] Define a concise version-local metadata convention only if Containerfile
  arguments are insufficient for discovery and documentation.
- [ ] Determine how to verify that a candidate manifest list contains both
  `linux/amd64` and `linux/arm64` without relying on an architecture-specific
  local pull.
- [ ] Add focused preview and metadata tests for any adopted convention.
- [ ] Add exact-approved live smokes on Linux and macOS before changing a
  default image reference.
- [ ] Document digest rotation: source, release/version identity, review
  trigger, and rollback reference.

## Proposed evaluation workflow

1. Read the target tool's context path and its canonical agent skill.
2. Obtain the upstream publisher's manifest-list digest and verify its
   platform entries with a non-mutating manifest inspection.
3. Confirm that the image contains the required executable and supports the
   concrete version's smoke command.
4. Set the fully qualified digest as the version-local default while retaining
   the existing `SHIMMY_<TOOL>_BASE_IMAGE` override.
5. Build only with explicit user authority, then run the version-owned
   non-mutating smoke using an exact wrapper approval.
6. Update the Containerfile context, guide, canonical skill, tests, and
   version-local documentation together.

## Red Hat OC reference

The validated pattern is:

```text
registry.redhat.io/openshift4/ose-cli-rhel9@sha256:<manifest-list-digest>
```

The manifest list—not an `x86_64` or `aarch64` image-specific digest—is the
default reference. Red Hat documents manifest-list digests as the recommended
choice for supported architectures. The catalog page used during the OC work
is <https://catalog.redhat.com/en/software/containers/openshift4/ose-cli-rhel9/6528096620ebdcf82af4cbf9>.
