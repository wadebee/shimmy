# Runtime preflight contract and caller map

## Review status

This document records the current runtime contract and the ownership boundaries
under review. It does not select a new execution strategy. Production runtimes
continue to call `shimmy_podman_preflight_require` or its preview-aware wrapper,
and `shimmy_podman_run_or_preview` still ends live execution with `exec`.

`lib/runtime/preflight-review.sh` is deliberately dormant. No production file
sources it. The source-only benchmark is its only intended caller during this
review, and materializing the shared `lib` tree does not activate it. Wiring a
review helper into a runtime requires a separately accepted implementation
plan.

## Current contract

The live preflight order is:

1. Resolve Podman and add its directory to `PATH`.
2. Resolve the native Linux container platform.
3. Validate installed-profile affinity where the current implementation applies
   it.
4. Run an unqualified `podman info` reachability probe.
5. Let the version-owned runtime assemble its command and replace the wrapper
   process with `podman run`.

Preview is a separate path. It resolves only enough binary/platform state to
render the command and skips installed-profile affinity and engine access.

On Darwin, installed-profile affinity validates the materialized profile,
active record, strict engine binding, connection overrides, registry policy,
machine/connection state, workload status, and explicit-connection engine
reachability. The successful path can make four Podman requests before the
final generic `info`: machine list, connection list, workload `ps`, and an
explicit-connection `info`. Conditional or failing paths can make fewer calls.

On Linux, the runtime affinity helper currently returns after materialized
profile identity validation. The generic `info` is the one pre-execution Podman
request. Management status and activation separately validate the local
rootless engine and active registry link; those management checks are not part
of the ordinary Linux wrapper call path.

The current final generic `info` and subsequent `podman run` are unqualified.
The earlier Darwin engine probe uses the profile's expected connection. A
successful probe therefore establishes reachability of that named connection,
but it does not bind the later run to the same target or eliminate the
check/use race around Podman's mutable default.

## Ownership boundaries

| Owner | Current responsibility | Review constraint |
| --- | --- | --- |
| `lib/runtime/podman.sh` | Binary/platform resolution, preview, installed runtime affinity, final reachability probe, privileged connection resolution, and final `exec`. | Preserve live order, streams, status, and `exec` until a later implementation is approved. |
| `lib/profile/activation.sh` | Shared management state reader plus activation recommendations and transitions. Its Darwin reader collects machine, connection, workload, reachability, override, and projection state. | Do not narrow this shared status reader to optimize wrappers; management callers require its full state. |
| `lib/engine/` | Strict bindings, engine records, Podman inspection primitives, ownership evidence, and lifecycle mutation. | Routing names are not destructive ownership evidence. Runtime review must remain read-only. |
| `lib/registries/registries.sh` | Profile registry validation, active Linux link state, Darwin projection policy, and Skopeo client mount resolution. | Skopeo may reuse same-process affinity evidence, but that is not a persistent runtime cache. |
| `lib/runtime/image.sh` | External/local image configuration plus local build and stale-image cleanup. | Local build and cleanup own additional preflights and must remain visible in call counts. |
| `tools/*/versions/*/run.sh` | Tool-specific arguments, mounts, environment, image selection, and the final runtime call. | Do not move shared authority decisions into individual tools. |

The dormant review split mirrors, rather than replaces, the live helper:

| Review helper | Exact work mirrored | Podman requests on a healthy installed Darwin path |
| --- | --- | ---: |
| `shimmy_podman_preflight_context_review_require` | Binary, platform, and current profile-affinity work. | 4 |
| `shimmy_podman_profile_affinity_require` | Existing affinity helper measured directly. | 4 |
| `shimmy_podman_preflight_reachability_review_require` | Current final unqualified `info`. | 1 |
| `shimmy_podman_preflight_require` | Unchanged live composition measured from source. | 5 |

These are path-specific expectations. Machine, metadata, override, registry,
and reachability failures short-circuit the sequence.

## Caller map

