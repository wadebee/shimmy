# Default Command Help Plan

**Status:** not started

## Objective

Standardize no-argument handling for non-executable Shimmy command groups so
that invoking a group without an action produces the same help text, standard
output, and successful exit status as invoking that group with `--help`.

Success means:

- `shimmy`, `shimmy catalog`, `shimmy images`, `shimmy profile`,
  `shimmy profile redirect`, and `shimmy skills` all treat an omitted required
  action as successful default help;
- the empty and explicit `--help` forms for each group are byte-equivalent;
- group help exits before profile, catalog, registry, or Podman validation and
  performs no mutation;
- unknown actions and malformed requests remain failures;
- valid no-option leaf commands retain their current behavior; and
- the behavior is documented and covered through the existing management and
  profile command test groups.

This is a separate control-surface change that should be implemented and
accepted before `plans/bash-completion.md`. The completion plan consumes the
accepted public command grammar but does not own command dispatch or help
semantics.

Explicit exclusions:

- Do not make every no-argument command print help. Preserve the executable
  defaults of `uninstall`, `netinfo`, `status`, `test`, and `update`.
- Do not change valid no-option actions such as `catalog list`, `catalog
  publish`, `catalog rollback`, installed `images verify`, `profile status`,
  `profile activate`, `profile redirect list`, or the `skills` actions.
- Do not change the missing-required-input failures of `install`, `catalog
  rebind`, or `profile redirect remove`.
- Do not add or remove command names, action names, options, environment
  variables, aliases, manifest fields, or completion candidates.
- Do not add a literal `help` action to `profile` or otherwise normalize help
  token aliases beyond the requested empty-invocation behavior.
- Do not introduce a CLI framework, shared parser rewrite, compatibility
  forwarding, or generated `.agents/skills/` changes.
- Do not implement or edit the Bash-completion plan as part of this work.

## Target layout and terminology

- **Command group** means a command node whose empty invocation has no
  executable operation and exists to select a child action. The current group
  nodes are the root `shimmy` launcher, `catalog`, `images`, `profile`,
  `skills`, and the hybrid `profile redirect` node.
- **Hybrid group** means `profile redirect`: `list` and `remove` are child
  actions, while a first option beginning with `--` selects its documented
  direct upsert form. An empty invocation remains group help and does not imply
  an `upsert` action token.
- **Executable leaf** means a command or action with documented behavior when
  no further option is supplied. Empty leaf invocations continue to execute.
- **Required-input leaf** means a command or action that cannot execute without
  an explicit selector or option. Its empty invocation remains a nonzero usage
  error rather than successful help.
- **Default help** means exact behavioral equivalence to the same command path
  with `--help`: identical stdout, no stderr, exit status `0`, and no command
  validation or mutation after help dispatch.

The target command-node policy is:

| Node type | Empty invocation |
| --- | --- |
| Command group | Print that group's `--help` output and exit `0`. |
| Executable leaf | Execute its documented default operation. |
| Required-input leaf | Retain its focused nonzero validation failure. |

## Recorded design decisions

1. Implement this independently before Bash completion. Completion remains a
   consumer of the resulting command surface; this plan does not modify
   `plans/bash-completion.md` or its implementation.
2. Preserve Shimmy's established success convention for empty groups. The root
   launcher, `catalog`, `images`, and `skills` already make empty invocation
   equivalent to help with status `0`; this plan extends that local convention
   to `profile` and `profile redirect` rather than adopting a framework's
   missing-command status `2` convention.
3. Change only the empty branches in `commands/profile.sh`. Do not add a
   launcher-wide no-argument preflight, because the launcher cannot distinguish
   an executable leaf from a command group and would break existing operations.
4. Dispatch bare `profile` and bare `profile redirect` help before canonical
   profile resolution, registry validation, lock setup, or Podman access, just
   as their explicit `--help` forms do.
