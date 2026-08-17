# Tests

`test.sh` is the canonical POSIX test runner, `runner.sh` owns the ordered
source-suite group registry, serial selection, option validation, and opt-in
timing, and `support.sh` provides shared assertions, scenarios, and cleanup.
`profile-smoke.sh` independently parses installed-profile test requests and
runs the enclosing profile's non-mutating smoke commands.
Smoke output capture preserves the wrapped command's exit status so engine or
tool failures cannot be reported as passes.
Tests use live Podman only for non-mutating commands; preview rendering is
preferred where it proves the same behavior. The default suite validates image
metadata offline and previews every concrete runtime across the supported
Linux/Darwin and amd64/arm64 host matrix.

Profile activation tests use a purpose-built Podman command seam and disposable
configuration roots. They verify discovery, workload guards, transition and
rollback ordering, and installed-runtime affinity without changing a developer
machine.

Registry redirect tests use disposable profile and containers configuration
roots. They validate strict parsing, deterministic rendering, locking, Linux
link ownership, Darwin same-path projection/link/record seams, fingerprint
freshness, restart requirements, transaction rollback, detach, and
install/uninstall preservation without contacting a registry or host engine.
Skopeo previews additionally prove exact read-only client mounting for the
active invoking profile, omission with no activation, and fail-closed sibling
or masking state.

Installation scenarios isolate state with absolute disposable `HOME` and
`XDG_CONFIG_HOME` values. They do not use a Shimmy installation-directory or
installed profile-selection override. Before the initial source snapshot, the
runner probes copy-on-write support from the checkout into the session
filesystem. One shared fixture-tree helper then materializes the clean source,
update source, catalogs, profiles, and large scenario trees with clone copies
when that probe succeeds and portable recursive copies otherwise. The helper
accepts only real source directories and nonexistent targets beneath the
physical session root; it rejects repository, source-equal, source-descendant,
pre-existing, and escaped targets. Recursive copies preserve internal
symlinks, modes, Git metadata, and independent mutation semantics.

The runner creates one disposable clean committed source checkout, then
creates pristine shared catalogs plus default and upstream profiles once per
session. Scenarios that do not need to exercise bootstrap or registration copy
those catalog and profile fixtures through the shared helper. Relocated
profiles rewrite the generated `shell-init.sh` path and every implementation
runtime root before use. Dirty-publication and live-upstream tests use isolated
Git checkout copies. The immutable committed source repository used by
self-update scenarios is also created once per session.
Source-suite runner options are validated before these session fixtures or the
session temporary root are created. Named groups execute serially in canonical
registry order in this phase; lifecycle prepare and complete are one
indivisible group. Timing records for setup, each selected group, and the total
run are emitted only when `SHIMMY_TEST_TIMING=1`.
Onboarding coverage sources the root
bootstrap to initialize PATH and executes it separately to verify automation
semantics.

`context-tree.sh` validates the retained hierarchical context links below
`commands/`, `lib/`, and `tests/`. It rejects any
`CONTEXT.md` below `tools/` or `plugins/shimmy/` and independently verifies
every concrete tool version's executable runtime and refresh hook plus its
smoke and image metadata.

Lifecycle coverage includes isolated default/upstream bootstrap, clean
publication, retained-generation rollback (including invalid-current
recovery), catalog-default adoption only on explicit update, source-loss
execution independence, profile-only uninstall, and explicit global removal
that preserves bound checkouts and external skill exports.

## Child contexts

- [shared-library behavior](lib/CONTEXT.md)
- [management commands](commands/CONTEXT.md)
