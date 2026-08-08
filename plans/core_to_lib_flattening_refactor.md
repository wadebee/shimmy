# Core-to-lib flattening refactor

```text
Prompt extraction: non-backward-compatible core/lib flattening refactor

- Reconcile and redesign the folder structure created under ~/.config/shimmy so it makes sense to both maintainers and end-users.
- Backward compatibility is not required.
- Rename the repository source directory core/ to lib/.
- Remove the installed nested control-tree pattern that currently produces ~/.config/shimmy/core/core/... .
- Change installer behavior so the contents currently copied under the installed core/ bundle are copied directly into the install root instead.
- Update all touchpoints universally: implementation, path resolution, dispatch, update logic, tests, docs, contexts, and skills.
- Produce a formal plan that supports multiple AI sessions with fresh context windows.
- Chunk work into reviewable iterations.
- Require human review/acceptance after each chunk before continuing.
- Maintain a cumulative “lessons learned” block to reduce churn, hallucinations, and repeated false starts across sessions.
- Include exact files to modify, a patchable verification checklist, and risk callouts.
```

## Objective

Refactor Shimmy so that:

- the source tree uses `lib/` instead of `core/`
- the installed control/runtime assets are placed directly in the install root
- the installed layout no longer contains a nested `core/core` structure
- all code, tests, docs, contexts, and skill guidance are updated consistently

This plan assumes **no backward compatibility requirement**.

## Current-state facts to preserve during planning

These are the verified facts that future sessions should treat as ground truth:

1. The current nested layout is produced by installed-path resolution plus installer copy targets, not by the repo tree alone.
2. The installed dispatcher currently hardcodes `core/core` and `core/commands` assumptions.
3. The installed launcher currently treats `../core` as the installed root payload.
4. Self-update logic currently detects installed management by checking `<install>/core/...`.
5. The repo architecture and contexts currently describe `core/` as the shared-module directory, so docs and context-tree tests must change too.

## Target end state

## Repo layout

```text
shimmy/
  agent/
  commands/
  lib/
  plugins/
  tests/
  tools/
  shimmy
```

## Installed layout

```text
~/.config/shimmy/
  shimmy
  activate.sh
  install-manifest.txt
  bin/
  commands/
  lib/
  plugins/
  tests/
  tools/
  agent/
  profiles/
    default/
    upstream/
```

Whether the flat install also contains `<install>/.agents/skills` is unresolved
and is intentionally not implied by this diagram.

## Naming model

- `lib/` = shared shell modules
- install root = installed control/runtime root
- no separate installed `core/` bundle
- remove `SHIMMY_*CORE*` variables and replace them with names that reflect the flattened layout

## Confirmed implementation constraints

- Treat the install root as a container of individually owned paths, not as a
  recursively replaceable bundle.
- Never translate the current `rm -rf "$SHIMMY_CORE_DIR"` behavior into an
  equivalent recursive removal of the install root.
- Refresh and additive install flows must preserve `profiles/`, manifests, and
  unknown or unmanaged files at the install root.
- Final-profile uninstall must remove each Shimmy-owned root asset explicitly
  and remove the install root only when it is empty.
- Add a disposable unmanaged sentinel file to install, refresh, update, and
  uninstall tests and prove that Shimmy does not delete it.
- Every accepted chunk must leave the repository in a testable, operational
  state. Do not accept an intermediate chunk that knowingly breaks source or
  installed dispatch.
- Repository paths in this plan are relative to `<repo>` so the plan remains
  portable across workstations and AI sessions.
- Preserve unrelated uses of `core`, including upstream API paths such as
  OPNsense `/core/...` endpoints. Cleanup searches require review, not blind
  replacement.

# Human-in-the-loop execution model

Each chunk below is intended to be run in a separate or reusable AI session.

For **every chunk**:

1. Read `AGENTS.md`, `CONTEXT.md`, every child context on the path to a changed
   file, the chunk header, and its listed files first.
2. Execute only that chunk’s scope.
3. Run the chunk verification checklist.
4. Produce a short summary:
   - changes made
   - tests run
   - failures or uncertainties
   - lessons learned
5. Update the **Lessons Learned** block in this plan.
6. Stop and wait for **human review/acceptance** before continuing.

