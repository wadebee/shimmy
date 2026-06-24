# OpenShift CLI 4.20 runtime

This is the metadata default version. `run.sh` builds from `container/` unless
overridden. `refresh.sh` rebuilds and cleans stale local images for
`shimmy update --build` without bypassing that override.

`status.conf` supplies the local-build description rendered by `shimmy status`.

## Child contexts

- [container build context](container/CONTEXT.md)
