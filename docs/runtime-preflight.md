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

Two runtime component comparisons matter for design selection:

- Full preflight median `0.508 s` versus benchmark-only minimum association
  `0.352 s` leaves a modeled `0.156 s` successful-path Darwin saving per wrapper
  invocation before any future-system verification.
- Linux current-path full preflight `0.707 s` versus Linux current-path
  association baseline `0.749 s` is a modeled `0.042 s` regression, so the
  current Linux data demonstrates no saving from the tested association path.
  A named-routing alternative remains unmeasured and requires a separate
  lifecycle contract.

## Ownership boundaries

| Owner | Current responsibility | Discovery constraint |
| --- | --- | --- |
| `lib/runtime/podman.sh` | Binary/platform resolution, preview, installed runtime affinity, final reachability probe, privileged connection resolution, and final `exec`. | Preserve stream ownership, status propagation, and `exec` unless a later implementation is explicitly approved. |
| `lib/profile/activation.sh` | Shared management state reader plus activation recommendations and transitions. | Do not weaken the shared state reader merely to optimize runtime preflight. |
| `lib/engine/` | Strict bindings, engine records, Podman inspection primitives, ownership evidence, and lifecycle mutation. | Routing names are not destructive ownership evidence. Discovery stays read-only. |
| `lib/registries/registries.sh` | Profile registry validation, active Linux link state, Darwin projection policy, and Skopeo client mount resolution. | Keep runtime policy proof separate from any same-process Skopeo reuse. |
| `lib/runtime/image.sh` | External/local image configuration plus local build and stale-image cleanup. | Extra preflights owned by local-image flows remain visible and out of scope for a wrapper-only optimization claim. |
| `tools/*/versions/*/run.sh` | Tool-specific arguments, mounts, environment, image selection, and the final runtime call. | Shared authority must stay in shared helpers, not per-tool copies. |

## Design matrix — reevaluated with Linux amd64 evidence

Reevaluated on 2026-09-19. Chunk 2 is accepted on both native platforms;
Chunk 3's recommendation remains pending review. Candidate E is excluded by
the user's instruction. Candidate F is outside this selection. Its findings
are retained in the assessment plan's pending-transfer section until the
skill-required confirmation permits creation of the proposed future plan
`plans/notional/caller-batching-and-reuse.md`.

Counts below exclude the final container `run` and tool/image-specific extra
work. Candidate letters are retained so earlier review references remain clear.

| Candidate | Darwin successful path | Linux successful path | Authority and compatibility | Cost finding | Disposition and rollback |
| --- | --- | --- | --- | --- | --- |
| A. Current eager path | Machine list, connection list, explicit workload `ps`, explicit `info`, generic `info`: 5 calls | Generic `info`: 1 call, after manifest identity validation | Preserves current behavior. Darwin's unqualified `run` still follows the mutable default. Linux runtime does not enforce Decision 2's active-record/binding/registry checks. | Preflight medians: Darwin 0.508 s; Linux 0.707 s. | Retain on Linux and as a reviewed code rollback; no optimization or stronger Linux authority claim. |
| B. Minimum association without explicit routing | Machine list, connection list, explicit `info`: 3 calls | Local identity, active record, binding, override and registry-link validation plus generic `info`: 1 call | Darwin still probes one target then executes against a mutable default. Linux adds useful checks but its unqualified dispatch is not explicit routing. | Darwin analogue 0.352 s, modeled 0.156 s saving. Linux analogue 0.749 s, 0.042 s (5.9%) slower than A; no demonstrated saving. | Reject as the selected optimization. Revert the dedicated runtime predicate to A. |
| C. Explicit derived-connection routing only | Keep A's 5 calls; route engine requests, including both `info` probes and final `run`, through the derived connection | A universal version requires a new service/connection contract; no applicable timing on the accepted host | Addresses default-selector drift on Darwin, retaining status work. Linux `local` is a binding sentinel, not a usable connection name. | Darwin explicit and generic `info` each measured 0.094 s; no measurable selector penalty in that lane, not an end-to-end C measurement. Linux selector cost unknown. | Retain routing as part of D, not as the primary cost reduction. Reviewed code rollback to A. |
| D. Darwin minimum association plus derived routing | B's 3 calls, with final `run` and applicable engine requests routed through the same derived selector | Exactly A: 1 preflight call, direct local execution; no service or connection setup | Recommended scoped improvement. Retains Darwin active-profile/policy checks and removes dependence on the default selector at dispatch. Preserves Linux compatibility but does not close its authority gap. | Closest measured Darwin analogue is 0.352 s: modeled saving 0.156 s/call, 12.48 s/80 calls. Linux saving is zero by design. Production D has not been measured. | Recommend for review. Invalid Darwin authority stops execution; it never triggers a weaker runtime fallback. Linux uses A by design. Code rollback is a separate reviewed action. |

