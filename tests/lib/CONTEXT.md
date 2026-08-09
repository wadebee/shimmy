# Shared-library test modules

These modules validate shared catalog and runtime behavior without starting
tool containers. They are sourced by `../test.sh` and use `../support.sh` for
fixtures and assertions.

## Files

- `catalog.sh` validates metadata discovery, preview dispatch, and concrete
  status metadata.
- `runtime.sh` validates the shared Podman platform and preview helpers.
- `update.sh` validates generic dispatch to version-local refresh hooks and the
  shared `pull`/`build` contract.
