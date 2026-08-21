# Default catalog authority

`catalog.sh` validates schema-1 catalog payloads, canonical management/tool
skills, tool/default/version metadata, concrete smoke/image metadata, safe
regular paths, and deterministic content fingerprints. Discovery is metadata-
driven and has no implementation-name or central tool routing map.

`state.sh` reads/renders the exact default registry, immutable generation
metadata, SHA-256 generation names, and profile catalog pins.

`authority.sh` validates the sole installation catalog `catalogs/default`, all
retained generation directory identities, current/previous provenance, and the
canonical skill warning/header contract. It renders local status and retained
tool discovery. Publication lifecycle lives in `lib/install/catalog.sh`.
