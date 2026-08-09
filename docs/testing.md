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

Switch installed profiles by evaluating the desired profile's absolute
`bin/shimmy` activation output before running `shimmy test`; installed test
commands do not select another profile.

The suite is POSIX shell and validates:

- the complete `CONTEXT.md` tree and parent-to-child links, including every
  source-bearing canonical-skill, test-module, and container directory;
- metadata-derived tool kinds, versions, defaults, and selectors;
- preview rendering for every tool and every concrete runtime through its
  declared smoke argument, without contacting Podman;
- shared Podman platform and preview helpers plus POSIX syntax;
- disposable version-3 flat default and upstream profile installs, installed
  command dispatch, status, update, legacy-layout rejection across management
  commands, and uninstall;
- activation, canonical skill export/removal, netinfo input rendering, and
  management-command argument validation;
- bootstrap-only profile selection, profile-isolated uninstalls, status
  availability, and profile-specific repair guidance;
- selected-shim profile-local update refreshes, manifest lifecycle-field
  preservation, request validation, and installed-management source refresh;
- idempotent activation, default-only managed startup-block install and repair,
  and upstream manual activation.
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

The runner in `tests/test.sh` sources shared assertions from
`tests/support.sh`, shared-library coverage from `tests/lib/`, and
management-command coverage from `tests/commands/`. Tool-specific coverage
belongs beside the tool in `tools/<kind>/`. Keep one assertion-focused scenario
per behavior and preserve executable bits on shell entrypoints.

Disposable installation scenarios set absolute temporary `HOME` and
`XDG_CONFIG_HOME` values. Do not introduce an installation-directory override.
