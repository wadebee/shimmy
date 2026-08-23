# Engine lifecycle

Engine modules define the unpublished schema-1 foundation for shared and
profile-isolated Podman engines. Chunk 1 exposes no new command or profile
record; these modules are sourced so later chunks can publish the schema as one
compatibility unit.

- `state.sh` owns strict engine, binding, projection, and lifecycle records plus
  canonical engine paths.
- `podman.sh` owns exact machine/connection inspection and lifecycle calls,
  guest ownership markers, and rootless user-service recycling.
- `ownership.sh` owns CSPRNG tokens and the redundant host/guest/current-machine
  proof required before destructive operations.
- `lifecycle.sh` owns journal-first machine creation and removal primitives.
- `projection.sh` owns atomic engine registry projection, effective-policy
  fingerprints, service recycling, validation, and compensated rollback.

Machine names and bindings are routing information, not ownership evidence.
Missing or mismatched current evidence always preserves a machine. Only
`lib/profile/activation.sh` may change active profile/engine authority.

## Parent context

- [shared library](../CONTEXT.md)
