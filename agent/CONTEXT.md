# Canonical agent guidance

Canonical management skills live in `core/`; this name is unrelated to the
shared POSIX library in `../lib/`. Each tool's canonical skill is
co-located at `../tools/<kind>/agent/SKILL.md`. `commands/skills.sh` exports
only from those canonical sources. Installed profiles retain these canonical
sources under their flat `agent/core/` and `tools/<kind>/agent/` trees.

An exported `.agents/skills` tree is external state owned by its own
`.shimmy-skills-manifest.txt`, not by the supplying profile. Profile lifecycle
operations do not implicitly refresh or remove it; explicit `shimmy skills
uninstall --target <target>` is the removal path. The repository `.agents/`
tree remains an externally managed distribution adapter for existing sessions.
Repository and home adapters contain only the canonical `SKILL.md`; do not
copy other repository metadata into them.
Before regenerating it, migrate any richer adapter guidance into the canonical
skill and modernize only obsolete paths or lifecycle wording. Fingerprint
parity does not substitute for semantic preservation.

## Child contexts

- [core skills](core/CONTEXT.md)