5. Remove the synthetic empty `profile redirect` fallback to the internal word
   `upsert`. Direct upsert remains selected only by the documented leading
   option form such as `--prefix`; no public `upsert` action is introduced.
6. Keep invalid named operations and malformed action requests nonzero. In
   particular, `profile unknown`, the unsupported redirect aliases, the
   explicit `profile redirect upsert ...` token, and option validation retain
   their current error behavior.
7. Use direct dispatcher cases rather than adding a shared helper. There are
   only two noncompliant branches in one command file, and the existing groups
   already have suitable local dispatch patterns.
8. Extend existing positive help coverage instead of adding broad tests for
   the absence of alternative behavior. Existing command tests already prove
   executable leaf defaults and required-input failures in their owning
   scenarios.
9. Update public and contributor guidance to define the group-only rule and
   distinguish it from executable and required-input leaves. Documentation
   currently claims all groups already summarize actions when empty, so the
   implementation corrects an existing code/documentation mismatch.
10. No profile schema or migration is required. `commands/profile.sh` is copied
    through the existing staged control-asset lifecycle; fresh installs and
    normal control-plane refreshes receive the accepted implementation.

## Verified implementation inventory

This inventory is the verified planning baseline, not permission to ignore a
newly discovered required dependency during implementation.

- `lib/install/launcher-template.sh` defaults an empty root invocation to
  `help` and dispatches all second-level commands. It must remain unchanged.
- `commands/catalog.sh`, `commands/images.sh`, and `commands/skills.sh` already
  produce successful group help when invoked without an action.
- `commands/profile.sh` currently prints profile usage to stderr, adds
  `ERROR: missing profile operation`, and exits nonzero for bare `profile`.
- The same file recognizes explicit `profile redirect --help` before profile
  validation, but a bare `profile redirect` later defaults its action variable
  to the unrecognized word `upsert`. This produces an unknown-operation error
  rather than redirect help; its nominal empty-action branch is unreachable.
- `commands/profile.sh` also owns valid no-option `profile status`, `profile
  activate`, and `profile redirect list` behavior plus the direct option-form
  redirect upsert. These paths must remain unchanged.
- `lib/install/request.sh`, `lib/netinfo/`, `commands/status.sh`,
  `tests/profile-smoke.sh`, and `lib/update/` own the deliberately different
  empty behavior of top-level leaf commands. They are inspected compatibility
  boundaries, not implementation targets.
- `lib/install/profile-assets.sh` stages the complete `commands/` tree into a
  profile and the existing update lifecycle refreshes those control assets.
  The change does not require a launcher, manifest, or transaction update.
- `tests/commands/management.sh` already compares empty and explicit help for
  the root, `catalog`, `images`, and `skills`, but does not include `profile`
  or `profile redirect` in that equivalence contract.
- `tests/commands/profile.sh` currently classifies bare `profile` as invalid.
  It already covers explicit profile/action help, invalid operations, no-option
  status and activation, redirect CRUD, profile isolation, and lock/mutation
  safeguards.
- `README.md`, `commands/README.md`, and `commands/CONTEXT.md` already state
  that all command groups summarize actions when empty. They need wording that
  makes the exact group/leaf boundary and `--help` equivalence durable.
- `tests/commands/CONTEXT.md` identifies `commands-management` as the owner of
  complete help discovery and `commands-profile` as the owner of profile help
  and rejection behavior.
- `plans/bash-completion.md` explicitly excludes public grammar changes and
  centralizes documented grammar in its future candidate backend. Completing
  this plan first avoids overlapping edits to `tests/commands/management.sh`
  and gives completion a settled baseline; no completion candidate changes are
  implied by default help.
- The worktree was clean when this plan was created, and no existing plan for
  this objective was present in `plans/`.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Make empty profile groups exactly equivalent to explicit help,
  preserve leaf behavior, and verify the public contract.

Active chunk: Chunk 1. Implementation has not been authorized.

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

