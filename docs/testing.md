# Testing

Run the source-only repository suite from the root:

```sh
./tests/test.sh
```

The runner uses a canonical group registry and up to three bounded workers by
default. Selected groups run in registry order, write private logs, and replay
their output in that same order.

```sh
./tests/test.sh --list-groups
./tests/test.sh --group lib-runtime
./tests/test.sh --group commands-profile --group commands-shim
./tests/test.sh --jobs 3
./tests/test.sh --serial --group commands-lifecycle-migration
```

Use the default parallel schedule for independent groups. Use `--serial` for a
single group, an order-sensitive case, or failure diagnosis. Repeated or
unknown groups, invalid job counts, and conflicting runner options fail before
test execution.

Lifecycle acceptance is split into five independently selectable groups:
`commands-lifecycle-bootstrap`, `commands-lifecycle-isolated`,
`commands-lifecycle-migration`, `commands-lifecycle-uninstall`, and
`commands-lifecycle-end-to-end`. When any is selected, the runner prepares one
clean immutable checkout template, prunes ignored checkout-only content, and
copies that template into each scenario's private mutable root.

## Coverage model

The suite validates:

- context hierarchy, POSIX shell syntax, executable modes, and canonical file
  inventory;
- immutable catalog metadata, concrete version layouts, image policy, and
  source previews for Linux/Darwin and amd64/arm64;
- catalog publication, verification, and rollback;
- schema-2 profile state, arbitrary safe profile names, activation authority,
  registry projection, startup ledgers, and transactional rollback;
- profile-local shim add/remove/default/sync/test behavior;
- exact active-profile AI-skill link reconciliation and ownership;
- bootstrap, profile lifecycle, grouped launcher dispatch, and uninstall;
- focused behavior owned beside each tool under `tools/<tool>/tests/`.

Installed profiles do not contain the repository test suite or a separate
installed test command. Use `shimmy shim test [<tool[@version]> ...]` for the
version-owned, non-mutating smoke arguments of installed shims.

## Development workflow

Run affected groups while implementing, then run the complete default suite at
the final integration gate. Changes to the runner, shared fixtures, lifecycle,
or broadly consumed libraries justify an earlier complete run.

Use preview whenever it proves runtime shape without Podman:

```sh
./commands/run-tool.sh jq --preview-shim --version
./commands/run-tool.sh oc --preview-shim version
```

Use live Podman only for non-mutating commands such as `--version`, `version`,
or `--help`. Registry inspection is explicit and uses an installed profile:

```sh
shimmy catalog verify --public-only
shimmy catalog verify --tool oc@4.20 --public-only
shimmy catalog refresh netcat@7.92 --dry-run
```

Authenticated verification requires an explicitly selected
`SHIMMY_SKOPEO_AUTH_SECRET`; never put credential contents in output.
Catalog refresh uses the same boundary and must be exercised from a disposable
attached-main checkout. Existing staged, unstaged, and untracked work is
permitted because refresh validates and mutates only the selected `image.conf`.
If it finds drift, apply there, review the resulting source diff, then run the
version-owned smoke on both native hosts before committing or publishing. The
complete catalog is validated by publication.

## Native acceptance

An OCI index proves descriptor presence, not runtime correctness. New or
rotated images require the concrete version's smoke command on native Linux
`amd64` and native Apple Silicon macOS `arm64`. Build local images on each host
before smoking them. Preview and cross-emulation do not replace either native
result. Record any reviewer-approved deferral explicitly.

## Timing and signals

Opt into coarse timing records with:

```sh
SHIMMY_TEST_TIMING=1 ./tests/test.sh
```

Each record has the stable form
`shimmy_test_timing=<setup|group|total>|<name>|<elapsed-seconds>`.
Timing-enabled runs also emit stable progress records before setup or group work:
`shimmy_test_progress=<setup|group>|<name>|START`. Group progress is buffered in
the group's private log and replayed in canonical registry order. Lifecycle
selection adds a separately timed `lifecycle-checkout-template` setup record.
Ordinary failures retain total timing, while interrupted timing-enabled runs
replay any partial group log and retain elapsed active setup or group plus total
timing before cleanup. Timing-disabled output remains unchanged.

Selected groups execute in child processes. Test sourced signal cleanup by
invoking the installed handler and asserting its status and state. Kernel-level
SIGINT delivery belongs in parent-runner coverage because background POSIX
shells may inherit SIGINT as ignored.
