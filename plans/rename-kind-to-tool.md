# Rename tool kind to tool

## Objective

Replace Shimmy's domain term **kind** with **tool** for the stable catalog and
installation unit represented by commands such as `jq`, `rg`, and `oc`.
Success means contributor guidance, CLI text, internal shell APIs, persisted
profile state, machine-readable output, tests, and canonical skills all use one
coherent vocabulary without weakening manifest validation or profile rollback.

This change does not rename the `tools/` directory, `tool.conf`, `--shim`,
concrete version labels, runtime names such as `oc_4_20`, or generated
`.agents/skills/` adapters. It does not mechanically change unrelated uses of
English `kind`, including virtualization classification in `lib/netinfo/`, the
sample host slug validator, or references to the Kubernetes `kind` CLI.

## Target layout and terminology

- **Tool**: a stable catalog and installation unit with a public command, such
  as `jq` or `oc`. It lives at `tools/<tool>/tool.conf`.
- **Tool version**: a selectable concrete implementation of a tool, addressed
  as `<tool>@<version-label>` and implemented at
  `tools/<tool>/versions/<version-label>/run.sh`.
- **Runtime**: the version-owned executable implementation and its image,
  mounts, credentials, and refresh behavior.
- **Shim**: an executable wrapper exposed to the shell or stored in an
  installed profile. The existing `--shim` option continues to select the shim
  for a tool or exact tool version.
- **Dispatcher**: the public tool shim that resolves the selected tool version.

Target persisted records:

```text
shimmy_install_manifest_version=1
shimmy_profile_manifest_version=1
tool=oc
tool_version=oc|default|oc_4_20
tool_version=oc|4.20|oc_4_20
```

Target status records:

```text
shimmy_profile_tool=oc
shimmy_profile_tool_version=oc|4.20|oc_4_20
shimmy_available_tool=jq
```

Representative internal names become `tool_name`, `shimmy_tool_exists`,
`shimmy_tool_list`, `shimmy_tool_version_default`,
`shimmy_tool_version_label_list`, `shimmy_tool_version_label_resolve`,
`shimmy_manifest_tool_list_read`, `tool_version_entry`, and
`PROFILE_MANIFEST_TOOLS`.

## Recorded design decisions

1. Use `tool`, not `tool kind`, as the stable domain noun. The repository
   already uses `tools/` and `tool.conf`, so this removes vocabulary rather
   than introducing another synonym. It also avoids the eventual phrase
   “tool kind `kind`” if the Kubernetes `kind` CLI is added.
2. Apply the rename through all active semantic interfaces. Keeping legacy
   names internally or in current manifests would make the terminology split
   permanent and future work would continue to reproduce it.
3. Reset both manifest identities to schema version 1. This repository has no
   published manifest compatibility contract or earlier supported formats, so
   the refactor establishes a clean baseline rather than describing the
   repository's internal iteration count as four prior public schemas.
4. Version 1 accepts only `tool=` and `tool_version=`. Do not add a migration,
   dual-schema reader, compatibility alias, or support for the current
   version-4 identity and `kind=` fields. Existing development profiles must be
   recreated from the clean baseline.
5. Keep `--shim` in this change. The flag describes the installed wrapper and
   renaming it to `--tool` is a separate CLI design change, not required to
   remove `kind`.
6. Do not add compatibility function aliases or accept legacy status keys.
   Internal helpers are not public API, and manifest-format status is an
   explicitly version-sensitive machine interface that should move coherently
   with the profile schema.
7. For every function and variable already refactored by this terminology
   change, order semantic segments from general to specific. Prefer names such
   as `shimmy_tool_version` and `shimmy_tool_version_default`; do not introduce
   inverted forms such as `shimmy_version_tool` or
   `shimmy_tool_default_version`. Apply this as ancillary naming guidance only:
   update the convention in contributor guidance, but do not expand the code
   change into unrelated functions or variables merely to enforce it globally.
   Existing names outside the required refactor may remain until their code is
   otherwise changed.
8. Update the active `plans/tool_grouping.md` terminology because it remains
   product brainstorming. Preserve completed historical plans as historical
   evidence rather than mechanically rewriting them.
