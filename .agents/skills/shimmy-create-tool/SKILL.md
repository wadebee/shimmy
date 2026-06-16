---
name: shimmy-create-tool
description: Guidance for building a new Shimmy CLI tool wrapper in this repository, including required companion-tool dependency checks before implementation.
---

# Shimmy Tool Creation

Use this skill when the user wants a new shim for a CLI tool that does not already exist in this repo.

## Files

- Skill file: `SKILL.md`
- Shared repo prompt: `../../../docs/prompt-shimmy-project.md`
- Runtime shims: `../../../shims/`
- Tool skills: `../../../.agents/skills/shimmy-tool-*/`
- Supported shim catalog: `../../../lib/repo/shimmy-catalog.sh`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- Status command: `../../../scripts/status-shimmy.sh`
- Update command: `../../../scripts/update-shimmy.sh`
- Docs: `../../../README.md`

## Default Workflow

1. Read `../../../CONTRIBUTING.md` and `../../../docs/prompt-shimmy-project.md` before making changes.
2. Identify the requested CLI tool, then run the dependency gate in `Required Checkpoints` before designing the shim.
3. Inspect `../../../shims/`, `../../../lib/repo/shimmy-catalog.sh`, `../../../scripts/install-shimmy.sh`, and `../../../scripts/test-shimmy.sh` so the new shim matches existing conventions.
4. Keep the skill-driven plan concise and actionable. Prefer a short default workflow over long narrative guidance.
5. Update the runtime shim, shim config, supported shim catalog, lifecycle scripts, tests, docs, README, and tool skill together when behavior changes.
6. Create or update a matching tool skill at `../../../.agents/skills/shimmy-tool-{toolname}/SKILL.md` when adding or materially changing a shim.
7. Share the new or updated tool skill before final verification with `./shimmy skills install --target repo shimmy-tool-{toolname}` from the Shimmy checkout unless the user chose `profile` or `plugin` as the target.
8. When adding a shim to the `Included Shims` table in `README.md`, keep the table sorted alphabetically by Tool name.

## Required Checkpoints

1. If the user asks for a new shim but does not name the CLI tool, stop and ask for the tool name.
2. After the tool is identified, inspect official upstream docs and candidate container image docs for required companion tools, plugins, or CLIs before designing the shim.
3. If a required companion tool is not already available as a native tool or Shimmy shim, and is not documented as bundled in the selected container image, stop before implementation and summarize:
   - dependency name,
   - why it is required,
   - official source links supporting the requirement,
   - whether `../../../shims/<dependency>` exists,
   - whether `../../../.agents/skills/shimmy-tool-<dependency>/SKILL.md` exists,
   - recommended next steps.
4. Default the recommended next step to creating the missing dependency shim first. Use a composite image strategy only after the user explicitly chooses it.
5. Treat optional integrations as non-blocking unless the user's requested use case depends on them.
6. Try to find a containerized version of the requested tool before designing the shim.
7. If there are multiple credible container repositories, multiple tags, or multiple image/version strategies, stop and ask the user which option should be used.
8. Do not silently choose between materially different images such as official vs community images, `latest` vs pinned tags, or Alpine vs full images when that choice affects behavior or maintenance.
9. If a containerized version of the tool is not available create one using a compatible base image and tooling dependencies. Discover base image options and present them to the user for decision on which to use. Preference to base image options should be given to latest stable versions coming from hardened registries or with a scanning pipeline.

## Implementation Rules

- Keep runtime shims as small POSIX shell wrappers with `#!/bin/sh` and `set -eu`.
- Mount `$PWD` to `/work` unless the tool has a documented reason not to.
- Use `SHIMMY_{TOOL_PREFIX}_IMAGE` for image override and `SHIMMY_{TOOL_PREFIX}_IMAGE_PULL=always` for pull policy.
- Choose `-it` for interactive CLIs and `-i` for filter-style CLIs.
- Add extra mounts and env forwarding only when the tool actually needs them, and document why.
- Do not make a shim silently rely on host-installed companion CLIs. Required companion tools must be provided by the selected image, a dependency shim, or an explicitly chosen composite image.
- Surface credential requirements and whether the requested tool and dependency share credential state. Shimmy's preferred future direction is `podman secret` for tool credentials because Podman is already required, but do not implement a new Podman-secret credential flow unless the user explicitly requests it.
- Existing credential mount patterns may remain until a dedicated credential-handling change is planned.
- End the shim with `exec podman run --rm ... "$IMAGE" "$@"`.
- Keep runnable shell files executable.
- Add new installable shim names to `../../../lib/repo/shimmy-catalog.sh` `SHIMMY_SUPPORTED_SHIMS`. `shimmy install --shim <tool>` validation and `shimmy status --available` both derive supported names from that catalog, then status filters out already installed profile shims.
- Add one `smoke_arg=` line per smoke-command argument in `../../../shims/<tool>.conf`. Do not put multiple shell words on one `smoke_arg=` line.
- Use `smoke_env=KEY=value` only for non-secret selector or test-mode values needed by the smoke command. Do not hardcode tool-specific smoke defaults in the generic test runner.

## Definition of Done

Use this checklist before final verification for every new runtime shim:

