# Tools

Each child directory is a self-contained tool kind. `tool.conf` declares its
default version and optional selector environment; concrete versions live in
`versions/<major.minor>/`. Each concrete version owns `run.sh`, `refresh.sh`,
`smoke.conf`, and one validated `image.conf`. External defaults are immutable
multi-platform index digests. Local builds declare their context, local
repository, base-image build arguments, immutable base defaults, registry
access, and both required platforms in that configuration. Containerfiles do
not duplicate configured base defaults. A tool directory also owns its guide
and canonical agent skill.

## Child contexts

- [aws](aws/CONTEXT.md)
- [gcloud](gcloud/CONTEXT.md)
- [gdrive](gdrive/CONTEXT.md)
- [gh](gh/CONTEXT.md)
- [go](go/CONTEXT.md)
- [jq](jq/CONTEXT.md)
- [logmine](logmine/CONTEXT.md)
- [netcat](netcat/CONTEXT.md)
- [nmap](nmap/CONTEXT.md)
- [oc](oc/CONTEXT.md)
- [opnsense-mcp-admin](opnsense-mcp-admin/CONTEXT.md)
- [opnsense-mcp-read-only](opnsense-mcp-read-only/CONTEXT.md)
- [rg](rg/CONTEXT.md)
- [skopeo](skopeo/CONTEXT.md)
- [task](task/CONTEXT.md)
- [terraform](terraform/CONTEXT.md)
- [tessl](tessl/CONTEXT.md)
- [textual](textual/CONTEXT.md)
