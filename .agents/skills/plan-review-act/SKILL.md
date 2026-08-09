---
name: plan-review-act
description: Investigate a software task without making changes, resolve material ambiguities, and produce a decision-complete implementation plan for review before acting. Use when the user asks to plan, design, scope, architect, migrate, refactor, or review an implementation approach, or explicitly requests PLAN -> REVIEW -> ACT behavior.
---



# Plan, Review, Act

Produce an evidence-based implementation plan and stop for review. Treat the
review gate as authorization-sensitive: planning does not authorize changes.

## Respect the execution boundary

- Start in `PLAN` and remain read-only.
- Do not edit files, install dependencies, format code, create commits, mutate
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

## Resolve ambiguity

- Make a reasonable, reversible assumption when it does not materially alter
  scope, architecture, compatibility, security, cost, or user-visible behavior.
- Ask only when the answer cannot be discovered and different choices would
  materially change the plan.
- If a structured user-input tool is available, ask no more than three short
  questions with two or three mutually exclusive choices each. Put the
  recommended choice first and explain its tradeoff in one sentence.
- If structured input is unavailable, ask one concise plain-text question.
- Stop when a missing decision would make the plan speculative or unsafe.

## Build a decision-complete plan

Make the plan executable by another agent without requiring it to rediscover
design decisions. Include, when relevant:

- the files, modules, commands, or interfaces to change;
- the intended behavior and data or control flow;
- compatibility, migration, ownership, and rollback treatment;
- validation, error handling, security, and destructive-action boundaries;
- tests for success, failure, edge cases, and regression-prone invariants;
- documentation, generated artifacts, contexts, and release notes to update;
- assumptions and explicit exclusions.

Use ordered implementation steps that are concrete and reviewable. Avoid
padding the plan with obvious actions such as "inspect the code" or "make the
change" after those details should already be known.

## REVIEW

Return a concise plan with this structure:

```markdown
## Proposed plan

### Summary
<objective and approach>

### Implementation
1. <specific change and location>
2. <specific change and location>

### Verification
- <test or inspection and expected evidence>

### Assumptions and exclusions
- <material assumption, unresolved choice, or explicit non-goal>
```

Call out meaningful risks and tradeoffs next to the step they affect. End by
requesting approval or revisions. Do not imply that approval has already been
given.

## ACT

Enter `ACT` only after the user explicitly approves implementation in a later
message or explicitly waives the review gate before planning begins. On entry:

1. Recheck applicable instructions and repository state.
2. Implement only the approved scope.
3. Report material divergence and seek direction instead of silently changing
   the approved design.
4. Verify the result in proportion to risk and summarize changes, evidence,
   and remaining limitations.

If the user requested only a plan, never enter `ACT` within that request.