9. Reconcile, do not overwrite, the existing user edit in
   `commands/README.md` when implementation is authorized.

## Verified implementation inventory

The planning search found 698 case-insensitive `kind` matches across 66 files
outside `plans/`. Not all are part of this rename. The verified semantic change
surface is:

- Catalog and dispatch: `lib/catalog/catalog.sh`, `commands/run-tool.sh`, and
  `commands/dispatch-tool.sh`.
- Profile schema and common readers: `lib/profile/profile.sh`,
  `lib/common/common.sh`, and `lib/install/manifest.sh`.
- Install, uninstall, and staged assets: `install.sh`, `lib/install/install.sh`,
  `lib/install/request.sh`, `lib/install/profile-assets.sh`, and
  `lib/install/uninstall.sh`.
- Management consumers: `commands/status.sh`, `commands/skills.sh`,
  `commands/agent-preflight.sh`, `commands/images.sh`, `lib/images/images.sh`,
  and `lib/update/*.sh`.
- Behavioral contracts: `tests/profile-smoke.sh`, `tests/lib/catalog.sh`, and
  affected `tests/commands/*.sh`, especially onboarding, lifecycle, profiles,
  status, skills, images, and update.
- Current guidance: `AGENTS.md`, `CONTRIBUTING.md`, `BOOTSTRAP.md`, `README.md`,
  `commands/README.md`, applicable `CONTEXT.md` files, `docs/podman.md`,
  `docs/testing.md`, `docs/prompt-shimmy-project.md`, generic templates,
  canonical management skills under `plugins/shimmy/skills/`, affected
  tool-local skills/guides, and active `plans/tool_grouping.md`.

Implementation must repeat the inventory after edits and classify every
remaining match. Expected exclusions include `virtual_kind` in
`lib/netinfo/platform.sh`, the generic `kind` parameter in
`samples/host/internal/hostconfig/config.go`, completed historical plans, and
literal references to the Kubernetes `kind` tool.

## Unresolved

None.

## Progress Checklist

- [x] Chunk 1 — Establish the clean terminology and schema baseline

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

## Chunk 1 — Clean terminology and schema baseline

### Goal

Move the complete active repository contract from `kind` to `tool` and reset
the unpublished manifest format to a strict version-1 baseline.
This remains one chunk because splitting producers, consumers, validators, or
owned-state paths would leave an incoherent format transition.

### Files

All files in the verified implementation inventory. Generated adapters under
`.agents/skills/` are explicitly excluded. The existing modification to
`commands/README.md` must be preserved and amended in place.

### Implementation requirements

1. Rename semantic shell functions, variables, comments, errors, help text,
   placeholders, and test names from kind-based to tool-based forms. Follow the
   repository naming conventions, apply general-to-specific segmentation to
   names this refactor already touches, and keep functions alphabetically
   ordered where required. Update the naming guidance to record this
   general-to-specific rule while explicitly allowing unrelated legacy names
   to remain. Do not broaden the refactor solely to rename them.
2. Change current profile ownership records to `tool=` and `tool_version=`,
   reset both manifest identities to version 1, and update strict validation,
   rendering, readers, status output, skills selection, dispatch ownership,
   update selection, image selection, and uninstall ownership together.
3. Remove the current version-4 identity and kind-based schema completely.
   Do not implement upgrade, migration, compatibility, or mixed-schema paths.
4. Ensure fresh installs emit only version-1 tool-based fields. Ensure
   malformed, mixed, duplicate, contradictory, unsafe, unknown, or non-version-1
   records fail before mutation.
5. Preserve all current tool/version behavior, public command names,
   selectors, version labels, concrete runtime names, images, and `--shim`
   request syntax.
6. Update canonical guidance and active planning vocabulary. Do not edit
   generated skill copies. Classify remaining matches instead of performing a
   blind repository-wide substitution.
7. Update the plan progress and lessons before the review gate.

### Verification checklist

- [x] Fresh default and upstream profiles render valid version-1 manifests
  containing `tool=`/`tool_version=` and no legacy ownership keys.
- [x] Version-4 manifests and `kind=`/`kind_version=` records are unsupported;
  no migration or compatibility reader exists.
