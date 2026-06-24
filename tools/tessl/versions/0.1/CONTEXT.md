# Tessl 0.1 runtime

`run.sh` builds from `container/` unless an image override is selected.
`refresh.sh` rebuilds and cleans stale local images for `shimmy update --build`
without bypassing that override.

## Child contexts

- [container build context](container/CONTEXT.md)
