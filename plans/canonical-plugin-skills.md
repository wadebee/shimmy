# Canonical Control-Plane Plugin Refactor

## Objective

Make `plugins/shimmy/skills/` the sole Git-controlled source of truth for the
five Shimmy control-plane skills currently owned by `agent/core/`, while
preserving every tool-specific skill beside its tool at
`tools/<kind>/agent/SKILL.md`.

As part of the same refactor, remove every `CONTEXT.md` below
`plugins/shimmy/` and `tools/`, remove the rules and tests that require those
files, and add a root `BOOTSTRAP.md` that discovers and explains the existing
shimmy public checkout bootstrap whose implementation is at `install.sh`.

Project Repo is not published so backwards compatibility is not required. 

Success requires:

- the canonical Shimmy management plugin to contain exactly the five
  control-plane skills relocated from `agent/core/`;
- all 18 current tool skills to remain canonical and co-located under a flattened 
  path `tools/<kind>/SKILL.md`;
- no `CONTEXT.md` to remain anywhere below `plugins/shimmy/` or `tools/`, and
  no maintained rule, test, template, plan, or skill to instruct future work
  to create one there;
- `commands/skills.sh` to resolve control-plane skills from the plugin and
  tool skills from their co-located tool directories;
- installed profiles to carry the management plugin and tool-local skills
  without a parallel top-level `agent/` tree;
- repository and home `.agents/skills/` targets to retain their current
  one-file adapter and target-manifest ownership semantics; and
- repo root level agent discovery via `AGENTS.md` to route through `BOOTSTRAP.md`, which identifies
  `lib/install/` as the install implementation and the existing root and
  command entrypoints as the supported invocation chain.

Explicit exclusions:

- do not move, copy, or generate tool-specific skills into
  `plugins/shimmy/skills/`; broader tool/plugin skills belongs to a future
  plan;
- do not remove the context system from the repository root, `commands/`,
  `lib/`, or `tests/`; this plan removes it only from `plugins/shimmy/`,
  `tools/`, and the retired `agent/` tree;
- do not add release-artifact discovery, downloading, signature/checksum
  verification, or a no-checkout installation path;
- do not add cross-agent native-plugin registration or a new
  `shimmy skills --scope ...` interface;
- do not change tool runtime behavior, image metadata, profile manifest schema,
  or the jq/rg bootstrap baseline; and
- do not create a compatibility forwarding tree at `agent/core/`.

## Target layout and terminology

`plugins/shimmy/` is the **management plugin**. Its `skills/` directory
canonically owns only these five **control-plane skills**:

- `shimmy-install`
- `shimmy-init`
- `shimmy-create-tool`
- `shimmy-escalation`
- `shimmy-tool-local-build`

A **tool skill** is canonical only at `tools/<kind>/SKILL.md`. Current nested location at `tools/<kind>/agents/SKILL.md` is to be flattened. All other Tool skills are deliberately separated from the management plugin folder structure pending a future
tool-separation design.

`.agents/skills/` below a repository or user home is an **adapter target** and git ignored. It
contains one `SKILL.md` per installed Shimmy skill and is owned by that
target's `.shimmy-skills-manifest.txt`. A portable `--export` remains a copied
artifact, not a canonical source.

The intended source layout is:

~~~text
<repo>/
├── AGENTS.md
├── BOOTSTRAP.md
├── install.sh                         # public checkout bootstrap
├── commands/install.sh                # public management entrypoint
├── lib/install/                       # canonical install implementation
├── plugins/shimmy/
│   ├── .agent-plugin/plugin.json
│   └── skills/
│       ├── shimmy-install/SKILL.md
│       ├── shimmy-init/SKILL.md
│       ├── shimmy-create-tool/SKILL.md
│       ├── shimmy-escalation/SKILL.md
│       └── shimmy-tool-local-build/SKILL.md
├── tools/<kind>/
│   ├── SKILL.md                 # canonical tool-specific skill relocated from flattened agent subdirectory
│   ├── guide.md
│   ├── tool.conf
│   ├── tests/
│   └── versions/
└── .agents/skills/                    # generated one-file adapters
~~~