Do **not** begin the next chunk without explicit approval.

# Lessons learned (living block)

Seed this block before any implementation starts, then append after each chunk.

## Initial lessons learned

- Do not preserve any legacy `core/` install compatibility paths.
- The install root itself should become the control/runtime root.
- `core/` is being renamed in the **source tree** to `lib/`; this is not just an install-path alias.
- Any remaining `SHIMMY_INSTALL_CORE_DIR` or `SHIMMY_CORE_DIR` naming after refactor is a design bug, not technical debt to defer.
- Dispatcher, launcher, update logic, runtime shims, tests, docs, and contexts all contain path assumptions and must be updated together.
- When changing a directory name, also update shellcheck source comments, context links, and test support globs.
- Flat installation requires targeted replacement and cleanup of owned paths;
  the current bundled-directory delete behavior cannot be reused for the
  install root.
- The flattened layout uses root install manifest version `3`, profile
  manifest version `3`, and the root-only layout label
  `shimmy_install_layout=flat-root`. Both manifest types require exact-version
  validation; an existing version-2 or mixed-version install must be rejected
  before any installed asset is changed.
- Retain `agent/core/` as the canonical source location for management skills
  during this refactor. Reconciling it with the cross-client
  `.agents/skills/` distribution and plugin copies is a separate effort.

## Chunk 1 lessons learned

- _append after completion_

## Chunk 2 lessons learned

- _append after completion_

## Chunk 3 lessons learned

- _append after completion_

## Chunk 4 lessons learned

- _append after completion_

## Chunk 5 lessons learned

- _append after completion_

# Confirmed scrub inventory

This inventory was produced from a repository-wide search before implementation.
It distinguishes known migration touchpoints from unrelated uses of `core`.

## Shared source tree

- Rename the complete `<repo>/core/` tree to `<repo>/lib/`, including all shell
  modules and all nine `CONTEXT.md` files currently rooted there.
- Update self-references in:
  - `lib/install/install.sh`
  - `lib/netinfo/netinfo.sh`
  - `lib/runtime/image.sh`
  - `lib/update/update.sh`
- Update source-checkout structural validation in `lib/profile/profile.sh`.

## Versioned runtime and refresh files

- `tools/aws/versions/2.31/run.sh`
- `tools/gcloud/versions/573.0/run.sh`
- `tools/gdrive/versions/0.2/run.sh`
- `tools/gdrive/versions/0.2/refresh.sh`
- `tools/gh/versions/2.94/run.sh`
- `tools/gh/versions/2.94/refresh.sh`
- `tools/go/versions/1.26/run.sh`
- `tools/jq/versions/1.8/run.sh`
- `tools/logmine/versions/0.1/run.sh`
- `tools/logmine/versions/0.1/refresh.sh`
- `tools/netcat/versions/7.92/run.sh`
- `tools/netcat/versions/7.92/refresh.sh`
- `tools/nmap/versions/7.98/run.sh`
- `tools/oc/versions/4.18/run.sh`
- `tools/oc/versions/4.18/refresh.sh`
- `tools/oc/versions/4.20/run.sh`
- `tools/oc/versions/4.20/refresh.sh`
- `tools/oc/versions/4.22/run.sh`
- `tools/oc/versions/4.22/refresh.sh`
- `tools/opnsense-mcp-admin/versions/1.0/run.sh`
- `tools/opnsense-mcp-admin/versions/1.0/refresh.sh`
- `tools/opnsense-mcp-read-only/versions/0.4/run.sh`
- `tools/opnsense-mcp-read-only/versions/0.4/refresh.sh`
- `tools/rg/versions/15.1/run.sh`
- `tools/skopeo/versions/1.22/run.sh`
- `tools/task/versions/3.45/run.sh`
- `tools/task/versions/3.45/refresh.sh`
- `tools/terraform/versions/1.15/run.sh`
- `tools/tessl/versions/0.1/run.sh`
- `tools/tessl/versions/0.1/refresh.sh`
- `tools/textual/versions/8.2/run.sh`
- `tools/textual/versions/8.2/refresh.sh`

## Confirmed non-migration matches

