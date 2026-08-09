---
name: plan-review-act
description: Investigate a software task without making changes, resolve material ambiguities, and produce a decision-complete implementation plan for review before acting. Use when the user asks to plan, design, scope, architect, migrate, refactor, create a resumable context-window-aware execution plan, or explicitly requests PLAN -> REVIEW -> ACT behavior, iterative chunks, progress checklists, human review gates, or lessons learned.
---

# Plan, Review, Act

Produce an evidence-based implementation plan and stop for review. Treat every
review gate as authorization-sensitive: planning does not authorize changes,
and acceptance of one chunk does not authorize later chunks.

## Respect the execution boundary

- Start in `PLAN` and remain read-only.
- Plan output should be created in a markdown document in the root of the repo under /plans folder. Name the plan with a succinct extract (40 chars or less) of the primary high-level goal.
- With the exception of the plan itself, do not edit files, install dependencies, format code, create commits, mutate
  external systems, or perform destructive actions while planning.
- Permit read-only discovery such as reading files, searching source, checking
  status or diffs, inspecting history, and running non-mutating diagnostics.
- Follow system, developer, sandbox, approval, and repository instructions.
  This skill does not change collaboration mode or grant unavailable tools.
- Preserve unrelated user changes and treat a dirty worktree as evidence, not
  permission to modify or discard it.

## PLAN

1. Restate the objective, deliverables, constraints, and explicit exclusions.
2. Read applicable `AGENTS.md`, repository guidance, and context files before
   evaluating implementation details.
3. Inspect the relevant code, tests, configuration, documentation, generated
   artifacts, and ownership or lifecycle boundaries.
4. Trace current behavior far enough to identify affected producers,
   consumers, interfaces, validation, failure handling, and rollback paths.
5. Prefer established repository patterns. Verify unstable, external, or
   unfamiliar facts with authoritative sources when browsing is available or
   required.
6. Separate confirmed facts, reasonable inferences, and unresolved decisions.

Do not present a plan that merely says to investigate facts that can be
discovered safely during `PLAN`. Perform that investigation first.

## Resolve ambiguity and unresolved decisions

- Make a reasonable, reversible assumption when it does not materially alter
  scope, architecture, compatibility, security, cost, or user-visible behavior.
- Ask only when the answer cannot be discovered and different choices would
  materially change the plan.
- If a structured user-input tool is available, ask no more than three short
  questions with two or three mutually exclusive choices each. Put the
  recommended choice first and explain its tradeoff in one sentence.
- If structured input is unavailable, ask one concise plain-text question.
- Maintain an `## Unresolved` section while iterating. For each item, state the
  issue, why it matters, viable choices, and the recommended choice.
- Move resolved items into recorded design decisions. A decision-complete plan
  must retain `## Unresolved` and state `None`.
- Stop when an unresolved decision would make the plan speculative or unsafe.

## Build the planning preamble

For substantial changes, establish a stable vocabulary and target before
describing implementation:

1. Write `## Objective` with the intended outcome, success conditions, and
   explicit exclusions.
2. Write `## Target layout and terminology` when paths, ownership, boundaries,
   interfaces, states, or renamed concepts could otherwise be ambiguous.
   Include compact trees, schemas, or examples when they make the target
   concrete. Define terms once and use them consistently.
3. Write `## Recorded design decisions` for decisions that implementation must
   not reopen. Include compatibility, migration, ownership, transaction, and
   lifecycle rules when relevant.
4. Write `## Verified implementation inventory` when broad changes require a
   known baseline of producers, consumers, tests, docs, generated artifacts,
   or migration matches. State that the inventory is a verified baseline, not
   permission to ignore newly discovered dependencies.
5. Write `## Risk register` when failure modes, destructive behavior,
   compatibility, or cross-component coordination materially affect execution.

Omit a preamble section only when it adds no implementation value. Never omit
`## Unresolved`.

## Choose and size implementation chunks

- Keep straightforward work in one implementation unit.
- Split substantial work into ordered chunks when context-window limits,
  dependency boundaries, atomic transitions, or human reviewability justify it.
- Size each chunk so a fresh agent session can read its target context,
  implement it, verify it, update the plan, and report for review.
- Order chunks by dependency. Do not split one schema, ownership, or
  compatibility transition into independently invalid intermediate states.