`AGENTS.md` to be modified to include pointer to `BOOTSTRAP.md` for bootstrapping of library to the end-users workstation. A sample of the new contents shown below but modify as necessary to optimize plan implementation.   
~~~text
## First-time installation

If Shimmy is not installed on this system:

1. Read `BOOTSTRAP.md`.

2. Follow the installation procedure defined there.

3. Do not require the user to clone this repository unless

   explicitly requested.

4. Obtain released Shimmy artifacts from the project's   official distribution location.

5. After installation, install Shimmy's agent skills according

   to the user's selected scope:

   - plugin/native (default if supported by agent harness)

   - repository-local (default if not supported by agent harness)
 
   - user-global (by user flag only)

## Existing installations

If Shimmy is already installed, use the installed Shimmy

skills rather than this bootstrap procedure.

## Canonical skills

The authoritative Shimmy skills are located at:

    plugin/shimmy/skills/

Do not modify generated copies of these skills.
~~~

The installation discovery chain documented by `BOOTSTRAP.md` is:

~~~text
BOOTSTRAP.md
  -> install.sh
~~~

`BOOTSTRAP.md` points agents to `install.sh` as the implementation and
explains the supported public entrypoints. It must not instruct users to source
or execute `lib/install/install.sh` directly.

The following paths do not exist in the target layout:

~~~text
agent/
plugins/shimmy/**/CONTEXT.md
tools/**/agent/*
tools/**/CONTEXT.md
plugins/shimmy/skills/.shimmy-skills-manifest.txt
bootstrap/
~~~

## Recorded design decisions

1. The existing plural path `plugins/shimmy/` is authoritative; the singular
   `plugin/shimmy/` spelling from the supplied discussion is not introduced.
2. The management plugin is intentionally limited to the five skills now under
   `agent/core/`. Tool-specific skills remain co-located and canonical under
   `tools/<kind>/SKILL.md`; implementation must not move or duplicate them.
3. The four existing plugin `SKILL.md` copies become canonical after one final
   semantic comparison with `agent/core/`.
   `shimmy-tool-local-build/SKILL.md` moves from `agent/core/` into the
   plugin. No forwarding files, aliases, symlinks, or lookup fallbacks preserve
   the retired top-level `agent/` tree.
4. All 90 current `CONTEXT.md` files below the two prohibited trees are
   removed: 86 under `tools/` and four under `plugins/shimmy/`. Context files
   under root, `commands/`, `lib/`, and `tests/` remain.
5. `tests/context-tree.sh` continues to validate the retained context
   hierarchy, but no longer traverses or requires contexts under `tools/`,
   `plugins/shimmy/`, or individual skill directories. During Chunk 1 it keeps
   only the explicit root -> `agent/` -> `agent/core/` links needed by the
   intermediate layout; Chunk 2 removes those retired links. It adds a
   regression check that fails if a `CONTEXT.md` is reintroduced under
   `tools/` or `plugins/shimmy/`; its independent tool runtime/config
   completeness assertions remain.
6. The tool-creation skill, generic template, project prompt, tool skills, and
   contributor rules must describe the tool-local `SKILL.md`, guide, metadata,
   tests, versions, and optional container build context without requiring a
   `CONTEXT.md` anywhere in `tools/` or the management plugin. Ordinary uses
   of “context” such as container build context or user/project context remain
   valid.
7. The canonical management plugin is not a manifest-owned generated target.
   Remove its `.shimmy-skills-manifest.txt`, remove `plugin` from the public
   `shimmy skills --target` values, and remove
   `SHIMMY_SKILLS_PLUGIN_DIR`. Requests using `--target plugin` must fail
   during argument validation before mutation.
8. Skill resolution remains intentionally split by ownership:
   control-plane names resolve from `plugins/shimmy/skills/<name>/`, and
   `shimmy-tool-<kind>` names resolve from `tools/<kind>`. Resolution
   must fail closed for unknown names and must not allow a tool skill to shadow
   a control-plane skill.
9. Default selection remains the four entries in `CORE_SKILLS` plus skills for
   kinds in the selected install manifest. `shimmy-tool-local-build` remains
   explicitly selectable but is not added to the default export set.