- OPNsense API endpoint paths such as `/core/system/info` and
  `/core/firmware/status` are upstream API names and must not be rewritten.
- Generic prose such as “core behavior” is not automatically a path reference;
  retain or rewrite it based on meaning.

# Chunked implementation plan

Do not begin implementation until the blocking choices under **Unresolved**
have decisions recorded and the affected chunk boundaries and file lists have
been reconciled. In particular, the current Chunk 1/Chunk 2 boundary is not an
approved operational transition.

## Chunk 1 — Source-tree rename and internal module path conversion

### Goal

Rename repo `core/` to `lib/` and update direct source-tree references without yet finishing the installed-layout flattening behavior.

### Why first

This establishes the new conceptual model for maintainers and reduces ambiguity in subsequent chunks.

### Files to modify

### Rename directory

- `<repo>/core/` -> `<repo>/lib/`

### Update command entrypoints

- `<repo>/commands/activate.sh`
- `<repo>/commands/agent-preflight.sh`
- `<repo>/commands/dispatch-tool.sh`
- `<repo>/commands/install.sh`
- `<repo>/commands/netinfo.sh`
- `<repo>/commands/status.sh`
- `<repo>/commands/update.sh`
- `<repo>/commands/skills.sh`

### Update moved library files for self-references and shellcheck paths

- all files currently under `<repo>/core/**/*.sh`, after rename under `<repo>/lib/**/*.sh`

### Update repo launcher and any root-level helpers that reference `core/`

- `<repo>/shimmy`

### Update tool runtime references to shared runtime helpers

Use the exact runtime and refresh inventory in **Confirmed scrub inventory**.

### Update tests that source repo `core/`

- `<repo>/tests/test.sh`
- `<repo>/tests/support.sh`
- `<repo>/tests/core/catalog.sh`
- `<repo>/tests/core/runtime.sh`
- `<repo>/tests/core/update.sh`
- `<repo>/tests/context-tree.sh`

### Deliverable

Repo compiles conceptually around `lib/` instead of `core/`, even if installed flattening is not fully complete yet.

### Human review gate

Confirm:

- `lib/` naming reads clearly
- no source-tree `core/` references remain except intentionally deferred doc/test text noted in summary

## Chunk 2 — Installed layout flattening and variable model rewrite

### Goal

Remove the installed `core/` bundle root and make the install root itself the control/runtime root.

### Why second

This is the highest-risk behavioral change and should happen only after the source-tree rename is coherent.

### Files to modify

### Installed path model

- `<repo>/lib/profile/profile.sh`

### Install request wiring

- `<repo>/lib/install/request.sh`

### Installer asset copy logic

- `<repo>/lib/install/profile-assets.sh`
- `<repo>/lib/install/install.sh`
- `<repo>/lib/install/uninstall.sh`
- `<repo>/lib/install/manifest.sh`

### Installed launcher

- `<repo>/shimmy`

### Dispatcher

- `<repo>/commands/dispatch-tool.sh`

### Manifest-consuming commands

- `<repo>/commands/activate.sh`
- `<repo>/commands/status.sh`

### Update installed-layout detection

- `<repo>/lib/update/management.sh`
- `<repo>/lib/update/profile.sh`
- `<repo>/lib/update/refresh.sh`
- `<repo>/lib/update/update.sh`

### Specific implementation intent

- eliminate `SHIMMY_INSTALL_CORE_DIR`
- eliminate `SHIMMY_CORE_DIR`
- eliminate installed path assumptions like:
  - `<install>/core/commands`
  - `<install>/core/core`
  - `<install>/core/tools`
- replace dispatcher symlink target `../core/commands/dispatch-tool.sh` with `../commands/dispatch-tool.sh`
- install `shimmy` at `<install>/shimmy`
- install commands at `<install>/commands`
- install shared library at `<install>/lib`
- install tools/tests/plugins/agent directly at install root
- replace managed root assets individually; do not recursively delete or
  replace `<install>` as a single directory
- preserve `<install>/profiles`, all existing profile manifests, the root manifest, and
  unmanaged root entries during additive install, refresh, and self-update
- on final-profile uninstall, remove only verified Shimmy-owned paths and use
  `rmdir` for the install root so unmanaged content is preserved
