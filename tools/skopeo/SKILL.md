---
name: shimmy-tool-skopeo
description: Use and maintain the Skopeo Shimmy tool.
---

# Skopeo Shim

Read `CONTEXT.md`, `CONTRIBUTING.md`, and
`tools/skopeo/guide.md`. The concrete runtime is
`tools/skopeo/versions/1.22/run.sh`; preserve explicit registry auth
secret mounting and avoid default host credential mounts. A valid active
installed profile mounts its authoritative strict redirect policy read-only;
profiles with no activation omit it, while mismatched, damaged, stale, unsafe,
connection-overridden, or registry-overridden state fails closed. Policy
mounting does not provide credentials, corporate CA trust, or signature
policy.
