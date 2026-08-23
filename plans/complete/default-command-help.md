# Default Command Help Plan

Completed: 2026-08-22

## Objective

Make the installed launcher's existing no-argument help behavior an
explicit, durable public contract. Invoking the root, any public command group,
or the `profile redirect` subgroup without a child command must be exactly
equivalent to invoking that path with `--help`: identical stdout, empty stderr,
status `0`, no installed-state validation, and no mutation.

It closes the remaining contract gap by strengthening observable
stream/status assertions and documenting empty-invocation equivalence.

Success means:

- `shimmy`, `shimmy admin`, `shimmy profile`, `shimmy catalog`, `shimmy shim`,
  `shimmy ai-skill`, and `shimmy profile redirect` have byte-equivalent bare and
  explicit `--help` results;
- help continues to render before manifest, profile, catalog, registry, lock,
  or Podman validation;
- named actions retain the exact grammar and defaults established by the
  redesign; and
- public and contributor guidance state the launcher-owned group/subgroup rule
  without implying that executable or required-input actions default to help.

This work should be accepted before implementation of
`plans/wip/bash-completion.md`. That plan consumes the settled public grammar,
overlaps `tests/commands/surface.sh`, and still requires its own rebase from the
pre-redesign command inventory; this plan does not perform that rebase.

Explicit exclusions:

- Do not add, remove, rename, or alias commands, actions, options, environment
  variables, manifest fields, or completion candidates.
- Do not change action defaults, including no-option list, status, sync,
  repair, verify, publish, rollback, test, network, or uninstall operations.
- Do not convert missing required inputs for create, activate, delete, redirect
  mutation, or shim mutation actions into successful help.
- Do not move help dispatch into individual handlers, add compatibility
  forwarding, alter profile schema, or edit generated `.agents/skills/` content.

## Target layout and terminology

- **Launcher help node** means a public command path that selects children but
  performs no operation itself: root `shimmy`; groups `admin`, `profile`,
  `catalog`, `shim`, and `ai-skill`; and subgroup `profile redirect`.
- **Action** means a leaf in the redesigned public grammar. It either executes
  with documented defaults or rejects missing required input.
- **Default help** means exact equivalence to the same launcher path with
  `--help`: identical stdout, empty stderr, status `0`, and dispatch before
  installed-state validation.
- **State-independent help** means help remains available with an invalid
  installed profile manifest. It does not let normal actions bypass validation.

| Node type | Empty invocation |
| --- | --- |
| Root/group/subgroup launcher help node | Render that node's `--help` output and exit `0`. |
| Action with documented defaults | Execute those defaults. |
| Action with required input | Retain its focused nonzero validation error. |

## Recorded design decisions

1. Treat `plans/complete/redesign-control-surface.md` as the authoritative
   public grammar and architecture baseline.
2. Keep default-help routing in `lib/install/launcher-template.sh`. It already
   recognizes all target nodes before manifest validation and delegates to the
   installed `commands/help.sh` renderer.
3. Do not change `commands/profile.sh` merely to make direct source-entrypoint
   calls mirror launcher behavior. Public acceptance uses the installed
   launcher; direct handler calls remain parser or transaction seams.
4. Preserve the existing root, group, and subgroup `help`, `-h`, and `--help`
   forms. This plan adds no alias.
5. Extend `tests/commands/surface.sh`, the redesigned owner of complete help
   discovery, rather than recreating removed `tests/commands/management.sh`
   coverage.
6. Use one positive table-driven contract for the seven help nodes. Capture
   stdout, stderr, and status independently for bare and explicit-help forms;
   assert status `0`, empty stderr, and byte-equal stdout.
7. Retain the damaged-manifest fixture as the positive proof that help precedes
   state validation. Do not add separate absence/rejection fixtures.
8. Update public and contributor guidance only as needed to state ownership and
   the group/action boundary. Keep the redesigned grammar unchanged.
9. No migration or staged control-asset lifecycle change is required. Existing
   profile creation and sync already materialize the launcher and help asset.
10. Keep the test and guidance changes in one chunk. They define one small
    observable contract and separating them would leave an avoidable review
    state where implementation and documentation disagree.

## Verified implementation inventory

This is a verified planning baseline, not permission to ignore a newly
discovered direct dependency during implementation.

