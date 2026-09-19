# Runtime preflight baseline and design selection

## Review status

Chunk 2 baseline evidence is accepted. This document records that accepted
baseline, compares alternate runtime designs against it, and selects one design
for a later implementation handoff. It does not itself authorize production code
changes.

Current production behavior is unchanged:

- production runtimes still call `shimmy_podman_preflight_require` or the
  preview-aware wrapper;
- live execution still ends in `exec` from `shimmy_podman_run_or_preview`;
- no runtime automatically replays a failed operation; and
- no benchmark or review helper is sourced by a production runtime.

## Current contract

The live preflight order is:

1. Resolve Podman and add its directory to `PATH`.
2. Resolve the native Linux container platform.
3. Validate installed-profile affinity where the current implementation applies
   it.
4. Run an unqualified `podman info` reachability probe.
5. Let the version-owned runtime assemble its command and replace the wrapper
   process with `podman run`.

Preview is separate. It resolves only enough binary and platform state to render
command text and skips installed-profile affinity and engine access.

On Darwin, installed-profile affinity validates the materialized profile,
active record, strict engine binding, connection overrides, registry policy,
machine/connection state, workload status, and explicit-connection engine
reachability. The successful path can make four Podman requests before the final
generic `info`: machine list, connection list, workload `ps`, and an
explicit-connection `info`.

On Linux, the runtime affinity helper currently returns after materialized
profile identity validation. The generic `info` is the one pre-execution Podman
request. Management status and activation separately validate the local
rootless engine and active registry link; those management checks are not part
of the ordinary Linux wrapper call path.

The current final generic `info` and subsequent `podman run` are unqualified.
The earlier Darwin engine probe uses the profile's expected named connection. A
successful probe therefore establishes reachability of that named connection,
but it does not bind the later `run` to the same target or remove the check/use
race around Podman's mutable default connection.

## Accepted baseline

### Provenance and limits

Accepted measured evidence now covers two native hosts on 2026-09-19:

- Darwin arm64 with Podman 5.8.1, active profile `default`, expected machine
  and named connection `shimmy-default`, checkout commit
  `9dee18c419d87efb38d7d36a0920de6b8a6e58c1`, and distinct older installed
  control commit `e920810ff61d29625f0000ec5939e2f804059bf7`.
- Linux amd64 with Podman 5.8.2, active profile `default`, strict shared
  `local`/`local` binding, no default connection, no rootless API socket, no
  compatible named connection, checkout commit
  `777b081210ccd29345798aaa09fad6e0e20962ca`, and distinct installed control
  commit `3089f168655f15a6de0ffac316d2453034c16c4e`.

The benchmark driver and installed runtime therefore were not assumed to be the
same source revision on either host. Linux now has accepted current-path
baseline evidence, but it still has no accepted explicit-routing proof because
that host lacked a rootless API socket and compatible named connection. Genuine
first/start or profile-switch activation evidence remains unavailable.
Reported lane medians are comparative measurements, not additive proofs, unless
a full session was timed end to end.

### Accepted workload and probe results

