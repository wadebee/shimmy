---
name: shimmy-create
description: Guidance for building a new shim in this repository. Use when asked to create a shim or "shimmy" a CLI tool that is not already covered by a tool-specific skill.
---

# Shimmy Skill

Use this skill when the user wants a new shim for a CLI tool that does not already exist in this repo.

## Files

- Skill file: `SKILL.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared repo prompt: `../../../docs/prompt-shimmy-project.md`
- Runtime shims: `../../../shims/`
- Tool skills: `../../../.agents/skills/shimmy-tool-*/`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- Docs: `../../../README.md`

## Default Workflow

1. Read `../../../CONTRIBUTING.md` and `../../../docs/prompt-shimmy-project.md` before making changes.
2. Inspect `../../../shims/`, `../../../scripts/install-shimmy.sh`, and `../../../scripts/test-shimmy.sh` so the new shim matches existing conventions.
3. Keep the skill-driven plan concise and actionable. Prefer a short default workflow over long narrative guidance.
4. Update the runtime shim, installer, tests, and README together when behavior changes.
5. Create or update a matching tool skill at `../../../.agents/skills/shimmy-tool-{toolname}/SKILL.md` when adding or materially changing a shim.
6. Share the new or updated tool skill before final verification with `./shimmy skills install --target repo shimmy-tool-{toolname}` from the Shimmy checkout unless the user chose `profile` or `plugin` as the target.
7. When adding a shim to the `Included Shims` table in `README.md`, keep the table sorted alphabetically by Tool name.

## Required Checkpoints

1. If the user asks for a new shim but does not name the CLI tool, stop and ask for the tool name.
2. After the tool is identified, try to find a containerized version of that tool before designing the shim.
3. If there are multiple credible container repositories, multiple tags, or multiple image/version strategies, stop and ask the user which option should be used.
4. Do not silently choose between materially different images such as official vs community images, `latest` vs pinned tags, or Alpine vs full images when that choice affects behavior or maintenance.
5. If a containerized version of the tool is not available create one using a compatible base image and tooling dependencies. Discover base image options and present them to the user for decision on which to use. Preference to base image options should be given to latest stable versions coming from hardened registries or with a scanning pipeline.

## Implementation Rules

- Keep runtime shims as small POSIX shell wrappers with `#!/bin/sh` and `set -eu`.
- Mount `$PWD` to `/work` unless the tool has a documented reason not to.
- Use `SHIMMY_{TOOL_PREFIX}_IMAGE` for image override and `SHIMMY_{TOOL_PREFIX}_IMAGE_PULL=always` for pull policy.
- Choose `-it` for interactive CLIs and `-i` for filter-style CLIs.
- Add extra mounts and env forwarding only when the tool actually needs them, and document why.
- End the shim with `exec podman run --rm ... "$IMAGE" "$@"`.
- Keep runnable shell files executable.

## Tool Skill Rules

- Name the skill directory `shimmy-tool-{toolname}` using the runtime shim name unless a shorter canonical tool name is clearer. Example: use `shimmy-tool-opnsense-mcp` for `shims/opnsense-mcp-server`.
- Use frontmatter `name: shimmy-tool-{toolname}` and a description that names the runtime shim plus its distinctive requirements.
- Use this section order where it fits: `Files`, `Current Behavior`, `Change Rules`, `Validation`, `Learning Guidance`.
- Derive `Current Behavior` from the runtime shim first, then reconcile it against `docs/shims/<tool>.md`, `scripts/test-shimmy.sh`, `scripts/install-shimmy.sh`, and `README.md`.
- Preserve tool-specific fidelity: mounts, env forwarding, local image build args, secrets, safe defaults, TTY/stdin mode, network privileges, and known mismatches.
- Keep old tool-specific lessons when renaming existing skills into the `shimmy-tool-*` convention.
- After creating or updating a `shimmy-tool-*` skill, run `./shimmy skills install --target <repo|profile|plugin> shimmy-tool-{toolname}` from the Shimmy checkout so the generated skill is tracked in Shimmy's skills manifest and can be updated idempotently.

## Decision Guidance

- Reuse established repo patterns instead of inventing a new shim shape.
- Prefer shallow context gathering: read only the files needed to match an existing shim pattern.
- Make assumptions explicit when they are low risk; checkpoint with the user when image selection or runtime behavior is ambiguous.
- When proposing an image choice, explain the tradeoff briefly: source, tag strategy, vulnerability scanning, and any expected mounts or env vars.

## Validation

- Update `../../../scripts/test-shimmy.sh` with non-mutating assertions and options for the new shim behavior.
- Use Podman and non-mutating commands such as `--help` or `version` when validating container execution.
- Update `../../../README.md` so image defaults, env vars, mounts, and examples stay aligned with the implementation.
- Keep the `Included Shims` table in `../../../README.md` alphabetized by Tool name after README updates.

## Learning Guidance

- After creating or exercising a tool shim, add tool-specific lessons to that tool's `Learning Guidance` section.
- If a lesson applies across tools, promote it here so future shim creation benefits from it.
- When a generated tool skill exposes a mismatch between runtime, docs, tests, or README, record the mismatch in the tool skill and either fix it in the same change or make the follow-up explicit.
- Prefer precise lessons about behavior and validation over broad reminders, for example: "rootless Podman cannot run raw Nmap host discovery without an explicit privileged opt-in."
