# Contributing

This document is the entrypoint for contributing to the Shimmy project.

Use it as the source of truth for repository contribution guidance that should be readable by humans, automation and AI.

## Contributor Workflow

- Keep runtime shims small and readable.
- Read root `CONTEXT.md` and the relevant retained child context before changing
  `commands/`, `lib/`, or `tests/`. Tool and management-plugin work uses this
  guide plus the tool guide or canonical skill; those trees do not own
  `CONTEXT.md` files.
- Update related implementation, tests, installer behavior, and user-facing docs together when behavior changes.
- When implementing a retained plan chunk, reconcile its objective verification
  checklist in the same change after validation. Mark only evidence-backed
  items complete; leave human review or acceptance gates pending until a human
  explicitly accepts them.
- Reuse established repo patterns before introducing new structure or naming.
- Keep runnable shell files executable.
- Follow `docs/testing.md` for POSIX-only test structure, shared assertions, and default-suite scope.
- Treat Podman as an explicit Shimmy dependency. Do not install or provision it from Shimmy code, tests, or CI helpers.
- Use live Podman execution for shim tests. Do not replace `podman` with fake binaries or argv-only mocks when validating shim behavior.
- Use the shared Podman helper for runtime platform selection. Supported Linux
  and Darwin hosts normalize `x86_64`/`amd64` and `aarch64`/`arm64`, then run
  the matching native `linux/amd64` or `linux/arm64` image. Unsupported or
  unreadable hosts fail closed.

## Profile Workflow

Shimmy has two built-in profiles, each installed as a complete independent
tree below `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`:

- `default` is the external-user profile and the default for top-level commands.
- `upstream` is the maintainer profile whose catalog binds to the recorded
  source checkout while installed tools execute from the profile
  materialization.

The root `install.sh` is a minimal bootstrap and the repository has no runnable
`shimmy` launcher. `./install.sh` selects `default`; only the bootstrap accepts
`--profile upstream`. Each installed profile has a self-contained
`bin/shimmy` launcher bound to its enclosing profile. Installed management and
tool commands have no profile-selection option or environment selector.

For source changes that should be tested through normal installed commands,
bootstrap the upstream profile, activate its deterministic engine through the
absolute launcher, then select its PATH:

```sh
. ./install.sh --profile upstream
profile_root=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream
"$profile_root/bin/shimmy" profile status
"$profile_root/bin/shimmy" profile activate --dry-run
"$profile_root/bin/shimmy" profile activate
. "$profile_root/shell-init.sh"
"$profile_root/bin/shimmy" status --format manifest
"$profile_root/bin/shimmy" test
rg --version
```

On macOS, activation may stop the one alternate Podman-managed VM. Running
containers block that stop unless interruption is separately acknowledged with
`--stop-running`. Contributors and agents must never provision, delete, rename,
or adopt machines through Shimmy workflows; a missing deterministic machine is
created by the user in a normal shell from the exact diagnostic guidance.

Every bootstrap installs jq and rg. Add other tools afterward through the
installed command, for example `shimmy install --shim task`. Executing
`./install.sh --profile upstream` is appropriate for automation but cannot
initialize its parent shell. Switch an existing shell by sourcing the desired
profile's absolute `shell-init.sh`; it prepends that profile's `bin/` directory
to `PATH`.

For repo-local previews, use `./commands/run-tool.sh rg --preview-shim
--version` or the concrete runtime selected by `tools/rg/tool.conf`. For
installed-state inspection, prefer `shimmy status --format manifest` over
`command -v <tool>`: `command -v` shows the invoking profile's dispatcher
entrypoint, while status shows that profile's manifest-derived metadata.

`SHIMMY_UPSTREAM_CHECKOUT_DIR` is the only upstream-specific path input. It
selects the absolute source checkout recorded when `./install.sh --profile
upstream` runs; it never relocates installed profile state.

The shared `upstream` catalog is a live binding to that validated checkout.
The shared `default` catalog is an immutable generation published only from a
clean committed upstream `HEAD`. Publication changes availability, not an
installed profile's materialization; selected tools adopt a new catalog
default only through an explicit profile install or update. Keep publication,
retained-generation rollback, explicit checkout rebind, profile uninstall, and
global owned-state uninstall as separate validated transactions.