All four candidates preserve the outer-wrapper approval boundary, direct final
`exec`, stream ownership, tool exit status, and no automatic replay. Failures
before `exec` use wrapper guidance; failures after `exec` remain Podman's/tool's
result. No candidate adds a parent supervisor or post-run classifier.

### What the Linux evidence changes

- Linux has one expensive pre-run probe (0.649 s `info` median), not Darwin's
  five-request status path. Removing Darwin `ps` or a second `info` offers
  nothing on Linux because those requests are already absent.
- The 0.749 s association lane validates more state than the 0.707 s current
  preflight. Its 0.042 s difference is a comparison of lane medians, not an
  isolated overhead estimate or a statistically established universal penalty.
  It demonstrates no saving from the tested local-path alternative.
- An absent API socket does not mean the Linux engine is unhealthy: the accepted
  local wrapper runs succeeded. `--connection` enables remote/API mode, so
  adding it is a transport and lifecycle change, not merely an argv adjustment.
  [Podman global options](https://docs.podman.io/en/latest/markdown/podman.1.html#connection-c),
  [Podman service](https://docs.podman.io/en/latest/markdown/podman-system-service.1.html).
- This rules out a universal named-connection rollout from this evidence. It
  does not prove that every possible future direct-local Linux optimization
  requires a socket, or that stronger Linux authority checks have no value.
- Linux's instrumented 80-command sequence (765.473 s) is drift evidence, not
  an interchangeable baseline for its 159.527 s uninstrumented median model.
  The stopped uninstrumented session cannot establish an observed speedup.

## Candidate implementation sketches

These are low-fidelity call flows, not executable patches. Existing names refer
to inspected source; names marked **proposed** describe future shared seams.
Every validation failure must return explicitly, including when called from a
conditional under `set -e`. No sketch authorizes implementation.

### Candidate A — preserve the existing call flow

```sh
# Existing version-owned runtime, e.g. tools/jq/versions/1.8/run.sh
shimmy_podman_preflight_or_preview_require "the jq shim" "$@"
# Live branch calls, in order:
#   shimmy_podman_bin_require
#   shimmy_podman_platform_resolve
#   shimmy_podman_profile_affinity_require
#     Darwin: shimmy_profile_state_read -> machine/connection/ps/info
#     Linux: validate installed manifest identity, then return
#   "$SHIMMY_PODMAN_BIN" info
shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run ... "$@"
# Existing live helper: exec "$@"
```

No implementation changes. Preview keeps its engine-free binary/platform path.
This is the baseline, not a proposed repair of Linux runtime authority.

### Candidate B — dedicated association predicate, unqualified dispatch

```sh
# Proposed shared predicate, based on runtime_benchmark_minimum_association_run.
shimmy_podman_runtime_association_require "$runtime_profile" || return 1
# Then existing helper receives an unqualified command:
shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run ... "$@"
```

The proposed predicate would use these existing seams after loading validated
installed helpers and resolving the invoking canonical profile:

```text
shimmy_profile_runtime_manifest_identity_validate(manifest, profile)
shimmy_profile_manifest_read(manifest)
shimmy_active_profile_read(active_record) -> require invoking profile
shimmy_engine_profile_binding_resolve(config_root, profile)
shimmy_profile_activation_override_read() -> require none
shimmy_registries_override_read() -> require none
shimmy_registries_config_validate(registry_path, profile)
Darwin:
  shimmy_engine_registry_projection_state_read(root, profile, engine_id)
    -> require current
  shimmy_engine_podman_machine_state_read(expected_machine) -> require running
  proposed same-response validation -> require only the expected machine running
  shimmy_engine_podman_connection_state_read(expected_connection)
    -> require rootless and current default matches expected connection
  shimmy_engine_podman_connection_run(expected_connection, info, format)
    -> require true|true (rootless, remote)
Linux:
  require strict local/local binding
  shimmy_registries_active_link_state_read() -> require current
  shimmy_engine_podman_run(info, format) -> require true|false (rootless, local)
```

The Darwin metadata calls provide routing/state evidence; explicit `info`
provides target shape and reachability, not unique machine identity. Linux's
single `info` provides local/rootless shape and reachability. Local file checks
provide active-profile and policy evidence. Neither branch lists workloads.

Files: a dedicated runtime predicate in `lib/runtime/podman.sh`,
`lib/engine/podman.sh` machine-response facts and existing registry primitives, `tests/lib/runtime.sh`, and runtime guidance. Keep
`shimmy_profile_state_read` intact for management. B is not selected because
its dispatch still depends on ambient routing and its Linux lane saves no time.

### Candidate C — keep eager checks and add shared derived routing

```text
shimmy_podman_preflight_or_preview_require(context, argv)
  existing eager authority/status path
  proposed shimmy_podman_runtime_connection_resolve()
    -> copy validated Darwin binding's expected connection into internal state
  generic reachability probe -> proposed shimmy_podman_runtime_request(info)
version runtime assembles its existing mounts, environment, image and argv
shimmy_podman_run_or_preview(podman_binary, run, ...)
  preview -> existing renderer
  live ordinary Darwin -> exec podman_binary --connection derived_name run ...
  live Linux -> existing exec argv
```

`shimmy_podman_runtime_request` is a **proposed**, non-`exec` shared helper for
runtime-owned engine calls such as image inspection/build/cleanup and tool
rootless probes. It prepends the validated connection on applicable Darwin
calls and otherwise preserves existing argv. Machine and connection inventory
are client discovery calls, not engine workloads; do not blindly prefix them.
Keep positional arguments intact, with no `eval` or string-based command assembly.

Files: `lib/runtime/podman.sh`, `lib/runtime/image.sh`, direct runtime-owned
Podman callers in `tools/*/versions/*/run.sh`, relevant runtime/tool tests and
guidance. `tools/nmap/versions/7.98/run.sh` has a direct rootless `info` probe;
changing only the final `exec` would miss it. Installed adoption remains an
explicit profile synchronization/materialization step.

For a universal C, Linux needs a separately reviewed API-service/connection
lifecycle and validators that understand local Unix socket connections. Current
`shimmy_engine_podman_connection_state_read` recognizes Darwin SSH rootless
connection shapes; it cannot simply be reused for that Linux contract.

### Candidate D — combine B's Darwin predicate and C's routing

```text
shimmy_podman_preflight_or_preview_require(context, argv)
  existing preview path -> return without engine access
  existing binary/platform resolution
  resolve invoking runtime context
  installed Darwin, ordinary rootless path:
    proposed shimmy_podman_runtime_association_require(profile)
      -> B's Darwin checks, exactly 3 Podman calls
    proposed shimmy_podman_runtime_connection_resolve()
      -> retain validated expected connection in internal same-process state
      -> publish existing profile:current Skopeo affinity marker after success
  Linux / source runtime / existing privileged opt-in path:
    existing eager path A
version runtime assembles arguments
applicable intermediate engine calls -> proposed shimmy_podman_runtime_request(...)
shimmy_podman_run_or_preview(podman_binary, run, ...)
  ordinary installed Darwin -> exec podman_binary --connection derived_name run ...
  other paths -> existing exec argv, including separately verified rootful selector
```

Implementation boundaries for the handoff:

1. Derive the selector only after successful validation; reset internal route
   state on entry so an inherited value cannot select a connection. Call the
   predicate in the invoking shell, not in a command substitution that loses
   assignments. It is not a new public environment override or persistent cache.
2. Retain the benchmark predicate's matching-default check initially. Explicit
   dispatch closes default-selector drift after that check; relaxing the check
   is a separate compatibility decision, not needed to obtain the modeled gain.
3. Invalid/missing Darwin binding, projection, connection, or live target evidence
   fails before dispatch. Do not switch to A in response to validation failure.
   Linux/source/privileged selection of the existing path is decided by runtime
   context before attempting D, not by catching an authority error.
4. Preserve the existing privileged opt-in and rootful verification path,
   including `shimmy_podman_privileged_connection_require`. Do not prepend a
   rootless selector over the explicitly verified rootful selector. Exclude
   privileged calls from the three-call and savings claims.
5. Keep Skopeo's existing registry mount capability and same-process affinity
   handoff. The resolver may be called inside a subshell; do not rely on its
   assignments becoming visible to the parent. Do not weaken its independent
   active-record, path, config, or override checks.
6. Preserve the current Darwin rejection of multiple/alternate running machines.
   The benchmark's `shimmy_engine_podman_machine_state_read` checks the expected
   machine but does not expose the current status reader's running-machine
   count. Extend its same-response facts (or use a dedicated runtime parser)
   to enforce that existing condition without another Podman request. Do not
   copy the benchmark predicate verbatim and silently weaken this behavior.
   Additional parsing cost remains unmeasured even with the same call count.
7. Route applicable local-image operations consistently, while retaining their
   existing extra preflights and build/pull policy. Do not claim a three-call
   total for those flows. Management calls retain their existing ownership.
8. A named selector does not lock its connection definition, active record, or
   registry state. Concurrent external mutation remains a check/use limitation.
   Current metadata helpers validate names, URI shape and state, not immutable
   endpoint identity; `true|true` is not an ownership attestation. D improves
   default selection while preserving the existing trust boundary; it is not
   proof against arbitrary same-user configuration changes.

Files: B and C's combined shared-runtime and direct-caller surfaces, installed
materialization consumers, runtime/registry/tool tests and documentation. Chunk
4 must enumerate concrete callers and acceptance cases before implementation.
No benchmark-only helper may become a production dependency.

## Selection and review gate

Recommend **D for ordinary installed Darwin rootless execution, with A retained
on Linux and on explicitly excluded source/privileged paths**. D is the smallest
candidate that combines the measured Darwin predicate with explicit dispatch.
Its prediction remains 0.156 s per invocation, or 12.48 s across 80 invocations;
neither figure is an observed production D result. Linux keeps its current cost
and its current weaker runtime authority checks.

Reject B as the optimization selection because its target probe does not bind
later dispatch and Linux shows no measured saving. C supplies D's routing
mechanism but retains the eager status workload. A remains a compatible baseline
and a deliberate code rollback, not a recovery branch after D validation fails.

Acceptance must cover platform scope, retained live `info`, privileged/source
exceptions, residual configuration races, and the distinction between a measured
predicate and an implemented end-to-end design. It authorizes Chunk 4's separate
implementation handoff only when the user explicitly directs that work.

Verification for the later handoff must positively demonstrate selected-route
execution and original argv/status/streams, engine-free preview, preserved
rootful opt-in behavior, Skopeo policy ownership, and unchanged Linux operation
without a socket or named connection. Reuse existing authority/override/isolation
proofs; add negative coverage only for established durable invariants. Benchmark
on native Darwin arm64 and Linux amd64 with matching provenance and report
median/p95/call-count deltas, unavailable lanes and long-run drift separately.

## Assumptions carried into the handoff

- Accepted baseline evidence covers Darwin arm64 and Linux amd64; neither the
  complete D implementation nor Linux named routing has been benchmarked.
- The Linux service/connection lifecycle is a future ownership decision. No
  setup, activation, default mutation, deployment or installed-profile sync is
  authorized by this assessment.
- The benchmark's retained Darwin `info` includes liveness. D removes two calls;
  it does not achieve a health-free preflight.
- Preserve secret redaction and original errors; do not print connection URIs,
  identity paths, overrides, raw arguments or stderr captures for diagnostics.
- Historical accepted baseline limitations remain explicit in the assessment
  plan. Future-system comparisons must use equivalent workloads and distinguish
  source checkout revisions from installed control revisions.
