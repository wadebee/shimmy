# Core test modules

These modules validate shared catalog and runtime behavior without starting
tool containers. They are sourced by `../test.sh` and use `../support.sh` for
fixtures and assertions.

## Files

- `catalog.sh` validates metadata discovery and preview dispatch.
- `runtime.sh` validates the shared Podman platform and preview helpers.
