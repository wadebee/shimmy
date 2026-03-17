---
name: shimmy
description: Guidance for building a new shim in this repository. Use when asked to create a shim or "shimmy" a CLI tool that is not already covered by a tool-specific skill.
---

# Shimmy Skill

Use this skill when the user wants a new shim for a CLI tool that does not already have a dedicated skill in this repo.

## Files

- Skill file: `SKILL.md`
- Shared repo prompt: `../../../docs/prompt-shimmy-project.md`
- Runtime shims: `../../../shims/`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- Docs: `../../../README.md`

## Default Workflow

1. Read `../../../docs/prompt-shimmy-project.md` before making changes.
2. Inspect `../../../shims/`, `../../../scripts/install-shimmy.sh`, and `../../../scripts/test-shimmy.sh` so the new shim matches existing conventions.
3. Keep the skill-driven plan concise and actionable. Prefer a short default workflow over long narrative guidance.
4. Update the runtime shim, installer, tests, and README together when behavior changes.

## Required Checkpoints

1. If the user asks for a new shim but does not name the CLI tool, stop and ask for the tool name.
2. After the tool is identified, try to find a containerized version of that tool before designing the shim.
3. If there are multiple credible container repositories, multiple tags, or multiple image/version strategies, stop and ask the user which option should be used.
4. Do not silently choose between materially different images such as official vs community images, `latest` vs pinned tags, or Alpine vs full images when that choice affects behavior or maintenance.
5. If a containerized version of the tool is not available create one using a compatible base image and tooling dependencies. Discover base image options and present them to the user for decision on which to use. Preference to base image options should be given to latest stable versions coming from hardened registries or with a scanning pipeline.

## Implementation Rules

- Keep runtime shims as small Bash wrappers with `set -euo pipefail`.
- Mount `$PWD` to `/work` unless the tool has a documented reason not to.
- Use `<PREFIX>_IMAGE` for image override and `<PREFIX>_IMAGE_PULL=always` for pull policy.
- Choose `-it` for interactive CLIs and `-i` for filter-style CLIs.
- Add extra mounts and env forwarding only when the tool actually needs them, and document why.
- End the shim with `exec podman run --rm ... "$IMAGE" "$@"`.
- Keep runnable shell files executable.

## Decision Guidance

- Reuse established repo patterns instead of inventing a new shim shape.
- Prefer shallow context gathering: read only the files needed to match an existing shim pattern.
- Make assumptions explicit when they are low risk; checkpoint with the user when image selection or runtime behavior is ambiguous.
- When proposing an image choice, explain the tradeoff briefly: source, tag strategy, vulnerability scanning, and any expected mounts or env vars.

## Validation

- Update `../../../scripts/test-shimmy.sh` with non-mutating assertions and options for the new shim behavior.
- Use Podman and non-mutating commands such as `--help` or `version` when validating container execution.
- Update `../../../README.md` so image defaults, env vars, mounts, and examples stay aligned with the implementation.
