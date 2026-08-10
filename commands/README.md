# Commands

Files in this directory are executable management entrypoints invoked by a
profile-local `bin/shimmy` launcher. The minimal root `install.sh` bootstrap
also invokes `commands/install.sh` to create one canonical profile. These
entrypoints orchestrate metadata and shared behavior from `../lib/`; do not
put tool-specific runtime logic here.

See [CONTEXT.md](CONTEXT.md) for command ownership and each tool's `guide.md`,
`tool.conf`, and version-owned files for runtime behavior.

`shimmy images verify` checks pinned remote defaults and reports upstream-tag
drift without pulling target image layers. Use `--public-only` to visibly skip
authenticated entries, or provide the Skopeo runtime's explicit
`SHIMMY_SKOPEO_AUTH_SECRET` when those registries must be checked.

Manifest output is one pipe-delimited record per configured runtime or base:

```text
image_verify=<kind>|<version>|<role>|<digest>|<media-type>|<platform-result>|<access-result>|<drift-result>|<result>|<error>
```

Results are `pass`, `warning`, `skip`, or `fail`. Upstream movement produces a
warning unless strict drift checking is requested; authenticated public-only
entries produce `skip`, never `pass`.
