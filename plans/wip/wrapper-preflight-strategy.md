# Wrapper preflight and execution strategy

## Objective

Improve wrapper failure guidance, measure invocation overhead, and evaluate a
broader execution strategy, including commands that run before reachability
preflight or agent escalation. Produce an evidence-backed recommendation before
changing the production execution policy.

Make the minimum useful runtime check an explicit target: activation establishes
which profile owns the intended engine; an invocation verifies that its shell's
selected profile still matches the active profile and effective Podman target.
Assess a cross-platform explicit-routing candidate: an installed wrapper derives
its Podman connection from the validated profile binding and passes it to every
runtime Podman request, rather than relying on Podman's mutable default.
Measure the one-time activation cost separately from the cost of checking that
association on every invocation, so later choices can be judged by their effect
on a real workflow.

The user confirmed this objective and the existing `plans` root on 2026-09-17,
then explicitly expanded the assessment beyond batching and sessions.
Authoritative path: `plans/notional/wrapper-preflight-strategy.md`.

Success means:

- Runtime and agent guidance distinguish observed failure from inferred cause
  and explain the correct outer-command escalation boundary.
- Measurements attribute wrapper, preflight, Podman, and container costs with
  explicit limitations, instead of assuming one `info` call per invocation.
- The assessment defines a minimal profile-to-engine association check and
  compares its measured or explicitly modeled cost with today's complete
  runtime preflight. It states which properties activation established and
  which the command must verify because they can change later.
- The assessment reports one-time activation and shell-selection timings
  separately from per-command state-check timings, then extrapolates both to
  common sessions such as 40 `rg` and 40 `jq` calls in a sequential loop.
- The assessment compares execution-first variants, narrower validation,
  connection selection, reuse, batching, and shell overhead improvements.
- A current-system benchmark captures reproducible baseline timings before any
  selected runtime change.
- Discovery produces one or more concrete alternate designs, including at
  least one that applies Decision 2's retained-authority/minimum-association
  model, and records a reviewer-selected implementation choice.
- A separate implementation handoff names the exact follow-up plan, acceptance
  tests, rollback, and unresolved prerequisites.
- After that implementation is accepted, the same benchmark captures a
  future-system dataset and reports comparable deltas rather than a modeled
  speedup alone.

This plan authorizes no implementation yet. Its proposed implementation scope
is diagnostic guidance plus measurement and assessment tooling. Changing the
default preflight or escalation policy, adding automatic replay, introducing a
public session/cache interface, enforcing explicit runtime connections,
provisioning or enabling a Linux Podman API service, creating or adopting a
Podman connection, and deploying or synchronizing installed profiles require a
subsequent concrete design and review. POSIX shell remains the implementation
architecture. Podman lifecycle and registry ownership stay with the existing
control plane.

## Target layout and terminology

Keep these separate throughout the assessment:

| Term | Meaning |
| --- | --- |
| Authority validation | Evidence that the invoking profile, engine binding, active record, overrides, and registry policy permit this invocation. |
| Minimum useful runtime check | The smallest check shown to keep the shell-selected profile associated with the active profile and effective Podman target, including applicable policy routing. It does not establish engine health. |
| Activation baseline | The elapsed cost of a specific measured activation transition, identified as already-active reactivation or a genuine profile/engine transition. A dry run is a different measurement. |
| Runtime baseline | The elapsed cost and Podman calls spent checking current invocation state before `run`, reported separately from container work. |
| Shell selection | PATH setup by a profile's `shell-init.sh`; it does not activate a profile or start a machine. |
| Reachability probe | A request whose purpose is to establish that the engine can currently be contacted. |
| Status collection | Additional information for inspection or activation, such as workload names and counts. |
| Agent escalation | The host agent's approval to execute an exact outer command beyond its default sandbox. The wrapper cannot grant it. |
| Post-failure diagnosis | Read-only inspection after a failed attempt, retaining the original result. |
| Replay | Executing the user's operation again; distinct from diagnosis and escalation. |

Existing source and installation ownership remain unchanged. Proposed new files
are `tests/runtime-benchmark.sh` and `docs/runtime-preflight.md`; the benchmark
is a source-only, opt-in experiment, outside the default test runner and
installed command surface. Retain summarized measurements in this plan and the
assessment document. Raw logs belong in a private temporary output directory.

## Recorded design decisions

1. Treat the user's fully optimistic model as a first-class alternative:
   attempt the command in the ordinary sandbox, with no preliminary engine
   health request; diagnose and consider escalation only after failure.
   Evaluate both complete removal of pre-execution authority checks and a
   variant that retains them. Do not quietly equate these different models.
2. The recommendation entering measurement is to retain authority validation
   and investigate moving redundant health checks and status-only work off
   the successful invocation path. In particular, target a minimum useful
   runtime check that verifies the invoking installed profile still owns the
   active record, its strict binding names the effective Podman connection,
   no override diverts execution, and relevant registry routing still belongs
   to that profile. Whether the engine is reachable belongs to execution or
   failure diagnosis. A successful command can use the wrong profile or policy,
   so success alone cannot replace authority validation.
3. Treat explicit connection selection as a cross-platform candidate invariant:
   an installed wrapper derives the connection from its validated binding and
   applies `--connection` to runtime Podman calls. It is not a user-supplied
   wrapper argument. On Darwin the binding already names the owned machine
   connection. On Linux, the candidate requires a named connection to the
   current user's local rootless API socket; remote or rootful endpoints remain
   unsupported. Current Linux operation uses the local rootless engine without
   a named connection, so this is a contract change, not a description of
   existing behavior.
4. Do not add `systemctl --user enable --now podman.socket`, `podman system
   connection add`, connection adoption, or a default-connection mutation to
   bootstrap under this plan. Those actions provision or mutate user Podman
   state, contrary to the current explicit-dependency boundary. A later design
   must choose and review a user-precondition, opt-in setup, or an amended
   lifecycle contract before it can make the Linux branch enforceable. Treat
   that choice as a non-blocking post-plan unresolved issue.
5. Measure association checks independently of status collection. The
   candidate may need connection/machine metadata but need not collect running
   workloads or make a health request if execution itself can report a stopped
   or unreachable engine. Explicitly evaluate running against the validated
   connection instead of relying on a global default that can change between
   check and execution. A name match without validated binding and routing is
   insufficient.
6. Preflight and escalation are independent policy dimensions. An unknown
   environment may benefit from one sandbox-first attempt. A known denial
   makes repeated sandbox attempts predictably wasteful. Current approved
   wrapper-first escalation instructions remain operative during this work;
   theoretical exploration is not permission to alter them or evade approval.
7. No automatic replay is implemented. Diagnose infrastructure failures
   separately from tool results. Even a safe read may have consumed stdin or
   partially emitted output; a write or remote request may already have taken
   effect. Shell redirection can modify files before Podman starts.
8. Do not classify every nonzero result as an infrastructure failure. Search
   no-match, validation failure, user cancellation, and tool errors retain
   their semantics. Podman status 125 and stderr text alone are insufficient
   proof that no user work occurred. Missing container records are also not
   conclusive after automatic removal or lost connectivity.
9. Runtime guidance must not assert that a process is sandboxed when the
   runtime lacks that evidence. Use conditional agent guidance and report an
   undetermined cause when stderr was discarded. Permission denial is an
   observation; the same operation succeeding outside the sandbox strengthens
   attribution to the execution boundary.
10. For the first diagnostic change, improve existing renderers using facts
    already available. Do not add raw stderr capture, a regex-based cause
    classifier, new public diagnostic schemas, or argument logging. Detailed
    error transport and optional runtime instrumentation are assessed through
    the baseline and discovery chunks, where their stream, confidentiality, and
    overhead costs are visible.
11. Preserve profile/engine schemas, activation and rollback behavior, source
    previews, native platform selection, privileged-connection validation,
    image acquisition/build policy, Skopeo registry capability, and final
    `exec` behavior. Existing local-build preflights remain in scope for the
    inventory, not implicit removal.
12. Activation is a one-time state transition, not part of every command. A
    newly opened shell selects a PATH with `shell-init.sh`; it does not perform
    activation. Report both session models: already activated before the shell
    opens (`A = 0` inside the session) and one measured activation followed by
    many invocations (`A` charged once). Never count the same activation 80
    times or treat a dry run as actual activation time.
13. The plan ends with a recommendation, not an automatically selected
    optimization. A production experiment or rollout must name its exact
    behavior, affected callers, acceptance tests, and rollback in a later review.

## Verified implementation inventory