10. Repository and home adapter targets continue to copy only `SKILL.md`,
    preserve unrelated siblings, and use their own manifest for update and
    uninstall. Portable exports retain the complete selected source directory;
    after context removal, current source skill directories contain only their
    `SKILL.md`.
11. A successful profile refresh removes the retired top-level `agent/`
    directory. Current owned directories and any legacy `agent/` directory are
    backed up within one transaction; failure restores the entire prior layout,
    while success discards the legacy backup. New profile validation no longer
    requires `agent/`, but uninstall continues to remove it when present.
12. Profile manifest version 4 remains unchanged because source placement is a
    replaceable profile payload detail, not a manifest identity change.
13. `BOOTSTRAP.md` documents the existing implementation chain under
    `install.sh`, identifies root `install.sh` as the checkout bootstrap, and
    identifies `commands/install.sh` as a separate shimmy management entrypoint. It covers
    checkout and Podman preconditions, sourced versus executed bootstrap
    behavior, default/upstream profiles, the jq/rg baseline, verification, and
    explicit repo/home adapter installation. It adds no executable logic.
14. `AGENTS.md` remains the universal repository entrypoint and links to
    `BOOTSTRAP.md` for first-time installation and the management plugin for
    control-plane skills.
15. Existing plugin metadata and `.agents/plugins/marketplace.json` remain at
    their current paths. Their wording may be narrowed to management/control
    scope, but their schema and identity are not redesigned.
16. The existing user-owned `.gitignore` modification is outside this plan and
    must be preserved without alteration.

## Verified implementation inventory

This is the verified baseline at commit `e228ad8`, plus the current user-owned
`.gitignore` modification. Implementation must recheck for newly introduced
dependencies before editing.

- `agent/core/` owns the five control-plane skills listed above. Four have
  byte-identical copies in `plugins/shimmy/skills/`;
  `shimmy-tool-local-build` is not yet in the plugin.
- Eighteen `tools/<kind>/agent/` directories each own one tool-specific
  `SKILL.md`: aws, gcloud, gdrive, gh, go, jq, logmine, netcat, nmap, oc,
  opnsense-mcp-admin, opnsense-mcp-read-only, rg, skopeo, task, terraform,
  tessl, and textual. These paths are retained.
- The prohibited context inventory is 90 files: 86 below `tools/` and four
  below `plugins/shimmy/`. The tool count includes root, kind, agent, tests,
  version, and local container `CONTEXT.md` files.
- Context creation/enforcement is present in `tests/context-tree.sh`, root and
  module context links, `AGENTS.md`, `CONTRIBUTING.md`, `README.md`,
  `commands/README.md`, `commands/CONTEXT.md`,
  `lib/catalog/CONTEXT.md`, `tests/CONTEXT.md`,
  `tests/commands/CONTEXT.md`, `docs/testing.md`,
  `docs/prompt-shimmy-project.md`, the generic shim template, the create-tool
  skill, four context-first tool skills, and the still-resumable
  multi-architecture plan.
- The current `./tests/context-tree.sh` baseline exits 1 because it recursively
  requires `agent/core/shimmy-create-tool/CONTEXT.md`, one of four management
  skill contexts already removed at HEAD while `agent/core/CONTEXT.md` still
  links them. Chunk 1 must remove those stale links and leaf-context
  enforcement; it must not recreate the deleted files.
- `plugins/shimmy/skills/` currently has a plugin-target manifest. That file
  fingerprints the four generated management skill directories, including
  their current `CONTEXT.md` payloads.
- `.agents/skills/` is a separate generated adapter containing 20
  manifest-tracked Shimmy skills plus unrelated repository-owned
  skills/resources. It intentionally does not contain logmine, skopeo, or
  tessl, so target selection remains distinct from canonical source inventory.
- `commands/skills.sh` resolves management skills from `agent/core/`, tool
  skills from `tools/<kind>/agent/`, and treats
  `plugins/shimmy/skills/` as a writable plugin target through
  `SHIMMY_SKILLS_PLUGIN_DIR`.
