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

## Naming model

- `lib/` = shared shell modules
- install root = installed control/runtime root
- no separate installed `core/` bundle
- remove `SHIMMY_*CORE*` variables and replace them with names that reflect the flattened layout

# Human-in-the-loop execution model

Each chunk below is intended to be run in a separate or reusable AI session.

For **every chunk**:

1. Read the chunk header and its listed files first.
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

# Chunked implementation plan

## Chunk 1 — Source-tree rename and internal module path conversion

### Goal

Rename repo `core/` to `lib/` and update direct source-tree references without yet finishing the installed-layout flattening behavior.

### Why first

This establishes the new conceptual model for maintainers and reduces ambiguity in subsequent chunks.

### Files to modify

### Rename directory

- `/home/beewa/repos/GitHub/wadebee/shimmy/core` -> `/home/beewa/repos/GitHub/wadebee/shimmy/lib`

### Update command entrypoints

- `/home/beewa/repos/GitHub/wadebee/shimmy/commands/activate.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/commands/agent-preflight.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/commands/install.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/commands/netinfo.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/commands/status.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/commands/update.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/commands/skills.sh`

### Update moved library files for self-references and shellcheck paths

- all files currently under `<repo>/core/**/*.sh`, after rename under `<repo>/lib/**/*.sh`

### Update repo launcher and any root-level helpers that reference `core/`

- `/home/beewa/repos/GitHub/wadebee/shimmy/shimmy`

### Update tool runtime references to shared runtime helpers

Representative set; in practice all matching files:

- all `tools/*/versions/*/run.sh`
- all `tools/*/versions/*/refresh.sh`

### Update tests that source repo `core/`

- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/test.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/support.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/core/catalog.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/core/runtime.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/core/update.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/context-tree.sh`

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

- `/home/beewa/repos/GitHub/wadebee/shimmy/lib/profile/profile.sh`

### Install request wiring

- `/home/beewa/repos/GitHub/wadebee/shimmy/lib/install/request.sh`

### Installer asset copy logic

- `/home/beewa/repos/GitHub/wadebee/shimmy/lib/install/profile-assets.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/lib/install/install.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/lib/install/uninstall.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/lib/install/manifest.sh`

### Installed launcher

- `/home/beewa/repos/GitHub/wadebee/shimmy/shimmy`

### Dispatcher

- `/home/beewa/repos/GitHub/wadebee/shimmy/commands/dispatch-tool.sh`

### Update installed-layout detection

- `/home/beewa/repos/GitHub/wadebee/shimmy/lib/update/management.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/lib/update/refresh.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/lib/update/update.sh`

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

### Deliverable

A fresh install produces the flattened layout with no `core/` subtree.

### Human review gate

Confirm:

- the resulting install tree is easy to understand
- no accidental path collisions were introduced at install root
- manifest semantics still make sense

## Chunk 3 — Tests and verification harness rewrite

### Goal

Update all tests and test infrastructure to validate the new `lib/` source layout and flattened install layout.

### Files to modify

### Command/install lifecycle tests

- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/install.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/lifecycle.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/update.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/test.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/profiles.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/dispatcher.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/management.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/skills.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/startup.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/netinfo.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/commands/agent-preflight.sh`

### Shared/core-now-lib tests

- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/core/catalog.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/core/runtime.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/core/update.sh`
- consider whether `tests/core/` should itself be renamed to `tests/lib/` for consistency

### Test runner and support

- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/test.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/support.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/context-tree.sh`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/profile-smoke.sh`

### Specific implementation intent

- replace installed assertions such as `$INSTALL_DIR/core/tools/...` with `$INSTALL_DIR/tools/...`
- update any env vars or helper names referencing `CORE`
- decide whether test directories named `tests/core/` should be renamed or kept as behavioral grouping; document the choice explicitly in this chunk summary

### Deliverable

Test suite validates the new model instead of preserving old assumptions.

### Human review gate

Confirm:

- test names still make sense
- expected install tree in tests matches agreed flattened design
- no tests silently retain legacy path assertions

## Chunk 4 — Documentation, contexts, and skills rewrite

### Goal

Update all maintainer-facing and AI-facing documentation to the new terminology and layout.

### Files to modify

### Root and contribution docs

- `/home/beewa/repos/GitHub/wadebee/shimmy/CONTEXT.md`
- `/home/beewa/repos/GitHub/wadebee/shimmy/CONTRIBUTING.md`
- `/home/beewa/repos/GitHub/wadebee/shimmy/AGENTS.md`

### Context files

- `/home/beewa/repos/GitHub/wadebee/shimmy/commands/CONTEXT.md`
- `/home/beewa/repos/GitHub/wadebee/shimmy/tests/CONTEXT.md`
- all context files currently under `<repo>/core/**/CONTEXT.md`, after rename under `<repo>/lib/**/CONTEXT.md`

### AI/skill guidance

- `/home/beewa/repos/GitHub/wadebee/shimmy/.agents/skills/shimmy-create-tool/SKILL.md`
- `/home/beewa/repos/GitHub/wadebee/shimmy/plugins/shimmy/skills/shimmy-create-tool/SKILL.md`
- `/home/beewa/repos/GitHub/wadebee/shimmy/agent/core/shimmy-create-tool/SKILL.md`
- `/home/beewa/repos/GitHub/wadebee/shimmy/agent/core/shimmy-create-tool/CONTEXT.md`
- `/home/beewa/repos/GitHub/wadebee/shimmy/agent/core/shimmy-tool-local-build/SKILL.md`
- any tool skill docs that mention `core/`

### Other docs and plans with hardcoded `core/`

- `/home/beewa/repos/GitHub/wadebee/shimmy/docs/prompt-shimmy-project.md`
- `/home/beewa/repos/GitHub/wadebee/shimmy/docs/testing.md`
- `/home/beewa/repos/GitHub/wadebee/shimmy/docs/templates/generic-shim/SKILL.md`
- plan/history docs that are intended to remain accurate:
  - `/home/beewa/repos/GitHub/wadebee/shimmy/plans/context.md`
  - `/home/beewa/repos/GitHub/wadebee/shimmy/plans/context_remaining.md`
  - `/home/beewa/repos/GitHub/wadebee/shimmy/plans/multi-architecture-manifest.md`

### Specific implementation intent

- replace “shared core” with “shared library” or equivalent accurate phrasing
- update path examples from `core/...` to `lib/...`
- update install layout descriptions from `<install>/core/...` to flat install-root examples
- ensure context-tree references point to renamed directories

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
- [ ] `grep` confirms no unintended source-tree `core/...` references remain
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
- Notes:

## Chunk 3 verification

- [ ] Command tests updated for flat install layout
- [ ] Shared-library tests updated for `lib/...`
- [ ] Context-tree tests pass with renamed source directory
- [ ] Profile smoke behavior still works
- [ ] No tests assert old installed paths
- Notes:

## Chunk 4 verification

- [ ] Root docs describe `lib/` accurately
- [ ] Context files reference `lib/` accurately
- [ ] AI skill docs no longer advise `core/` paths
- [ ] Any persistent historical plan docs were either updated or intentionally left as historical artifacts with justification
- Notes:

## Chunk 5 verification

- [ ] Full repo search shows no unintended `core/core` references
- [ ] Full repo search shows no unintended `SHIMMY_*CORE*` variable names
- [ ] Fresh install works
- [ ] `shimmy activate` works
- [ ] Installed shim dispatch works
- [ ] `shimmy update` works for a fresh install
- [ ] `shimmy uninstall` works
- [ ] Full relevant test suite passes
- Notes:

## Suggested commands to run during verification

Adjust as needed per chunk:

- [ ] `./shimmy test`
- [ ] disposable install with `./shimmy install --install-dir <tmpdir> --no-startup --no-skills`
- [ ] inspect install tree with `ls`
- [ ] `./shimmy activate --install-dir <tmpdir>`
- [ ] installed command smoke check from `<tmpdir>/bin/<shim> --version`
- [ ] `./shimmy update --install-dir <tmpdir>`
- [ ] `./shimmy uninstall --install-dir <tmpdir> --profile default`
- Notes:

# Risk callouts

## High risk

1. **Installed launcher path resolution**
   - If `shimmy` root detection is wrong, every installed command path becomes unreliable.

2. **Dispatcher recursion or broken symlink targets**
   - The dispatcher currently protects against recursion and assumes specific central paths.

3. **Update/self-update detection**
   - Installed-management detection is tightly coupled to current layout and can silently misclassify environments if partially updated.

4. **Tool runtime helper paths**
   - Many versioned tool runtimes hardcode `core/runtime/...`; missing even one will create fragmented failures.

## Medium risk

5. **Context-tree and shellcheck source comments**
   - These are easy to miss and can create noisy failures late in the process.

6. **Test naming and folder semantics**
   - `tests/core/` may become misleading once source `core/` is gone. Decide explicitly whether to rename it or document it as a legacy grouping.

7. **Manifest semantics**
   - Install manifests may still be valid structurally, but any path keys written into them must reflect the new layout.

## Low risk

8. **Contributor/skill docs drift**
   - Easy to fix, but if skipped, future AI sessions will reintroduce stale assumptions.

# Recommended session bootstrap for future AI runs

At the start of each new AI session working on this plan:

1. Read:
   - `/home/beewa/repos/GitHub/wadebee/shimmy/AGENTS.md`
   - `/home/beewa/repos/GitHub/wadebee/shimmy/CONTEXT.md`
   - this plan document
   - the relevant chunk’s target files

2. Restate:
   - source `core/` becomes `lib/`
   - installed assets are flattened into install root
   - no backward compatibility
   - stop after the current chunk for review

3. Before ending the session:
   - update the Lessons Learned block
   - update the verification checklist
   - summarize remaining open risks
