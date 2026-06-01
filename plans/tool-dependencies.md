# Tool Dependency Planning

## Goal

Improve Shimmy's tool-creation guidance for cases where a requested CLI shim depends on another CLI or tool that does not yet exist as a native tool or a Shimmy shim.

## Planned Changes

1. Hard rename `shimmy-create` to `shimmy-create-tool`.
   - Rename the repo-local skill directory from `.agents/skills/shimmy-create/` to `.agents/skills/shimmy-create-tool/`.
   - Rename the packaged plugin skill directory from `plugins/shimmy/skills/shimmy-create/` to `plugins/shimmy/skills/shimmy-create-tool/`.
   - Update skill frontmatter, descriptions, README plugin docs, skill install/share scripts, tests, manifests, and tool-skill references.
   - Remove the old `shimmy-create` name entirely; no compatibility alias is required.

2. Add a required dependency gate to the tool-creation workflow.
   - After the requested CLI tool is identified, require the agent to inspect official upstream docs and candidate container image docs for required companion tools, plugins, or CLIs.
   - If a required companion tool is not already present as a native tool or Shimmy shim and is not documented as bundled in the selected container image, stop before implementation.
   - The stop point should summarize:
     - the dependency name,
     - why it is required,
     - official source links supporting the requirement,
     - whether `shims/<dependency>` exists,
     - whether `.agents/skills/shimmy-tool-<dependency>/SKILL.md` exists,
     - recommended next steps.

3. Default the next step to creating the missing dependency shim first.
   - Recommend creating the missing dependency shim before creating the dependent shim.
   - Allow a composite image strategy only after the user explicitly chooses it.
   - Treat optional integrations as non-blocking unless the user's requested use case depends on them.

4. Account for Shimmy's credential-handling direction.
   - Do not teach agents to casually default to bind-mounted credential files for new shims.
   - Document that Shimmy's preferred future direction for tool credentials is `podman secret`, because Podman is already a required Shimmy dependency.
   - For this change, agents should surface credential requirements and design choices clearly, but should not implement new Podman-secret credential flows unless explicitly requested.
   - Existing credential mount patterns may remain until a dedicated credential-handling change is planned.

5. Clarify dependent-tool implementation guidance.
   - Shimmy wrappers must not silently rely on host-installed companion CLIs.
   - For paired tools, the agent should document the relationship in the eventual tool skill.
   - When credentials are involved, the agent should identify whether the dependency and dependent tool share credential state, while deferring the final credential mechanism to the explicit design choice above.
   - Keep the guidance generic rather than hardcoding a single tool pair, so it applies beyond examples such as `gcloud` and `kubectl`.

## Verification Plan

- Search for remaining `shimmy-create` references after the hard rename.
- Run the skills-related tests, or the full `./scripts/test-shimmy.sh` if practical.
- Validate `./shimmy skills install --target repo` and `./shimmy skills install --target plugin` after the rename.
- If a Shimmy-backed tool or Podman-backed check fails because of reachability, sandboxing, or AI Agent approval symptoms, pause and use the Shimmy remediation workflow instead of silently falling back.

## Risks And Assumptions

- This intentionally breaks existing references to `shimmy-create`; current sessions or exported plugins may need skill reinstall or reload.
- The dependency gate must distinguish required dependencies from optional integrations, otherwise it will block too much.
- Source links should be gathered fresh from official tool docs during the actual shim-planning task; this plan should not embed stale tool-specific links.
- Podman-secret credential handling is a planned guidance direction, not part of this implementation.
