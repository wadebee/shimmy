# Profile AI-skill bundles

`bundle.sh` is the private target schema reader, renderer, and pure content
validator for control and shims AI-skill bundles. It verifies exact metadata
order, source identities, lexical skill records, SHA-256 `SKILL.md` mappings,
frontmatter, and a regular link-free two-level bundle tree. User-link mutation
is outside this module and a later plan chunk.