- keep source checkout validation synchronized with the required
  `commands/`, `lib/`, and `tools/` source structure
- make installed-layout detection validate the flattened paths rather than
  merely checking that the install directory exists
- write `shimmy_install_manifest_version=3` and
  `shimmy_install_layout=flat-root` in the root manifest
- write `shimmy_profile_manifest_version=3` in every profile manifest and
  remove the ambiguous unscoped `shimmy_layout` key from profile manifests
- validate the root manifest version and layout label together, then validate
  the selected profile manifest version before using profile-owned paths or
  metadata
- apply the same validation contract to install, additive install, refresh,
  update, status, activation, dispatch, profile enumeration, and uninstall;
  no command may consume incompatible manifest paths before rejecting them
- if a root manifest exists but either required root identity field is missing
  or different, fail before mutation with:
  `incompatible Shimmy install layout at <manifest-path> (expected shimmy_install_manifest_version=3 and shimmy_install_layout=flat-root); uninstall it with the Shimmy version that created it, then reinstall`
- if a profile manifest exists but its version is missing or different, fail
  before mutation with:
  `incompatible Shimmy profile manifest at <manifest-path> (expected shimmy_profile_manifest_version=3); uninstall the existing Shimmy installation with the Shimmy version that created it, then reinstall`
- treat an absent root manifest as a fresh-install candidate, but do not treat
  an existing manifest with missing identity fields as compatible

### Deliverable

A fresh install produces the flattened layout with no `core/` subtree.

### Human review gate

Confirm:

- the resulting install tree is easy to understand
- no accidental path collisions were introduced at install root
- manifest semantics still make sense
- refresh and additive install cannot erase profile or unmanaged state
- final-profile uninstall removes owned assets without recursively deleting the install root

## Chunk 3 — Tests and verification harness rewrite

### Goal

Update all tests and test infrastructure to validate the new `lib/` source layout and flattened install layout.

### Files to modify

### Command/install lifecycle tests

- `<repo>/tests/commands/install.sh`
- `<repo>/tests/commands/lifecycle.sh`
- `<repo>/tests/commands/update.sh`
- `<repo>/tests/commands/test.sh`
- `<repo>/tests/commands/profiles.sh`
- `<repo>/tests/commands/dispatcher.sh`
- `<repo>/tests/commands/management.sh`
- `<repo>/tests/commands/skills.sh`
- `<repo>/tests/commands/startup.sh`
- `<repo>/tests/commands/netinfo.sh`
- `<repo>/tests/commands/agent-preflight.sh`

### Shared/core-now-lib tests

- `<repo>/tests/core/catalog.sh`
- `<repo>/tests/core/runtime.sh`
- `<repo>/tests/core/update.sh`
- apply the recorded decision from **Unresolved: Shared-library test directory
  name**

### Test runner and support

- `<repo>/tests/test.sh`
- `<repo>/tests/support.sh`
- `<repo>/tests/context-tree.sh`
- `<repo>/tests/profile-smoke.sh`

### Specific implementation intent

- replace installed assertions such as `$INSTALL_DIR/core/tools/...` with `$INSTALL_DIR/tools/...`
- update any env vars or helper names referencing `CORE`
- implement the recorded `tests/core/` naming decision consistently in paths,
  context links, shellcheck comments, and test function names
- rename test helper variables and functions that encode the old installed-core
  model; do not retain `SHIMMY_INSTALL_CORE_DIR`, `install_core_dir`, or
  equivalent aliases
- verify fresh default and upstream installs independently and together
- verify additive install and management refresh preserve both profiles
- verify removing one profile preserves the other profile and shared assets
- verify removing the final profile removes all owned root assets
- verify an unmanaged install-root sentinel survives install, refresh,
  self-update, and uninstall
- verify exact dispatcher symlink targets and reject broken or recursive links
- verify source-checkout validation requires `lib/` and rejects stale `core/`
- verify root manifests require version `3` plus
  `shimmy_install_layout=flat-root`, and profile manifests require version `3`
- verify missing, version-2, unknown-version, wrong-label, and mixed-version
  manifests are rejected before any installed asset changes
- verify executable bits on `shimmy`, command entrypoints, library entrypoints,
  version runtimes, and refresh hooks

