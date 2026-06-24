# OpenShift CLI 4.18 runtime

`run.sh` builds from `container/` unless a version-specific image override is
provided. `refresh.sh` rebuilds and cleans stale local images for
`shimmy update --build` without bypassing that override.

## Child contexts

- [container build context](container/CONTEXT.md)
