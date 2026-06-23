# Testing

Run the repository suite from the root:

```sh
./shimmy test
```

The suite is POSIX shell and validates:

- the complete `CONTEXT.md` tree and parent-to-child links;
- metadata-derived tool kinds, versions, defaults, and selectors;
- preview rendering for every tool without contacting Podman;
- a clean layout-version-2 install, installed command dispatch, status, and
  uninstall lifecycle.

Use live Podman only for non-mutating commands such as `--version`, `version`,
or `--help`. Prefer `--preview-shim` whenever it proves the intended runtime
shape without pulling, building, or running a container.

Tool-specific coverage belongs beside the tool in `tools/<kind>/`; shared test
support belongs in `tests/support.sh`. Keep one assertion-focused scenario per
behavior and preserve executable bits on shell entrypoints.
