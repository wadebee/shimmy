# Remaining Context-first Shimmy Reorganization

## Goal

Complete the context-first migration without reducing Shimmy behavior coverage.
Preserve the documented management commands, tool names, profiles, runtime
variables, image strategies, credentials, mounts, and non-mutating smoke
capabilities.

## Approach 

You may split this work into smaller iterations as needed to keep your context window manageable and to prevent truncation  of work when token usage budget is exceeded. Use this plan to maintain a section marked "Checklist" and place your work segments there marking each as done and allowing user review before continuing.

## Core and lifecycle modularization

- Split `commands/install.sh` into sourceable `core/install/` modules for
  request resolution, manifests, profile assets, startup integration, and
  uninstall cleanup; leave `commands/install.sh` as argument parsing and
  orchestration.
- Split `commands/update.sh` into `core/update/` modules for profile refresh,
  source-management refresh, image pull/build refresh, and cleanup; retain
  `commands/update.sh` as the public entrypoint.
- Move host-network discovery functions from `commands/netinfo.sh` into
  `core/netinfo/` modules grouped by input validation, CIDR handling, Linux,
  macOS, and output rendering.
- Add a `CONTEXT.md` file to every new core subtree and link it from
  `core/CONTEXT.md`.

## Tool-local metadata and refresh hooks

- Replace the remaining tool/version `case` statements in update behavior with
  version-local hooks at `tools/<kind>/versions/<version>/refresh.sh`.
- Define a common hook contract: accept `pull` or `build`, perform only the
  relevant remote-image pull or local-image rebuild, and preserve the existing
  environment override semantics and non-mutating tool invocation used to
  trigger refreshes.
- Add version-local status metadata or hooks so status image descriptions are
  derived from the owning version directory rather than command-level logic.
- Keep `tool.conf` as the source of default-version and selector metadata;
  retain `smoke.conf` as the source of installed smoke configuration.

## Tests and verification

- Restore the prior behavioral suite by splitting it into sourceable modules:
  shared assertions and fixtures in `tests/`, command/profile lifecycle tests
  in `tests/commands/`, shared-core tests in `tests/core/`, and tool-specific
  tests under `tools/<kind>/tests/`.
- Make `tests/test.sh` load every module and retain all previous assertions for
  installation, manifests, activation, status, update, skills, netinfo,
  profiles, dispatch, credentials, error guidance, and tool behavior.
- Add test coverage for each new refresh/status hook and for every concrete
  tool version's metadata, preview path, installed dispatch, and live
  non-mutating Podman smoke command.
- Extend context-tree validation to cover `agent/`, tool `agent/` directories,
  test modules, local container directories that contain source files, and all
  new core subtrees. Require every context to be linked by its parent and every
  documented path to exist.
- Run `./shimmy test`, POSIX syntax checks, executable-bit checks,
  `git diff --check`, clean default/upstream install tests, `update --pull` and
  `update --build` tests, and live version/help smokes for all versions.

## Agent guidance and documentation

- Make `agent/` and each `tools/<kind>/agent/` the canonical skill sources.
  Update `commands/skills.sh` to materialize repository, profile, plugin, and
  export targets from those sources.
- Keep the read-only `.agents/` tree as a compatibility distribution adapter;
  document its generated or externally managed status without depending on it
  as the canonical source.
- Update all core agent skills and every tool skill so paths point to
  `commands/`, `core/`, `tools/`, and `tests/`; remove remaining references to
  the retired source roots.
- Reconcile README, contributor guidance, templates, tool guides, and Podman
  instructions with the final hook and test layout.

## Acceptance criteria

- No runtime, lifecycle, or documentation path refers to retired `lib/`,
  `scripts/`, `shims/`, or `images/` source roots.
- No command-level catalog, status-image, or update-refresh case list names a
  particular tool or concrete version.
- Every tool owns its runtime, metadata, guide, skill, tests, and local build
  context where applicable.
- The complete restored suite passes, and every concrete version has a live
  non-mutating Podman smoke result.