- `lib/install/launcher-template.sh` defaults empty root invocation to `help`,
  routes bare groups and `profile redirect` to help, and does so before manifest
  validation.
- The public groups are exactly `admin`, `profile`, `catalog`, `shim`, and
  `ai-skill`.
- `commands/help.sh` is the single installed renderer for root, group,
  subgroup, and action help.
- `tests/commands/surface.sh` already compares bare and explicit `--help`
  output for all target nodes using a damaged manifest. Command substitution
  implies successful status but does not independently capture both statuses
  or both stderr streams.
- `tests/commands/profile.sh` owns profile lifecycle, redirect CRUD, activation,
  and transaction behavior. It needs no planned change.
- `commands/profile.sh` treats bare direct invocation as profile usage and
  requires `list`, `set`, or `delete` after a direct `redirect` invocation. The
  installed launcher intercepts the public bare subgroup before this parser.
- `README.md` calls help state-independent; `commands/README.md` states that
  help precedes installed-state validation. Neither states the exact bare versus
  `--help` stream/status contract.
- `commands/CONTEXT.md` assigns rendering to `commands/help.sh` and
  `tests/commands/CONTEXT.md` assigns complete help discovery to `surface.sh`.
- `plans/wip/bash-completion.md` is not started, but its command inventory and
  test ownership still describe the pre-redesign surface. It must be rebased
  separately after this contract is accepted; it is not an implementation
  dependency of this chunk.

## Unresolved

None.

## Progress Checklist

- [x] Chunk 1 — Implemented, automatically verified, and accepted.

Active chunk: none. Chunk 1 is complete.

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

## Chunk 1 — Harden the redesigned default-help contract

### Goal

Turn the already-implemented launcher behavior into an exact tested and
documented contract while preserving every redesigned action and lifecycle
boundary.

### Suggested thinking level

**Medium.** The edit surface is small and the runtime behavior should remain
unchanged, but the test must handle POSIX-shell status and stream capture
without losing trailing newlines or masking failures under `set -e`.

### Files

Primary tests and guidance:

- `tests/commands/surface.sh`
- `README.md`
- `commands/README.md`
- `commands/CONTEXT.md`
- `tests/commands/CONTEXT.md`

Inspected compatibility boundary, changed only if the strengthened positive
test exposes a real contract defect:

- `lib/install/launcher-template.sh`
- `commands/help.sh`

Plan state updated during execution:

- `plans/complete/default-command-help.md`

Do not expand into command grammar, individual action parsers,
or removed compatibility surfaces.

### Implementation requirements

1. Refactor the existing help-node assertions in `tests/commands/surface.sh`
   into a local helper and table-driven loop. For the bare path and the same
   path with `--help`, redirect stdout and stderr to distinct files, record each
   status immediately under controlled `set +e`/`set -e`, assert both statuses
   are `0`, assert both stderr files are empty, and compare stdout files with a
   bytewise file comparison such as `cmp -s`.
2. Do not use command substitution to prove byte equality: it strips trailing
   newlines and therefore cannot establish the stated byte-for-byte contract.
3. Cover exactly root `shimmy`; `admin`; `profile`; `catalog`; `shim`;
   `ai-skill`; and `profile redirect`.
4. Retain focused discovery/warning assertions and the accepted root `help`
   alias assertion without broadening alias coverage.
5. Retain the damaged-manifest assertion proving help precedes state validation
   and that an ordinary action still validates the manifest.
6. Do not add negative tests for removed commands, unknown actions, or missing
   inputs. This plan's contract is positive default-help behavior.
7. Update guidance to say bare root/group/subgroup invocation is an exact
   successful `--help` equivalent. State that actions retain documented
   defaults and required inputs.
8. Update command and test context only where needed to preserve clear
   launcher/help/test ownership.
9. Do not edit action parsers, `tests/commands/profile.sh`, or any removed
   pre-redesign file path.
10. If the strengthened test reveals a real defect, fix only the launcher or
   help renderer and verify the rendered launcher artifact. Otherwise leave
   runtime code unchanged.
11. Do not edit `plans/wip/bash-completion.md`. State at handoff that its rebase
    and implementation should begin only after this chunk is accepted.

### Verification checklist

- [x] `sh -n tests/commands/surface.sh` passes.
- [x] No runtime source changed, so additional runtime syntax checks were not
  applicable.
