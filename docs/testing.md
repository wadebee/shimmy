# Testing

Run the repository suite from the root:

```sh
./shimmy test
```

To smoke an installed profile through its real wrappers, use:

```sh
shimmy test --profile default
shimmy test --profile upstream --all
shimmy test --profile default --shim oc@4.18
```

The profile mode validates the selected install manifests. By default it runs
each installed public kind; `--all` also runs every installed concrete version.
Those commands use live Podman only for the version-owned non-mutating smoke
arguments.

The suite is POSIX shell and validates:

- the complete `CONTEXT.md` tree and parent-to-child links, including every
  source-bearing canonical-skill, test-module, and container directory;
- metadata-derived tool kinds, versions, defaults, and selectors;
- preview rendering for every tool and every concrete runtime through its
  declared smoke argument, without contacting Podman;
- shared Podman platform and preview helpers plus POSIX syntax;
- disposable layout-version-2 default and upstream profile installs, installed
  command dispatch, status, update, legacy-layout rejection across management
  commands, and uninstall;
- activation, canonical skill export/removal, netinfo input rendering, and
  management-command argument validation;
- profile selection precedence, profile-isolated uninstalls, status
  availability, and profile-specific repair guidance;
- selected-shim and all-profile update refreshes, manifest lifecycle-field
  preservation, request validation, and installed-management source refresh;
- idempotent activation and explicit managed startup-block install and repair.
- canonical skill-source export, portable manifests, installed-kind selection,
  refresh, and manifest-tracked cleanup.
- source and installed dispatcher validation, including selector, profile, and
  recursion protections.
- deterministic netinfo CIDR rendering, explicit-host precedence, help, and
  malformed-input rejection.
- tool-owned Nmap preview coverage for explicit LAN, network, capability, and
  privilege controls.
- tool-owned OPNsense MCP preview coverage for URL normalization, read-only and
  admin secret separation, no-write defaults, and change-window guidance.
- additive install behavior, explicit uninstall-profile requests, and macOS
  Podman dependency guidance.

Use live Podman only for non-mutating commands such as `--version`, `version`,
or `--help`. Prefer `--preview-shim` whenever it proves the intended runtime
shape without pulling, building, or running a container.

The runner in `tests/test.sh` sources shared assertions from
`tests/support.sh`, core coverage from `tests/core/`, and management-command
coverage from `tests/commands/`. Tool-specific coverage belongs beside the
tool in `tools/<kind>/`. Keep one assertion-focused scenario per behavior and
preserve executable bits on shell entrypoints.