- `lib/install/profile-assets.sh` stages, replaces, and restores both
  top-level `plugins/` and `agent/`. `lib/profile/profile.sh` requires both for
  a valid installed profile, and `lib/install/uninstall.sh` owns removal of
  both.
- `tests/commands/update.sh` builds update fixtures by copying both top-level
  source trees. `tests/commands/skills.sh`,
  `tests/commands/lifecycle.sh`, `tests/commands/install.sh`, and
  `tests/context-tree.sh` encode the current duplicate management layout,
  plugin-target behavior, and tool/plugin context requirements.
- The install call chain is verified as root `install.sh` ->
  `commands/install.sh` -> sourceable `lib/install/install.sh` -> its sibling
  request, manifest, profile-assets, startup, and uninstall modules. Direct
  invocation of `lib/install/install.sh` is not the supported public interface.
- `.github/workflows/test.yml` still watches the retiring `agent/**`; it
  already watches `tools/**` and `plugins/shimmy/**`.
- `plans/multi-architecture-manifest.md` contains future-facing instructions
  that would regenerate plugin copies and recreate tool/plugin contexts if
  left unchanged. Completed historical verification evidence may remain only
  when clearly described as past state.
- The worktree was initially clean. It now contains a user-owned addition of
  `.agents/` to `.gitignore` and this untracked plan; implementation must not
  revert or rewrite the `.gitignore` change.

Primary implementation surface:

- context removal and enforcement:
  `plugins/shimmy/**/CONTEXT.md`, `tools/**/CONTEXT.md`, `tools/**/agent/CONTEXT.md`,
  `tests/context-tree.sh`, root/module contexts, contributor/docs/template
  guidance, the create-tool skill, and affected tool skills;
- control-plane ownership and distribution: `agent/**`,
  `plugins/shimmy/skills/**`, `commands/skills.sh`, and generated
  `.agents/skills/**`;
- profile lifecycle: `lib/install/profile-assets.sh`,
  `lib/install/uninstall.sh`, `lib/profile/profile.sh`, update fixtures,
  lifecycle/skills/profile tests, and retained closest contexts outside the
  prohibited trees;
- bootstrap discovery: `BOOTSTRAP.md`, `AGENTS.md`, `README.md`,
  `install.sh`, `commands/install.sh`, `lib/install/**`, and onboarding tests;
  and
- stale future guidance: `.github/workflows/test.yml`,
  `plans/multi-architecture-manifest.md`, and this plan.

## Unresolved

None.

## Progress Checklist

Active chunk: Chunk 1, not started; awaiting explicit implementation approval.

- [ ] Chunk 1 — Remove tool/plugin contexts and every mechanism that requires
  or prescribes them while preserving tool-local skill ownership.
- [ ] Chunk 2 — Move only the control-plane skills into the canonical
  management plugin, migrate installed profiles, add bootstrap discovery,
  regenerate adapters, and verify the final repository.

## Execution protocol

For every chunk:

1. Read `AGENTS.md`, `CONTEXT.md`, every child context on the path to a changed
   file, this plan, and the chunk's target files.
2. Execute only that chunk's scope.
3. Run its verification checklist and record `[x]`, `[ ]`, or `[~]` with notes.
4. Update the cumulative **Lessons learned** block.
5. Summarize changes, tests, failures, uncertainties, and remaining risks.
6. Stop for human review and explicit acceptance before starting the next
   chunk.

Repository paths in this plan are relative to `<repo>` so it remains portable
across workstations and sessions.

## Chunk 1 — Remove tool and plugin contexts

### Goal

Remove the prohibited context files and their creation/enforcement model while
leaving the current management-source and skill-distribution behavior
operational until the separately reviewed ownership cutover.

### Files

Primary change surface:

- all 86 `tools/**/CONTEXT.md` files and all four
  `plugins/shimmy/**/CONTEXT.md` files;
- `CONTEXT.md`, `agent/CONTEXT.md`, `agent/core/CONTEXT.md`, and retained
  contexts under `commands/`, `lib/`, and `tests/` that link to or prescribe
  the removed files;
- `tests/context-tree.sh`, `tests/lib/catalog.sh`,
  `tests/lib/runtime.sh`, `tests/CONTEXT.md`, and
  `tests/commands/CONTEXT.md`;
