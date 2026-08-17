# Testing

Run the repository suite from the root:

```sh
./tests/test.sh
```

The source suite uses one canonical named group registry. The current runner
executes the registry serially; `--jobs` accepts the bounded interface that
later parallel orchestration will use without changing serial execution yet.
Use these commands to inspect or select coverage:

```sh
./tests/test.sh --list-groups
./tests/test.sh --group lib-runtime
./tests/test.sh --group lib-runtime --group tools-rg
./tests/test.sh --serial
./tests/test.sh --jobs 3
```

Repeated groups, unknown groups, invalid or duplicate job counts, and
conflicting `--serial`/`--jobs` or list/execution requests fail before session
fixture creation. Selected groups always run in canonical registry order. The
lifecycle prepare and complete sequence is exposed only as the single
`commands-lifecycle` group.

Opt in to integer-second setup, per-group, and total timing records with:

```sh
SHIMMY_TEST_TIMING=1 ./tests/test.sh --serial
```

Each record has the stable form
`shimmy_test_timing=<setup|group|total>|<name>|<elapsed-seconds>`. Timing
records are absent by default.

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
- disposable version-2 materialized default and upstream profile installs,
  named-catalog bootstrap isolation, installed command dispatch, status,
  catalog-default update, rollback, legacy-layout rejection, profile-isolated
  uninstall, and explicit global uninstall;
- shell initialization, canonical skill export/removal, netinfo input
  rendering, and management-command argument validation;
- bootstrap-only profile selection, profile-isolated uninstalls, status
  identity, named catalog listing, and profile-specific repair guidance;
- selected-shim profile-local default adoption and image refreshes, manifest
  lifecycle-field preservation, request validation, failed-update safety, and
  installed-management source refresh;
- idempotent shell initialization, default-only managed startup-block install
  and repair, and direct upstream shell initialization.
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
- additive install behavior, enclosing-profile uninstall requests, and macOS
  Podman dependency guidance.

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
