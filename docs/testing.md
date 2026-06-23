# Testing

Run the repository suite from the root:

```sh
./shimmy test
```

The suite is POSIX shell and validates:

- the complete `CONTEXT.md` tree and parent-to-child links, including every
  source-bearing canonical-skill, test-module, and container directory;
- metadata-derived tool kinds, versions, defaults, and selectors;
- preview rendering for every tool without contacting Podman;
- shared Podman platform and preview helpers plus POSIX syntax;
- disposable layout-version-2 default and upstream profile installs, installed
  command dispatch, status, update, legacy-layout rejection, and uninstall;
- activation, canonical skill export/removal, netinfo input rendering, and
  management-command argument validation;
- profile selection precedence, profile-isolated uninstalls, status
  availability, and profile-specific repair guidance;
- selected-shim and all-profile update refreshes, manifest lifecycle-field
  preservation, and update request validation.

Use live Podman only for non-mutating commands such as `--version`, `version`,
or `--help`. Prefer `--preview-shim` whenever it proves the intended runtime
shape without pulling, building, or running a container.

The runner in `tests/test.sh` sources shared assertions from
`tests/support.sh`, core coverage from `tests/core/`, and management-command
coverage from `tests/commands/`. Tool-specific coverage belongs beside the
tool in `tools/<kind>/`. Keep one assertion-focused scenario per behavior and
preserve executable bits on shell entrypoints.