## Chunk 1 — Default help for profile groups

### Goal

Bring `profile` and `profile redirect` into the existing successful default-help
contract without changing any executable or required-input leaf behavior.

### Files

Primary implementation and tests:

- `commands/profile.sh`
- `tests/commands/management.sh`
- `tests/commands/profile.sh`

Public and contributor guidance:

- `README.md`
- `commands/README.md`
- `commands/CONTEXT.md`
- `tests/commands/CONTEXT.md`

Plan state updated during execution:

- `plans/default-command-help.md`

The file list identifies the verified primary change surface. Implementation
must inspect and include any newly discovered directly required consumer, but
must stop for direction before expanding into completion or unrelated command
parsers.

### Implementation requirements

1. In the initial `commands/profile.sh` dispatch, route an empty operation to
   `profile_usage` on stdout and exit `0`, matching explicit `--help`. Preserve
   the current nonzero unknown-operation and selector rejection paths.
2. In the initial redirect dispatch, route an empty request to
   `profile_redirect_usage` on stdout and exit `0` before resolving or
   validating the installed profile.
3. Normalize the later redirect action selection so an absent argument cannot
   become the nonexistent action word `upsert`. Preserve the leading-`--`
   direct option form and its existing validation, mutation, dry-run, and
   rollback behavior.
4. Do not modify `lib/install/launcher-template.sh` or add a generic
   second-level empty-argument interception. The already-compliant groups and
   all leaf commands retain their current dispatch.
5. In `tests/commands/management.sh`, extend the existing positive equality
   checks into one group contract covering root `shimmy`, `catalog`, `images`,
   `profile`, `profile redirect`, and `skills`. For every path, capture bare and
   explicit `--help` stdout separately, prove byte equality, prove both stderr
   streams are empty, and prove both statuses are `0`. Retain focused action
   discovery assertions, including the existing accepted root `help` alias.
6. In `tests/commands/profile.sh`, remove bare `profile` from the invalid request
   table and cover both empty profile group paths as successful help. Keep the
   existing invalid-operation, unsupported-alias, malformed-input, and
   no-mutation coverage authoritative; do not add duplicative absence tests.
7. Ensure help dispatch remains validation-free and non-mutating. Reuse the
   existing scenario checksums and lock assertions where they prove this
   without adding another profile/bootstrap fixture solely for absence
   coverage.
8. Update `README.md` and `commands/README.md` to state that empty command
   groups are successful `--help` equivalents, while executable and
   required-input leaves retain their documented behavior. Keep the command
   grammar and examples unchanged.
9. Refine `commands/CONTEXT.md` and `tests/commands/CONTEXT.md` so future command
   work preserves the group/leaf distinction and the owning test locations.
10. Do not edit Bash-completion code or its plan. At handoff, state that
    `plans/bash-completion.md` should begin only after this chunk is accepted;
    its candidate inventory is unchanged because no token was added or removed.

### Verification checklist

- [ ] `sh -n commands/profile.sh` passes.
- [ ] `sh -n tests/commands/management.sh` passes.
- [ ] `sh -n tests/commands/profile.sh` passes.
- [ ] `./tests/test.sh --group commands-management --group commands-profile`
  passes using the runner's default bounded parallel execution.
- [ ] Tests prove exact stdout equivalence and status `0` for bare versus
  explicit `--help` at the root, `catalog`, `images`, `profile`, `profile
  redirect`, and `skills` group nodes.
- [ ] Tests prove profile and redirect help is returned before engine,
  registry, or mutating command behavior, reusing existing checksum/lock
  assertions where applicable.
- [ ] Existing positive tests for no-option `profile status`, `profile
  activate`, and `profile redirect list` still pass, while invalid named
  operations and incomplete redirect mutations remain nonzero.
- [ ] Static review confirms no launcher or leaf parser changed, preserving
  no-option `uninstall`, `netinfo`, `status`, `test`, `update`, catalog actions,
  image verification, skills actions, and required-input failures.
