# OPNsense read-only MCP 0.4 runtime

`run.sh` validates the API URL and secret selectors before starting the
local-build MCP image. `refresh.sh` rebuilds and cleans stale local images for
`shimmy update --build` without requiring endpoint credentials or bypassing an
image override.

## Child contexts

- [container build context](container/CONTEXT.md)