Baseline inspected on 2026-09-17 at source commit
`9f42392a42718a03a68f2727224a73fa87420837`. The worktree was clean before this
plan. This inventory is a verified baseline, not permission to ignore newly
discovered dependencies.

| Surface | Confirmed behavior and relevance |
| --- | --- |
| `lib/runtime/podman.sh` | `shimmy_podman_preflight_require` resolves Podman/platform, enforces applicable profile affinity, then invokes generic `info` with both streams discarded. `shimmy_podman_run_or_preview` ends in `exec`, so the shell cannot currently diagnose a later run failure. |
| `lib/profile/activation.sh` | Runtime Darwin affinity calls the general state reader. Its successful path normally includes machine list, connection list, workload `ps`, and explicit-connection `info`. Recommendation logic also serves management commands. |
| Profile activation and `shell-init.sh` | Activation owns the engine, default connection, projection, active record, and link transition. The shell initializer selects the profile's PATH only; opening a new shell does not re-activate the machine. |
| `lib/engine/state.sh`, `lib/engine/registry.sh` | Binding resolution reads strict local records. The current projection state reader validates local source, effective, and loaded fingerprints; it does not itself perform guest SSH inspection. Historical plans describing older live projection checks are not the current call graph. |
| `lib/runtime/podman.sh` platform branch | Installed manifest checks precede a Darwin-only affinity branch. Ordinary Linux/source execution does not traverse the full Darwin state reader and uses the local rootless engine with no named connection. Management Linux status has its own rootless/registry checks. A cross-platform explicit-routing change must replace these distinct mechanisms deliberately rather than claim they are already identical. |
| `lib/runtime/image.sh` | Local-image resolution and stale-image cleanup can invoke preflight separately. A per-wrapper count depends on image strategy and execution path. |
| `tools/*/versions/*/run.sh` | Ordinary external-image versions share preflight and invoke unqualified `podman run`; gh, gcloud, and OPNsense runtimes have additional conditional behavior. jq and rg provide small filter/search baselines. A future explicit-routing change belongs in the shared runtime command assembly, not per-tool copies. |
| `tools/skopeo/versions/1.22/run.sh`, `lib/registries/registries.sh` | Skopeo consumes profile registry policy and may reuse same-process affinity evidence. This reuse is narrower than a general persistent preflight cache. |
| `commands/agent-preflight.sh` | Both normal discovery and `--smoke` currently execute a direct `podman info`; failures print generic smoke-prefix guidance. The script cannot grant outer-command approvals. |
| `tests/lib/runtime.sh` | Existing tests cover successful affinity, another active profile sharing the engine, source preview, modes, syntax, and unreachable guidance. Extend the existing guidance assertions rather than creating duplicate rejection scenarios. |
| `tests/lib/profile-activation.sh`, `tests/lib/codec.sh` | Existing seams cover lifecycle state and override secrecy; the codec proves explicit secret redaction. Fake lifecycle evidence does not prove real sandbox behavior or real container acceptance. |
| `tests/commands/agent-preflight.sh`, `tests/commands/shim.sh` | Existing coverage proves metadata-driven smoke commands and wrapped nonzero status propagation. |
| `lib/install/profile.sh`, `lib/update/profile.sh` | Materialization copies/extracts the shared `lib` tree. Profiles retain exact control source; changing checkout files does not update installed wrappers. `agent-preflight.sh` and the benchmark remain source-only. |
| `README.md`, `docs/podman.md`, `docs/testing.md`, canonical management/tool skills | Skills already describe sandbox evidence and exact outer-command escalation. Runtime hints lag them. `docs/podman.md` incorrectly groups `agent-preflight.sh` with engine-free source validation. |

For the ordinary successful installed Darwin external-image path, static
inspection predicts five Podman calls before `run`: machine list, connection
list, workload `ps`, explicit-connection `info`, and generic `info`. This is a
path-specific prediction to verify, not a count reconstructed from the incident
or a universal count for every wrapper. Source/Linux paths differ.

Plan discovery checked `notional`, `wip`, and `complete`. No existing plan owns
this objective. Related boundaries appear in
`plans/notional/podman-6-architecture.md`,
`plans/notional/image-retention-resilience.md`,
`plans/wip/engine-cpu-capability-foundation.md`, and the retained engine and
registry lifecycle plans. Recheck these if a subsequent proposal changes their
interfaces; do not edit unrelated plans as part of this assessment.

## Execution-first theory and alternatives

The fully optimistic model is:

```text
ordinary sandbox -> execute requested command
  success -> return unchanged
  failure -> retain status and evidence
          -> determine whether it is a tool result or infrastructure failure
          -> perform narrowly scoped diagnosis when useful
          -> request exact outer-command escalation if supported and justified
          -> replay only when safe and authorized
```

Its attraction is avoiding successful-path health queries and unnecessary
elevated execution. Its central limitation is that a successful invocation
does not establish that it used the authorized profile/policy. Its failure path
also needs evidence that the current `exec`-based wrapper cannot retain.

A more conservative variant keeps local authority and required engine-policy
validation before execution, and defers health/status diagnosis. This can still
require some pre-execution Podman calls: label each retained call by the
property it proves rather than calling the variant “no preflight.”

For this assessment, the minimum useful check answers: “Does this wrapper's
selected profile still match the active profile and the Podman target this
command would use?” It reads the installed profile identity, active record,
strict engine binding, effective connection or local engine, override state,
and applicable registry projection. It does not list running workloads.
Candidate designs must show how they verify the effective target without a
health-only request, or count any required remote probe honestly as part of the
minimum check. Stopped and unreachable engines can then fail during execution
and receive post-failure diagnosis. This is a target contract to prove, not a
claim that the current code already implements the cheaper path.

| Alternative | Potential saving | Questions and tradeoffs to assess |
| --- | --- | --- |
| Current eager checks with better diagnostics | Operational clarity; baseline for comparisons | Continues all current per-invocation cost. |
| Omit the final generic `info` after successful Darwin affinity | One engine request | Earlier probe uses an explicit connection, while final execution normally uses the default. Prove equivalent routing and document the existing check/use race before calling the probe redundant. |
| Separate runtime validation from status collection | Avoid workload `ps` and unused status parsing | Retain active-record, binding, override, default-connection, and projection decisions; decide whether a machine-state query proves authority or only liveness. Management status still needs full data. |
| Minimum useful association check | Run only the checks needed to connect this shell's profile to the active effective engine and policy | Specify whether machine-running and remote rootless probes prove authority or only liveness. A stopped engine may be left for execution to report; a mismatched target must fail before execution. |
| Execute first, retain authority checks, diagnose health failures | Avoid health-only queries on success | Requires careful failure transport and possibly a shell supervisor; measure its cost and preserve signal/TTY/stdin behavior. |
| Fully optimistic execution with all checks deferred | Upper bound on removable preflight cost | Wrong-profile or stale-policy execution can succeed silently. Requires a redesigned authority boundary or explicit contract change before production use. |
| Explicitly bind every runtime request to a validated profile connection on all hosts | Remove default-connection reversion as a check/use race and make the explicit probe describe execution | Darwin already records a named connection. Linux requires a named rootless local-service connection instead of today's direct local engine path. The connection must be derived from the strict binding, never accepted from the caller. Do not enable a user service, create/adopt a connection, or change its default without a separately reviewed lifecycle contract. Explicit routing still does not authorize an inactive profile; keep override and privileged-rootful behavior explicit. |
| Consolidate POSIX parsing and reuse evidence within one invocation | Fewer subprocesses and duplicate same-process checks | Measure shell/file/hash overhead separately. Evidence inside command substitutions may not propagate to the parent. |
| Activation-generation or time-limited evidence cache | Amortize checks across invocations | Local epochs alone miss external Podman changes. Define engine/service restart, binding, projection, overrides, expiry, and failure invalidation; a timeout bounds staleness, not correctness. |
| Native CLI batching or parallel independent work | Amortize wrapper and container startup | Preserve per-input attribution, ordering requirements, and error semantics; parallelism may increase contention. |
| Explicit sessions, reusable containers, or a broker | Amortize validation and/or container startup | Adds state ownership, image/credential/mount lifetime, isolation, concurrency, and cleanup contracts. A generic arbitrary-command broker also changes approval scope. |

Evaluate agent policy independently for each runtime alternative:

- Sandbox first while reachability/permission is unknown.
- Reuse existing narrowly approved escalation where denial is already known.
- After one proven denial, retain that evidence for the active agent session;
  do not build a persistent permission cache into Shimmy or claim approvals
  persist across sessions.

