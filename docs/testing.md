# Testing

Run the repository suite from the root:

```sh
./tests/test.sh
```

The source suite uses one canonical named group registry. The runner uses
three bounded workers by default after creating immutable session fixtures in
the parent. Each group writes a private log and result; the parent waits for
every started worker and replays logs in canonical registry order. Use these
commands to inspect, select, or diagnose coverage:

```sh
./tests/test.sh --list-groups
./tests/test.sh --group lib-runtime
./tests/test.sh --group lib-runtime --group tools-rg
./tests/test.sh --serial
./tests/test.sh --jobs 2
```

Repeated groups, unknown groups, invalid or duplicate job counts, and
conflicting `--serial`/`--jobs` or list/execution requests fail before session
fixture creation. Selected groups always run in canonical registry order. The
lifecycle prepare and complete sequence is exposed only as the single
`commands-lifecycle` group. A selected run starts only workers that own at
least one requested group. Use `--serial` for immediate single-worker failure
diagnosis. Parallel failures can identify more than one failed worker because
the parent always waits for every worker it started.

### Signal tests inside groups

Every selected group runs in a background process, including a one-worker
`--serial` run. POSIX shells may inherit SIGINT as ignored when started in that
position, and a non-interactive child shell cannot reliably make an inherited
ignored SIGINT trappable. Do not use kernel-level `kill -INT`, `kill -2`, or
`kill -s INT` delivery inside a test group. The group harness rejects those
forms immediately instead of allowing a false pass or hang.

To test an INT boundary in a command or sourced lifecycle, inject the boundary
and invoke its installed INT cleanup handler directly, then assert status 130
and the required state. Use the same handler-level pattern for TERM when both
paths share cleanup behavior. Actual process-level signal delivery belongs in
parent-runner coverage where the target did not inherit SIGINT as ignored.

Opt in to integer-second setup, per-group, and total timing records with:

```sh
SHIMMY_TEST_TIMING=1 ./tests/test.sh --serial
SHIMMY_TEST_TIMING=1 ./tests/test.sh
```

Each record has the stable form
`shimmy_test_timing=<setup|group|total>|<name>|<elapsed-seconds>`. Timing
records are absent by default.

When timing is relevant to acceptance, run one clean default execution on the
same host and compare it with the retained baseline:

```sh
/usr/bin/time -p env SHIMMY_TEST_TIMING=1 ./tests/test.sh
```

Keep its `real`, `user`, and `sys` records. Treat the result as a coarse
directional measurement, not a precision benchmark. Compare group timings and
worker result data when wall time or aggregate CPU cost regresses; do not repeat
the suite solely to calculate a median, and do not add a host-specific timeout.

For transition-pruning work, freeze one before measurement prior to test edits.
Run each affected group once in isolation with the same command on the same
host:

```sh
/usr/bin/time -p env SHIMMY_TEST_TIMING=1 \
  ./tests/test.sh --serial --group commands-startup
```

Retain the setup, group, total, `real`, `user`, `sys`, and test-count values.
Compare one identical before and after invocation:

```text
savings_seconds = before_seconds - after_seconds
improvement_percent = 100 * savings_seconds / before_seconds
```

Also record one complete timed serial baseline before editing so projected
suite savings can be distinguished from a measured full-suite result. A
multi-group change must report the net affected group time; moving work to a
different group or to session setup is not a performance improvement.

The retained transition-pruning benchmark from 2026-08-17 keeps scenario
ownership inside each command group: onboarding owns one progressive
absolute/sourced/selection/switching world, startup owns one progressive
default/upstream repair world plus isolated failure/retry, catalog owns one
progressive publication/rollback world, skills owns transport, failure,
ownership, and catalog-authority worlds, and lifecycle owns its indivisible
prepare/complete world plus distinct migration and registry boundaries. No
mutable scenario crosses a registered group or worker.

Those retained measurements are historical evidence from the former
three-sample policy; do not repeat the runs to reproduce a median. The
benchmark's final complete serial group values sum to 1,248 seconds. The
checked-in static schedule partitions them at the exact lower bounds of
624/624 seconds for two workers and 416/416/416 seconds for three; zero-second
groups are distributed to keep worker group counts balanced. The final serial
run passed 41 groups and 159 tests in 1,293.88 seconds real, while three clean
default runs produced a 532.16-second median. The five optimized groups saved
109 seconds in aggregate, so the retained plan records the 146-second
shortfall against its 255-second acceptance threshold rather than weakening
unique integration coverage.

During implementation, run only the named groups that exercise the changed
behavior, plus syntax, context-tree, or other focused checks required by the
files changed. Use `--list-groups` to discover the canonical names and repeat
`--group` to select the affected set. Run the complete default suite once at a
final integration gate, or earlier when a chunk changes the runner, shared
fixtures, shared libraries with broad consumers, group registration or
assignment, installation lifecycle, or another boundary that cannot be
covered confidently by selected groups. A plan chunk should state its affected
groups explicitly instead of inheriting a complete-suite run by default.

To smoke an installed profile through its real wrappers, use:

```sh
shimmy test
shimmy test --all
shimmy test --shim oc@4.18
```

Installed test mode validates the invoking profile's manifest. By default it
runs each installed public tool; `--all` also runs every installed concrete
version. Those commands use live Podman only for the version-owned
non-mutating smoke arguments.

