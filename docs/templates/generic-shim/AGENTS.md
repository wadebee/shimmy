## Scope

This template describes one Shimmy tool directory.

## Instructions

- Read this directory's `SKILL.md`, root `CONTEXT.md`, `CONTRIBUTING.md`, and a
  comparable existing tool's guide and canonical skill.
- Create `tools/<tool>/tool.conf`, `guide.md`, and `SKILL.md`.
- Put each concrete runtime at `versions/<major.minor>/run.sh` with a sibling
  `smoke.conf` and `image.conf`.
- Put local build assets in that version's `container/` directory.
- Keep runtime wrappers POSIX shell, executable, and `SHIMMY_`-prefixed for
  Shimmy-defined environment variables.
- Choose `image_source=external` or `image_source=local-build`. Pin repository
  defaults and non-`scratch` bases to top-level indexes containing
  `linux/amd64` and `linux/arm64`; retain tags only for upstream discovery.
- Use the shared image and Podman helpers. Audit architecture-specific
  artifacts, run the explicit image verifier, and require native smokes on
  Linux `amd64` and Apple Silicon macOS `arm64`.