- `AGENTS.md`, `CONTRIBUTING.md`, `README.md`,
  `commands/README.md`, `docs/testing.md`,
  `docs/prompt-shimmy-project.md`, and `docs/templates/generic-shim/**`;
- `agent/core/shimmy-create-tool/SKILL.md`,
  `tools/{logmine,oc,skopeo,tessl}/agent/SKILL.md`, any newly discovered
  prescriptive skill references, generated affected adapters, and checked-in
  target fingerprints; and
- future-facing context instructions in
  `plans/multi-architecture-manifest.md`.

### Implementation requirements

1. Delete every `CONTEXT.md` below `tools/` and `plugins/shimmy/`. Do not
   delete or relocate any `tools/<kind>/agent/SKILL.md`, runtime, metadata,
   guide, test, version, container asset, or plugin `SKILL.md`.
2. Narrow `tests/context-tree.sh` to the retained root, `commands/`, `lib/`,
   and `tests/` hierarchy plus explicit links to `agent/CONTEXT.md` and
   `agent/core/CONTEXT.md` for this intermediate state. Stop recursively
   requiring contexts below individual `agent/core/` skills, `tools/`, or the
   plugin; remove the four stale child links instead of recreating already
   deleted management-skill contexts; add an explicit absence check for both
   prohibited trees; and preserve the independent tool version checks for
   executable `run.sh`/`refresh.sh` plus `smoke.conf`/`image.conf`.
3. Remove broken child/related context links and move any still-needed tool
   metadata or operating rules into the established owners: `AGENTS.md`,
   `CONTRIBUTING.md`, tool `guide.md`, tool-local `SKILL.md`, metadata
   schemas/tests, or existing docs. Do not silently discard a unique safety,
   credential, platform, lifecycle, or verification rule solely because its
   context file is deleted.
4. Update the canonical create-tool skill and generic template so new tools
   continue to create a co-located `agent/SKILL.md` but do not create kind,
   agent, test, version, or container `CONTEXT.md` files. Remove
   “context-first” wording where it denotes the deleted file system; retain
   accurate “container build context” and ordinary task-context language.
5. Update tool-local skills that explicitly instruct readers to load deleted
   context files. Preserve their operational guidance and point them to stable
   source files or root contributor guidance only where needed.
6. Update documentation and the active portions of
   `plans/multi-architecture-manifest.md` so no future-facing instruction
   recreates tool/plugin contexts. Preserve clearly labeled historical test
   evidence rather than rewriting past results.
7. Regenerate the four-skill plugin target and only affected
   manifest-tracked `.agents/skills/` adapters from the reviewed current
   canonical sources so this intermediate chunk remains internally consistent.
   Update their fingerprints, preserve unrelated `.agents` content, and do not
   alter the user-owned `.gitignore` change.
8. Re-run broad `CONTEXT.md` and “context-first” searches before the gate.
   Classify retained matches: remaining context infrastructure outside the
   prohibited trees, ordinary language, and historical evidence are allowed;
   prescriptive tool/plugin context creation or lookup is not.

### Verification checklist

- [ ] A filesystem inventory finds zero `CONTEXT.md` below
  `plugins/shimmy/` and zero below `tools/`, while all retained context files
  outside those trees remain linked and valid.
- [ ] All 18 `tools/<kind>/agent/SKILL.md` files remain at their original paths
  with unchanged names; all five current `agent/core/` skills remain available
  for Chunk 2.
- [ ] No tool/plugin template, rule, skill, test, current plan instruction, or
  documentation tells contributors to create or read a prohibited context
  file. Container build-context and ordinary context wording remains accurate.
- [ ] `tests/context-tree.sh` passes, checks the retained context hierarchy,
  rejects a fixture or discovered `CONTEXT.md` under either prohibited tree,
  no longer demands the four already-deleted management-skill contexts, and
  retains tool runtime/config completeness checks.
- [ ] The checked-in plugin-target and repository-adapter manifests match their
  post-removal payloads; semantic parity still uses `agent/core/` for
  management skills and `tools/<kind>/agent/` for tool skills in this
  intermediate state.
