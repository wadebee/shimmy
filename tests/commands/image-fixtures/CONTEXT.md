# Image verification fixtures

Committed raw-manifest fixtures cover accepted OCI indexes and Docker manifest
lists plus malformed, single-manifest, unsupported-media-type, empty-list, and
missing-platform failures. They are consumed only through controlled Skopeo
and jq runtime fixtures, so the default suite never contacts target registries.

## Parent context

- [management-command tests](../CONTEXT.md)