| Lane | Median | p95 | Podman calls/sample | Notes |
| --- | ---: | ---: | ---: | --- |
| Shell selection | 0.007 s | 0.008 s | 0 | PATH-only. |
| Activation dry run | 33.677 s | 33.677 s | 0 | One sample; already-active same-profile dry run. |
| Installed `rg --version` | 1.409 s | 1.499 s | 6 | Five pre-run calls plus final `run`. |
| Installed `jq --version` | 1.419 s | 1.510 s | 6 | Five pre-run calls plus final `run`. |
| Four individual jq inputs | 5.222 s | 5.319 s | 24 | Four separate wrapper/container runs. |
| One batched four-file jq command | 1.305 s | 1.363 s | 6 | Same records preserved in one wrapper/container run. |
| Installed full preflight | 0.508 s | 0.521 s | 5 | Current eager Darwin path. |
| Installed Darwin affinity | 0.406 s | 0.414 s | 4 | Current profile-affinity helper only. |
| Machine list | 0.025 s | 0.026 s | 1 | Probe component. |
| Connection list | 0.022 s | 0.023 s | 1 | Probe component. |
| Explicit-connection workload `ps` | 0.077 s | 0.086 s | 1 | Status-only for runtime authority. |
| Unqualified `info` | 0.094 s | 0.100 s | 1 | Current final generic reachability probe. |
| Explicit `shimmy-default` `info` | 0.094 s | 0.097 s | 1 | Same target, no measurable selector penalty. |
| Direct equivalent rg container | 0.849 s | 0.898 s | 1 | Experimental lower bound; not a wrapper replacement. |
| Direct equivalent jq container | 0.722 s | 0.747 s | 1 | Experimental lower bound; not a wrapper replacement. |
| Benchmark-only minimum association | 0.352 s | 0.363 s | 3 | Verified Darwin review predicate only. |

The benchmark-only minimum-association lane validated installed manifest
identity, the active record, strict shared-engine binding, expected machine and
named connection, absence of connection and registry overrides, current engine
registry projection, running expected machine, rootless named connection,
matching default connection, and explicit `true|true` rootless/remote target
response. It deliberately omitted workload `ps` and the final unqualified
`info`.

Linux amd64 added the following accepted current-path baseline:

| Lane | Median | p95 | Podman calls/sample | Notes |
| --- | ---: | ---: | ---: | --- |
| Shell selection | 0.007 s | 0.012 s | 0 | PATH-only. |
| Activation dry run | 30.805 s | 30.805 s | 0 | One sample; already-active same-profile dry run. |
| Installed `rg --version` | 2.075 s | 2.239 s | 2 | One pre-run `info` plus final `run`. |
| Installed `jq --version` | 1.976 s | 2.132 s | 2 | One pre-run `info` plus final `run`. |
| Four individual jq inputs | 7.982 s | 8.271 s | 8 | Four separate wrapper/container runs. |
| One batched four-file jq command | 2.031 s | 2.220 s | 2 | Same records preserved in one wrapper/container run. |
| Installed full preflight | 0.707 s | 0.743 s | 1 | Current eager Linux path. |
| Installed runtime affinity helper | 0.014 s | 0.018 s | 0 | Current Linux profile-affinity helper only. |
| Connection list | 0.028 s | 0.036 s | 1 | Candidate named-connection discovery cost only. |
| Unqualified `info` | 0.649 s | 0.737 s | 1 | Current final generic reachability probe. |
| Direct equivalent rg container | 1.353 s | 1.595 s | 1 | Experimental lower bound; not a wrapper replacement. |
| Direct equivalent jq container | 1.312 s | 1.492 s | 1 | Experimental lower bound; not a wrapper replacement. |
| Benchmark-only Linux current-path association baseline | 0.749 s | 0.856 s | 1 | Verified local/current-path baseline only. |

The Linux current-path association baseline validated installed manifest
identity, the active record, strict shared `local`/`local` binding, absence of
connection and registry overrides, the current Linux registry active link, and
an unqualified `true|false` rootless/local target response. Because the host had
neither a rootless API socket nor a compatible named connection, explicit-
connection-only lanes were recorded as unavailable rather than treated as zero-
cost results.

### Session evidence used for design comparison

| Session model | Darwin arm64 | Linux amd64 |
| --- | --- | --- |
| One already-active shell plus one `rg` and one `jq` | 2.602 s by median model. | 3.995 s by median model. |
| Actual 40 `rg` + 40 `jq` sequence | 102.689 s wall time, uninstrumented. | 765.473 s wall time, instrumented through the benchmark proxy. |
| Median formula for an 80-command sequence | 103.807 s, 1.1% above the measured uninstrumented sequence. | 159.527 s from uninstrumented wrapper medians; the later uninstrumented sequence was user-stopped after severe drift was already established. |
| Add one already-active activation to that 80-command session | About 133.696 s total, with activation about 23.2%. | About 215.970 s total, with actual same-profile activation about 26.1%. |
| 200 `rg` + 200 `jq` sensitivity model | 519.007 s; extrapolation only. | 797.607 s; extrapolation only. |

