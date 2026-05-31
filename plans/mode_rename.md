# Rename Mode To Profile

## Context

Shimmy currently uses `mode` wording for selected profile behavior. This project
is still new and has one user, so this should be a hard rename with no backward
compatibility for `--mode`, `SHIMMY_MODE`, `mode=`, or internal `*_MODE` names.

The rename should preserve unrelated uses of "mode", such as Podman rootless
mode, TTY mode, runtime mode, and Go/tooling documentation modes.

## Target Names

- CLI flag: `--mode` becomes `--profile`.
- Active profile environment variable: `SHIMMY_MODE` becomes
  `SHIMMY_PROFILE_ACTIVE`.
- Root manifest/status default profile field: `default_mode` and
  `shimmy_default_mode` become `shimmy_profile_default`.
- Selected profile manifest field: `mode=default` becomes
  `shimmy_profile_name=default`.

## Public Interface

Replace canonical CLI usage across `install`, `uninstall`, `activate`,
`status`, `update`, and `test`:

```sh
--profile default
--profile upstream
```

Remove `--mode` parsing from those commands. After the rename, `--mode` should
fail as an unknown argument.

Direct tool commands such as `rg` and `jq` should not accept `--profile`; they
should read `SHIMMY_PROFILE_ACTIVE` and dispatch through the selected profile.

## Profile Resolution

Profile selection precedence should be:

1. Explicit `--profile`.
2. `SHIMMY_PROFILE_ACTIVE`.
3. `default`.

Activation should export only `SHIMMY_PROFILE_ACTIVE`.

## Internal Code Vocabulary

Rename internal variables and helpers that model selected profile behavior:

- `REQUESTED_MODE` -> `SHIMMY_PROFILE_REQUESTED`
- `MODE_WAS_SELECTED` -> `SHIMMY_PROFILE_ACTIVATED`
- `SHIMMY_MODE_RESOLVED` -> `SHIMMY_PROFILE_RESOLVED`
- `SHIMMY_PROFILE_MODE` -> `SHIMMY_PROFILE_NAME`
- `shimmy_mode_resolve` -> `shimmy_profile_name_resolve`
- `shimmy_mode_validate` -> `shimmy_profile_name_validate`

Prefer local lowercase names only for short-lived local values that are not part
of the shared script contract. Shared state exported by `shimmy-profile.sh`
should use the `SHIMMY_PROFILE_*` vocabulary above.

## Manifest And Status Fields

Root manifest and manifest-format status output should use:

```text
shimmy_profile_default=default
```

Selected profile manifests should use:

```text
shimmy_profile_name=default
```

or:

```text
shimmy_profile_name=upstream
```

Manifest-format status output should emit the selected profile name as:

```text
shimmy_profile_name=default
```

Do not emit unscoped `mode=` or `default_mode=` fields after the rename.

## Diagnostics And Repair Hints

Update user-facing diagnostics to say "profile" when referring to selected
Shimmy profile behavior.

Examples:

```text
unsupported Shimmy profile: upstreamish
incomplete Shimmy profile default: expected manifest at ...
shimmy_repair_hint=shimmy install --profile upstream
shimmy_repair_hint=shimmy update --profile upstream
```

## Files To Update

Implementation:

- `lib/repo/shimmy-profile.sh`
- `scripts/install-shimmy.sh`
- `scripts/update-shimmy.sh`
- `scripts/test-shimmy.sh`
- `scripts/status-shimmy.sh`
- `scripts/activate-shimmy.sh`
- `scripts/dispatch-shimmy.sh`
- `shimmy`

Docs and agent guidance:

- `README.md`
- `CONTRIBUTING.md`
- `AGENTS.md`
- `docs/podman.md`
- `docs/prompt-shimmy-project.md`
- `docs/templates/generic-shim/`
- `.agents/skills/shimmy-*`

Avoid churn in unrelated Go skills and unrelated "mode" wording.

## Tests

Update tests in `scripts/test-shimmy.sh` to use:

- `--profile`
- `SHIMMY_PROFILE_ACTIVE`
- `shimmy_profile_name=...`
- `shimmy_profile_default=...`

Remove compatibility expectations for:

- `--mode`
- `SHIMMY_MODE`
- `mode=`
- `default_mode`
- `shimmy_default_mode`

Add negative coverage that `--mode` is rejected as an unknown argument.

## Verification

Run strict scans over project-owned files:

```sh
rg -- '--mode|SHIMMY_MODE|\bmode=' shimmy scripts lib docs README.md AGENTS.md CONTRIBUTING.md .agents/skills/shimmy-*
rg 'default_mode|shimmy_default_mode|REQUESTED_MODE|MODE_WAS_SELECTED|SHIMMY_MODE_RESOLVED|SHIMMY_PROFILE_MODE|shimmy_mode_' shimmy scripts lib
```

Run the behavioral test suite:

```sh
./scripts/test-shimmy.sh
```

If live Shimmy or Podman-backed validation fails because of wrapper approval,
Podman reachability, or sandbox symptoms, pause and use the Shimmy escalation
workflow rather than falling back to host tools.

## Risks

- Existing local install state using `mode=` will be incompatible. This is
  acceptable for the current project stage.
- Machine-readable status and manifest consumers must be updated together with
  the implementation.
- The broad text rename can accidentally touch unrelated "mode" concepts, so
  final scans must be reviewed by meaning, not only by raw match count.
