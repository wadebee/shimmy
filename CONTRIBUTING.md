# Contributing

This document is the entrypoint for contributing to the Shimmy project.

Use it as the source of truth for repository contribution guidance that should be readable by humans, automation and AI.

## Contributor Workflow

- Keep runtime shims small and readable.
- Update related implementation, tests, installer behavior, and user-facing docs together when behavior changes.
- Reuse established repo patterns before introducing new structure or naming.
- Keep runnable shell files executable.
- Treat Podman as an explicit Shimmy dependency. Do not install or provision it from Shimmy code, tests, or CI helpers.
- Use live Podman execution for shim tests. Do not replace `podman` with fake binaries or argv-only mocks when validating shim behavior.

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
- `lib/repo/shimmy-env.sh`
- `docs/prompt-shimmy-project.md`

### Function Naming

Use function names that are explicit, source-safe, and easy to scan.

- Do not use the `function` keyword.
- Keep functions in a file sorted alphabetically unless a different order materially improves readability.
- For shell functions, use the POSIX-safe `shimmy_` prefix to avoid collisions with other libraries or built-in commands.
- Internal helper functions that are not intended for external use should start with `shimmy__`.
- Use lowercase snake_case after the prefix.
- Keep token flow general to specific.
- Flag functions that return `0/1` or `true/false` intent should be prefixed with `is_`.
- Name flag functions so the predicate is obvious from the call site.

Patterns:

- public function: `shimmy_<resource>_<action>_<instance>`
- internal function: `shimmy__<resource>_<action>_<instance>`
- public flag function: `shimmy_is_<resource>_<state>`
- internal flag function: `shimmy__is_<resource>_<state>`

Examples:

- `shimmy_image_build_context_hash`
- `shimmy_is_shimmy_in_path`
- `shimmy_is_dir_in_path`
- `shimmy__is_token_in_manifest`
- `shimmy_install_path_render`
- `shimmy__log_level_normalize`
- `shimmy__shim_list_read`

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
- Any variable that Shimmy exports into the user's shell environment must use the `SHIMMY_` prefix.
- Use resource-first ordering where possible.
- Reuse established env var prefixes for tool shims.

Patterns:

- local value: `<resource>_<action>_<instance>`
- env var or constant: `<RESOURCE>_<ACTION>_<INSTANCE>`

Examples:

- `image_build_context`
- `install_dir_target`
- `shim_name_requested`
- `AWS_IMAGE`
- `SHIMMY_INSTALL_DIR`
- `SHIMMY_SHIM_DIR`

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