Two component comparisons matter for design selection:

- Full preflight median `0.508 s` versus benchmark-only minimum association
  `0.352 s` leaves a modeled `0.156 s` successful-path Darwin saving per wrapper
  invocation before any future-system verification.
- Linux current-path full preflight `0.707 s` versus Linux current-path
  association baseline `0.749 s` is a modeled `0.042 s` regression, so the
  current Linux data supports no successful-path saving before a separately
  designed named-connection lifecycle exists.
- Four separate jq wrapper runs `5.222 s` versus one batched jq wrapper run
  `1.305 s` on Darwin, and `7.982 s` versus `2.031 s` on Linux, show that
  caller-controlled batching can dwarf wrapper preflight savings when a
  workload is naturally batchable.

## Ownership boundaries

| Owner | Current responsibility | Discovery constraint |
| --- | --- | --- |
| `lib/runtime/podman.sh` | Binary/platform resolution, preview, installed runtime affinity, final reachability probe, privileged connection resolution, and final `exec`. | Preserve stream ownership, status propagation, and `exec` unless a later implementation is explicitly approved. |
| `lib/profile/activation.sh` | Shared management state reader plus activation recommendations and transitions. | Do not weaken the shared state reader merely to optimize runtime preflight. |
| `lib/engine/` | Strict bindings, engine records, Podman inspection primitives, ownership evidence, and lifecycle mutation. | Routing names are not destructive ownership evidence. Discovery stays read-only. |
| `lib/registries/registries.sh` | Profile registry validation, active Linux link state, Darwin projection policy, and Skopeo client mount resolution. | Keep runtime policy proof separate from any same-process Skopeo reuse. |
| `lib/runtime/image.sh` | External/local image configuration plus local build and stale-image cleanup. | Extra preflights owned by local-image flows remain visible and out of scope for a wrapper-only optimization claim. |
| `tools/*/versions/*/run.sh` | Tool-specific arguments, mounts, environment, image selection, and the final runtime call. | Shared authority must stay in shared helpers, not per-tool copies. |

## Design matrix

The matrix below uses only accepted baseline evidence.