- [ ] `./tests/test.sh`, shell syntax checks for changed scripts,
  `git diff --check`, and executable-bit checks pass.
- [ ] Final status for the chunk preserves the user-owned `.gitignore`
  modification and contains only the approved Chunk 1 work plus this plan.

### Human review gate

The reviewer must confirm that:

- tool-local skills were preserved and not moved into the plugin;
- all 90 prohibited context files and all prescriptive/enforcement paths were
  removed without losing material operating or safety guidance;
- retained context validation is limited to allowed repository trees; and
- every `[~]` item has an explicitly accepted disposition.

Do not begin the control-plane ownership cutover until Chunk 1 is explicitly
accepted.

## Chunk 2 — Control-plane plugin cutover and bootstrap

### Goal

Make the five-skill management plugin canonical, retire top-level
`agent/core/` safely in source and installed profiles, preserve co-located
tool-skill export, and add accurate root bootstrap discovery for the existing
`lib/install/` implementation.

### Files

Primary change surface:

- `agent/**`, `plugins/shimmy/skills/**`,
  `plugins/shimmy/.agent-plugin/plugin.json`, and
  `.agents/plugins/marketplace.json`;
- `commands/skills.sh`, `commands/CONTEXT.md`,
  `lib/install/profile-assets.sh`, `lib/install/uninstall.sh`,
  `lib/install/CONTEXT.md`, `lib/profile/profile.sh`, and
  `lib/profile/CONTEXT.md`;
- `tests/commands/skills.sh`, `tests/commands/lifecycle.sh`,
  `tests/commands/install.sh`, `tests/commands/update.sh`,
  `tests/commands/profiles.sh`, `tests/context-tree.sh`, and their retained
  parent contexts;
- `BOOTSTRAP.md`, `AGENTS.md`, `README.md`, `CONTRIBUTING.md`,
  `docs/testing.md`, `docs/prompt-shimmy-project.md`, and affected
  canonical/generated skills;
- `.agents/skills/**`, `.github/workflows/test.yml`, and
  `plans/multi-architecture-manifest.md`.

### Implementation requirements

1. Compare the four duplicate management `SKILL.md` files semantically one
   final time, retain the plugin versions, move only
   `shimmy-tool-local-build/SKILL.md` into the plugin, and remove the retired
   top-level `agent/` tree. The plugin must contain exactly those five
   control-plane skill directories and no tool-specific skills.
2. Change `commands/skills.sh` so explicit control-plane names resolve from
   `plugins/shimmy/skills/` and tool names continue to resolve from
   `tools/<kind>/agent/`. Preserve default management selection,
   installed-kind selection, explicit names, stale target-manifest filtering,
   one-file repo/profile adapters, complete exports, collision checks, and
   manifest-tracked cleanup.
3. Remove the canonical plugin's target manifest, the `plugin` target, and
   `SHIMMY_SKILLS_PLUGIN_DIR` together. Update help, validation,
   documentation, canonical install guidance, and tests. Prove obsolete target
   requests fail before touching plugin, profile, repository, or home state.
4. Refactor profile asset staging so fresh profiles contain `plugins/` and
   tool-local skills within `tools/`, but no top-level `agent/`. Treat an
   existing profile `agent/` as retired schema-owned state inside the same
   backup/restore transaction as current owned directories; restore it after
   any commit failure and discard it only after complete success.
5. Remove top-level `agent/` from new profile-structure requirements and
   self-update source fixtures. Keep legacy `agent/` cleanup in uninstall.
   Cover fresh layout, successful legacy refresh, induced rollback, uninstall
   cleanup, profile isolation, and co-located tool-skill availability.
6. Add root `BOOTSTRAP.md` as a discovery and routing document. Explain the
   verified chain from root `install.sh` through `commands/install.sh` to
   `lib/install/install.sh` and its sibling modules. Direct agents to the
   supported public entrypoint for each use case, not to direct execution of
   the sourceable internal module. Document checkout and Podman prerequisites,
   sourced/executed bootstrap semantics, profiles, jq/rg, verification, and
   explicit repo/home adapter installation.
