# Wrapper preflight and execution strategy

## Objective

Improve wrapper failure guidance, measure invocation overhead, and evaluate a
broader execution strategy, including commands that run before reachability
preflight or agent escalation. Produce an evidence-backed recommendation before
changing the production execution policy.

Make the minimum useful runtime check an explicit target: activation establishes
which profile owns the intended engine; an invocation verifies that its shell's
selected profile still matches the active profile and effective Podman target.
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
- A reviewer can choose the next optimization with its authority, retry,
  compatibility, and performance consequences stated.

This plan authorizes no implementation yet. Its proposed implementation scope
is diagnostic guidance plus measurement and assessment tooling. Changing the
default preflight or escalation policy, adding automatic replay, introducing a
public session/cache interface, and deploying or synchronizing installed
profiles require a subsequent concrete design and review. POSIX shell remains
the implementation architecture. Podman lifecycle and registry ownership stay
with the existing control plane.

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
   active record, its strict binding names the effective Podman machine and
   connection, no override diverts execution, and relevant registry routing
   still belongs to that profile. Whether the engine is reachable belongs to
   execution or failure diagnosis. A successful command can use the wrong
   profile or policy, so success alone cannot replace authority validation.
   On Linux, use the equivalent active profile, local rootless engine, and
   registry-link association; there is no Shimmy-managed machine.
3. Measure association checks independently of status collection. The
   candidate may need connection/machine metadata but need not collect running
   workloads or make a health request if execution itself can report a stopped
   or unreachable engine. Explicitly evaluate running against the validated
   connection instead of relying on a global default that can change between
   check and execution. A name match without validated binding and routing is
   insufficient.
4. Preflight and escalation are independent policy dimensions. An unknown
   environment may benefit from one sandbox-first attempt. A known denial
   makes repeated sandbox attempts predictably wasteful. Current approved
   wrapper-first escalation instructions remain operative during this work;
   theoretical exploration is not permission to alter them or evade approval.
5. No automatic replay is implemented. Diagnose infrastructure failures
   separately from tool results. Even a safe read may have consumed stdin or
   partially emitted output; a write or remote request may already have taken
   effect. Shell redirection can modify files before Podman starts.
6. Do not classify every nonzero result as an infrastructure failure. Search
   no-match, validation failure, user cancellation, and tool errors retain
   their semantics. Podman status 125 and stderr text alone are insufficient
   proof that no user work occurred. Missing container records are also not
   conclusive after automatic removal or lost connectivity.
7. Runtime guidance must not assert that a process is sandboxed when the
   runtime lacks that evidence. Use conditional agent guidance and report an
   undetermined cause when stderr was discarded. Permission denial is an
   observation; the same operation succeeding outside the sandbox strengthens
   attribution to the execution boundary.
8. For the first diagnostic change, improve existing renderers using facts
   already available. Do not add raw stderr capture, a regex-based cause
   classifier, new public diagnostic schemas, or argument logging. Detailed
   error transport and optional runtime instrumentation are assessed in
   Chunk 2, where their stream, confidentiality, and overhead costs are visible.
9. Preserve profile/engine schemas, activation and rollback behavior, source
   previews, native platform selection, privileged-connection validation,
   image acquisition/build policy, Skopeo registry capability, and final
   `exec` behavior. Existing local-build preflights remain in scope for the
   inventory, not implicit removal.
10. Activation is a one-time state transition, not part of every command. A
    newly opened shell selects a PATH with `shell-init.sh`; it does not perform
    activation. Report both session models: already activated before the shell
    opens (`A = 0` inside the session) and one measured activation followed by
    many invocations (`A` charged once). Never count the same activation 80
    times or treat a dry run as actual activation time.
11. The plan ends with a recommendation, not an automatically selected
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
| `lib/runtime/podman.sh` platform branch | Installed manifest checks precede a Darwin-only affinity branch. Ordinary Linux/source execution does not traverse the full Darwin state reader. Management Linux status has its own rootless/registry checks. Do not claim identical runtime enforcement across platforms. |
| `lib/runtime/image.sh` | Local-image resolution and stale-image cleanup can invoke preflight separately. A per-wrapper count depends on image strategy and execution path. |
| `tools/*/versions/*/run.sh` | Ordinary external-image versions share preflight; gh, gcloud, and OPNsense runtimes have additional conditional behavior. jq and rg provide small filter/search baselines. |
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
| Explicitly bind the run to a validated connection | Reduce dependence on mutable global default | An explicit connection selects transport; it does not authorize an inactive profile. Keep override and privileged-rootful behavior explicit. |
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
- Lost responses can leave callers uncertain whether work happened. Safe
  replay requires idempotency or reconciliation; a failure does not establish
  that nothing happened.
  [AWS retry design](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/).