### Deliverable

Test suite validates the new model instead of preserving old assumptions.

### Human review gate

Confirm:

- test names still make sense
- expected install tree in tests matches agreed flattened design
- no tests silently retain legacy path assertions
- every chunk accepted before this test rewrite has a documented passing test
  command appropriate to its scope

## Chunk 4 — Documentation, contexts, and skills rewrite

### Goal

Update maintainer-facing and AI-facing documentation only where the shared
shell-module rename or flattened installed layout requires it. Do not use this
chunk to redesign or reconcile the agent-skill source and distribution trees.

### Files to modify

### Root and contribution docs

- `<repo>/README.md`
- `<repo>/CONTEXT.md`
- `<repo>/CONTRIBUTING.md`
- `<repo>/AGENTS.md`
- `<repo>/commands/README.md`

### Context files

- `<repo>/commands/CONTEXT.md`
- `<repo>/tests/CONTEXT.md`
- `<repo>/tests/core/CONTEXT.md`
- all context files currently under `<repo>/core/**/CONTEXT.md`, after rename under `<repo>/lib/**/CONTEXT.md`
- `<repo>/agent/CONTEXT.md`
- `<repo>/agent/core/CONTEXT.md`
- `<repo>/agent/core/shimmy-create-tool/CONTEXT.md`
- `<repo>/agent/core/shimmy-escalation/CONTEXT.md`
- `<repo>/agent/core/shimmy-init/CONTEXT.md`
- `<repo>/agent/core/shimmy-install/CONTEXT.md`
- `<repo>/agent/core/shimmy-tool-local-build/CONTEXT.md`

### AI/skill guidance

- `<repo>/.agents/skills/shimmy-create-tool/SKILL.md`
- `<repo>/plugins/shimmy/skills/shimmy-create-tool/SKILL.md`
- `<repo>/agent/core/shimmy-create-tool/SKILL.md`
- `<repo>/agent/core/shimmy-create-tool/CONTEXT.md`
- `<repo>/agent/core/shimmy-tool-local-build/SKILL.md`
- no canonical tool-local agent skill currently contains a shared-module
  `core/` path; repeat the scrub after implementation and review any new match

### Other docs and plans with hardcoded `core/`

- `<repo>/docs/prompt-shimmy-project.md`
- `<repo>/docs/testing.md`
- `<repo>/docs/templates/generic-shim/SKILL.md`
- plan/history docs that are intended to remain accurate:
  - `<repo>/plans/context.md`
  - `<repo>/plans/context_remaining.md`
  - `<repo>/plans/multi-architecture-manifest.md`

### Specific implementation intent

- replace “shared core” with “shared library” or equivalent accurate phrasing
- update path examples from `core/...` to `lib/...`
- update install layout descriptions from `<install>/core/...` to flat install-root examples
- ensure context-tree references point to renamed directories
- update `README.md` and `commands/README.md`, which currently describe the
  shared source directory as `core/`
- audit the complete canonical agent context subtree and keep every parent-child
  context link valid
- retain `agent/core/` and its current meaning of “core management skills”
- make only migration-required path and terminology edits in canonical,
  plugin, and `.agents` skill files; do not resolve unrelated pre-existing
  content divergence between those trees in this plan

### Deliverable

Repository guidance matches actual code and install behavior.

### Human review gate

Confirm:

- wording is maintainable and not overfit to this migration
- AI skill prompts do not preserve stale path advice
- context-tree docs remain consistent

## Chunk 5 — Final cleanup, naming normalization, and end-to-end validation

### Goal

Remove leftover legacy naming, run full validation, and prepare final review.

### Files to modify

This chunk is cleanup-oriented and may touch any file modified previously, especially:

- all remaining files with:
  - `SHIMMY_INSTALL_CORE_DIR`
  - `SHIMMY_CORE_DIR`
  - `core/core`
  - `../core/commands/dispatch-tool.sh`
  - source comments or examples that still reference `core/`

### Specific implementation intent

- perform final variable renames to match the flattened model
- decide whether any intentionally retained `core` words still make sense
- ensure no stale context-tree references remain
- ensure no install script, update path, or test helper can recreate a nested `core` tree

### Deliverable