| Callee | Production callers | Notes |
| --- | --- | --- |
| `shimmy_podman_preflight_or_preview_require` | 23 version-owned runtime scripts. | Standard runtime entrypoint; preview skips engine access. |
| `shimmy_podman_preflight_require` | Four conditional runtimes (`gh`, `gcloud`, and the two OPNsense MCP tools), both local-image operations in `image.sh`, and the preview-aware helper. | The conditional runtimes perform argument or environment checks before preflight. |
| `shimmy_podman_profile_affinity_require` | The live preflight and Darwin Skopeo registry mount resolution when same-process evidence is absent. | The benchmark also invokes it directly in a disposable review lane. |
| `shimmy_profile_state_read` | Runtime Darwin affinity, profile status/activation management, profile listing/status rendering, and registry redirect inspection. | This is a shared status collector, not a runtime-only minimum association predicate. |
| `shimmy_local_image_ensure` | 13 version-owned runtimes. | When a local image path is selected, its build check can add another full preflight after the runtime's initial preflight. |
| `shimmy_local_image_stale_cleanup` | Local-image refresh scripts. | Cleanup owns its own full preflight before image listing/removal. |
| `shimmy_registries_client_mount_resolve` | Skopeo runtime. | Reuses `SHIMMY_PODMAN_PROFILE_REGISTRY_AFFINITY` only within the current process. |
| `shimmy_podman_run_or_preview` | All 27 version-owned runtime scripts. | Live execution uses `exec`; there is no post-failure wrapper diagnosis or automatic replay. |

## Disposable measurements

The benchmark's review scope compares the unchanged full preflight with the
dormant split and records transparent Podman call counts:

```sh
./tests/runtime-benchmark.sh --review-only --samples 20 --warmups 3
```

The benchmark sources the review module only inside its private measured child,
uses the active installed profile for affinity state, and prepends a private
transparent Podman forwarder. Raw records stay in the reported temporary output
directory. The forwarder preserves arguments, streams, and status and records
no command arguments or environment values. Warmup records are discarded before
median and p95 aggregation. Provenance includes the source commit, dirty/clean
state, content hashes for the benchmark and dormant helper, installed control
commit, host, Podman version, and default connection so an uncommitted review
run is not mislabeled as evidence from `HEAD` alone.

These lanes measure the current extraction boundary; they do not prove that a
smaller future association predicate preserves authority. In particular, the
current context lane still includes Darwin workload status and reachability.
The benchmark does not enable a Podman service, create or adopt a connection,
change a default connection, activate a profile, run a tool container, or alter
an installed profile.

### Apple Silicon review baseline — 2026-09-18

The authorized disposable run used 3 warmups followed by 20 measured samples
per lane on Darwin arm64 with Podman 5.8.1 and default connection
`shimmy-default`. Checkout `HEAD` was
`e405736924930dbf2fd71c8c2b90be953dd042c8`; the dirty review content was
identified by benchmark blob `c47880bc36c641ccac20cf46f486a5daf5f5c2f7`
and dormant-helper blob `315a066d550cbaad32d76f9d768d731dc805fa8a`.
The active profile's installed control commit was
`e920810ff61d29625f0000ec5939e2f804059bf7`.

| Lane | Median | p95 | Calls/sample | Status |
| --- | ---: | ---: | ---: | --- |
| Unchanged full preflight | 0.576 s | 0.598 s | 5 | 20/20 zero |
| Dormant context split | 0.476 s | 0.483 s | 4 | 20/20 zero |
| Current affinity alone | 0.464 s | 0.479 s | 4 | 20/20 zero |
| Dormant final reachability split | 0.095 s | 0.101 s | 1 | 20/20 zero |

The proxy recorded 322 successful Podman calls across warmups and measured
samples: 115 full-preflight, 92 context, 92 affinity, and 23 reachability calls.
Each aggregate contains exactly 20 measured records; warmups are absent from
the aggregate files.

This is a partial review baseline. The measured runtime helper came from the
dirty source checkout while profile state helpers came from a different
installed control commit. The transparent proxy's observer cost was not
measured against an uninstrumented review lane. The separately timed medians
are not additive, and this run supplies no Linux amd64 evidence, minimum-
association authority proof, wrapper/container timing, or activation timing.
