---
name: shimmy-tool-oc
description: Use and maintain the context-first OpenShift CLI Shimmy tool.
---

# OpenShift CLI Shim

Read `../../../CONTEXT.md`, `../CONTEXT.md`, and the selected version context.
`SHIMMY_OC_VERSION` selects a supported local-build version; metadata defaults
to 4.20. Preserve publisher-supplied multi-architecture manifest-list digests
for default CLI images so the shared runtime helper can select the host platform.
Use `oc version --client` for non-network smoke checks.
