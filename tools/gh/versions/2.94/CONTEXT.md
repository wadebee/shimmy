# GitHub CLI 2.94 runtime

`run.sh` selects an override or the local image built from `container/`.
`refresh.sh` rebuilds and cleans stale local images for `shimmy update --build`
without bypassing an image override. `smoke.conf` defines installed smoke
behavior.

## Child contexts

- [container build context](container/CONTEXT.md)
