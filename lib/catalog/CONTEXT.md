# Shared catalog authority

`catalog.sh` is the single resolver and schema-1 validator for catalog-aware
commands. A profile records exactly one fixed catalog name in its manifest:
`upstream` resolves a registered live Git checkout and `default` resolves an
immutable generation under the shared XDG catalog registry. Consumers use the
resolved `SHIMMY_CATALOG_AUTHORITY_ROOT` and
`SHIMMY_CATALOG_TOOLS_DIR`; profile-local `tools/` is materialized execution
state, not availability authority.

Each payload has an exact `catalog.conf` identity plus `tools/` and
`plugins/shimmy/skills/`. Validation rejects unknown or duplicate metadata,
unsafe paths and links, unsupported schemas, incomplete management skills,
invalid tools or concrete versions, duplicate logical version names, and
invalid version-owned image metadata. Default generation resolution also
validates the registry, current and retained previous generation metadata,
and deterministic content fingerprints.

Tool and concrete-version discovery remains metadata-driven; this module must
not grow a central tool, version, or default list. Image schema details remain
in `../runtime/image.sh`.