- [x] Strict version-1 consumers reject non-version-1, mixed-schema, duplicate,
  contradictory, unsafe, malformed, and unknown ownership records before
  mutation.
- [x] Install, dispatch, status human/manifest output, skills selection,
  images, test selection, update, and uninstall retain their existing behavior
  under the new vocabulary.
- [x] `shimmy status --format manifest` emits only the new tool-based keys, and
  tests assert that legacy status keys are absent.
- [x] Catalog and command tests use only tool-based helper and variable names;
  no compatibility aliases remain.
- [x] A repository terminology scan shows no active semantic `kind` uses;
  every remaining match is documented as an intentional exclusion.
- [x] Shell syntax checks, the default offline suite, affected focused suites,
  and live non-mutating Podman smoke checks pass as required by repository
  guidance.
- [x] `git diff --check` passes, executable bits are preserved, and the
  pre-existing `commands/README.md` work remains present.

### Human review gate

Confirm that the tool/version/runtime/shim vocabulary is clearer, the clean
version-1 schema is internally coherent, touched names follow
general-to-specific segmentation, and all remaining `kind` uses were
explicitly classified. Do not begin unrelated renames, compatibility work, or
grouping work without a new approval.

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| Treating the work as a text substitution | Unrelated meanings change while hidden producers or consumers retain the old schema | Use the verified inventory, classify all residual matches, and test behavior rather than match count alone. |
| Development profiles still use the unpublished version-4 format | New code correctly rejects them | Document that development profiles must be removed with their current installation or recreated; do not add compatibility code. |
| Version-4 or kind-based compatibility survives accidentally | The intended clean baseline remains internally split | Assert that version-1 producers and consumers reject non-version-1 and legacy ownership fields, and scan for active legacy schema names. |
| Naming cleanup expands across unrelated code | Scope and regression risk grow without helping the terminology objective | Apply general-to-specific segmentation only to names already changed by this refactor; update guidance for future touched code. |
| Machine consumers rely on status `kind` keys | Automation breaks silently | Treat status as an explicit breaking interface, change it with the schema, document it, and fail tests on legacy output. |
| Existing user documentation work is overwritten | Unrelated work is lost | Re-read and merge the dirty `commands/README.md` immediately before editing; verify its original additions remain. |
| Historical plans are rewritten indiscriminately | Project history becomes misleading | Update only active brainstorming and leave completed plans intact. |

## Lessons learned

### Initial

- `kind` is a real schema and API identity, not only contributor prose.
- The existing repository already supplies the clearer noun through `tools/`
  and `tool.conf`; the rename consolidates vocabulary.
- Manifest validation is intentionally strict. Because the format is
  unpublished, this refactor can reset it to version 1 and remove the false
  implication of three historical compatibility contracts.
- The requested naming direction is general to specific. Apply it to names
  already touched by this refactor without turning the work into a global
  naming cleanup.
- The active grouping exploration makes the current term especially awkward
  because Kubernetes has a CLI literally named `kind`.
- Some `kind` matches belong to virtualization detection, sample code, or
  historical records and must remain unchanged.

### Chunk 1

- Manifest identity checks exist in both the shared profile validator and the
  generated launcher template; changing only one produces fresh profiles that
  their own installed launcher rejects.
- Canonical skill guidance is packaged into fresh profiles, while checked-in
  `.agents/skills/` adapters remain separately generated state. Verification
  now checks canonical-to-profile payload parity without editing those adapters.
- The remaining active-tree `kind` matches are intentional: virtualization
  classification, a generic sample slug parameter, shim-source classification,
  and negative assertions or fixtures proving legacy schema/status keys fail.
- The complete offline suite passes all 103 tests, and a live Apple Silicon
  Podman smoke reports `jq-1.8.1` through the source dispatcher.

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, every applicable child
context, this entire plan, and all target files. Re-run `git status --short` and
the terminology inventory before editing. The target is a strict version-1
tool/tool-version schema with no migration or backward-compatibility path;
apply general-to-specific segmentation to names already in scope. Do not rename
`--shim`, rewrite POSIX shell architecture, edit generated
`.agents/skills/`, overwrite user changes, or begin grouping work. Chunk 1 is
complete and verified; stop at the human review gate.
