---
name: shimmy-tool-local-build
description: Create, change, test, or troubleshoot a Shimmy concrete version that builds a local Podman image from a tool-owned container context.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Shimmy Local Image Builds

## Layout

A local-build concrete version owns its build context:

```text
tools/<tool>/versions/<major.minor>/
  run.sh
  smoke.conf
  image.conf
  container/Containerfile
```

`run.sh` uses `lib/runtime/image.sh` to build or reuse the local image. Keep
image naming, hash labels, and platform selection in the shared helper; do not
copy image-cache logic into a tool runtime.

Do not restore the retired central `local_build_repo_for_shim` mapping or
`images/<tool>_<version>/` layout. Version-owned `container/` directories and
refresh hooks provide that behavior in the current tree.

## Rules

- Keep every build argument and image override under the `SHIMMY_` prefix.
- Set `image_source=local-build` and describe the context, local repository,
  ordered build arguments, registry access, required platforms, and each base
  in the version-owned `image.conf`.
- Pin every non-`scratch` base default to an immutable top-level index digest
  containing `linux/amd64` and `linux/arm64`. Keep mutable tags only in
  upstream discovery fields and do not duplicate defaults in the
  `Containerfile`.
- Default to the cached local image; use a documented
  `SHIMMY_<TOOL>_IMAGE_BUILD=always` opt-in for rebuilds.
- Place tool-specific source or base-image overrides in the version runtime
  and document them in the guide and tool skill.
- Keep `Containerfile` dependencies pinned where reproducibility matters.
- Preserve `$PWD:/work`, shared platform resolution, and non-mutating preview
  behavior.
- Audit packages, installers, compiled dependencies, and downloaded archives
  for both target architectures. Map publisher archive names explicitly when
  they differ by architecture and fail closed on unknown values.
- Treat a digest or effective build-argument change as a cache-identity change;
  ensure, build, and stale cleanup must derive the same current reference.

## Validation

Use preview first:

```sh
./commands/run-tool.sh <tool> --preview-shim --help
shimmy catalog verify --tool <tool>@<version>
```

Use a live build only with explicit user authorization and a running Podman
engine. Exercise it with a non-mutating tool command, then run `./tests/test.sh`
and `git diff --check`.
Build and smoke on native Linux `amd64` and native Apple Silicon macOS `arm64`;
cross-emulated success is not acceptance. For a base digest rotation, update
only `image.conf`, confirm a new cache identity, and preserve the prior digest
in git history/review notes as the rollback reference.
