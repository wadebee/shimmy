# Context-first Shimmy reorganization
Based on work described here --> https://developer.webex.com/blog/boosting-ai-performance-the-power-of-llm-friendly-content-in-markdown 
## Goal

Make context modular, hierarchical, and local to the code it describes while
preserving Shimmy's public management commands, tool names, profiles, runtime
environment variables, image behavior, mounts, credentials, and previews.

## Target layout

- Root `CONTEXT.md` indexes `commands/`, `core/`, `tools/`, `tests/`, and
  canonical `agent/` guidance.
- `commands/` contains the management surface; `core/` contains narrow shared
  POSIX modules.
- `tools/<kind>/` owns `tool.conf`, guide, agent skill, concrete versions,
  smoke configuration, and local `container/` context where required.
- `tests/` validates context integrity, catalog discovery, generic dispatch,
  previews, and installation lifecycle.

## Metadata and installation

`tool.conf` declares the kind default and optional selector. The shared catalog
discovers kinds and concrete version metadata from the tool tree; no central
tool-name, status-image, or dispatcher list is maintained. `run-tool.sh`
performs generic version dispatch.

Installations use manifest layout version 2 and package the command, core,
tool, test, and canonical agent trees. Version-1 installations are not
migrated: users must uninstall and reinstall.

## Validation

Run `./shimmy test` for context-tree validation, metadata/default checks,
preview coverage for every tool, and clean install/dispatch/uninstall coverage.
Run POSIX syntax checks and at least one live non-mutating Podman smoke through
the generic dispatcher.
