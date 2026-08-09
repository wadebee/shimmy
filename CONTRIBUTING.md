# Contributing

This document is the entrypoint for contributing to the Shimmy project.

Use it as the source of truth for repository contribution guidance that should be readable by humans, automation and AI.

## Contributor Workflow

- Keep runtime shims small and readable.
- Read root `CONTEXT.md` and the relevant child context before changing a module.
- Update related implementation, tests, installer behavior, and user-facing docs together when behavior changes.
- Reuse established repo patterns before introducing new structure or naming.
- Keep runnable shell files executable.
- Follow `docs/testing.md` for POSIX-only test structure, shared assertions, and default-suite scope.
- Treat Podman as an explicit Shimmy dependency. Do not install or provision it from Shimmy code, tests, or CI helpers.
- Use live Podman execution for shim tests. Do not replace `podman` with fake binaries or argv-only mocks when validating shim behavior.
- Use the shared Podman helper for runtime platform selection. Linux shims run containers as `linux/amd64`; macOS shims run containers as `linux/arm64`.

## Profile Workflow

Shimmy has two built-in profiles, each installed as a complete independent
tree below `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`:

- `default` is the external-user profile and the default for top-level commands.
- `upstream` is the maintainer profile whose generated tool implementations
  dispatch to the recorded source checkout.

The root `install.sh` is a minimal bootstrap and the repository has no runnable
`shimmy` launcher. `./install.sh` selects `default`; only the bootstrap accepts
`--profile upstream`. Each installed profile has a self-contained
`bin/shimmy` launcher bound to its enclosing profile. Installed management and
tool commands have no profile-selection option or environment selector.

For source changes that should be tested through normal installed commands,
source the bootstrap for the upstream profile:

```sh
. ./install.sh --profile upstream
shimmy status --format manifest
shimmy test
rg --version
```

Every bootstrap installs jq and rg. Add other tools afterward through the
installed command, for example `shimmy install --shim task`. Executing
`./install.sh --profile upstream` is appropriate for automation but cannot
initialize its parent shell. Switch an existing shell by sourcing the desired
profile's absolute `shell-init.sh`; it prepends that profile's `bin/` directory
to `PATH`.

For repo-local previews, use `./commands/run-tool.sh rg --preview-shim --version` or the concrete runtime listed in `tools/rg/CONTEXT.md`. For installed-state inspection, prefer `shimmy status --format manifest` over `command -v <tool>`: `command -v` shows the invoking profile's dispatcher entrypoint, while status shows that profile's manifest-derived metadata.

`SHIMMY_UPSTREAM_CHECKOUT_DIR` is the only upstream-specific path input. It
selects the absolute source checkout recorded when `./install.sh --profile
upstream` runs; it never relocates installed profile state.

Only `default` may create, repair, or remove Shimmy's persistent shell-startup
block. `upstream` never changes shell startup files. Canonical agent sources
and packaged plugin skills are included unconditionally in each profile;
shared repository and home agent skills live outside profile roots and are
owned by their target's
`.shimmy-skills-manifest.txt`. Profile lifecycle operations never implicitly
refresh or remove them. Use explicit standalone `shimmy skills install
--target repo|profile` or `shimmy skills update --target repo|profile`
operations to write them and `shimmy skills uninstall --target repo|profile`
for removal. The `plugin` target is a packaged profile-local bundle, not a
shared external target.

## Shim Kind Workflow

Shimmy exposes logical tool kinds as the user-facing commands on `PATH`.
Runtime behavior belongs in concrete major.minor version shims under those kinds.

- Tool kinds live at `tools/<kind>/tool.conf`; generic dispatch selects their default or selected version.
- Concrete version runtimes live at `tools/<kind>/versions/<major.minor>/run.sh` and contain Podman, image, mount, credential, and local-build logic.
- Every installable kind must have at least one concrete version and exactly one catalog default version.
- `shimmy install --shim <kind>` installs the kind dispatcher plus its default version. Use `shimmy install --shim <kind>@<version-label>` when a non-default version is needed.
- Profile manifests record `kind=` for installed user-facing commands and `kind_version=<kind>|<label>|<version>` for installed concrete versions.
- Do not put tool-specific runtime behavior in a kind dispatcher. Add or update the relevant version shim instead.

## Naming Conventions

Use these naming conventions for files, functions, and variables unless a stronger repo-specific rule already exists.

Default to POSIX shell best practices when choosing names. Apply the overrides in this section when they are more specific.

### Naming Priorities

