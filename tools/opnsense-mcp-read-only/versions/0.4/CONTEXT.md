# OPNsense read-only MCP 0.4 runtime

`run.sh` validates the API URL and secret selectors before starting the
local-build MCP image. `refresh.sh` rebuilds and cleans stale local images for
`shimmy update --build` without requiring endpoint credentials or bypassing an
image override.

`image.conf` owns the local context/repository, configured Python base digest,
public registry access, and required platforms consumed by build/cache helpers
and `shimmy status`.

## Child contexts

- [container build context](container/CONTEXT.md)
