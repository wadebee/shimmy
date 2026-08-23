# Installation lifecycle

- `manifest.sh` solely renders schema-2 profile manifests.
- `transaction.sh` owns same-filesystem file candidates, authority revalidation,
  atomic replacement, exact rollback, and injected boundary tests.
- `catalog.sh` stages tracked clean-main catalog payloads, creates/reuses
  immutable generations, commits current/previous registry authority, rolls
  back, and never deletes retained generations.
- `profile.sh` stages complete profile candidates: canonical commands/libs,
  direct shim versions, launcher, shell initializer, engine binding, registry
  policy, manifest, and control/tool skill bundles. Profiles contain no tests
  or generated repository adapters.
- `lifecycle.sh` integrates fresh bootstrap, shared/isolated profile create,
  true profile clone, activation, target-engine image preparation, exact active
  authority, startup compensation, AI-skill reconciliation, dry-run, and
  failure cleanup.
- `uninstall.sh` owns profile deletion and global uninstall. Global removal
  preflights the complete local/external set, journals ordered owned-machine
  deletion before mutation, resumes irreversible partial progress, rejects
  reused names, resolves the active engine explicitly for last-place ordering,
  and preserves external or ambiguous engines.
- `launcher-template.sh` is the byte-authoritative final installed launcher for
  `admin`, `profile`, `catalog`, `shim`, and `ai-skill`.

Materialized controls include the published `lib/engine/` schema-1 registry and
dual-read bridge. Update installs those readers before explicit migration can
publish engine and binding records.

Initial bootstrap requires a clean committed attached `main`, creates only
`default`, publishes a shared engine/binding, installs jq/rg/Skopeo, activates
engine/registry authority, records the active profile, reconciles exact skill
links, and applies startup policy as one compensated lifecycle. Darwin creates
the owned `shimmy` machine; Linux records the host-local rootless engine. An
existing config root or exact Darwin name collision is never adopted or merged.
