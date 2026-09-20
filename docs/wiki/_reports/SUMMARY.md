# Wiki Documentation Summary

Generated: 2026-09-20 14:40:50 EDT
Repository: Shimmy
Commit: `aaebadedc4bd1ac9f56f7e31bd394ae86cd97485`

## Generation Status

**Overall Status**: ✅ Complete

All expected pages and sections are present, all page identifiers match, and structural validation reports no errors or warnings. Mermaid CLI validation could not run because `mmdc` is unavailable; this is a validation-tool warning, not a documentation-structure failure.

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| Pages | 15 | 15 | ✅ |
| Sections | 74 | 74 | ✅ |
| Citations | - | 1,250 | ✅ |
| Diagrams | 28 | 28 found; CLI validation unavailable | ⚠️ |

## Page Details

| Page | Title | Sections | Citations | Diagrams | Status |
|------|-------|----------|-----------|----------|--------|
| 01-overview.md | Overview | 4/4 | 46 | 1 | ✅ |
| 02-getting-started.md | Getting Started | 5/5 | 47 | 1 | ✅ |
| 03-command-line-reference.md | Command-Line Reference | 5/5 | 111 | 0 | ✅ |
| 04-architecture-and-state.md | Architecture and State Model | 5/5 | 84 | 4 | ✅ |
| 05-profile-lifecycle.md | Profile Lifecycle | 5/5 | 81 | 3 | ✅ |
| 06-engines-and-registries.md | Engines, Activation, and Registries | 5/5 | 79 | 3 | ✅ |
| 07-catalog-lifecycle.md | Catalog Lifecycle | 5/5 | 78 | 3 | ✅ |
| 08-shims-and-tool-execution.md | Shims and Tool Execution | 5/5 | 78 | 2 | ✅ |
| 09-tool-authoring.md | Tool Authoring and Image Supply Chain | 5/5 | 64 | 2 | ✅ |
| 10-runtime-security-and-configuration.md | Runtime Security and Configuration | 5/5 | 95 | 2 | ✅ |
| 11-ai-agent-integration.md | AI-Agent Integration | 5/5 | 95 | 2 | ✅ |
| 12-administration-and-recovery.md | Administration, Diagnostics, and Recovery | 5/5 | 76 | 3 | ✅ |
| 13-bundled-tools.md | Bundled Tool Catalog | 5/5 | 177 | 0 | ✅ |
| 14-testing.md | Testing and Validation | 5/5 | 78 | 1 | ✅ |
| 15-contributing-and-maintenance.md | Contributing and Maintenance | 5/5 | 61 | 1 | ✅ |

## Source Coverage

### Covered Files