Let `P` be removable health/status overhead, `S` added supervision/diagnostic
plumbing on success, `fD` expected diagnostic cost after failures, and `qR` the
extra cost of sandbox-denied attempts plus safe escalated replay. Execution
first is faster when `P > S + fD + qR`, for comparable workloads and authority
checks. Measure the terms and sensitivity to `f` and `q`; do not invent a
speedup or failure probability. When sandbox denial is certain, `qR` recurs
unless agent-session evidence changes the next attempt.

Use measured terms for common session summaries. For a shell with an already
active profile, a sequential 40-`rg`/40-`jq` loop has 80 wrapper invocations
and no activation inside the loop. For a workflow that first activates once:

```text
current = A + shell-selection + 40 × (R_rg + C_rg) + 40 × (R_jq + C_jq)
candidate = A + shell-selection + 40 × (M_rg + C_rg) + 40 × (M_jq + C_jq)
estimated saving = 40 × (R_rg - M_rg) + 40 × (R_jq - M_jq)
```

`A` is the observed activation transition, `R` today's runtime checks, `M`
the candidate minimum association check, and `C` the remaining container and
tool work. Report activation as a separate amount and as a share of total
session time. Model sandbox denial and failure/diagnosis as additional cases,
not as assumed costs in every success. Do not derive a loop p95 by adding
individual p95 values; directly time a representative 80-call sequence when
possible and label the formula as an extrapolation.

The current successful installed Darwin external-image path predicts five
pre-run Podman calls per wrapper. These are static call counts, not timing
measurements:

| Common workflow | Activation charged in session | Wrapper runs | Predicted pre-run Podman calls under current Darwin path |
| --- | ---: | ---: | ---: |
| Agent opens shell with an already-active profile, then runs `rg` and `jq` once each | 0 | 2 | 10 |
| Agent opens shell with an already-active profile, then runs `rg` and `jq` 40 times each | 0 | 80 | 400 |
| Agent activates once, then runs `rg` and `jq` 40 times each | 1 | 80 | 400, plus activation's separately measured calls |
| Agent runs `rg` and `jq` 200 times each with an already-active profile | 0 | 400 | 2,000 |

On a different OS, installed version, image strategy, or failure path, count
again rather than applying this Darwin estimate. The later measurement should
replace these predicted counts with observed values and add elapsed time and
percentages for each workflow.

External evidence checked against current primary documentation:

