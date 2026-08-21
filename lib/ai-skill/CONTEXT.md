# Profile AI-skill bundles

`bundle.sh` reads, renders, and validates deterministic control and shim skill
bundles: exact metadata order, source identity, lexical skill records, SHA-256
`SKILL.md` mapping, frontmatter, warning header, and a regular link-free tree.

`link.sh` plans and applies exact direct-child mutations below the recorded user
skill root. Bundle-declared collisions are overwritten without backup or
recovery. Recognized Shimmy links are compensable; unrelated names and the root
itself are never recursively removed.

`ai-skill.sh` materializes bundles from an exact source commit or retained
catalog generation, validates profile-wide consistency, renders collision/list
output, and reconciles the active profile. Malformed supported bundles block
mutation; unsupported bundle kinds warn and are skipped.