- `AGENTS.md` - cited in 09-tool-authoring.md, 11-ai-agent-integration.md, 15-contributing-and-maintenance.md
- `BOOTSTRAP.md` - cited in 02-getting-started.md, 12-administration-and-recovery.md
- `CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `CONTRIBUTING.md` - cited in 04-architecture-and-state.md, 14-testing.md, 15-contributing-and-maintenance.md
- `README.md` - cited in 01-overview.md, 02-getting-started.md, 03-command-line-reference.md, 10-runtime-security-and-configuration.md, 13-bundled-tools.md
- `bootstrap.sh` - cited in 02-getting-started.md
- `commands/README.md` - cited in 01-overview.md, 02-getting-started.md, 03-command-line-reference.md, 10-runtime-security-and-configuration.md, 13-bundled-tools.md
- `commands/admin.sh` - cited in 03-command-line-reference.md, 12-administration-and-recovery.md
- `commands/agent-preflight.sh` - cited in 11-ai-agent-integration.md
- `commands/ai-skill.sh` - cited in 03-command-line-reference.md, 11-ai-agent-integration.md
- `commands/bootstrap.sh` - cited in 02-getting-started.md
- `commands/catalog.sh` - cited in 03-command-line-reference.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md
- `commands/help.sh` - cited in 03-command-line-reference.md
- `commands/profile.sh` - cited in 03-command-line-reference.md, 05-profile-lifecycle.md, 07-catalog-lifecycle.md, 11-ai-agent-integration.md
- `commands/run-tool.sh` - cited in 08-shims-and-tool-execution.md
- `commands/shim.sh` - cited in 03-command-line-reference.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md
- `docs/ARCHITECTURE.md` - cited in 01-overview.md, 04-architecture-and-state.md
- `docs/agents/domain.md` - cited in 15-contributing-and-maintenance.md
- `docs/agents/issue-tracker.md` - cited in 15-contributing-and-maintenance.md
- `docs/netinfo.md` - cited in 12-administration-and-recovery.md
- `docs/network-tools.md` - cited in 10-runtime-security-and-configuration.md
- `docs/podman.md` - cited in 06-engines-and-registries.md, 12-administration-and-recovery.md
- `docs/prompt-shimmy-project.md` - cited in 15-contributing-and-maintenance.md
- `docs/registries.md` - cited in 06-engines-and-registries.md
- `docs/runtime-preflight.md` - cited in 10-runtime-security-and-configuration.md, 11-ai-agent-integration.md
- `docs/templates/generic-shim/AGENTS.md` - cited in 09-tool-authoring.md, 11-ai-agent-integration.md, 15-contributing-and-maintenance.md
- `docs/templates/generic-shim/SKILL.md` - cited in 09-tool-authoring.md, 11-ai-agent-integration.md, 15-contributing-and-maintenance.md
- `docs/testing.md` - cited in 08-shims-and-tool-execution.md, 14-testing.md
- `lib/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `lib/ai-skill/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `lib/ai-skill/ai-skill.sh` - cited in 03-command-line-reference.md, 11-ai-agent-integration.md
- `lib/ai-skill/bundle.sh` - cited in 11-ai-agent-integration.md
- `lib/ai-skill/link.sh` - cited in 11-ai-agent-integration.md
- `lib/catalog/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `lib/catalog/authority.sh` - cited in 07-catalog-lifecycle.md
- `lib/catalog/catalog.sh` - cited in 03-command-line-reference.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md
- `lib/catalog/refresh.sh` - cited in 07-catalog-lifecycle.md, 09-tool-authoring.md
- `lib/catalog/state.sh` - cited in 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md
- `lib/common/common.sh` - cited in 04-architecture-and-state.md
- `lib/common/lock.sh` - cited in 04-architecture-and-state.md
- `lib/engine/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `lib/engine/lifecycle.sh` - cited in 05-profile-lifecycle.md, 06-engines-and-registries.md, 12-administration-and-recovery.md
- `lib/engine/ownership.sh` - cited in 06-engines-and-registries.md
- `lib/engine/projection.sh` - cited in 06-engines-and-registries.md
- `lib/engine/state.sh` - cited in 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md
- `lib/images/catalog.sh` - cited in 03-command-line-reference.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md
- `lib/images/images.sh` - cited in 07-catalog-lifecycle.md
- `lib/install/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `lib/install/lifecycle.sh` - cited in 05-profile-lifecycle.md, 06-engines-and-registries.md, 12-administration-and-recovery.md
- `lib/install/uninstall.sh` - cited in 05-profile-lifecycle.md, 12-administration-and-recovery.md
- `lib/netinfo/netinfo.sh` - cited in 12-administration-and-recovery.md
- `lib/netinfo/render.sh` - cited in 12-administration-and-recovery.md
- `lib/profile/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `lib/profile/activation.sh` - cited in 05-profile-lifecycle.md
- `lib/profile/management.sh` - cited in 05-profile-lifecycle.md, 11-ai-agent-integration.md
- `lib/profile/profile.sh` - cited in 03-command-line-reference.md, 05-profile-lifecycle.md, 07-catalog-lifecycle.md, 11-ai-agent-integration.md
- `lib/profile/state.sh` - cited in 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md
- `lib/profile/transaction.sh` - cited in 05-profile-lifecycle.md
- `lib/registries/registries.sh` - cited in 06-engines-and-registries.md
- `lib/runtime/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `lib/runtime/image.sh` - cited in 08-shims-and-tool-execution.md
- `lib/runtime/log.sh` - cited in 08-shims-and-tool-execution.md
- `lib/runtime/podman.sh` - cited in 08-shims-and-tool-execution.md, 10-runtime-security-and-configuration.md
- `lib/runtime/preflight-review.sh` - cited in 10-runtime-security-and-configuration.md
- `lib/shim/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `lib/shim/shim.sh` - cited in 03-command-line-reference.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md
- `lib/shim/state.sh` - cited in 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md
- `lib/startup/startup.sh` - cited in 05-profile-lifecycle.md
- `plugins/shimmy/skills/shimmy-commit/SKILL.md` - cited in 09-tool-authoring.md, 11-ai-agent-integration.md, 15-contributing-and-maintenance.md
- `plugins/shimmy/skills/shimmy-create-tool/SKILL.md` - cited in 09-tool-authoring.md, 11-ai-agent-integration.md, 15-contributing-and-maintenance.md
- `plugins/shimmy/skills/shimmy-escalation/SKILL.md` - cited in 09-tool-authoring.md, 11-ai-agent-integration.md, 15-contributing-and-maintenance.md
- `plugins/shimmy/skills/shimmy-init/SKILL.md` - cited in 09-tool-authoring.md, 11-ai-agent-integration.md, 15-contributing-and-maintenance.md
- `plugins/shimmy/skills/shimmy-tool-local-build/SKILL.md` - cited in 09-tool-authoring.md, 11-ai-agent-integration.md, 15-contributing-and-maintenance.md
- `tests/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `tests/commands/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `tests/context-tree.sh` - cited in 14-testing.md
- `tests/lib/CONTEXT.md` - cited in 01-overview.md, 04-architecture-and-state.md, 05-profile-lifecycle.md, 06-engines-and-registries.md, 07-catalog-lifecycle.md, 08-shims-and-tool-execution.md, 11-ai-agent-integration.md, 14-testing.md, 15-contributing-and-maintenance.md
- `tests/runner.sh` - cited in 14-testing.md
- `tests/runtime-benchmark.sh` - cited in 14-testing.md
- `tests/support.sh` - cited in 14-testing.md
- `tests/test.sh` - cited in 14-testing.md
- `tools/aws/guide.md` - cited in 10-runtime-security-and-configuration.md, 13-bundled-tools.md
- `tools/jq/tool.conf` - cited in 09-tool-authoring.md, 13-bundled-tools.md
- `tools/jq/versions/1.8/image.conf` - cited in 09-tool-authoring.md
- `tools/jq/versions/1.8/run.sh` - cited in 08-shims-and-tool-execution.md, 09-tool-authoring.md
- `tools/jv/versions/6.0/image.conf` - cited in 09-tool-authoring.md
- `tools/jv/versions/6.0/refresh.sh` - cited in 07-catalog-lifecycle.md, 09-tool-authoring.md
- `tools/jv/versions/6.0/run.sh` - cited in 08-shims-and-tool-execution.md, 09-tool-authoring.md
- `tools/nmap/guide.md` - cited in 10-runtime-security-and-configuration.md, 13-bundled-tools.md
- `tools/opnsense-mcp-read-only/guide.md` - cited in 10-runtime-security-and-configuration.md, 13-bundled-tools.md
- `tools/terraform/guide.md` - cited in 10-runtime-security-and-configuration.md, 13-bundled-tools.md

Coverage: 91 of 91 concrete TOC source-file entries are cited (100%). Glob patterns are excluded because they cannot be matched directly to citations.

## Issues

### Errors

None. Structural validation passed for 15 pages and 74 sections.

### Warnings

- **Mermaid validation**: All 28 Mermaid blocks across 13 files were discovered, but none could be rendered because `mmdc` is unavailable. The validator classified all 28 results as `cli_unavailable`; they are unvalidated, not confirmed invalid diagrams.

### Recommendations

- Install `@mermaid-js/mermaid-cli` and rerun Mermaid validation to confirm all 28 diagrams render.