7. Link `BOOTSTRAP.md` from `AGENTS.md` and `README.md`. Update
   user/contributor wording to distinguish the five-skill management plugin
   from co-located tool skills and generated adapters. Do not introduce a
   bootstrap directory, PowerShell workflow, downloader, or native-plugin
   registration command.
8. Update the plugin description only if necessary to avoid claiming it owns
   the 18 tool-specific skills. Verify the existing marketplace path and
   plugin JSON rather than changing their schema or identity.
9. Correct CI paths and the active future instructions in
   `plans/multi-architecture-manifest.md` so they point to the management
   plugin for control-plane skills and tool-local paths for tool skills. Do not
   revive deleted contexts.
10. Regenerate only manifest-tracked `.agents/skills/` adapters from the
    reviewed split canonical sources. Preserve unrelated `.agents` content,
    keep every adapter to one `SKILL.md`, update fingerprints, and do not
    generate into the canonical management plugin.
11. Before the review gate, run repository-wide path and terminology
    inventories. Remove stale behavioral references to `agent/core/`,
    writable/generated plugin skills, or tool/plugin `CONTEXT.md` while
    retaining accurate uses of AI agent, `.agents/skills/`, container build
    contexts, and explicit legacy migration tests.

### Verification checklist

- [ ] The management plugin contains exactly five skill directories with
  matching `name:` frontmatter, each containing `SKILL.md` and no
  `CONTEXT.md`; plugin discovery exposes those five and no tool-specific
  skills.
- [ ] All 18 tool-specific skills remain at
  `tools/<kind>/agent/SKILL.md`, and every catalog kind resolves and exports
  its co-located skill, including both hyphenated OPNsense kinds.
- [ ] `agent/`, `plugins/shimmy/skills/.shimmy-skills-manifest.txt`, every
  `plugins/shimmy/**/CONTEXT.md`, and every `tools/**/CONTEXT.md` are absent,
  with no maintained path capable of recreating them.
- [ ] Skills command success cases cover control-plane, local-build, and every
  tool skill; default and installed-kind selection remain unchanged;
  repo/profile adapters contain only `SKILL.md`; exports and unrelated target
  siblings remain correct.
- [ ] `--target plugin` is absent from help and install/update/uninstall
  requests using it fail before mutation. `SHIMMY_SKILLS_PLUGIN_DIR` no longer
  affects valid behavior.
- [ ] Fresh default and upstream profiles contain the five-skill plugin and all
  co-located tool source skills, contain no top-level `agent/`, pass structure
  validation, and remain isolated from external adapter targets.
- [ ] A fixture shaped like the current profile loses its legacy `agent/` only
  after successful refresh; an induced commit failure restores it and every
  other backed-up owned asset; uninstall removes it when present.
- [ ] `BOOTSTRAP.md` is linked from `AGENTS.md` and `README.md`, names
  `lib/install/` as the implementation, accurately maps the public entrypoints
  to it, matches onboarding tests, and contains no second installer, bootstrap
  subdirectory, PowerShell workflow, or direct internal invocation.
- [ ] Plugin metadata parses as JSON and the marketplace still resolves
  `./plugins/shimmy` with management-only skill discovery.
- [ ] Checked-in repository-adapter fingerprints match generated files,
  semantic comparisons use the plugin for control-plane skills and tool-local
  sources for tool skills, and unrelated `.agents` content remains intact.
- [ ] `./tests/context-tree.sh` and the complete `./tests/test.sh` suite pass.
- [ ] Every changed runnable shell file passes `/bin/sh -n`; executable bits
  remain correct; `git diff --check` passes; and final status preserves the
  user-owned `.gitignore` modification.

### Human review gate

The reviewer must confirm all verification states and explicitly accept:

- the five-skill limit of the canonical management plugin;
- continued canonical ownership of tool skills under
  `tools/<kind>/agent/SKILL.md`;
- removal, rather than deprecation, of `--target plugin` and
  `SHIMMY_SKILLS_PLUGIN_DIR`;
- transactional deletion of legacy installed-profile `agent/` payloads;
- the `lib/install/` implementation routing documented by root
  `BOOTSTRAP.md`; and
- the disposition of every `[~]` item surfaced in the review report.