- [ ] `README.md`, `commands/README.md`, `commands/CONTEXT.md`, and
  `tests/commands/CONTEXT.md` consistently describe the accepted group/leaf
  policy without advertising a new command or option.
- [ ] `./tests/context-tree.sh` passes after context edits.
- [ ] `git diff --check` passes, and `git diff --summary` shows no unintended
  mode changes.
- [ ] The progress checklist and `Lessons learned` are updated with actual
  verification evidence before review.
- [ ] Human review accepts Chunk 1; implementation does not mark this item
  complete before explicit acceptance.

### Human review gate

Reviewers confirm that the change is limited to the two previously
noncompliant profile group nodes; empty group output and exit status exactly
match explicit help; invalid operations and all leaf defaults remain intact;
documentation states the group-only policy; and Bash completion has not been
implemented or modified. Explicit acceptance completes this plan and permits
the separate Bash-completion plan to use the resulting command baseline.

## Risk register

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Empty handling is added at the launcher rather than the owning group. | Valid no-option commands silently become help, including destructive or operational workflows. | Change only `commands/profile.sh`; statically confirm no launcher or leaf parser diff. |
| Bare help returns success but differs from `--help` output or stream. | Users and scripts receive an inconsistent pseudo-help mode. | Reuse the same usage functions and assert exact captured stdout equality. |
| Help runs after profile or engine validation. | Discovery fails for a damaged or inactive profile and may contact Podman. | Exit from the initial dispatcher before helpers, context resolution, traps, locks, or engine access. |
| Redirect's synthetic `upsert` default survives. | Bare redirect remains an unknown action or future refactoring accidentally exposes an undocumented token. | Remove the default word and select direct upsert only from a documented leading option. |
| Invalid commands accidentally become help. | Typographical errors return success and automation defects are hidden. | Match only an actually empty operation; retain focused invalid-operation tests. |
| Completion implementation overlaps this change. | Parallel plans conflict in management tests or freeze the old behavior as a grammar assumption. | Complete and accept this focused plan first; do not edit completion artifacts here. |
| Documentation continues to imply a global empty-command rule. | Future work applies help semantics to executable leaves. | Define group, hybrid group, executable leaf, and required-input leaf explicitly in public and contributor guidance. |

## Lessons learned

### Initial

- Shimmy already has a local default-help convention at the root and in three
  second-level command groups, including exact output equality tests. The
  smallest consistent change extends that convention rather than adding a new
  abstraction.
- Repository guidance currently claims `profile` provides empty action
  discovery, but the parser treats it as an error. This feature resolves a
  code/documentation inconsistency rather than inventing a new documented
  command shape.
- `profile redirect` is a hybrid group. Its direct upsert syntax begins with an
  option, so treating an empty request as help does not require or justify an
  `upsert` action token.
- No-argument behavior is meaningful at executable leaves. A global
  `empty == --help` rule would break several primary Shimmy workflows and is
  intentionally excluded.
- The Bash-completion plan already forbids command-surface changes. Keeping
  default help separate gives its candidate grammar a stable accepted baseline
  without changing candidate tokens.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`,
   `commands/CONTEXT.md`, `tests/CONTEXT.md`, `tests/commands/CONTEXT.md`, and
   this plan.
2. Read `commands/profile.sh`, `tests/commands/management.sh`, and
   `tests/commands/profile.sh`; inspect the current worktree before editing.
3. Reconfirm the target: only bare `profile` and bare `profile redirect` change
   from errors to exact successful help. All executable and required-input leaf
   semantics remain unchanged.
4. Execute only Chunk 1. Do not edit the launcher, leaf parsers, completion
   implementation, `plans/bash-completion.md`, or generated skill adapters.
5. Run and record every Chunk 1 verification item, update progress and lessons,
   then stop at the human review gate.