| Candidate | Retained successful-path Podman requests | Authority outcome | Failure and approval behavior | Compatibility and implementation surface | Baseline cost view | Rollback |
| --- | --- | --- | --- | --- | --- | --- |
| A. Current eager path | Darwin: machine list, connection list, workload `ps`, explicit-connection `info`, unqualified `info`; Linux: unqualified `info` | Preserves current behavior. Darwin still has a default-connection race between explicit probe and unqualified `run`. Linux has reachability only, not the retained-authority proof from Decision 2. | Unchanged. Existing wrapper approval boundary and `exec` remain. | No change. | Accepted baseline: Darwin `0.508 s` preflight median and `1.409 s`/`1.419 s` wrapper medians for `rg`/`jq`; Linux `0.707 s` preflight median and `1.994 s`/`1.994 s` uninstrumented wrapper medians. | No-op. |
| B. Minimum association without explicit routing | Verified Darwin review lane keeps machine list, connection list, explicit-connection `info`; omits workload `ps` and unqualified `info` | Incomplete. The explicit probe can prove facts about the expected connection, but the later unqualified `run` can still drift with the mutable default. | Approval boundary unchanged. Failure reporting would still remain wrapper-local only before `exec`. | Smaller helper surface than execution-first, but not sufficient without a routing change. | Darwin review lane median `0.352 s`; modeled successful-path saving `0.156 s` per wrapper versus current eager preflight. | Restore current eager preflight helper. |
| C. Explicit derived-connection routing only | Same requests as current eager path, but runtime Podman operations use a binding-derived `--connection` where available | Improves authority by binding live operations to the validated connection. Alone it does not remove status-only work or reduce call count. | Approval boundary unchanged. Final runtime still uses direct wrapper approval. | Shared runtime command assembly changes; Linux cross-platform form needs a separate socket/connection lifecycle contract. | Explicit versus unqualified `info` had equal `0.094 s` median at 1 ms resolution on the accepted Darwin host. Linux had no compatible named connection, so there is no accepted selector-cost datum. | Revert runtime command assembly to unqualified Podman calls. |
| D. Darwin minimum association plus explicit derived connection routing | Darwin keeps the verified three-call review predicate: machine list, connection list, explicit-connection `info`, and routes runtime Podman calls with the same binding-derived `--connection`. Linux stays on candidate A until a separate lifecycle decision exists. | Smallest accepted design with an explicit Darwin authority proof: active profile, binding, overrides, registry policy, expected named connection, and live explicit target all remain aligned, and the final `run` uses the same derived selector. | Approval boundary unchanged. No replay, no parent supervisor, and live execution can still end in `exec`. | Shared-runtime change on Darwin only for the first implementation. Linux explicit routing remains a separate post-plan issue. | Uses accepted `0.352 s` Darwin predicate as the closest verified current-state analogue. Modeled Darwin saving versus current eager preflight: `0.156 s` per wrapper, about `12.48 s` across an 80-command 40+40 session. Linux current-path association was slower than current eager preflight (`0.749 s` versus `0.707 s`) and still lacked an explicit-routing proof. | Gate by platform/verified binding; fall back to candidate A on Linux or on any host without the required validated named connection. |
| E. Guarded execution-first supervision | None on the successful path before dispatch; any retained authority checks would move into a parent supervisor or post-failure diagnosis path | Unproven. A successful command cannot by itself prove it ran under the authorized profile and policy. | Must preserve original status, signals, partial output, stdin, and no-replay semantics. Approval reuse after a known sandbox denial stays external to Shimmy. | Highest complexity: replaces final `exec` with a supervising parent and needs new failure transport rules. | Accepted baseline does not measure supervisor overhead `S`, failure cost `fD`, or sandbox-denial replay term `qR`, so benefit is not established. | Restore direct `exec` path and current eager preflight. |
| F. Caller batching or reuse | Depends on caller. For jq batch evidence, one wrapper/container run replaces four independent runs. | Preserves authority only per resulting wrapper invocation. It is a caller/workflow optimization, not a general wrapper contract. | Approval boundary unchanged for ordinary batching; a broker or reusable session would broaden it and needs a separate contract. | Outside generic wrapper policy unless a tool explicitly defines batched semantics. | Accepted jq evidence: `5.222 s` for four separate runs versus `1.305 s` batched. | Revert caller behavior; wrapper contract unchanged. |

## Retained-request inventory by candidate

### Candidate A — current eager path

- `podman machine list`
  - proves: Darwin machine identity and running status;
  - class: routing plus status.
- `podman system connection list`
  - proves: expected named connection exists and is recorded rootless/default;
  - class: routing and authority.
- `podman --connection <expected> ps`
  - proves: workload status only;
  - class: status.
- `podman --connection <expected> info`
  - proves: explicit target reachability and rootless/remote target shape;
  - class: routing plus reachability.
- `podman info`
  - proves: current default-target reachability only;
  - class: reachability.

The accepted baseline shows that `workload ps` is status-only for runtime
authority, and the final generic `info` duplicates liveness work without proving
that the later unqualified `run` cannot drift.

### Candidate B — minimum association without explicit routing

- `podman machine list`
  - proves: expected machine still exists and is running;
  - class: routing plus status.
- `podman system connection list`
  - proves: expected named connection still exists with the expected rootless
    characteristics;
  - class: routing and authority.