A coherent, non-backward-compatible, fully updated codebase with a single layout model.

### Human review gate

Confirm:

- layout is clear to maintainers
- layout is clear to end-users
- no legacy-path wording remains except in explicit migration notes, if any

# Patchable verification checklist

Use this as a living checklist. Mark each item with `[x]`, `[ ]`, or `[~]`, and append notes inline.

## Chunk 1 verification

- [ ] Repo directory renamed from `core/` to `lib/`
- [ ] All command entrypoints source `lib/...` instead of `core/...`
- [ ] All moved library files have correct shellcheck source comments
- [ ] All runtime shims reference `lib/runtime/...`
- [ ] Test runner and support reference `lib/...`
- [ ] `rg` confirms no unintended source-tree `core/...` references remain
- [ ] Source-checkout validation requires `commands/`, `lib/`, and `tools/`
- [ ] The repository remains operational at the chunk review gate
- Notes:

## Chunk 2 verification

- [ ] Fresh install no longer creates `<install>/core`
- [ ] Fresh install places `shimmy`, `commands/`, `lib/`, `tools/`, `tests/`, `plugins/`, `agent/` at install root
- [ ] Dispatcher symlinks point to `../commands/dispatch-tool.sh`
- [ ] Installed launcher resolves install root directly
- [ ] Dispatcher loads helpers from `<install>/lib/...`
- [ ] Update logic no longer checks `<install>/core/...`
- [ ] Uninstall removes flattened install layout correctly
- [ ] No `SHIMMY_INSTALL_CORE_DIR` or `SHIMMY_CORE_DIR` remain
- [ ] Additive install and refresh preserve both profile trees and manifests
- [ ] An unmanaged install-root sentinel is preserved
- [ ] No code path recursively removes the install root
- [ ] Installed-layout validation rejects the previous incompatible layout
- [ ] Root manifests use `shimmy_install_manifest_version=3` and
      `shimmy_install_layout=flat-root`
- [ ] Profile manifests use `shimmy_profile_manifest_version=3` and do not
      contain the ambiguous unscoped `shimmy_layout` key
- [ ] Existing malformed, version-2, unknown-version, wrong-label, and
      mixed-version manifests are rejected before mutation with the agreed
      remediation
- Notes:

## Chunk 3 verification

- [ ] Command tests updated for flat install layout
- [ ] Shared-library tests updated for `lib/...`
- [ ] Context-tree tests pass with renamed source directory
- [ ] Profile smoke behavior still works
- [ ] No tests assert old installed paths
- [ ] Default-only, upstream-only, and combined-profile scenarios pass
- [ ] Removing one profile preserves the other and shared root assets
- [ ] Removing the final profile removes owned assets but preserves an
      unmanaged sentinel
- [ ] Dispatcher symlinks have the exact agreed target and are not broken
- [ ] Required runnable files retain executable bits
- Notes:

## Chunk 4 verification

- [ ] Root docs describe `lib/` accurately
- [ ] Context files reference `lib/` accurately
- [ ] AI skill docs no longer advise `core/` paths
- [ ] `agent/CONTEXT.md`, its management-skill child context, and all five leaf
      contexts are explicitly reviewed
- [ ] Migration-related `core/` -> `lib/` guidance is consistent in every
      affected canonical, plugin, and `.agents` skill file
- [ ] No skill tree was moved or broadly reconciled as part of this refactor
- [ ] Any persistent historical plan docs were either updated or intentionally left as historical artifacts with justification
- Notes:

## Chunk 5 verification

- [ ] Full repo search shows no unintended `core/core` references
- [ ] Full repo search shows no unintended `SHIMMY_*CORE*` variable names
- [ ] Full repo search classifies every remaining `core` match as intentional
- [ ] Fresh install works
- [ ] `shimmy activate` works
- [ ] Installed shim dispatch works
- [ ] `shimmy update` works for a fresh install
- [ ] `shimmy uninstall` works
- [ ] Full relevant test suite passes
- [ ] The context-tree test passes
- [ ] Repository diff contains no stale workstation-specific absolute paths
- Notes:

## Suggested commands to run during verification

Adjust as needed per chunk:

