# Profile AI-skill bundles

`bundle.sh` is the private target schema reader, renderer, and pure content
validator for control and shims AI-skill bundles. It verifies exact metadata
order, source identities, lexical skill records, SHA-256 `SKILL.md` mappings,
frontmatter, and a regular link-free two-level bundle tree. User-link mutation
is separate from bundle validation.

`link.sh` is private target-only exact-name planning and mutation. It accepts a
skill name only when a validated profile bundle declares it, classifies empty,
file, directory, foreign-link, broken-link, current, and wrong-profile states,
and replaces only that exact direct child of the recorded user root. Recognized
Shimmy links receive compensating rollback; overwritten foreign occupants are
never backed up or reported as recoverable. The API has no wildcard or
recursive user-root operation.