Switch installed profiles by sourcing the desired profile's absolute
`shell-init.sh` before running `shimmy test`; installed test commands do not
select another profile.

The suite is POSIX shell and validates:

- the retained `CONTEXT.md` hierarchy and parent-to-child links under root,
  `commands/`, `lib/`, and `tests/`, plus rejection of context files under
  `tools/` and `plugins/shimmy/`;
- metadata-derived tools, versions, immutable image defaults, configured
  local bases, required platforms, and selectors;
- negative schema coverage for missing, duplicate, unsafe, incomplete, tag-only,
  and illegal image metadata, including platform-neutral `scratch` handling;
- preview rendering for every concrete runtime across Linux/Darwin and
  amd64/arm64 through its declared smoke argument, without contacting Podman;
- local image identity changes for image configuration, ordered build
  arguments, overrides, and platform while identical inputs remain stable;
- fixture-driven image verification for OCI indexes, Docker manifest lists,
  required-platform failures, selection, remote-reference deduplication,
  authentication policy, drift handling, and stable output without contacting
  target registries;
- shared fail-closed Podman OS/architecture and preview helpers plus POSIX syntax;
- disposable version-3 materialized default and upstream profile installs,
  named-catalog bootstrap isolation, installed command dispatch, status,
  catalog-default update, rollback, legacy-layout rejection, profile-isolated
  uninstall, exact Linux link cleanup, transactional Darwin running/stopped/
  missing cleanup, failure-injected reprojection rollback, and explicit global
  detach-before-delete uninstall;
- shell initialization, canonical skill export/removal, netinfo input
  rendering, and management-command argument validation;
- bootstrap-only profile selection, profile-isolated uninstalls, status
  identity, named catalog listing, and profile-specific repair guidance;
- selected-shim profile-local default adoption and image refreshes, manifest
  lifecycle-field preservation, request validation, failed-update safety, and
  installed-management source refresh;
- idempotent shell initialization, normalized managed/manual default startup
  policy, immutable repeat bootstrap, exact-ledger repair and uninstall, and
  direct upstream shell initialization.
- canonical skill-source export, target-owned portable manifests,
  installed-tool selection, refresh, and explicit manifest-tracked cleanup.
- source and installed dispatcher validation, including selector, canonical
  profile identity, and recursion protections.
- deterministic netinfo CIDR rendering, explicit-host precedence, help, and
  malformed-input rejection.
- tool-owned Nmap preview coverage for explicit LAN, network, capability, and
  privilege controls.
- tool-owned OPNsense MCP preview coverage for URL normalization, read-only and
  admin secret separation, no-write defaults, and change-window guidance.
- additive install behavior, enclosing-profile uninstall requests including
  workload acknowledgement validation, and macOS Podman dependency guidance.

Use live Podman only for non-mutating commands such as `--version`, `version`,
or `--help`. Prefer `--preview-shim` whenever it proves the intended runtime
shape without pulling, building, or running a container.

Registry verification is deliberately separate from the default suite. Run a
live public check explicitly with:

```sh
./commands/images.sh verify --all --public-only
```

That command can contact registries but does not pull target layers. A full
authenticated acceptance run additionally requires an explicitly selected
`SHIMMY_SKOPEO_AUTH_SECRET`; never place credential contents in test output.

Feature acceptance for a new or rotated image also requires the concrete
version's `smoke.conf` command on native Linux `amd64` and native Apple Silicon
macOS `arm64`. Build every `image_source=local-build` version on each host
before its smoke; run external defaults with the shared helper's selected
native platform. Record the host platform, concrete version, command result,
and any approved deferral without recording credentials. The deterministic
preview suite covers both supported host-OS branches, but emulation and preview
results do not replace the two native container-architecture runs.

The runner in `tests/test.sh` sources its registry and orchestration helpers
from `tests/runner.sh`, shared assertions from `tests/support.sh`,
shared-library coverage from `tests/lib/`, and management-command coverage from
`tests/commands/`. Tool-specific coverage belongs beside the tool in
`tools/<tool>/`. Keep one assertion-focused scenario per behavior and preserve
executable bits on shell entrypoints.

Disposable installation scenarios set absolute temporary `HOME` and
`XDG_CONFIG_HOME` values. Do not introduce an installation-directory override.
Before creating the initial clean source, the runner performs a disposable
copy-on-write probe from the checkout into the session filesystem. One shared
fixture-tree helper uses clone copies only after that probe succeeds and uses a
portable recursive-copy fallback otherwise. It materializes the clean source,
update source, catalog, profile, and other large disposable scenario trees.
Targets must be nonexistent descendants of the physical session root; empty,
root, repository, source-equal, source-descendant, escaped, and pre-existing
targets fail before copying. Internal symlinks, executable modes, Git metadata,
and copy independence are covered directly by runner tests.

The runner creates pristine default and upstream profiles once per session.
Scenarios that test installed-profile behavior rather than bootstrap behavior
copy those fixtures through the shared helper, then relocate generated
shell-init and implementation paths to the scenario profile. Self-update tests
also share one immutable committed source-repository fixture for the session.

After parent-only setup, selected groups run in one to three static workers
against immutable session fixtures and unique scenario roots. Group logs are
replayed in canonical order after all workers finish. Worker status, elapsed
time, group coverage, and assertion counts must all be present and consistent
before the parent accepts a run. Recorded live worker PIDs are the only
processes terminated during signal cleanup.