1. Runtime wrapper exists at `../../../shims/<tool>` and is executable.
2. Shim config exists at `../../../shims/<tool>.conf` with a non-mutating smoke command.
3. Each smoke command argument uses its own `smoke_arg=` line; selector-only environment uses `smoke_env=KEY=value`.
4. `../../../lib/repo/shimmy-catalog.sh` includes the installable shim name in `SHIMMY_SUPPORTED_SHIMS`.
5. `../../../scripts/status-shimmy.sh` describes the image, dispatcher, or local build reference instead of returning `unknown`.
6. `../../../scripts/update-shimmy.sh` handles the shim when remote images need `--pull` refresh or local images need `--build` refresh.
7. `../../../README.md` includes the shim in the sorted `Included Shims` table and links to shim docs.
8. `../../../docs/shims/<tool>.md` documents image defaults, env vars, mounts, examples, and any credential or config expectations.
9. `../../../.agents/skills/shimmy-tool-<tool>/SKILL.md` exists for new or materially changed shims and is installed into the repo skills manifest.
10. `../../../scripts/test-shimmy.sh` covers direct preview or smoke behavior, installed smoke config, status output, and update pull/build behavior when applicable.
11. A final `rg` scan for the shim name across `README.md`, `docs/`, `shims/`, `scripts/`, `lib/repo/`, and `.agents/skills/` confirms the feature is wired through the expected repo surfaces.

## Tool Skill Rules

- Name the skill directory `shimmy-tool-{toolname}` using the runtime shim name unless a shorter canonical tool name is clearer. Example: use `shimmy-tool-opnsense-mcp-read-only` for `shims/opnsense-mcp-read-only`.
- Use frontmatter `name: shimmy-tool-{toolname}` and a description that names the runtime shim plus its distinctive requirements.
- Use this section order where it fits: `Files`, `Current Behavior`, `Change Rules`, `Validation`, `Learning Guidance`.
- Derive `Current Behavior` from the runtime shim first, then reconcile it against `docs/shims/<tool>.md`, `scripts/test-shimmy.sh`, `scripts/install-shimmy.sh`, and `README.md`.
- Preserve tool-specific fidelity: mounts, env forwarding, local image build args, secrets, safe defaults, TTY/stdin mode, network privileges, and known mismatches.
- Document required companion-tool relationships in the tool skill, including shared credential state when applicable.
- Keep old tool-specific lessons when renaming existing skills into the `shimmy-tool-*` convention.
- After creating or updating a `shimmy-tool-*` skill, run `./shimmy skills install --target <repo|profile|plugin> shimmy-tool-{toolname}` from the Shimmy checkout so the generated skill is tracked in Shimmy's skills manifest and can be updated idempotently.

## Decision Guidance

- Reuse established repo patterns instead of inventing a new shim shape.
- Prefer shallow context gathering: read only the files needed to match an existing shim pattern.
- Make assumptions explicit when they are low risk; checkpoint with the user when image selection or runtime behavior is ambiguous.
- When proposing an image choice, explain the tradeoff briefly: source, tag strategy, vulnerability scanning, and any expected mounts or env vars.
- Do not downgrade a missing required dependency into an optional follow-up unless the official docs or selected image docs support that choice.

## Validation

- Update `../../../scripts/test-shimmy.sh` with non-mutating assertions and options for the new shim behavior.
- Use Podman and non-mutating commands such as `--help` or `version` when validating container execution.
- Update `../../../README.md` so image defaults, env vars, mounts, and examples stay aligned with the implementation.
- Update `../../../scripts/status-shimmy.sh` image description logic when adding a new remote-image default, local build image, or image override env var so installed status output stays accurate.
- Update `../../../scripts/update-shimmy.sh` refresh logic when adding a remote-image shim that supports `SHIMMY_{TOOL_PREFIX}_IMAGE_PULL=always` or a local-build shim that supports `SHIMMY_{TOOL_PREFIX}_IMAGE_BUILD=always`.
- Keep the `Included Shims` table in `../../../README.md` alphabetized by Tool name after README updates.

## Learning Guidance

- After creating or exercising a tool shim, add tool-specific lessons to that tool's `Learning Guidance` section.
- If a lesson applies across tools, promote it here so future shim creation benefits from it.
- When a generated tool skill exposes a mismatch between runtime, docs, tests, or README, record the mismatch in the tool skill and either fix it in the same change or make the follow-up explicit.
- Prefer precise lessons about behavior and validation over broad reminders, for example: "rootless Podman cannot run raw Nmap host discovery without an explicit privileged opt-in."
- After changing a repo-local shim, verify whether the user is invoking an installed profile copy. Check `command -v <tool>` and `shimmy status --format manifest`; repo-local `./shims/<tool>` validation does not prove the bare command on PATH has been refreshed.
- For source-built Node shims, inspect `package.json` lifecycle scripts and whether built artifacts such as `dist/` are committed. Avoid expensive or fragile build-time lifecycle scripts when a pinned upstream source ref already contains the intended runtime artifact.
- If `podman info` succeeds but a Shimmy wrapper reports Podman unreachable, treat it as the nested-wrapper approval case. Request approval for the exact repo-local or installed wrapper smoke command prefix before trying fallback tools.
- When `./shimmy skills install --target repo shimmy-tool-<tool>` reports skill content is current but manifest writing fails due local filesystem metadata or permissions, note that the skill files may still be present while the manifest needs a targeted follow-up.
- For image-backed shims, confirm the candidate image supports Shimmy's resolved platforms before selecting it: `linux/amd64` on Linux and `linux/arm64` on macOS. Prefer official image documentation or manifest inspection over Docker Hub assumptions, and avoid defaults that make Apple Silicon run amd64 images under emulation unless the user explicitly accepts that tradeoff.
- `smoke_arg=` lines are not shell-split by `shimmy test`. Use repeated `smoke_arg=` entries for multi-argument commands, and use `smoke_env=KEY=value` for non-secret selector variables such as `SHIMMY_OC_VERSION=4.20`.
