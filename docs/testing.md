# Testing

Run the repository suite from the root:

```sh
./tests/test.sh
```

To smoke an installed profile through its real wrappers, use:

```sh
shimmy test
shimmy test --all
shimmy test --shim oc@4.18
```

Installed test mode validates the invoking profile's manifest. By default it
runs each installed public kind; `--all` also runs every installed concrete
version. Those commands use live Podman only for the version-owned
non-mutating smoke arguments.

Switch installed profiles by sourcing the desired profile's absolute
`shell-init.sh` before running `shimmy test`; installed test commands do not
select another profile.

The suite is POSIX shell and validates:

- the complete `CONTEXT.md` tree and parent-to-child links, including every
  source-bearing canonical-skill, test-module, and container directory;
- metadata-derived tool kinds, versions, immutable image defaults, configured
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
- disposable version-4 flat default and upstream profile installs, installed
  command dispatch, status, update, legacy-layout rejection across management
  commands, and uninstall;
- shell initialization, canonical skill export/removal, netinfo input
  rendering, and management-command argument validation;
- bootstrap-only profile selection, profile-isolated uninstalls, status
  availability, and profile-specific repair guidance;
- selected-shim profile-local update refreshes, manifest lifecycle-field
  preservation, request validation, and installed-management source refresh;
- idempotent shell initialization, default-only managed startup-block install
  and repair, and direct upstream shell initialization.
- canonical skill-source export, target-owned portable manifests,
  installed-kind selection, refresh, and explicit manifest-tracked cleanup.
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

The runner in `tests/test.sh` sources shared assertions from
`tests/support.sh`, shared-library coverage from `tests/lib/`, and
management-command coverage from `tests/commands/`. Tool-specific coverage
belongs beside the tool in `tools/<kind>/`. Keep one assertion-focused scenario
per behavior and preserve executable bits on shell entrypoints.

Disposable installation scenarios set absolute temporary `HOME` and
`XDG_CONFIG_HOME` values. Do not introduce an installation-directory override.
The runner creates pristine default and upstream profiles once per session.
Scenarios that are testing installed-profile behavior rather than bootstrap
behavior may clone those fixtures; APFS copy-on-write is used when available,
with a portable recursive-copy fallback. Cloning relocates generated shell-init
and default implementation paths to the scenario profile. Self-update tests
also share one immutable committed source-repository fixture for the session.
