# Testing

Shimmy tests are POSIX shell scripts. Do not add test dependencies such as
`bats`, `jq`, `yq`, or coverage tools.

## Runner

Run the default source-checkout suite from the repository root:

```sh
./scripts/test-shimmy.sh
```

Installed profile smoke checks use the same runner with profile flags:

```sh
./scripts/test-shimmy.sh --profile default
./scripts/test-shimmy.sh --profile upstream --shim jq
./scripts/test-shimmy.sh --profile default --all
```

## Shared Helpers

Tests source `lib/repo/shimmy-test.sh` for assertions, scenario setup, cleanup,
and repository command execution. Keep common test behavior there instead of
copying assertion or temp-directory logic into individual tests.

The shared helpers intentionally stay POSIX-only and use only standard Unix
commands already required by the repository.

## Structure

Keep tests in existing repository locations:

- `scripts/test-shimmy.sh` is the canonical test entry point.
- `lib/repo/shimmy-test.sh` contains shared test utilities.
- `docs/testing.md` documents test conventions.

Do not create a separate `test/` tree.

Group tests by behavioral layer:

- helper/function checks for source-able shell helpers
- command behavior checks for argument parsing and output rendering
- install/profile integration checks for filesystem and manifest effects
- live shim smoke checks for representative Podman-backed execution

Prefer one canonical test per behavior per layer. Avoid repeating a full install
only to assert a nearby variant that is already covered by another layer.

## Assertions

Every test must assert meaningful behavior beyond exit status. Prefer checking:

- exact manifest keys
- expected files, directories, symlinks, and executable bits
- important stdout or stderr text
- both success and failure paths for each major command family

Use `assert_contains`, `assert_not_contains`, `assert_equals`,
`assert_file_exists`, `assert_file_contains`, `assert_path_symlink`,
`assert_path_not_exists`, and related helpers from `lib/repo/shimmy-test.sh`.

## Performance

Use one temp root per runner execution and one scenario directory per test that
needs isolation. Avoid repeated full installs unless they validate distinct
install, update, profile, or dispatcher behavior.

Live Podman checks should use non-mutating commands such as `--version`,
`--help`, or preview rendering. Keep installed-live-smoke coverage
representative rather than duplicating every direct shim smoke test.