Only `default` may create, repair, or remove Shimmy's persistent shell-startup
blocks. A fresh checkout bootstrap records one normalized shell from
`--shell` or `$SHELL`; managed policy records that shell's conventional exact
paths, while `--no-startup` records manual policy with no owned paths. Later
bootstraps inherit that immutable state, additive install never changes startup
files, and `shimmy update --repair-startup` consumes only the recorded ledger.
Changing policy requires uninstalling and recreating the profile. `upstream`
never changes shell startup files. Canonical
management and tool skills remain in the selected named catalog and are not
copied into profiles. Shared repository and home agent skill adapters live
outside profile roots and are owned by their target's
`.shimmy-skills-manifest.txt`. Profile lifecycle operations never implicitly
refresh or remove them. Use explicit standalone `shimmy skills install
--target repo|profile` or `shimmy skills update --target repo|profile`
operations to write them and `shimmy skills uninstall --target repo|profile`
for removal. Stage and validate complete skill output against one coherent
catalog snapshot before changing an external target.

After accepting canonical skill changes in a newer catalog generation, refresh
an existing repository or home adapter only through the explicit profile-local
`shimmy skills update --target repo|profile` operation. Never edit generated
`.agents/skills/` copies directly.

Repository and home `.agents/skills/<name>/` targets are one-file compatibility
adapters containing only `SKILL.md`. Do not copy other repository metadata
into those targets. The packaged management plugin is canonical source, not a
writable skills target.

## Shim Tool Workflow

Shimmy exposes logical tools as the user-facing commands on `PATH`.
Runtime behavior belongs in concrete major.minor version shims under those tools.

- Tool tools live at `tools/<tool>/tool.conf`; generic dispatch selects their default or selected version.
- Concrete version runtimes live at `tools/<tool>/versions/<major.minor>/run.sh` and contain Podman, image, mount, credential, and local-build logic.
- Every concrete version owns exactly one validated `image.conf`. Repository
  defaults are immutable OCI-index or Docker-manifest-list digests that declare
  both required platforms. Direct runtimes read their default from that file;
  local Containerfiles receive configured base defaults as build arguments and
  do not duplicate them.
- Every installable tool must have at least one concrete version and exactly one catalog default version.
- `shimmy install --shim <tool>` installs the tool dispatcher plus its default version. Use `shimmy install --shim <tool>@<version-label>` when a non-default version is needed.
- Profile manifests record `tool=` for installed user-facing commands and `tool_version=<tool>|<label>|<version>` for installed concrete versions.
- Do not put tool-specific runtime behavior in a tool dispatcher. Add or update the relevant version shim instead.

### Image selection and rotation

Choose the image strategy before adding a concrete version:

- Use `image_source=external` when a suitable publisher image exists.
- Use `image_source=local-build` when Shimmy must build a version-owned
  `container/` context. Every non-`scratch` base is part of the same image
  contract.

Every concrete version must own one valid `image.conf`. Repository defaults
must be fully qualified immutable OCI-index or Docker-manifest-list digests
whose descriptors include both `linux/amd64` and `linux/arm64`; tags belong in
the upstream discovery fields, not in default fields. Use the shared runtime
helpers for host OS/architecture selection and image consumption. Audit any
download URL, package, installer, or compiled dependency in a local build for
target-architecture behavior rather than assuming a multi-platform base is
sufficient.

Before accepting a new or rotated default, run `shimmy images verify` (or
`./commands/images.sh verify` from source) and native version-owned smokes on
Linux `amd64` and Apple Silicon macOS `arm64`. Cross-emulated builds do not
replace either native acceptance run.

Rotate a digest as a focused reviewed change:

1. Locate the publisher's intended tag or release reference.
2. Resolve its top-level index digest and verify both required platforms and
   any required registry authentication.
3. Update only the affected version's `image.conf` default and upstream
   discovery fields as applicable.
4. For a local build, confirm the derived cache identity changes.
5. Pull or build the selected native image and run the version-owned smoke on
   both native acceptance hosts.
6. Keep the prior digest recoverable in git history and identify it in review
   notes as the rollback reference.

Do not make remote registry checks part of the default offline suite. A
scheduled verifier requires a separately reviewed runner and credential
design.

`shimmy images verify` uses the profile-local Skopeo runtime and therefore
inherits a valid current invoking-profile registry redirect mount. Skopeo is
the only initial tool-container opt-in. Keep logical image references
unchanged, preserve explicit auth-secret handling, and do not infer that other
tool containers receive registry policy.

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
