---
name: shimmy-tool-logmine
description: Use and maintain the Logmine Shimmy tool.
---

# Logmine Shim

Read `CONTEXT.md`, `CONTRIBUTING.md`, and
`tools/logmine/guide.md`.
Preserve local-image behavior and minimal host-integration mounts. The default
source ref is the immutable commit recorded in the Containerfile because the
upstream repository publishes no tags; verify a replacement ref before
rotation.