- [ ] `./shimmy test`
- [ ] `./tests/context-tree.sh`
- [ ] disposable install with `./shimmy install --install-dir <tmpdir> --no-startup --no-skills`
- [ ] inspect the complete install tree, including hidden paths
- [ ] `./shimmy activate --install-dir <tmpdir>`
- [ ] installed command smoke check from `<tmpdir>/bin/<shim> --version`
- [ ] `./shimmy update --install-dir <tmpdir>`
- [ ] `./shimmy uninstall --install-dir <tmpdir> --profile default`
- Notes:

# Risk callouts

## High risk

1. **Install-root destructive replacement**
   - The current installer safely replaces a dedicated bundled directory with
     `rm -rf`. Applying that behavior to the flattened install root would erase
     profiles, manifests, and unmanaged content. Flat refresh and uninstall
     must operate on individually validated owned paths.

2. **Installed launcher path resolution**
   - If `shimmy` root detection is wrong, every installed command path becomes unreliable.

3. **Dispatcher recursion or broken symlink targets**
   - The dispatcher currently protects against recursion and assumes specific central paths.

4. **Update/self-update detection**
   - Installed-management detection is tightly coupled to current layout and can silently misclassify environments if partially updated.

5. **Manifest layout identification**
   - The incompatible flat layout must not be accepted as the existing layout.
     The recorded decision is root manifest version `3`, profile manifest
     version `3`, and root layout label `flat-root`, with strict validation of
     all identity fields before mutation.

6. **Tool runtime helper paths**
   - Many versioned tool runtimes hardcode `core/runtime/...`; missing even one will create fragmented failures.

## Medium risk

7. **Context-tree and shellcheck source comments**
   - These are easy to miss and can create noisy failures late in the process.

8. **Test naming and folder semantics**
   - `tests/core/` may become misleading once source `core/` is gone. Decide explicitly whether to rename it or document it as a legacy grouping.

9. **Installed skill compatibility assets**
   - The installer currently writes `.agents/skills` inside the bundled control
     tree. Its flat-layout ownership and cleanup contract must be explicit.

## Low risk

10. **Contributor/skill docs drift**
   - Easy to fix, but if skipped, future AI sessions will reintroduce stale assumptions.

# Unresolved

Resolve these items with the maintainer before implementation. Record each
decision here, then update the affected chunks and verification items so later
sessions do not reopen it accidentally.

## 1. Safe chunk sequencing

The current Chunk 1 source rename and Chunk 2 installed-layout rewrite are not
independently operational: the installed launcher and dispatcher span both
models.

Decide whether to:

- merge the source rename, installed flattening, launcher, dispatcher, and
  minimum lifecycle tests into one atomic chunk; or
- add a preparatory, behavior-preserving path-abstraction chunk, followed by
  one atomic layout-transition chunk.

Decision: _pending_

## 2. Manifest version and layout label

The flat layout is incompatible with the current layout-version-2 structure.
Decide:

- the new root install manifest version;
- whether the profile manifest version also changes;
- whether `shimmy_layout=metadata-tree` remains accurate or receives a new
  value; and
- the exact error and remediation shown when an existing incompatible install
  is encountered.

Decision: **resolved**.

- The root install manifest version is `3`.
- The profile manifest version is also `3`. Although profile directories keep
  their current shape, the profile schema drops the ambiguous global
  `shimmy_layout` field and becomes subject to exact-version validation. The
  two version fields remain independently named so they may diverge in a
  future schema change.
- The root manifest replaces `shimmy_layout=metadata-tree` with the scoped
  field `shimmy_install_layout=flat-root`.
- Profile manifests do not contain a layout label. They describe profile
  metadata, not ownership or placement of the shared install-root assets.
- A missing root manifest is valid only as a fresh-install candidate. If the
  root manifest exists, both its version and layout label must exactly match.
  If a profile manifest exists, its version must exactly match before its
  paths or metadata are consumed. Missing identity fields are incompatible;
  they are not aliases for the current version.
- Root-layout incompatibility must fail before mutation with this message:
  `incompatible Shimmy install layout at <manifest-path> (expected shimmy_install_manifest_version=3 and shimmy_install_layout=flat-root); uninstall it with the Shimmy version that created it, then reinstall`
