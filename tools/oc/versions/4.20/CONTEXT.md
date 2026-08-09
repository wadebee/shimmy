# OpenShift CLI 4.20 runtime

This is the metadata default version. `run.sh` builds from `container/` unless
overridden. `refresh.sh` rebuilds and cleans stale local images for
`shimmy update --build` without bypassing that override.

`image.conf` owns the local context/repository, authenticated Red Hat base
digest, and required platforms consumed by build/cache helpers and
`shimmy status`.

## Child contexts

- [container build context](container/CONTEXT.md)
