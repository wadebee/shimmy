# Test suite

`tests/test.sh` is a source-checkout-only runner. It validates the current
catalog before creating one private session root, detects copy-on-write support,
then runs named groups with one to three bounded workers. There is no installed-
profile test mode or session-wide compatibility profile fixture.

The runner registry contains promoted canonical library/command groups followed
by tool groups. Independently scheduled lifecycle scenario groups preserve
their internal transitions as indivisible units. Group logs replay in registry
order and exact count/status/worker artifacts fail closed. Timing-enabled runs
also retain canonical setup/group START evidence and elapsed setup/group/total
evidence on failure or interruption. Default execution uses three workers; use
serial only for one group or failure diagnosis.

Fixtures use absolute disposable XDG/HOME roots. Catalog-heavy groups create
clean local-main Git copies because publication validates real Git state and
tracked archive content. Selected lifecycle groups copy one session-owned,
clean, immutable Git template into scenario-private roots. Lifecycle tests use
fake Podman state only to exercise engine transaction boundaries; tool
acceptance uses live non-mutating runtimes.

Coverage preserves schema/ownership, unsafe-path, collision, locking,
transaction, rollback, engine/registry, startup, active-record, and exact skill-
link invariants. Do not add tests merely to prove removed files or aliases remain
absent.

## Child contexts

- [command tests](commands/CONTEXT.md)
- [library tests](lib/CONTEXT.md)
- tool-specific tests live under `tools/<tool>/tests/`