- Require every accepted chunk to leave the repository coherent and its
  affected behavior operational or explicitly documented as intentionally
  partial.
- Keep each chunk within its declared scope. Assign shared follow-up work to
  exactly one chunk unless an earlier mechanical update is required to keep
  the repository operational.
- Give every chunk these subsections:
  - `### Goal`
  - `### Files`
  - `### Implementation requirements`
  - `### Verification checklist`
  - `### Human review gate`
- Use the files subsection to identify the primary change surface without
  treating it as permission to ignore newly discovered required files.
- Make verification items observable and acceptance-oriented. Include success,
  failure, regression, isolation, migration, and documentation checks as
  appropriate.

## Maintain the progress checklist

Add a cumulative `## Progress Checklist` before the chunks. Identify the
active chunk and use these states consistently:

- `[ ]` means not started or not verified.
- `[~]` means partially complete and requires a follow-on decision and/or notes.
- `[x]` means complete and verified.

For every `[~]` item, record what passed, what remains, why it remains, its
risk or impact, and the proposed next action. Update the checklist before every
review gate so a new session can resume after a transient failure without
reconstructing status from chat history.

For every chunked plan, include the following section verbatim.

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

## Preserve lessons and session handoff

- Add cumulative `## Lessons learned` with an `### Initial` subsection and one
  subsection per executed chunk.
- Record concise, durable findings that improve later chunks or future work.
  Do not duplicate fixed design decisions or retain incidental debugging logs.
- Update lessons after verification and before the human review gate.
- For multi-session work, add `## Session bootstrap` that tells the next agent
  which guidance, plan sections, contexts, and target files to read; restates
  the target and non-negotiable boundaries; identifies the active chunk; and
  requires stopping at that chunk's human review gate.

## REVIEW

For substantial or chunked work, return a plan using this order:

```markdown
# <Plan title>

## Objective
<outcome, success conditions, and exclusions>

## Target layout and terminology
<target state and stable definitions, when relevant>

## Recorded design decisions
<implementation decisions that must not be reopened>

## Verified implementation inventory
<known change surface, when relevant>

## Unresolved
None

## Progress Checklist
- [ ] Chunk 1 — <goal>

## Execution protocol
<the required verbatim protocol>

## Chunk 1 — <name>

### Goal
<atomic outcome>

### Files
<primary change surface>

### Implementation requirements
<decision-complete requirements>

### Verification checklist
- [ ] <observable acceptance check>

### Human review gate
<what the reviewer must confirm before accepting the chunk>

## Risk register
<material risks and mitigations, when relevant>

## Lessons learned

### Initial
<durable planning findings>

## Session bootstrap
<instructions for a fresh implementation session>
```

For straightforward work, keep the plan concise and unchunked while preserving
the objective, implementation decisions, verification, unresolved status, and
review boundary.

Call out meaningful risks and tradeoffs next to the requirement they affect.
Request approval or revisions without implying approval has already been given.

## Review completed chunks

At every chunk review gate, surface the execution result directly in the
user-facing response. Include changes, tests, failures, uncertainties,
remaining risks, progress, and lessons learned.

Add a distinct `### Partial verification items` section to the review output.
List every verification or progress item marked `[~]`, preserving the item text
and reporting:

- what completed or passed;
- what remains incomplete or unverified;
- why it remains partial;
- its impact or risk;
- the proposed next action; and
- whether it blocks acceptance or is proposed for explicit deferral.

Do not bury `[~]` items in general notes or only record them in the plan file.
If no item is partial, output `None`. Do not start the next chunk until the user
explicitly accepts the current chunk, including the disposition of every
surfaced `[~]` item.

## ACT

Enter `ACT` only after the user explicitly approves implementation in a later
message or explicitly waives the initial review gate before planning begins.
On entry:

1. Recheck applicable instructions and repository state.
2. Implement only the approved chunk or unchunked scope.
3. Report material divergence and seek direction instead of silently changing
   the approved design.
4. Update the plan's progress checklist and cumulative lessons learned.
5. Run the approved verification and prepare the required review output.
6. Stop at the human review gate. Do not begin another chunk without explicit
   acceptance.

If the user requested only a plan, never enter `ACT` within that request.