- Prefer names that read from general to specific, left to right.
- Arrange naming tokens in `{resource} {action} {instance}` order when that structure fits the thing being named.
- Reuse existing naming tokens when they clearly represent the thing being named.
- If clarity and reuse conflict, choose clarity.
- If two names are equally clear, choose the one that is more consistent with nearby code.

Examples:

- `shimmy_install_path_render`
- `image_build_context_hash`
- `aws_config_mount`

### Action Tokens

- Prefer action names that align with CRUD when that matches the real behavior.
- Do not force CRUD wording when a more specific verb is clearer.
- Choose the most truthful action available.

Prefer:

- `create`
- `read`
- `update`
- `delete`
- `render`
- `resolve`
- `install`
- `validate`

Avoid:

- vague verbs such as `handle`, `process`, or `do`
- misleading CRUD verbs when the function is actually rendering, resolving, normalizing, or validating

### File Naming

Use names that communicate role first, then scope.

- Public installed commands keep the CLI command name with no extension; source runtime entrypoints use `run.sh` below their version directory.
- Executable management commands in `commands/` and shared shell modules in `lib/` use lowercase kebab-case and end in `.sh`.
- Contributor-facing Markdown documents should use uppercase conventional names when they are standard repo entrypoints such as `README.md`, `AGENTS.md`, and `CONTRIBUTING.md`.
- Other documentation files should use lowercase kebab-case.

Examples:

- `tools/aws/versions/2.31/run.sh`
- `commands/install.sh`
- `lib/startup/startup.sh`
- `docs/prompt-shimmy-project.md`

### Function Naming

Use function names that are explicit, source-safe, and easy to scan.

- Do not use the `function` keyword.
- Keep functions in a file sorted alphabetically unless a different order materially improves readability.
- For shell functions, use the POSIX-safe `shimmy_` prefix to avoid collisions with other libraries or built-in commands.
- Internal helper functions that are not intended for external use should start with `shimmy__`.
- Use lowercase snake_case after the prefix.
- For shared shell helpers, prefer action-first names after the prefix: `shimmy_<action>_<resource>[_<resource_id>]`.
- Choose conformity when it improves scanning, but do not force action-first or CRUD wording when it makes the function less clear.
- Flag functions that return `0/1` or `true/false` intent should be prefixed with `is_`.
- Name flag functions so the predicate is obvious from the call site.
- Internal helper function names are not public API. Compatibility wrappers are not required when refactoring internal helpers; update all in-repo call sites instead.

Patterns:

- public shared helper: `shimmy_<action>_<resource>[_<qualifier>]`
- internal shared helper: `shimmy__<action>_<resource>[_<qualifier>]`
- public flag function: `shimmy_is_<resource>_<state>`
- internal flag function: `shimmy__is_<resource>_<state>`

Examples:

- `shimmy_read_manifest_value`
- `shimmy_resolve_path_absolute`
- `shimmy_validate_remove_path_safe`
- `shimmy_is_shimmy_in_path`
- `shimmy__read_shim_list`
- `shimmy__log_level_normalize`

Avoid:

- `function shimmy_install()`
- `shimmyInstall`
- `_shimmy_install`
- `shimmy::install_path_render`
- `install_shimmy_thing`

### Variable Naming

Choose variable names using the same general-to-specific token flow.

- Local shell variables should use lowercase snake_case.
- Exported environment variables and shared constants should use uppercase snake_case.
- Global environment variables should use uppercase snake_case and start with the `SHIMMY_` prefix.
- Any Shimmy-defined user-facing environment variable must use the `SHIMMY_` prefix, including image overrides, pull or build flags, opt-in behavior switches, and secret-name selectors.
- Non-`SHIMMY_` environment variables are allowed only when they are upstream-defined pass-through variables such as `AWS_*`, `TF_VAR_*`, or another tool's documented native configuration.
- Use resource-first ordering where possible.
- Reuse established env var prefixes for tool shims.

Patterns:

- local value: `<resource>_<action>_<instance>`
- env var or constant: `<RESOURCE>_<ACTION>_<INSTANCE>`

Examples:

- `image_build_context`
- `install_dir_target`
- `shim_name_requested`
- `SHIMMY_AWS_IMAGE`
- `SHIMMY_OC_VERSION`

Avoid:

- `installDir`
- `doThing`
- `tmp1`
- `foo`

### Consistency Rules

- When extending an existing area of the repo, prefer the established local vocabulary unless it is actively confusing.
- Do not rename only to introduce a personal preference.
- Rename when the current name is misleading, conflicts with these conventions, or blocks readability.
- In naming decisions, consistency is the tie-breaker.