No later implementation chunk exists. Do not mark the plan complete until the
reviewer accepts the verified repository state.

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| Tool skills are moved into the management plugin despite the clarified boundary. | The future tool-separation model is preempted and management/tool ownership is coupled. | Move only the five `agent/core/` skills and assert all 18 tool skill paths remain intact after each chunk. |
| Context files are deleted without preserving unique operating rules. | Safety, credentials, platform, or lifecycle knowledge is lost. | Classify content before deletion and migrate durable rules into AGENTS, contributor docs, guides, skills, schemas, or tests according to ownership. |
| A template, test, historical plan, or context link recreates prohibited files. | The removed context topology returns in later changes. | Remove all prescriptive references, add absence checks, and search future-facing guidance at both gates. |
| The old `--target plugin` writes into or uninstalls the new canonical source. | Canonical control-plane skills can be deleted or self-copied. | Remove the target, environment override, target manifest, docs, and forwarding paths together; assert rejection before mutation. |
| Refresh deletes legacy profile `agent/` before another commit step fails. | A failed update leaves the prior profile incomplete under its old validator. | Back up the retired tree in the same replace/restore transaction and discard it only after full success. |
| Split source resolution allows name collision or breaks hyphenated tool kinds. | Wrong guidance is exported or installed kinds lose their skills. | Resolve the explicit control-plane set first, map tool names only through validated catalog kinds, fail closed, and test every kind. |
| Adapter regeneration overwrites richer guidance or unrelated `.agents` content. | Documentation or user-owned files are lost. | Review canonical sources first, regenerate only manifest-tracked names, verify parity and unknown-sibling preservation, and preserve `.gitignore`. |
| `BOOTSTRAP.md` tells users to run the internal sourceable module directly. | Initialization, argument setup, or cleanup contracts are bypassed. | Document the complete chain, name `lib/install/` as implementation, and route actual invocation through root or command entrypoints. |
| Plugin metadata is changed incidentally. | Existing marketplace discovery regresses for an unrelated reason. | Keep schema, path, and identity unchanged; make only scope wording changes proven necessary by validation. |

## Lessons learned

### Initial

- The clarified architecture intentionally has two kinds of canonical skill
  ownership: five management/control skills in the Shimmy plugin and each tool
  skill beside its tool.
- The prior draft incorrectly treated “one canonical plugin tree” as applying
  to tool-specific skills; the supplied future direction makes the plugin a
  control-plane boundary instead.
- Context removal affects 90 files and multiple producers, not only the four
  current plugin copies. Removing files without removing creation rules would
  be temporary.
- The writable plugin target becomes unsafe and circular when the management
  plugin becomes canonical source.
- Installed top-level `agent/` is part of the current profile validity
  contract, so removal requires a rollback-safe installed-state migration.
- Installation is implemented in `lib/install/`, reached through
  `commands/install.sh` and the root checkout bootstrap. Discovery should
  expose that ownership chain without bypassing the public entrypoints.
- The current `.gitignore` change is user-owned and outside this plan.

## Session bootstrap

A fresh implementation session must:

1. Read `AGENTS.md`, root `CONTEXT.md`, `CONTRIBUTING.md`, this entire plan,
   and the currently applicable retained contexts for the active chunk. Before
   deleting current tool/plugin contexts in Chunk 1, read and classify them for
   unique durable rules.
2. Re-run the context and skill inventories; preserve the user-owned
   `.gitignore` modification and any other unrelated worktree changes.
3. Keep the ownership boundary fixed: five control-plane skills in
   `plugins/shimmy/skills/`, 18 tool skills at
   `tools/<kind>/agent/SKILL.md`, and generated adapters under
   `.agents/skills/`.
4. Treat `plugins/shimmy/**/CONTEXT.md` and `tools/**/CONTEXT.md` as prohibited
   final state, but retain the context system outside those trees.
5. Treat root `install.sh` and `commands/install.sh` as public entrypoints into
   the implementation under `lib/install/`; do not instruct direct execution
   of the internal sourceable module.
6. Execute only the active chunk, update the cumulative checklist and
   **Lessons learned**, report every partial verification item explicitly, and
   stop at that chunk's human review gate.