- Profile-schema incompatibility must fail before mutation with this message:
  `incompatible Shimmy profile manifest at <manifest-path> (expected shimmy_profile_manifest_version=3); uninstall the existing Shimmy installation with the Shimmy version that created it, then reinstall`
- No in-place version-2 migration, compatibility alias, or automatic deletion
  is permitted. Tests must cover version `2`, unknown versions, missing
  identity fields, a wrong root layout label, and a version-3 root paired with
  a non-version-3 profile. Each rejection must prove that existing install
  assets and an unmanaged sentinel remain unchanged.

## 3. Canonical agent skill directory name

`agent/core/` means “core management skills,” not the shared shell-module
directory being renamed. Keeping it is valid but leaves two meanings of
“core”; renaming it affects skill discovery, tests, contexts, plugin copies,
and installed agent assets.

Decision: Retain `agent/core/` unchanged for this refactor and use “core
management skills” when its meaning needs to be explicit. Do not rename it to
`agent/management/` as part of the source `core/` -> `lib/` migration.

Rationale: the repository currently treats `agent/core/` as the canonical
authoring source for management skills, while `commands/skills.sh` exports
those sources to `.agents/skills/` and the plugin bundle. `.agents/skills/` is
the cross-client discovery surface, but the Agent Skills format does not
require it to be the authoring source. The existing trees also contain
pre-existing content differences, so changing canonical ownership or
reconciling copies is a distinct design and migration effort.

Follow-up outside this plan: inventory `agent/core/`, tool-local `agent/`,
`.agents/skills/`, and `plugins/shimmy/skills/`; choose one canonical ownership
model; define generation, collision, and drift checks; then reconcile the
trees deliberately. Until that work is accepted, this plan may update
migration-related `core/...` references in place but must not relocate or
broadly synchronize skill trees.

## 4. Shared-library test directory name

Decide whether `tests/core/` and `test_core_*` names become `tests/lib/` and
`test_lib_*`, or remain a behavioral grouping with documented meaning.

Decision: _pending_

## 5. Installed launcher contract

The target includes both `<install>/shimmy` and `<install>/bin/shimmy`.
Decide whether `bin/shimmy` is:

- a relative symlink to `../shimmy`; or
- a separately installed copy.

Document the authoritative launcher, refresh behavior, uninstall behavior, and
the exact assertions tests must make.

Decision: _pending_

## 6. Installed `.agents/skills` ownership

The current bundled control tree contains a managed `.agents/skills` copy, but
the proposed installed-layout diagram omits it. Decide whether the flat install
continues to contain `<install>/.agents/skills`.

If retained, define whether refresh replaces only manifest-owned `shimmy-*`
skills or the entire directory, and whether final-profile uninstall removes
those assets while preserving unmanaged entries.

Decision: _pending_

## 7. Pre-existing install-root collisions

The flat layout claims common names such as `commands`, `lib`, `tools`,
`tests`, `plugins`, and `agent`. Decide whether installation into a non-empty
custom root:

- refuses conflicting pre-existing paths unless they are proven to be managed
  by the same compatible Shimmy layout; or
- replaces those named paths because the install root is considered wholly
  Shimmy-owned.

Regardless of this decision, unknown paths outside the claimed asset names
must not be recursively deleted.

Decision: _pending_

## 8. Historical plan treatment

Decide whether completed historical plans containing `core/` references should
remain unchanged with an archival notice, or be rewritten to current paths.
Rewriting them may make their historical descriptions inaccurate; leaving them
unchanged requires cleanup searches to allowlist them explicitly.

Decision: _pending_

# Recommended session bootstrap for future AI runs

At the start of each new AI session working on this plan:

1. Read:
   - `<repo>/AGENTS.md`
   - `<repo>/CONTEXT.md`
   - this plan document
   - the relevant chunk’s target files
   - every child `CONTEXT.md` on the path to each changed file

2. Restate:
   - source `core/` becomes `lib/`
   - installed assets are flattened into install root
   - no backward compatibility
   - all resolved decisions recorded under **Unresolved**
   - stop after the current chunk for review

3. Before ending the session:
   - update the Lessons Learned block
   - update the verification checklist
   - summarize remaining open risks