- [x] `./tests/test.sh --group commands-surface` passes: all 2 tests passed.
- [x] Tests independently prove stdout equality, empty stderr, and status `0`
  for bare versus explicit `--help` at all seven help nodes.
- [x] Stdout equality is file-based and bytewise, preserving trailing-newline
  differences that command substitution would discard.
- [x] The damaged-manifest fixture proves help remains state-independent while
  a normal action still validates installed state.
- [x] Static review confirms no group, action, option, alias, default,
  required-input rule, or compatibility surface changed.
- [x] Public and context guidance consistently describe launcher-owned default
  help and the group/action boundary.
- [x] `./tests/context-tree.sh` passes. Root child-context links were made
  explicit so the retained tree validator recognizes them.
- [x] `git diff --check` passes, and `git diff --summary` is empty, showing no unintended
  mode changes.
- [x] Progress and **Lessons learned** contain actual verification evidence.
- [x] Human review accepted Chunk 1 on 2026-08-22.

### Human review gate

Reviewers confirm that the contract matches the completed five-group surface;
all seven help nodes exactly match explicit `--help`; help remains
state-independent; action defaults and required-input failures are unchanged;
no removed compatibility route returns.

## Risk register

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Pre-redesign names remain in scope. | Work restores obsolete interfaces or edits nonexistent owners. | Use the completed redesign and current launcher as authoritative. |
| Help moves into individual handlers. | Discovery becomes inconsistent and state-dependent. | Preserve launcher routing and the single help renderer. |
| Tests compare text but mask stream/status differences. | Scripts can observe failure despite matching text. | Independently assert both stdout, stderr, and statuses. |
| The rule is applied to actions. | Defaults stop executing or missing inputs silently succeed. | Limit the contract to root/group/subgroup nodes. |
| Direct handlers are mistaken for the public CLI. | Internal seams duplicate launcher policy. | Exercise rendered installed launchers for acceptance. |
| Completion overlaps this work. | Tests conflict, consume an unaccepted contract, or restore obsolete grammar. | Accept this chunk first; exclude completion artifacts and rebase the separate completion plan afterward. |

## Lessons learned

### Initial

- The redesign subsumed the original runtime change: default help is now a
  centralized installed-launcher responsibility, not two `profile.sh` cases.
- The authoritative groups are `admin`, `profile`, `catalog`, `shim`, and
  `ai-skill`. `profile redirect` has `list`, `set`, and `delete`; there is no
  direct upsert form.
- `tests/commands/surface.sh` replaced the former management-help owner and
  already proves help-before-state ordering with a damaged manifest.
- Remaining useful work is contract precision: independently prove streams and
  statuses and document bare invocation as an exact `--help` equivalent.
- Public acceptance uses the rendered installed launcher. Direct command
  entrypoints remain implementation seams.
- The not-started completion plan remains in `plans/wip/` but still inventories
  the removed pre-redesign command surface. It needs a separate rebase after
  this contract is accepted.

### Chunk 1

- One table-driven helper now exercises exactly the seven launcher help nodes,
  captures bare and explicit-help stdout and stderr separately, records both
  statuses immediately under controlled `set +e`, and compares stdout files
  bytewise with `cmp -s`.
- Focused discovery assertions, the root `help` alias, and the damaged-manifest
  proof remain intact. The ordinary `profile status` action still reaches
  manifest validation and fails on the damaged fixture.
- Runtime sources and action parsers required no change; the existing launcher
  already satisfied the strengthened contract.
- Public and contributor guidance now distinguishes launcher help nodes from
  actions with defaults or required inputs.
- `sh -n tests/commands/surface.sh`, the two-test `commands-surface` group,
  `tests/context-tree.sh`, and `git diff --check` pass. No file mode changed.

## Session bootstrap

1. Read `AGENTS.md`, `CONTRIBUTING.md`, root and applicable child contexts, this
   plan, and `plans/complete/redesign-control-surface.md`.
2. Read `lib/install/launcher-template.sh`, `commands/help.sh`, and
   `tests/commands/surface.sh`; inspect the worktree before editing.
3. Reconfirm that runtime behavior already exists; strengthen its positive
   contract and guidance without changing grammar.
4. Execute only Chunk 1 and avoid action parsers, compatibility surfaces,
   `plans/wip/bash-completion.md`, completion implementation, and generated
   skill adapters.
5. Run and record every verification item, update progress and lessons, then
   stop at the human review gate.
