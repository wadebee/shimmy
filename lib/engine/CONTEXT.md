# Engine lifecycle

Engine modules define the published schema registry for shared and
profile-isolated Podman engines. Every supported profile requires one strict
binding to one valid engine record.

- `state.sh` owns strict engine, binding, projection, and lifecycle records plus
  canonical engine paths.
- `podman.sh` owns exact machine/connection inspection and lifecycle calls,
  guest ownership markers, and rootless user-service recycling.
- `ownership.sh` owns CSPRNG tokens and the redundant host/guest/current-machine
  proof required before destructive operations.
- `lifecycle.sh` owns journal-first machine creation and removal primitives.
- `projection.sh` owns atomic engine registry projection, effective-policy
  fingerprints, service recycling, validation, and compensated rollback.
- `registry.sh` owns status, shared/host-local publication, fresh shared- and
  isolated-machine creation, isolated-create compensation, and projection
  freshness planning.

Machine names and bindings are routing information, not ownership evidence.
Missing or mismatched current evidence always preserves a machine. Only
`lib/profile/activation.sh` may change active profile/engine authority.
Creation transitions through `initializing` before `podman machine init` and
does not gain deletion authority until exact created identity is committed in
`initialized`; an earlier ambiguous machine is preserved with its journal.

## Parent context

- [shared library](../CONTEXT.md)
