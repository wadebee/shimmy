# Contributing

This document is the entrypoint for contributing to the Shimmy project.

Use it as the source of truth for repository contribution guidance that should be readable by humans, automation and AI.

## Contributor Workflow

- Keep runtime shims small and readable.
- Update related implementation, tests, installer behavior, and user-facing docs together when behavior changes.
- Reuse established repo patterns before introducing new structure or naming.
- Keep runnable shell files executable.
- Follow `docs/testing.md` for POSIX-only test structure, shared assertions, and default-suite scope.
- Treat Podman as an explicit Shimmy dependency. Do not install or provision it from Shimmy code, tests, or CI helpers.
- Use live Podman execution for shim tests. Do not replace `podman` with fake binaries or argv-only mocks when validating shim behavior.
- Use the shared Podman helper for runtime platform selection. Linux shims run containers as `linux/amd64`; macOS shims run containers as `linux/arm64`.

## Profile Workflow

Shimmy has one install root with two built-in profiles:

- `default` is the external-user profile and the default for top-level commands.
- `upstream` is the maintainer profile that dispatches installed tool commands to the recorded source checkout.

Profile precedence is explicit flag, then `SHIMMY_PROFILE_ACTIVE`, then `default`. Direct tool commands such as `rg` and `jq` do not accept `--profile`; they read `SHIMMY_PROFILE_ACTIVE` and dispatch through the selected profile.

Bare `shimmy install` creates or repairs only the default profile. Use `shimmy install --profile upstream` only when intentionally installing the maintainer profile.

For source changes that should be tested through normal installed commands, install and activate the upstream profile:

```sh
./shimmy install --profile upstream
eval "$(./shimmy activate --profile upstream)"
shimmy status --profile upstream --format manifest
shimmy test --profile upstream
SHIMMY_PROFILE_ACTIVE=upstream rg --version
```

Use repo-local wrapper paths such as `./shims/rg` only when intentionally testing source files directly. For installed-state inspection, prefer `shimmy status --format manifest` over `command -v <tool>`: `command -v` shows the stable dispatcher entrypoint, while status shows the selected profile manifest, implementation directory, and upstream checkout.

`SHIMMY_UPSTREAM_DIR` is Shimmy-managed profile state, defaulting under `$SHIMMY_INSTALL_DIR/p/upstream`. It is not the git checkout. Use `SHIMMY_UPSTREAM_CHECKOUT_DIR` only as an optional install-time override for `shimmy install --profile upstream`; Shimmy records that absolute checkout path in the upstream manifest.

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

- Runtime shims in `shims/` should keep the CLI command name with no extension.
- Executable repo scripts in `scripts/` should use lowercase kebab-case and end in `.sh`.
- Shared shell libraries in `lib/` should use lowercase kebab-case and end in `.sh`.
- Contributor-facing Markdown documents should use uppercase conventional names when they are standard repo entrypoints such as `README.md`, `AGENTS.md`, and `CONTRIBUTING.md`.
- Other documentation files should use lowercase kebab-case.

Examples:

- `shims/aws`
- `scripts/install-shimmy.sh`
- `lib/repo/shimmy-startup.sh`
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
- `SHIMMY_INSTALL_DIR`
- `SHIMMY_PROFILE_ACTIVE`

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