## Unresolved

None.

Selecting a production execution strategy is the output of this plan, not an
undecided implementation branch within the diagnostic and assessment scope.
Native host availability and event support are verification prerequisites to
record during execution; unavailable evidence must be surfaced for explicit
deferral and must not be presented as a pass.

## Progress Checklist

Active state: PLAN complete; awaiting initial review. No implementation chunk
is active.

- [x] Confirm objective and planning root; discover related plans.
- [x] Trace runtime, status, installation, test, and guidance boundaries.
- [x] Assess the execution-first model and record alternative designs.
- [x] Define the minimum useful runtime association target and two timing
  baselines for later measurement.
- [ ] Chunk 1 — Align runtime and agent diagnostic guidance.
- [ ] Chunk 1 — Verify focused behavior and source/materialization boundaries.
- [ ] Human acceptance of Chunk 1.
- [ ] Chunk 2 — Measure activation and invocation costs; compare execution
  strategies and common session extrapolations.
- [ ] Chunk 2 — Verify measurement integrity and record native evidence.
- [ ] Human acceptance of Chunk 2 and disposition of the recommendation.

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

## Chunk 2 — Measurement and strategy assessment

### Goal

Produce reproducible, distinct baselines for establishing activation state and
checking it during each invocation. Quantify the candidate minimum association
check and common agent sessions, then rank the alternatives, including the
fully optimistic model, without installing an experimental runtime policy.

### Files

Primary changes: new `tests/runtime-benchmark.sh`, new
`docs/runtime-preflight.md`, `docs/testing.md`, and this plan. The existing
`tests/CONTEXT.md` remains the context for the source-only benchmark.

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
   version, control commit, tool version/image digest, engine mode, and image
   availability. Read exact manifests as data. Verify the selected launchers
   belong to the active profile; invoke installed wrappers by normal names.
   Treat source and installed versions as distinct datasets when they differ.
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
   explicit setup validation. Record the exact current Podman call graph per
   tool and platform. The direct-container sample is an experimental lower
   bound, not a replacement wrapper or fallback approval. Keep the same
   image, platform, mount, working directory, and stdin behavior. Never
   evaluate preview text with `eval` to construct commands.
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
   target, local rootless status on Linux, and the applicable current registry
   policy. A benchmark-only probe may read state and make safe Podman
   inspection calls but may not alter installed profiles or bypass checks in
   ordinary wrappers; only that probe can verify whether the predicate is
   satisfied. Separately, use a component-cost model built from current
   validated helpers when a probe is unavailable or incomplete; the model may
   estimate timing and removable work but must not be reported as proof of
   authority. Mark each required Podman request and explain whether it proves
   routing, identity, or only reachability. If a complete authority proof
   cannot be demonstrated without the live `info` request, retain that request
   in the candidate cost and label any proposed reduction unverified.
9. Analyze each alternative in the table using observed removable costs,
   authority preserved/lost, complexity, cross-platform behavior, and required
   evidence. Include shell parsing/hash/subprocess cost as the residual, with
   its measurement uncertainty. Distinguish measured comparisons from modeled
   speedups: this chunk does not silently suppress checks in production code.
10. Produce a common use-case summary with measured baselines and clearly
    labeled extrapolations: (a) one new shell using an already-active profile
    for one `rg` and one `jq`; (b) one shell running 40 `rg` plus 40 `jq`
    invocations sequentially in a tight loop; and (c) that same 80-command
    workload after one measured activation. Show `A`, shell-selection time,
    current per-command check, candidate minimum check, container/tool time,
    total wall time, percent spent in checks, projected saving, and the
    per-invocation amortized share of `A`. Report at least one longer-run
    sensitivity example (for example 400 invocations). Time one actual
    sequential 80-command run where the selected host and approvals permit;
    compare it with the formula's result and explain contention or drift.
    Include success, one known sandbox denial followed by authorized retry,
    and repeated denial on every command as separate modeled cases; never
    assume a failed first attempt is free or that approval persists.
11. Produce a concrete proposed failure decision table for an execution-first
   follow-up: success; ordinary tool nonzero; observed transport denial before
   dispatch; refused connection; uncertain/lost response; image acquisition;
   container setup; signal/cancellation. Identify original status, diagnostic
   action, retry eligibility, and evidence limits for each. Cover stdin pipes,
   partial output, outer redirection, interactive TTYs, and commands with side
   effects. A diagnostic failure must not overwrite the original result.