- `podman --connection <expected> info`
  - proves: the expected explicit target is reachable and reports the required
    rootless/remote identity;
  - class: routing plus reachability.

This candidate fails the authority goal because the final `podman run` would
remain unqualified.

### Candidate C — explicit derived-connection routing only

- retains candidate A's request inventory;
- changes meaning by routing live runtime Podman requests through the strict
  binding's derived connection rather than the mutable default.

The connection selector must come only from the validated strict binding. It is
not user input, not a wrapper argument, and not an environment-selected runtime
override. A later implementation must reject override states exactly as the
current affinity check does rather than silently accepting them.

### Candidate D — selected primary design

Darwin keeps only the accepted review predicate's three requests:

- `podman machine list`
  - proves: the binding's expected machine exists and is running;
  - class: routing plus status.
- `podman system connection list`
  - proves: the binding's expected connection exists, is rootless, and remains
    consistent with the installed profile's binding metadata;
  - class: routing and authority.
- `podman --connection <expected> info`
  - proves: the same explicit target used for live runtime requests is reachable
    and reports the required rootless/remote identity;
  - class: routing plus reachability.

This first implementation deliberately retains the measured three-call Darwin
predicate rather than inventing a smaller unverified proof. It removes only the
accepted status-only `ps` request and the redundant generic default-target
`info`, then binds the final runtime request to the same validated explicit
connection.

Linux remains on candidate A because the accepted record now shows a
host-local current path with no rootless API socket, no compatible named
connection, and no measured successful-path saving from the current-path
association baseline. A named local rootless connection and its lifecycle still
lack accepted proof.

### Candidate E — guarded execution-first supervision

No retained request inventory can be called authoritative without redesigning
the wrapper contract. Any such design would need to spell out which, if any,
local authority checks still run before dispatch and how post-failure diagnosis
is distinguished from replay.

### Candidate F — caller batching or reuse

The accepted jq evidence replaces four full wrapper/container invocations with
one. That reduces all per-wrapper checks together. It is materially beneficial
when a caller already has a batchable workload, but it is not evidence that the
generic runtime should grow a session broker or hidden batching layer.

## Execution-first supervision decision table

The accepted baseline does not justify selecting an execution-first design, but
the rejection is only credible if the failure semantics are explicit.

| Situation | Required supervisor behavior | Result preserved? | Replay allowed? |
| --- | --- | --- | --- |
| Wrapped tool returns a normal nonzero status | Return the child's exact exit status without reclassifying it as infrastructure failure. | Yes. Exact child status. | No. |
| Sandbox denial before dispatch | Preserve the denial result. Suggest the same exact outer wrapper command only where the agent policy already permits escalation reuse. | Yes. Original denial. | No automatic replay. Human or agent retries explicitly outside Shimmy. |
| Connection failure before container start | Preserve the failing status and any already-emitted output. Optional post-failure diagnosis must stay read-only. | Yes. | No. |
| Uncertain response after dispatch | Treat the command as semantically ambiguous. A lost response does not prove no work occurred. | Yes, with ambiguity recorded. | No. |
| Image/setup failure | Return the original failure exactly. Do not convert setup failure into wrapped-tool semantics. | Yes. | No. |
| Signal during execution | Forward the signal to the child, wait, and return signal-derived termination status. | Yes. | No. |
| stdin already consumed or partially consumed | Forward stdin directly and do not attempt another run. | Yes. | No. |
| TTY/interactive behavior | Preserve direct terminal attachment; do not insert buffered capture that changes interactivity. | Yes. | No. |
| Partial stdout/stderr already emitted | Stream directly and preserve partial output ordering. | Yes. | No. |
| Shell redirection already applied by the caller | Treat pre-dispatch filesystem side effects as already real. | Yes. | No. |

A supervisor candidate would therefore need all of the following just to remain
behaviorally acceptable:

- keep child stdin/stdout/stderr unbuffered and directly forwarded;
- preserve process-group and signal semantics for `INT`, `TERM`, `HUP`, and
  `QUIT`;
- avoid raw stderr classification or argv capture in the first implementation;
- perform only read-only cleanup such as temporary diagnostic files; and
- work under sourced callers using `set -e` without skipping cleanup or
  rewriting child status.

That complexity is not justified by the accepted evidence because the baseline
measures neither supervisor success-path cost nor failure-rate terms.

## Selected design

### Primary design

Select candidate D:

**Darwin minimum association plus explicit derived connection routing, with the
current eager path retained everywhere else.**

The first implementation should:

1. keep the current Linux runtime path unchanged;
2. keep production approval boundaries unchanged;
3. keep final live execution in `exec`;
4. derive the Darwin runtime `--connection` selector only from the validated
   strict binding;
5. replace Darwin successful-path `workload ps` and generic unqualified `info`
   with the accepted three-call review predicate; and
6. fail closed to the current eager path when the required validated named
   connection evidence is unavailable.

### Why this design was selected

- It is the smallest candidate backed by an accepted explicit authority proof on
  the measured host.
- It preserves Decision 2's retained-authority model instead of replacing it
  with optimistic execution.
- It removes only work the accepted baseline already classified as status-only
  (`ps`) or redundant with the derived explicit route (generic default-target
  `info`).
- The accepted Darwin host showed no measurable selector overhead between
  explicit and unqualified `info`, so the routing change does not spend the
  recovered budget.
- Its modeled Darwin saving is bounded and concrete: `0.156 s` per wrapper, or
  about `12.48 s` across the measured 40-`rg`/40-`jq` session, without inventing
  Linux or execution-first benefits.
- It leaves the unresolved Linux socket/connection lifecycle outside the first
  implementation rather than smuggling in a new ownership contract.

### Fallback

Fallback to candidate A:

**Keep the current eager path on Linux and on any installation that cannot prove
an expected named connection from the validated binding.**

This is a true rollback path because it preserves today's implementation and
approval contract exactly.

## Rejected designs

### Candidate B — minimum association without explicit routing

Rejected because it does not prove that the later unqualified `run` uses the
same validated target. The accepted benchmark predicate is only meaningful when
live runtime requests use the same derived connection.

### Candidate C — explicit derived-connection routing as the only change

Rejected as the primary design because it improves authority but does not itself
remove any status-only or redundant successful-path work. It is retained as a
required ingredient of candidate D.

### Candidate E — guarded execution-first supervision

Rejected because the accepted baseline does not establish a benefit large enough
to justify replacing the final `exec`, adding a supervising parent process, or
introducing new ambiguity-handling logic. Authority would still need a separate
proof.

### Candidate F — generic batching, reusable sessions, or a broker

Rejected as a wrapper-policy selection. Caller batching is clearly beneficial
for batchable workloads, but the accepted jq result is a workload optimization,
not a general wrapper-contract proof. Reusable sessions or a broker would also
broaden approval, isolation, cleanup, and concurrency scope far beyond this
plan.

## Assumptions carried into the handoff

- The accepted measurement record is Darwin arm64 only. No claim in this
  document proves native Linux runtime savings or Linux named-connection
  readiness.
- The first implementation must preserve current secret-redaction and override
  handling. It must not print connection URIs or override values.
- The first implementation must not add automatic replay, a persistent runtime
  cache, a session broker, Podman service enablement, connection adoption, or a
  default-connection mutation.
- The current benchmark-only minimum-association proof still includes liveness
  work through explicit `info`. It is not evidence that a health-free check is
  already proved sufficient.
- Local-image and refresh-owned extra preflights remain out of scope for the
  first runtime-path change and must stay visible in any later verification.
- Future-system benchmarking must reuse the accepted benchmark protocol and must
  report deviations explicitly rather than normalizing them away.