- Podman documents runtime statuses, automatic container removal, and CID-file
  behavior. These support preserving the original result and treating a CID
  file as correlation evidence rather than universal proof of execution state.
  [Podman run](https://docs.podman.io/en/latest/markdown/podman-run.1.html).
- Podman exposes container events, timestamp fields, and bounded event queries;
  events can be disabled. Use them for optional phase attribution, not as a
  universal source of complete execution evidence.
  [Podman events](https://docs.podman.io/en/latest/markdown/podman-events.1.html).
- Connection selection is a transport control. Its suitability for enforcing
  Shimmy authority is an inference requiring repository-specific proof.
  [Podman global options](https://docs.podman.io/en/latest/markdown/podman.1.html).
- Podman system connections are named destinations for Podman services and are
  persisted in Podman-managed connection/configuration state. A Shimmy-created
  Linux connection is therefore a new ownership and lifecycle responsibility,
  not an ambient wrapper option.
  [Podman system connection](https://docs.podman.io/en/latest/markdown/podman-system-connection.1.html).
- On Linux, the rootless API socket is normally
  `unix://$XDG_RUNTIME_DIR/podman/podman.sock`; the user `podman.socket` unit
  can activate the service on demand. Enabling or starting that unit is a
  Podman service-management action that must be separately authorized by a
  future lifecycle design.
  [Podman system service](https://docs.podman.io/en/latest/markdown/podman-system-service.1.html).
- Lost responses can leave callers uncertain whether work happened. Safe
  replay requires idempotency or reconciliation; a failure does not establish
  that nothing happened.
  [AWS retry design](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/).

## Unresolved

### Post-plan Linux connection lifecycle

A cross-platform explicit-routing implementation needs a separately approved
Linux lifecycle contract for the rootless API service and named connection.
The unresolved choices are whether Shimmy documents a user-managed
precondition, offers an explicit opt-in setup transaction, or changes its
Podman-dependency/ownership boundary to manage `podman.socket`, connection
creation, and any default-connection transition. This does not block this
plan: baseline measurement and alternate-design discovery can record the
current direct-local Linux path and any already-configured connection without
mutating either. The implementation handoff must carry this issue forward if
its selected design requires Linux explicit routing.

Selecting a production execution strategy is the output of the discovery
chunk, not an undecided implementation branch within diagnostic or baseline
work. Native host availability and event support are verification prerequisites
to record during execution; unavailable evidence must be surfaced for explicit
deferral and must not be presented as a pass.

## Progress Checklist

Active state: Chunks 1 and 2 were accepted by 2026-09-19. Chunk 3
alternate-design discovery and selection are drafted in
`docs/runtime-preflight.md` and await human acceptance. The Linux continuation
now supplies current-path baseline evidence; explicit Linux named-connection
routing remains an unresolved post-plan lifecycle question. The implementation
handoff and future-system delta report are not started.

- [x] Confirm objective and planning root; discover related plans.
- [x] Trace runtime, status, installation, test, and guidance boundaries.
- [x] Assess the execution-first model and record alternative designs.
- [x] Define the minimum useful runtime association target and two timing
  baselines for later measurement.
- [x] Chunk 1 — Align runtime and agent diagnostic guidance.
- [x] Chunk 1 — Verify focused behavior and source/materialization boundaries.
  `lib-profile-activation` and `commands-agent-preflight` passed in the focused
  group run. Dash is optional because macOS does not ship it: `lib-runtime`
  now records a skipped Dash parser check when unavailable, while retaining the
  check on hosts that provide Dash. `commands-shim` stalled during isolated
  verification in this environment and was stopped after repeated no-output
  waits. `./commands/run-tool.sh jq --preview-shim --version` succeeded as a
  source preview. The active-profile installed wrapper at
  `/home/beewa/.config/shimmy/profiles/default/bin/rg` succeeded with
  `rg --version`, but that smoke does not prove the new source diagnostics until
  the user explicitly syncs or rematerializes the installed profile control
  assets. `./tests/context-tree.sh` and `git diff --check` passed.
- [x] Human acceptance of Chunk 1.
- [~] Chunk 2 — Build the benchmark and capture the current-system baseline.
  `tests/runtime-benchmark.sh` now implements the bounded source-only workload,
  provenance capture, transparent Podman call counter, warmup/sample aggregation,
  and jq individual-versus-batched record comparison. It is executable and
  passes `/bin/sh -n`. Its host elapsed-time harness explicitly uses Bash's
  default `time` output without `-p`, while the measured workload remains
  POSIX `sh`. A reviewer-authorized call/ownership scope adds only a dormant
  preflight split, an explicit caller/ownership contract, and disposable
  full/context/affinity/reachability lanes. Warmups are now excluded from
  aggregates. A 20-sample Apple Silicon review baseline recorded the predicted
  5/4/4/1 calls per full/context/affinity/reachability lane with all statuses
  zero; no production caller uses the review helpers. The 2026-09-19 Apple
  Silicon continuation added installed-helper, individual
  probe, direct-container, observer-cost, minimum-association, session, and
  event evidence. Same-profile activation was dry-run-cleared and explicitly
  authorized. The 2026-09-19 Linux amd64 continuation added local/current-path
  support to the benchmark, recorded a 20-sample installed-wrapper and probe
  baseline on a host-local rootless engine, captured exact dry-run and same-
  profile activation evidence, and marked named-connection explicit-routing
  lanes unavailable when no rootless API socket or compatible named connection
  existed. A user-authorized early stop ended the overlong Linux 400-invocation
  sensitivity completion after the 20-sample lane set and instrumented 80-
  command session had been gathered.

- [x] Human acceptance of Chunk 2 baseline evidence.
  The accepted dataset now includes native Linux amd64 current-path evidence;
  explicit-connection-only Linux lanes remain unavailable where the host has no
  rootless API socket or compatible named connection.
- [x] Chunk 3 — Produce alternate designs and select a discovery outcome.
  `docs/runtime-preflight.md` now records the accepted Darwin and Linux
  baselines, execution-first decision table, design matrix, selected
  Darwin-first minimum-association plus explicit-routing design, Linux/current-
  path fallback, rejected alternatives, and handoff assumptions.
- [ ] Human acceptance of Chunk 3 design choice.
- [ ] Chunk 4 — Produce and accept the implementation handoff.
- [ ] Complete the separately approved implementation handoff.
- [ ] Chunk 5 — Capture future-system timings and report the measured delta.
- [ ] Human acceptance of Chunk 5 and completion disposition.

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

## Chunk 1 — Diagnostic guidance

### Goal

Make existing failure output actionable without changing when commands run,
what authority checks execute, or who grants escalation.

### Files

Primary changes: `lib/runtime/podman.sh`, `commands/agent-preflight.sh`,
`tests/lib/runtime.sh`, `tests/commands/agent-preflight.sh`, `README.md`,
`docs/podman.md`, and this plan.

Inspect `lib/profile/activation.sh`, `lib/install/profile.sh`, canonical
`plugins/shimmy/skills/shimmy-escalation/SKILL.md` and
`plugins/shimmy/skills/shimmy-init/SKILL.md`, plus affected tool guidance for
semantic consistency. The current canonical skills already provide the basic
policy; edit them only if the final guidance needs a concrete clarification.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high for evidence ordering and shared consumers.

1. Share a small conditional agent hint between generic unreachable and
   affinity failures caused by unreachable/unknown engine state. State that
   sandbox-only evidence leaves the engine unverified from the sandbox and
   directs the agent to the same authorized outer wrapper operation.
2. For an existing safe approval, retain direct escalated execution. For an
   unknown sandbox failure, suggest one exact outer-command retry where the
   operation is known safe to replay. Do not reconstruct argv or print secrets;
   the agent has the original tool call. Keep metadata-derived smoke commands
   in `agent-preflight.sh` as explicit pre-authorization/discovery examples.
3. Retain specific stopped, missing, override, active-record, and projection
   failures. Where identity is already validated, print profile and expected
   connection names. Do not run extra probes merely to enrich an error, and
   do not print connection URIs or override values.
4. Preserve `podman_info=ok|failed|skipped`, exit behavior, smoke discovery,
   stdout/stderr ownership, and all production execution checks. Explain that
   direct `podman info` success does not approve or verify nested wrapper
   access. Do not automatically activate or restart from these hints.
5. Correct the engine-free documentation example: source preview avoids
   engine access; `agent-preflight.sh` currently probes the engine even without
   `--smoke`. Explain `$PWD:/work` visibility and separate sandbox, image,
   container setup, and wrapped-tool failures without inventing their cause.
6. Verify materialization includes the updated shared helper through its
   existing `lib` copy/archive path. Document explicit profile control-source
   adoption; do not sync the user's installation or change bootstrap behavior.

### Verification checklist

- [ ] Existing guidance assertions prove conditional sandbox wording, validated
  identity when available, and the outer-wrapper approval distinction.
- [ ] Existing affinity/override/secret-redaction proofs still pass; avoid
  duplicate negative tests or new rejection invariants.
- [ ] Run `./tests/test.sh --group lib-runtime --group lib-profile-activation
  --group commands-agent-preflight --group commands-shim` using default bounded
  parallelism. Update assertions that describe intentionally changed wording.
- [ ] Exercise source preview and a live non-mutating installed wrapper with
  the actual applicable outer-command approval. Record its source provenance;
  an unchanged installed wrapper does not verify new source diagnostics.
- [ ] Run `./tests/context-tree.sh` and `git diff --check`; confirm syntax,
  executable modes, inventory, and existing materialization copy paths.

### Human review gate

Review the final errors, focused results, source-versus-installed evidence,
remaining diagnostic limitations, and any partial verification. Explicitly
accept Chunk 1 before Chunk 2. Acceptance does not authorize a lazy runtime,
automatic replay, profile synchronization, or activation.

## Chunk 2 — Current-system benchmark and baseline

### Goal

Build the source-only benchmark and capture reproducible current-system timing
and call-count baselines before selecting or implementing a runtime strategy.
This chunk measures current behavior; it does not rank alternatives, select a
design, or modify the runtime policy.

### Files

Primary changes: new `tests/runtime-benchmark.sh`, `docs/testing.md`, and this
plan. Chunk 3 owns the design report in `docs/runtime-preflight.md`. The
existing `tests/CONTEXT.md` remains the context for the source-only benchmark.

Read runtime/image/profile/engine helpers, jq and rg version-owned runtimes and
guides, `tests/support.sh`, and the existing timing documentation. Keep the
benchmark out of `tests/runner.sh` and installed assets.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high for measurement validity and failure semantics.

1. Build a POSIX-shell benchmark with a bounded workload set: selected-profile
   `shell-init.sh`, an already-active `profile activate <name>` under the
   conditions below, `rg --version`, `jq --version`, and jq reading small
   private JSON fixtures individually versus in one multi-file invocation.
   Preserve record identifiers in the batching comparison. Do not accept
   arbitrary user commands or execute credentialed/cloud/network
   administration tools as benchmarks.
2. Discover the selected installed profile and record OS/architecture, Podman
   version, control commit, tool version/image digest, engine mode, image
   availability, effective default connection, and whether the profile has a
   valid named connection usable for explicit runtime routing. On Linux, also
   record whether the user rootless API socket and a compatible named
   connection already exist; do not create, enable, adopt, or alter either.
   Read exact manifests as data. Verify the selected launchers belong to the
   active profile; invoke installed wrappers by normal names. Treat source and
   installed versions as distinct datasets when they differ.
3. Establish one named activation baseline separately. Time PATH-only shell
   selection; time `profile activate <active-name> --dry-run` as a dry-run
   baseline. Inspect its exact effects, then time same-profile
   activation only when the selected active profile's dry run proves a
   no-transition operation and the exact control-plane command has the needed
   approval. No `--stop-running`, profile switch, machine creation, or
   automatic repair is part of this benchmark. Label this result
   `already-active activation`; it must not stand in for initial bootstrap or
   a machine start. If an independently authorized disposable native profile
   transition is available, time it as a separate transition lane with its
   dry-run effects and cleanup recorded. Otherwise mark native first/start or
   switch activation unavailable, not zero; a fake-Podman lifecycle scenario
   can supply only a separately labeled control-plane estimate.
4. Establish the runtime baseline separately. Measure ordinary installed
   invocations, the installed helper's full preflight alone, the Darwin
   affinity check alone where applicable, individual Podman probes and local
   metadata/hash work, and an equivalent direct container smoke after one
   explicit setup validation. Where an already-configured valid named profile
   connection exists, compare unqualified and explicit-connection forms using
   an identical `info --format` payload, then record the selector's incremental
   cost and whether it targets the same engine. Record the exact current Podman
   call graph per tool and platform. The direct-container sample is an
   experimental lower bound, not a replacement wrapper or fallback approval.
   Keep the same image, platform, mount, working directory, and stdin behavior.
   Never evaluate preview text with `eval` to construct commands.
5. Use a benchmark-owned transparent Podman forwarding script in a private
   temporary directory when counting/timing actual child calls. It must call
   the resolved real Podman binary, preserve argv, status and streams, and
   never synthesize success or skip operations. Log only phase labels,
   ordinals, elapsed time and status, not raw arguments, environment, or
   credentials. Approve the benchmark's concrete outer invocation; never use
   a proxy to bypass an approval denial.
6. Compare instrumented and uninstrumented totals to disclose observer cost.
   Use `/usr/bin/time -p` for host elapsed measurements and record resolution.
   Run a fixed warmup followed by at least 20 measured warm samples per
   selected lane, sequentially to avoid self-contention. Report median, p95,
   sample count, status, and observed Podman-call counts. Report cold first-use
   separately; do not delete images or force builds/pulls to create it.
7. Where existing Podman events are available, correlate only benchmark
   containers and collect bounded `create/start/died/cleanup/remove` events.
   Describe event intervals as approximations to lifecycle phases. Do not
   subtract guest/VM wall timestamps from host timestamps, enable verbose
   inspect payloads, or change event configuration. When unavailable, report
   combined startup/execution/cleanup cost and the attribution limitation.
8. Define the minimum association predicate and keep its two evidence products
   separate. The predicate must cover invoking profile identity and active
   record, strict binding, absence of routing overrides, expected effective
   target, an explicit derived connection on each host under the candidate
   invariant, rootless local-service identity on Linux, and the applicable
   current registry policy. Record the current Linux no-named-connection path
   as a baseline, not as proof of the candidate. A benchmark-only probe may
   read state and make safe Podman inspection calls but may not alter installed
   profiles, enable services, create or adopt connections, change a default,
   or bypass checks in ordinary wrappers; only that probe can verify whether
   the predicate is satisfied. Separately, use a component-cost model built
   from current validated helpers when a probe is unavailable or incomplete;
   the model may estimate timing and removable work but must not be reported as
   proof of authority. Mark each required Podman request and explain whether it
   proves routing, identity, or only reachability. If a complete authority proof
   cannot be demonstrated without the live `info` request, retain that request
   in the candidate cost and label any proposed reduction unverified.
9. Record the measured inputs needed for later design comparison: observed
   removable costs, call graph, shell parsing/hash/subprocess residual, and
   measurement uncertainty. Do not rank alternatives or claim modeled speedups
   in this chunk; Chunk 3 owns that analysis.
10. Produce a common use-case summary with measured baselines and clearly
    labeled extrapolations: (a) one new shell using an already-active profile
    for one `rg` and one `jq`; (b) one shell running 40 `rg` plus 40 `jq`
    invocations sequentially in a tight loop; and (c) that same 80-command
    workload after one measured activation. Show `A`, shell-selection time,
    current per-command check, container/tool time, total wall time, percent
    spent in checks, and the per-invocation amortized share of `A`. Reserve
    candidate checks, projected savings, and sandbox-policy comparison for
    Chunk 3. Report at least one longer-run sensitivity example (for example
    400 invocations). Time one actual sequential 80-command run where the
    selected host and approvals permit; compare it with the formula's result
    and explain contention or drift.
11. Record baseline evidence needed for later discovery without selecting a
    strategy: original statuses and observed failure boundaries, current `exec`
    behavior, stdin/TTY/redirection conditions, and any unavailable sandbox or
    native-host lane. Do not deliberately repeat known denied operations.
12. Preserve all raw timing records privately and summarize reproducible
    aggregate baseline results, environment provenance, call counts, and stated
    limitations in this plan. The subsequent discovery chunk consumes this
    evidence.

### Verification checklist

- [x] The benchmark produces attributable records and equivalent jq results
  for individual and batched input. Check timing aggregation with fixed sample
  records, then validate actual execution using live Podman.
- [x] Compare measured preflight call counts with the path-specific inventory;
  explain discrepancies rather than forcing a predetermined count.
- [x] Report actual activation, dry-run, and shell-selection timings as distinct
  baselines with exact transition state. If a first/start or switch transition
  is unmeasured, state that limitation and its effect on session estimates.
- [x] Verify the minimum association candidate against active profile,
  binding, effective derived connection on every available host, overrides,
  rootless Linux service identity, and registry policy using existing authority
  fixtures when a benchmark-only probe is available; report which predicate
  fields and outcomes were actually verified. Do not create a Linux service or
  connection merely to satisfy this benchmark.
- [x] Report the candidate's measured cost only for verified probe executions.
  If the probe is unavailable or incomplete, report a separately labeled
  component-cost model for timing and removable-work estimates, and state that
  the model does not verify authority behavior.
- [~] Show the 1+1, 40+40, and longer-run session estimates with assumptions,
  activation charged zero or once as appropriate, check share, and modeled
  sandbox outcomes. The Darwin 80-command loop is complete; Linux has a
  completed instrumented 80-command loop, while the uninstrumented loop and
  full 400-invocation sensitivity lane were explicitly stopped after severe
  long-run drift was established.
- [x] Record native Apple Silicon macOS and Linux amd64 evidence, or mark each
  unavailable lane partial with impact and an explicit deferral request.
- [x] Record sandbox-versus-escalated evidence or its absence truthfully, with
  exact operation, approval outcome, status, and source provenance.
- [x] Baseline report distinguishes measured intervals from modeled session
  extrapolations and records every unavailable or unverified lane for Chunk 3.
- [~] Run affected focused groups, then the full `./tests/test.sh` at the final
  integration gate with default bounded parallelism. Separately parse the new
  executable with `dash -n`, verify its mode, and run context/inventory and
  `git diff --check` validation. Benchmark sampling itself stays sequential.
  `/bin/sh -n`, context-tree validation, and `git diff --check` passed for the
  Linux continuation; `dash` is not installed on that host.

Apple Silicon is complete and Linux amd64 current-path evidence is now
recorded. The Linux host reported a local/shared binding with no default
connection, no rootless API socket, and no compatible named connection, so the
explicit-connection-only lanes were correctly recorded as unavailable rather
than forcing a failing benchmark. The full suite still stopped during
lifecycle-template setup because the source checkout contains pre-existing
ignored `.agents/skills` and metadata content; no full group run executed, and
the benchmark did not remove user-owned ignored files. A focused four-group
retry previously reproduced the known `commands-shim` no-output stall and was
interrupted. The remaining `lib-runtime`, `lib-profile-activation`, and
`commands-agent-preflight` focused run passed all 16 assertions. `/bin/sh -n`
passed on the Linux host. `dash` is not installed in this environment, so its
parser check was unavailable here rather than falsely reported as passed.
Executable mode, context-tree validation, and `git diff --check` still remain
required at the final integration gate.

### Human review gate

Review the current-system measurements, observer overhead, native coverage, and
all unavailable lanes. Accept the baseline dataset only if its provenance,
workload, and limitations are sufficient for a later comparison. Do not select
or implement an optimization at this gate.

## Chunk 2 investigation — activation dry-run and wrapper timing

### Benchmark-only Podman forwarding proxy

The source-only benchmark creates a private executable named `podman` in its
private output directory and prepends that directory to `PATH` only for the
measured wrapper process. The proxy invokes the resolved real Podman binary
with the original argument vector and preserves its stdout, stderr, and exit
status. It records only benchmark lane, ordinal, phase label `podman`, elapsed
whole seconds, and status. It does not record arguments, environment values,
connection URIs, image references, or credentials; it does not synthesize a
result, alter routing, or bypass agent approval.

Its purpose is call attribution. A one-warmup/one-sample smoke on this Linux
host observed two Podman calls for each `rg --version` and `jq --version`, eight
for four separate jq JSON inputs, and two for the equivalent one-command
four-file jq input.

### Call and ownership review seam

On 2026-09-18, the reviewer authorized a narrow continuation of Chunk 2: add
dormant helper stubs, contract documentation, caller mapping, and disposable
baseline measurements without changing live behavior or running unit tests.
`lib/runtime/preflight-review.sh` mirrors the exact current split between
binary/platform/profile-context work and the final generic reachability probe.
No production module sources it. `tests/runtime-benchmark.sh --review-only`
is its only intended caller during this review.

The caller inventory found 23 preview-aware version runtimes and four
conditional direct-preflight runtimes. All 27 version runtimes end through
`shimmy_podman_run_or_preview`. Thirteen runtimes can add another preflight via
local-image resolution. The Skopeo registry mount is the only runtime policy
consumer that can reuse same-process Darwin affinity evidence. Management
status and activation share the broader `shimmy_profile_state_read`, so that
collector cannot be narrowed as a runtime-only optimization.

The review lanes compare the unchanged full preflight, the dormant context
split, current affinity alone, and the dormant final reachability probe. They
do not implement or prove the minimum association predicate. The committed
benchmark stores no measurements; raw output remains in a private disposable
directory and aggregate observations belong below after execution.

The authorized Apple Silicon run used three warmups and 20 measured samples per
lane. Provenance was Darwin arm64, Podman 5.8.1, default connection
`shimmy-default`, checkout `HEAD`
`e405736924930dbf2fd71c8c2b90be953dd042c8`, dirty benchmark blob
`c47880bc36c641ccac20cf46f486a5daf5f5c2f7`, dirty review-helper blob
`315a066d550cbaad32d76f9d768d731dc805fa8a`, and active-profile installed
control commit `e920810ff61d29625f0000ec5939e2f804059bf7`.

| Review lane | Median | p95 | Podman calls/sample | Status |
| --- | ---: | ---: | ---: | --- |
| Unchanged full preflight | 0.576 s | 0.598 s | 5 | 20/20 zero |
| Dormant context split | 0.476 s | 0.483 s | 4 | 20/20 zero |
| Current affinity alone | 0.464 s | 0.479 s | 4 | 20/20 zero |
| Dormant final reachability split | 0.095 s | 0.101 s | 1 | 20/20 zero |

The transparent proxy recorded 322 successful Podman calls including warmups:
115 full, 92 context, 92 affinity, and 23 reachability. Each aggregate sample
file contains exactly 20 records, confirming that warmups were excluded.

This is a partial, source/installed-hybrid baseline. The runtime and dormant
review helpers came from the dirty checkout, while profile state helpers came
from a different installed control commit. The proxy's observer cost was not
compared with an uninstrumented review lane, and separately timed medians are
not additive. No Linux amd64 lane, wrapper/container lane, activation lane, or
minimum-association authority proof was added under this authorization. Per the
reviewer's direction, no unit tests were run.

### Activation dry-run finding

On 2026-09-17, the apparent benchmark stall was traced to
`profile activate default --dry-run`, not shell initialization, the timing
harness, or a Podman engine request. The benchmark initially treated that
one-time activation baseline as a normal lane with three warmups and 20
samples. At roughly 26 seconds each, it could consume about ten minutes before
repeated wrapper measurements began.

The benchmark now invokes this same-profile dry run once. It is recorded as
one-time activation baseline `A`, separately from repeated per-wrapper lanes.
The dry run performs no mutation, starts no engine, and made zero proxied Podman
calls in this measurement.

A direct timing measurement found `profile --help` at 0.010 seconds and
`profile activate default --dry-run` at 23.051 seconds wall time, with 10.341
seconds user CPU and 6.588 seconds system CPU. This profile indicates local
validation and child-process work rather than a remote engine wait.

The same installed control source was loaded into a non-mutating timing driver
and its activation path was measured sequentially:

| Discrete step | Elapsed | Observed work |
| --- | ---: | --- |
| Installation context resolution | 9.653 s | Catalog-tree authority validation; installation/profile path validation; active-record and user skill-root validation; active profile candidate resolution. |
| Prior-engine validation | 0.001 s | Same-profile fast path. |
| Requested candidate resolution | 6.612 s | Catalog authority and selected-profile manifest, source/catalog, binding, registry, startup, and profile-state validation. |
| AI-skill reconciliation preflight | 3.528 s | Control/tool bundle, declared-destination, and active user skill-root validation. |
| Human AI-skill plan rendering | 1.253 s | Render current link actions. |
| Engine context resolution | 0.012 s | Read selected binding and local engine context. |
| Activation dry-run decision | 1.003 s | Evaluate the no-mutation activation path. |
| Manifest AI-skill plan rendering | 1.345 s | Render machine-readable current link actions. |
| Instrumented subtotal | 23.407 s | Sum of the staged timings. |

Separate end-to-end samples ranged from 23.051 to 28.553 seconds. The staged
subtotal and the end-to-end range differ because nested shell utilities and
normal scheduling/process-start overhead are not separately attributed by this
coarse driver. The two repeated catalog/profile-validation passes account for
16.265 seconds of the 23.407-second staged subtotal. The later discovery chunk
must classify their internal catalog fingerprinting, manifest validation,
filesystem traversal, and subprocess costs before proposing a reduction; this
finding does not authorize weakening activation authority validation.

After the one-time baseline correction and timed-child environment preservation
fix, a one-warmup/one-sample smoke completed with these aggregates:

| Lane | Observed result |
| --- | --- |
| Shell selection | 0.007 s; zero Podman calls. |
| Already-active activation dry run | 28.553 s; one sample; zero Podman calls. |
| `rg --version` | 2.531 s median; two Podman calls per invocation. |
| `jq --version` | 2.522 s median; two Podman calls per invocation. |
| Four individual jq inputs | 10.960 s median; eight Podman calls per invocation. |
| One batched four-file jq command | 2.402 s median; two Podman calls per invocation. |

This smoke is implementation evidence, not the required 20-sample baseline or
a replacement for native macOS evidence.

## Chunk 2 investigation — Apple Silicon completion baseline

On 2026-09-19, the remaining feasible Darwin arm64 lanes ran against Podman
5.8.1 and active profile `default`, bound to machine and named connection
`shimmy-default`. The checkout commit was
`9dee18c419d87efb38d7d36a0920de6b8a6e58c1`; the extended benchmark ran from a
dirty checkout with benchmark blob
`3d35f08190974bf32b14eba9caf0e521354ffdf9`. The installed control commit was
the distinct older commit `e920810ff61d29625f0000ec5939e2f804059bf7`.
Installed helper/runtime blobs and exact rg/jq image digests are retained in
the private provenance record. This distinction matters: the benchmark driver
and installed runtime were not inferred to be the same source revision.

The complete workload run used three warmups and 20 measured warm samples.
All measured statuses were zero, individual and batched jq outputs were
equivalent after preserving and sorting record identifiers, and warmups were
excluded from aggregate files.

| Workload lane | Median | p95 | Podman calls/sample |
| --- | ---: | ---: | ---: |
| Shell selection | 0.007 s | 0.008 s | 0 |
| Activation dry run (one sample) | 33.677 s | 33.677 s | 0 |
| Installed `rg --version` | 1.409 s | 1.499 s | 6 |
| Installed `jq --version` | 1.419 s | 1.510 s | 6 |
| Four individual jq inputs | 5.222 s | 5.319 s | 24 |
| One batched four-file jq command | 1.305 s | 1.363 s | 6 |

The six wrapper calls are five successful-path pre-run calls plus the final
container run. The direct equivalent used the same installed image digest,
native platform, `$PWD:/work` mount, `/work` working directory, and `-i` stdin
mode. Images were already present; the benchmark did not force a pull.

| Extended lane, 20 samples | Median | p95 | Podman calls/sample |
| --- | ---: | ---: | ---: |
| Installed full preflight | 0.508 s | 0.521 s | 5 |
| Installed Darwin affinity | 0.406 s | 0.414 s | 4 |
| Machine list | 0.025 s | 0.026 s | 1 |
| Connection list | 0.022 s | 0.023 s | 1 |
| Explicit-connection workload `ps` | 0.077 s | 0.086 s | 1 |
| Unqualified `info` | 0.094 s | 0.100 s | 1 |
| Explicit `shimmy-default` `info` | 0.094 s | 0.097 s | 1 |
| Direct equivalent rg container | 0.849 s | 0.898 s | 1 |
| Direct equivalent jq container | 0.722 s | 0.747 s | 1 |
| Uninstrumented installed rg wrapper | 1.352 s | 31.862 s | not observed |
| Uninstrumented installed jq wrapper | 1.243 s | 1.426 s | not observed |
| Benchmark-only minimum association | 0.352 s | 0.363 s | 3 |

The unqualified and explicit `info --format` payloads were identical for every
sample, so both selectors reached the same observed rootless remote host and
graph root. Their medians were equal; no selector increment was measurable at
the timer's 1 ms resolution. Separately measured medians are not additive, but
the five individual probe medians total 0.312 s versus the 0.508 s full
preflight, leaving about 0.196 s of local validation, parsing, hashing,
subprocess, and scheduling residual. Affinity's four constituent probes total
0.218 s versus 0.406 s, leaving about 0.188 s on the same non-additive basis.

The benchmark-only minimum-association lane validated the installed manifest
identity, active record, strict shared-engine binding, expected machine and
derived named connection, absence of connection and registry overrides,
current engine registry projection, running expected machine, rootless named
connection, matching default connection, and explicit `true|true`
rootless/remote target response. It deliberately omitted workload `ps` and the
final unqualified `info`, but retained machine list, connection list, and live
explicit `info`; therefore its 0.352 s result is a verified three-call Darwin
probe, not a health-free authority proof or a production implementation.

The activation dry run reported no service recycle, VM restart, workload stop,
profile switch, or skill-link replacement. The reviewer then authorized the
exact command
`/Users/wade/.config/shimmy/profiles/default/bin/shimmy profile activate default`.
It succeeded in approximately 31 seconds by the execution adapter's coarse
wall clock. This is an already-active reassertion, not bootstrap, machine
start, or profile-switch evidence.

The actual 40-rg/40-jq uninstrumented session completed in 102.689 s. The
median formula `shell + 40 × (rg + jq)` gives 103.807 s, 1.118 s (1.1%) above
the actual sequence. Adding the approximately 31 s already-active activation
gives about 133.696 s; activation is about 23.2% of that session and amortizes
to about 0.388 s per invocation. One already-active shell plus one rg and one
jq is 2.602 s by the same median model. Two full-preflight medians are about
39% of that modeled 1+1 total and 40 full-preflight pairs are about 39.6% of
the measured 80-command session; these are component-share models, not
instrumented subtractions from the session wall time.

A median-only 200-rg/200-jq sensitivity model is 519.007 s including shell
selection and no activation. It is an extrapolation, not an actual longer run.
No sandbox-denial cost was added: after the initial sandbox-only status result,
the approved outer benchmark path was used directly and a deliberately denied
wrapper sequence was not repeated. The later design comparison must keep that
unknown separate rather than inventing `qR`.

The instrumented 80-command sequence also completed, in 1,026.911 s with all
480 expected Podman calls successful. Thirty calls took about 31 seconds each,
recurring as the first call in six-call wrapper sequences. This temporal tail
also appeared in the final four uninstrumented rg samples, despite ordinary
1.3-second medians. The later uninstrumented 80-command sequence returned to
102.689 s. Consequently the 1,026.911-second result is retained as real
sensitivity/drift evidence, not attributed solely to proxy observer overhead.
At the reviewer's direction, the subsequent 200-rg/200-jq lane was stopped
before it produced a sample because the completed normal and degraded 80-call
sequences adequately bound the current design questions.

A stable-source one-sample event lane correlated one benchmark jq container
and returned six events with zero command/query statuses: `create`, `init`,
`attach`, `start`, `died`, and `remove`. All carried the same coarse engine
timestamp, so the engine exposes lifecycle ordering but not useful sub-second
phase attribution for this workload. No event configuration was changed.

Sandbox-only profile status first reported the engine as unknown/unreachable.
The exact outer benchmark and activation commands were then approved and
succeeded outside the sandbox. This strengthens attribution to the execution
boundary and does not establish an engine failure. No profile, connection,
default, registry policy, image state, or event configuration was changed by
the benchmark. Native Linux amd64 and genuine first/start or profile-switch
activation remain unavailable; they are explicit deferred lanes rather than
zero-cost results.

## Chunk 2 investigation — Linux amd64 continuation

On 2026-09-19, a native Linux x86_64 host completed the missing current-path
baseline against Podman 5.8.2 and active profile `default`. The source checkout
commit was `777b081210ccd29345798aaa09fad6e0e20962ca`; the benchmark driver ran
from the same dirty checkout with benchmark blob
`6443c577683e8f02bb58b21ff2d37002098a3660`. The active installed profile kept a
distinct control commit `3089f168655f15a6de0ffac316d2453034c16c4e`. The strict
binding was installation-shared `local`/`local`, the Podman default connection
was `none`, the user rootless API socket path
`/run/user/1000/podman/podman.sock` did not exist, and no compatible named
connection was present. The Linux continuation therefore extends the benchmark's
host support and baseline inventory, but it does not make the cross-platform
explicit-routing candidate enforceable.

The 20-sample Linux workload run used three warmups and 20 measured warm
samples. All statuses were zero and the individual-versus-batched jq records
remained equivalent after preserving and sorting record identifiers.

| Linux workload lane | Median | p95 | Podman calls/sample |
| --- | ---: | ---: | ---: |
| Shell selection | 0.007 s | 0.012 s | 0 |
| Activation dry run (one sample) | 30.805 s | 30.805 s | 0 |
| Installed `rg --version` | 2.075 s | 2.239 s | 2 |
| Installed `jq --version` | 1.976 s | 2.132 s | 2 |
| Four individual jq inputs | 7.982 s | 8.271 s | 8 |
| One batched four-file jq command | 2.031 s | 2.220 s | 2 |

The dry run reported `would_change=nothing`. The exact same-profile activation
command `/home/beewa/.config/shimmy/profiles/default/bin/shimmy profile activate
default` then completed successfully in 56.443 s wall time, with 25.831 s user
CPU and 17.202 s system CPU. This is an already-active reassertion only; it is
not bootstrap, initial Linux service setup, or a profile switch.

A second 20-sample extended Linux run completed every host-applicable lane
before the user-authorized early stop. All measured statuses were zero.

| Linux extended lane | Median | p95 | Podman calls/sample |
| --- | ---: | ---: | ---: |
| Installed full preflight | 0.707 s | 0.743 s | 1 |
| Installed runtime affinity helper | 0.014 s | 0.018 s | 0 |
| Connection list | 0.028 s | 0.036 s | 1 |
| Unqualified `info` | 0.649 s | 0.737 s | 1 |
| Direct equivalent rg container | 1.353 s | 1.595 s | 1 |
| Direct equivalent jq container | 1.312 s | 1.492 s | 1 |
| Uninstrumented installed `rg --version` | 1.994 s | 2.150 s | not observed |
| Uninstrumented installed `jq --version` | 1.994 s | 2.090 s | not observed |
| Benchmark-only Linux current-path association baseline | 0.749 s | 0.856 s | 1 |

The Linux current-path association baseline validated installed manifest
identity, the active record, strict shared `local`/`local` binding, absence of
connection and registry overrides, the current Linux registry active link, and
an unqualified `true|false` rootless/local `podman info` response. It is a
verified current-path baseline only. Because the host had neither a rootless API
socket nor a compatible named connection, the explicit-connection-only lanes
were recorded as unavailable: `probe-machine-list` and `probe-workload-ps`
were not in the Linux runtime path, while explicit `info` could not run against
an absent named connection.

For Linux current-path comparison, the benchmark-only association baseline was
slower than today's eager preflight: `0.749 s` versus `0.707 s`, a `0.042 s`
(5.9%) increase. The current Linux path therefore provides no measured
successful-path saving before any new named-connection lifecycle exists. The
wrapper-minus-direct medians were `0.641 s` for `rg` and `0.682 s` for `jq`.

The Linux median-only session models are:

| Linux session model | Result |
| --- | --- |
| One already-active shell plus one `rg` and one `jq` | 3.995 s by median model. |
| Median formula for one 40 `rg` + 40 `jq` sequence | 159.527 s. |
| Add one already-active activation to that 80-command session | 215.970 s total, with activation about 26.1% and about 0.706 s amortized per invocation. |
| 200 `rg` + 200 `jq` sensitivity model | 797.607 s; extrapolation only. |

Using the measured Linux full-preflight median, pre-execution checks account for
about 35.5% of the modeled 80-command session. The instrumented Linux 40-rg/40-
jq sequence completed in 765.473 s with 160 proxied Podman calls, establishing
severe long-run drift under sustained proxy measurement. The user then
explicitly authorized ending the remaining baselining early as soon as the
requirement had sufficient evidence. The subsequent Linux uninstrumented 80-
command loop, the 400-invocation sensitivity completion, and the final extended
run event pass were stopped rather than presented as missing or zero-cost data.
A prior one-warmup/one-sample Linux smoke confirmed event availability with six
ordered events and zero event-command/query statuses.

## Chunk 3 — Alternate-design discovery and selection

### Goal

Use the accepted baseline to produce comparable alternate runtime designs and
select the smallest design with an explicit authority proof. At least one design
must implement Decision 2: retain authority validation while moving status-only
work and redundant health probes off the successful path.

### Requirements

1. Produce a design matrix for the current eager path, Decision 2's minimum
   association check, explicit derived-connection routing, guarded
   execution-first supervision, and any batching/reuse proposal that remains
   viable after baseline evidence. State authority preserved/lost, changed
   failure behavior, approval boundary, compatibility, implementation surface,
   rollback, and predicted cost using only accepted baseline data.
2. For every candidate, name each retained Podman request and whether it proves
   profile authority, routing, policy, reachability, or status. Do not call a
   request redundant solely because another command succeeded.
3. Produce the execution-first failure decision table, including tool nonzero,
   denial before dispatch, connection failure, uncertain response, image/setup
   failure, signals, stdin, TTY, partial output, and redirection. Preserve the
   original result and prohibit automatic replay.
4. For any supervisor candidate, specify process groups, signals, stream
   forwarding, buffering, cleanup, and `set -e` behavior. For an explicit
   connection candidate, show how the binding supplies the selector without
   accepting user input or relying on a mutable default.
5. Select one primary design and, if justified, one fallback. Record why the
   rejected designs lack authority proof, benefit, or acceptable complexity.
   The Linux service/connection lifecycle issue remains post-plan unless the
   selected design requires it.

### Deliverables and review gate

Update `docs/runtime-preflight.md` with the accepted baseline, design matrix,
selected design, and explicit assumptions. Human review accepts the selection
only; it does not authorize code changes.

## Chunk 4 — Implementation handoff

### Goal

Translate the accepted discovery choice into an independently reviewable
implementation plan without implementing it in this assessment plan.

### Requirements

1. Create a follow-up plan under `plans/wip/` that names the selected behavior,
   exact source/install/test/documentation files, positive acceptance outcomes,
   rollback, and installed-profile adoption boundary.
2. Preserve the approved authority, approval, replay, secret-redaction,
   POSIX-shell, `exec`, and platform contracts, or make each deliberate change
   explicit for review.
3. Carry forward every prerequisite. In particular, if the selected design
   requires Linux named explicit routing, include the unresolved Linux
   `podman.socket`/connection lifecycle decision as a separate post-plan work
   item; this assessment does not enable a service, add/adopt a connection, or
   mutate a default connection.
4. Define the future-system benchmark protocol: same benchmark revision,
   workload, warmup/sample count, host/profile/image provenance, and reporting
   method as the accepted baseline, with deviations reported rather than hidden.

### Human review gate

Review and accept the implementation handoff separately. Its implementation is
owned by that follow-up plan. Completing this handoff does not complete the
present plan or authorize Linux Podman provisioning.

## Chunk 5 — Future-system timing and delta report

### Entry condition

Start only after the accepted implementation handoff has been implemented and
its own acceptance tests have passed. Record its commit, installed-profile
provenance, and any configuration transition before benchmarking.

### Goal and requirements

1. Re-run the accepted benchmark protocol against the future system without
   forcing pulls, builds, service changes, or connection provisioning.
2. Report per-lane current-versus-future median, p95, sample count, call count,
   absolute delta, percent delta, and changed authority properties. Compare one
   actual 80-command sequence with its session model.
3. Treat a changed host, image state, Podman version, connection topology, or
   unavailable lane as a comparison limitation; do not present it as an
   improvement. Keep raw records private and publish aggregate evidence only.
4. Confirm that the implemented behavior matches the selected design and its
   handoff acceptance criteria. If it does not, return to the implementation
   plan rather than relabeling the result.

### Final review gate

Review the delta report, authority behavior, cross-platform coverage, and all
limitations. Only this gate may complete and move this plan to
`plans/complete/wrapper-preflight-strategy.md`.

## Risk register

| Risk | Consequence | Handling |
| --- | --- | --- |
| Success against wrong authority | Silent use of another profile or policy | Keep authority distinct from reachability; full optimism needs a changed enforcement design. |
| Ambiguous failure and replay | Duplicate writes, API effects, consumed input, repeated output | Preserve the first result; no automatic replay in this plan. |
| Changing `exec` to a supervisor | Signal, TTY, stdin, and exit-status regressions | Assess explicitly; implement only through a later reviewed contract. |
| Blanket sandbox-first rule | Known-denied attempts add latency every time | Separate first discovery from reuse of active-session evidence. |
| Stale cache or connection race | Validation no longer describes execution | Prefer minimal same-invocation work; model explicit routing and invalidation, with remaining races stated. |
| Linux explicit-routing prerequisite is absent | A universal invariant either breaks current supported hosts or causes Shimmy to provision user Podman state implicitly | Treat named local-service connection availability as measured evidence. Do not enable `podman.socket`, create/adopt a connection, or change a default until a later lifecycle contract explicitly authorizes and owns those transitions. |
| Benchmark changes the system under test | Misleading apparent speedup | Transparent real-Podman forwarding and instrumented/uninstrumented comparison. Any activation timing is a separately reported, dry-run-cleared, exact authorized action. |
| Activation baseline conflates unlike transitions | A cheap already-active run understates first activation or machine startup | Name each transition, keep dry-run and shell selection separate, and mark unmeasured native transitions unavailable. |
| Session extrapolation hides startup or tail cost | Wrong usability prediction for repeated agent calls | Show cold/warm data, one-time `A`, per-call `R/M`, 80-command measured comparison, and distinct sandbox cases. |
| Historical plans or installed-source drift | Wrong call-count and validation claims | Anchor source and installed datasets to exact provenance. |
| New diagnostics reveal sensitive values | Credentials or private endpoints in output | Use validated names and existing facts; omit raw stderr/argv capture from the first change. |
| Incomplete native or sandbox evidence | Overgeneralized performance or correctness claims | Surface partial verification and require explicit reviewer disposition. |

## Lessons learned

### Initial

- The incident correctly motivates an execution-boundary distinction, but its
  simplified call graph is not a complete current runtime inventory.
- Current Darwin runtime status collection includes work that is potentially
  separable from invocation authority. This offers an alternative to caching.
- Projection checks in the current source read local persisted evidence;
  historical descriptions of remote inspection must not drive new designs.
- Error-first diagnosis and error-first replay are separate features with
  different correctness requirements.
- Already-approved escalation can avoid repeated failed attempts without
  caching any engine-health or profile-authority result.
- `shell-init.sh` selects the invoking profile's PATH, while activation
  establishes installation and engine authority. An agent opening a new shell
  does not imply another activation, so usability estimates need both an
  already-active and a newly activated session.
- Podman supports named system connections for service destinations, including
  a Linux rootless API socket. That capability does not make a named connection
  part of the current Shimmy Linux contract or transfer ownership of user
  service and connection state to Shimmy.
- Explicit runtime routing should be derived from the strict profile binding,
  not accepted as user-selected wrapper input; otherwise it weakens the
  authority boundary it is intended to enforce.

### Chunk 1

- Shared runtime hints must describe sandbox evidence conditionally as
  `unverified from the sandbox`; they cannot claim the engine is inactive
  without an outer-wrapper retry or other stronger evidence.
- `commands/agent-preflight.sh` is source-only approval discovery, not an
  engine-free preview. The docs must keep it separate from `--preview-shim`
  examples that avoid Podman entirely.
- Updating `lib/runtime/podman.sh` changes future materialization through the
  existing profile lib copy/archive paths, but existing installed profiles do
  not adopt that helper until an explicit profile sync or other rematerializing
  lifecycle action.
- Dash is not available by default on macOS, so Dash parser checks remain
  exercised where available but do not block portable host verification.

### Chunk 2

- The host exposes `time` only as a Bash keyword and its POSIX `/bin/sh`
  cannot invoke it. The measurement harness therefore invokes Bash explicitly
  and must not pass `-p`; the benchmark workloads remain POSIX `sh`.
- Warmup invocations must not remain in the sample file used for median, p95,
  and sample-count aggregation. The review work resets each lane's sample file
  after warmup while retaining proxied call records for private diagnostics.
- Runtime affinity is not owned solely by runtimes: Skopeo may request it again
  for registry mount policy, while the underlying profile state reader also
  serves management status, activation, and redirect inspection. Any later
  minimum runtime predicate needs its own contract instead of weakening the
  shared status collector.
- On this Darwin host, unqualified and explicit `shimmy-default` information
  probes reached the same target at the same 94 ms median. The selector itself
  was not a measurable cost, but explicit routing still needs an authority
  contract rather than a timing argument.
- A three-call benchmark-only association predicate can validate the active
  profile, binding, overrides, projection, named connection, machine state,
  and live explicit target in about 0.352 s median. It still contains liveness
  work and is not evidence that a health-free production check is sufficient.
- On Linux, a host-local rootless `local`/`local` binding with no rootless API
  socket or compatible named connection must not make the benchmark fail. The
  correct evidence is to record explicit-connection-only lanes as unavailable
  and keep the current no-named-connection path separate from any explicit-
  routing candidate.
- The Linux current-path association baseline measured `0.749 s` versus
  `0.707 s` for today's eager preflight. That is a `0.042 s` regression, not a
  candidate saving, so Linux should remain on the current path until a named
  rootless service and connection lifecycle is separately designed and proven.
- Sequential measurements exposed a repeatable approximately 31-second first
  Podman-call tail after sustained sampling. Median formulas matched the later
  uninstrumented 80-command run within 1.1%, while the instrumented sequence
  was almost ten times slower. Preserve both results: observer and temporal
  engine state cannot be separated by subtracting those two session totals.

### Chunk 3

- The measured three-call Darwin association predicate becomes a credible
  production candidate only when the final runtime request is bound to that
  same validated connection. Without explicit runtime routing, the later
  unqualified `run` can still drift from the probe.
- Explicit routing is therefore a correctness ingredient, not merely a
  performance tweak. The accepted equal-cost explicit and unqualified `info`
  probes justify carrying that selector into the design, but not claiming a
  benefit on Linux without a separate connection lifecycle contract.
- Caller batching can materially outperform wrapper-preflight optimization for
  naturally batchable workloads, but that evidence belongs to caller guidance,
  not to a generic hidden-session or broker redesign.

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, this plan, and retained
contexts on each changed path. Read the active chunk's files and canonical
skills. Recheck worktree and source/installed provenance.

Chunks 1 and 2 are accepted. Preserve POSIX shell, authority checks,
approval scope, installed profile ownership, stdin/stdout/stderr and `exec`
behavior while Chunk 3's selected design awaits human acceptance. Chunk 4 hands
that design to a separate implementation plan, and Chunk 5 reports the
future-system delta after that plan is accepted and implemented.

This plan does not authorize implementation of any execution strategy. It
completes only after the separate implementation handoff is accepted and the
post-implementation delta report is reviewed.