12. Compare retaining `exec` with agent-owned diagnosis against a shell
   supervisor that can inspect failures. Specify the supervisor's signal,
   process-group, stdout/stderr, buffering, cleanup, and `set -e` obligations
   before recommending it. Do not implement a supervisor in ordinary wrappers.
13. Evaluate sandbox-first behavior using genuinely unknown environments only
    where current permissions allow that experiment. Do not deliberately repeat
    a known denied installed-wrapper operation contrary to current guidance.
    If the host cannot reproduce the incident boundary, retain the handoff as
    reported evidence and mark live paired verification unrun. Synthetic
    classifier inputs cannot be labeled proof of real sandbox enforcement.
14. Rank at least the final-`info` removal, runtime/status split, and guarded
    execution-first variants against full optimism, batching, and reuse.
    Recommend the smallest change with demonstrated benefit and a stated
    authority proof. If none qualifies, recommend retaining current behavior.
    Give the preferred follow-up exact files, acceptance outcomes, compatibility
    implications, and rollback; bring it back for review before implementation.

### Verification checklist

- [ ] The benchmark produces attributable records and equivalent jq results
  for individual and batched input. Check timing aggregation with fixed sample
  records, then validate actual execution using live Podman.
- [ ] Compare measured preflight call counts with the path-specific inventory;
  explain discrepancies rather than forcing a predetermined count.
- [ ] Report actual activation, dry-run, and shell-selection timings as distinct
  baselines with exact transition state. If a first/start or switch transition
  is unmeasured, state that limitation and its effect on session estimates.
- [ ] Verify the minimum association candidate against active profile,
  binding, effective connection/local engine, overrides, and registry policy
  using existing authority fixtures when a benchmark-only probe is available;
  report which predicate fields and outcomes were actually verified.
- [ ] Report the candidate's measured cost only for verified probe executions.
  If the probe is unavailable or incomplete, report a separately labeled
  component-cost model for timing and removable-work estimates, and state that
  the model does not verify authority behavior.
- [ ] Show the 1+1, 40+40, and longer-run session estimates with assumptions,
  activation charged zero or once as appropriate, check share, and modeled
  sandbox outcomes. Compare one real 80-command loop when available.
- [ ] Record native Apple Silicon macOS and Linux amd64 evidence, or mark each
  unavailable lane partial with impact and an explicit deferral request.
- [ ] Record sandbox-versus-escalated evidence or its absence truthfully, with
  exact operation, approval outcome, status, and source provenance.
- [ ] Assessment distinguishes measured intervals, modeled estimates, and
  unverified hypotheses; every alternative has an authority and replay analysis.
- [ ] Run affected focused groups, then the full `./tests/test.sh` at the final
  integration gate with default bounded parallelism. Separately parse the new
  executable with `dash -n`, verify its mode, and run context/inventory and
  `git diff --check` validation. Benchmark sampling itself stays sequential.

### Human review gate

Review measurements, observer overhead, native coverage, all partial items,
and the recommended follow-up. Accept or revise the completed assessment.
Implementation of the recommended optimization requires a separately reviewed
concrete plan; it is not triggered by finishing these measurements. After final
acceptance, add the completion date below the title and move this plan to
`plans/complete/wrapper-preflight-strategy.md` without overwriting a collision.

## Risk register

| Risk | Consequence | Handling |
| --- | --- | --- |
| Success against wrong authority | Silent use of another profile or policy | Keep authority distinct from reachability; full optimism needs a changed enforcement design. |
| Ambiguous failure and replay | Duplicate writes, API effects, consumed input, repeated output | Preserve the first result; no automatic replay in this plan. |
| Changing `exec` to a supervisor | Signal, TTY, stdin, and exit-status regressions | Assess explicitly; implement only through a later reviewed contract. |
| Blanket sandbox-first rule | Known-denied attempts add latency every time | Separate first discovery from reuse of active-session evidence. |
| Stale cache or connection race | Validation no longer describes execution | Prefer minimal same-invocation work; model explicit routing and invalidation, with remaining races stated. |
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

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, this plan, and retained
contexts on each changed path. Read the active chunk's files and canonical
skills. Recheck worktree and source/installed provenance.

The next executable unit is Chunk 1, only after explicit implementation
approval. Move this plan from `notional` to `wip` before implementation. Preserve
POSIX shell, authority checks, approval scope, installed profile ownership,
stdin/stdout/stderr and `exec` behavior. Chunk 2 must time activation as a
one-time operation, the current runtime check per invocation, and the minimum
association candidate separately. Implement only the approved chunk, record
verification and lessons, and stop at its human review gate.

This plan is complete for diagnostic improvements and evaluation, not a blanket
authorization to implement any execution strategy in the alternatives table.
